import pytest
import jwt
from app.sys.auth import issue_token

pytestmark = pytest.mark.sys


def test_sem_contrato_nao_finge_login(db, client):
    r = client.post(
        "/api/v1/sys/login", json={"email": "x@teste.invalid", "senha": "abc"}
    )
    assert r.status_code == 503
    assert client.get("/api/v1/status").json()["autenticacao_core"] == "pendente"


def test_token_assinado(monkeypatch):
    monkeypatch.setenv("JWT_SECRET", "a" * 64)
    token, jti, end = issue_token(123)
    body = jwt.decode(
        token, "a" * 64, algorithms=["HS256"], audience="erp-api", issuer="erp"
    )
    assert body["sub"] == "123" and body["jti"] == jti


def test_anonimo_nao_acessa(client):
    assert client.get("/api/v1/sys/usuarios").status_code == 401


def test_login_senha_errada(identities, client):
    assert (
        client.post(
            "/api/v1/sys/login",
            json={"email": "admin@teste.invalid", "senha": "errada"},
        ).status_code
        == 401
    )


def test_logout_revoga_token(db, client, admin):
    assert client.get("/api/v1/sys/me", headers=admin).status_code == 200
    assert client.post("/api/v1/sys/logout", headers=admin).status_code == 200
    assert client.get("/api/v1/sys/me", headers=admin).status_code == 401
    events = db.execute("SELECT evento FROM sys.log_acessos ORDER BY id").fetchall()
    assert [e["evento"] for e in events] == ["login", "logout"]


def test_operador_negado_sem_permissao(identities, client):
    token = client.post(
        "/api/v1/sys/login",
        json={"email": "operador@teste.invalid", "senha": "SomenteTeste123"},
    ).json()["access_token"]
    assert (
        client.get(
            "/api/v1/sys/usuarios", headers={"Authorization": "Bearer " + token}
        ).status_code
        == 403
    )


def test_usuario_desativado_perde_acesso(db, client, admin):
    db.execute("UPDATE test_support.identidades SET ativo=false WHERE id=101")
    assert client.get("/api/v1/sys/me", headers=admin).status_code == 401


def test_parametros_auditoria_e_exclusao(db, client, admin):
    body = {"chave": "politica.retencao_dias", "valor": 30, "descricao": "Retencao"}
    assert (
        client.put("/api/v1/sys/parametros", headers=admin, json=body).status_code
        == 200
    )
    assert client.get("/api/v1/sys/parametros", headers=admin).json()[0]["valor"] == 30
    assert (
        db.execute(
            "SELECT created_by FROM sys.auditorias WHERE tabela='sys.parametrizacoes'"
        ).fetchone()["created_by"]
        == 101
    )
    assert (
        client.delete(
            "/api/v1/sys/parametros/politica.retencao_dias", headers=admin
        ).status_code
        == 200
    )
    assert client.get("/api/v1/sys/parametros", headers=admin).json() == []


def test_ultimo_admin_protegido(db, client, admin):
    pid = db.execute("SELECT id FROM sys.perfis WHERE nome='role_dba'").fetchone()["id"]
    assert (
        client.delete(
            f"/api/v1/sys/usuarios/101/perfis/{pid}", headers=admin
        ).status_code
        == 409
    )


def test_permissao_concedida_e_revogada(db, client, admin):
    pid = db.execute("SELECT id FROM sys.perfis WHERE nome='role_operador'").fetchone()[
        "id"
    ]
    pm = db.execute("SELECT id FROM sys.permissoes WHERE codigo='dw.ler'").fetchone()[
        "id"
    ]
    assert (
        client.put(
            "/api/v1/sys/usuarios-perfis",
            headers=admin,
            json={"usuario_id": 102, "perfil_id": pid},
        ).status_code
        == 200
    )
    assert (
        client.put(
            "/api/v1/sys/perfis-permissoes",
            headers=admin,
            json={"perfil_id": pid, "permissao_id": pm},
        ).status_code
        == 200
    )
    token = client.post(
        "/api/v1/sys/login",
        json={"email": "operador@teste.invalid", "senha": "SomenteTeste123"},
    ).json()["access_token"]
    headers = {"Authorization": "Bearer " + token}
    assert client.get("/api/v1/dw/paineis/vendas", headers=headers).status_code == 200
    assert (
        client.delete(
            f"/api/v1/sys/perfis/{pid}/permissoes/{pm}", headers=admin
        ).status_code
        == 200
    )
    assert client.get("/api/v1/dw/paineis/vendas", headers=headers).status_code == 403


def test_vinculo_core_inexistente(db, client, admin):
    pid = db.execute("SELECT id FROM sys.perfis WHERE nome='role_dba'").fetchone()["id"]
    assert (
        client.put(
            "/api/v1/sys/usuarios-perfis",
            headers=admin,
            json={"usuario_id": 999, "perfil_id": pid},
        ).status_code
        == 404
    )


def test_limite_payload(client):
    assert client.post("/api/v1/sys/login", content=b"x" * 262145).status_code == 413
