"""Fixtures existem apenas no banco descartavel *_test. Nunca sao seeds do ERP."""

import os
import pytest
import psycopg
from psycopg.rows import dict_row
from fastapi.testclient import TestClient
from app.main import app


@pytest.fixture
def db():
    url = os.environ.get("TEST_DATABASE_URL")
    if not url:
        pytest.skip("TEST_DATABASE_URL nao configurada")
    if os.environ.get("ALLOW_TEST_FIXTURES") != "1":
        raise RuntimeError("Confirme ALLOW_TEST_FIXTURES=1")
    with psycopg.connect(url, autocommit=True, row_factory=dict_row) as conn:
        name = conn.execute("SELECT current_database() db").fetchone()["db"]
        if not name.endswith("_test"):
            raise RuntimeError("Fixtures somente em banco *_test")
        # Limpa somente dados de teste, preservando catalogos e historico Flyway.
        conn.execute("ALTER TABLE integ.blocos DISABLE TRIGGER USER")
        conn.execute(
            "TRUNCATE integ.blocos,integ.eventos,integ.log_chamadas,integ.resumos_sensores,sys.sessoes,sys.log_acessos,sys.usuarios_perfis,sys.perfis_permissoes,sys.parametrizacoes,sys.auditorias,dw.dim_tempo,dw.dim_clientes,dw.dim_produtos,dw.dim_fornecedores,dw.fato_vendas,dw.fato_financeiro,dw.fato_estoque,dw.fato_producao,dw.previsoes_demanda RESTART IDENTITY CASCADE"
        )
        conn.execute("ALTER TABLE integ.blocos ENABLE TRIGGER USER")
        conn.execute("DROP VIEW IF EXISTS sys.vw_identidades_core")
        conn.execute("DROP SCHEMA IF EXISTS test_support CASCADE")
        yield conn
        conn.execute("DROP VIEW IF EXISTS sys.vw_identidades_core")
        conn.execute("DROP SCHEMA IF EXISTS test_support CASCADE")


@pytest.fixture
def identities(db):
    db.execute("CREATE SCHEMA test_support")
    db.execute(
        "CREATE TABLE test_support.identidades(id bigint PRIMARY KEY,email text,senha_hash text,ativo boolean,deleted_at timestamptz)"
    )
    db.execute(
        "INSERT INTO test_support.identidades VALUES(101,'admin@teste.invalid',crypt('SomenteTeste123',gen_salt('bf')),true,NULL),(102,'operador@teste.invalid',crypt('SomenteTeste123',gen_salt('bf')),true,NULL)"
    )
    db.execute(
        "CREATE VIEW sys.vw_identidades_core AS SELECT * FROM test_support.identidades"
    )
    db.execute("GRANT SELECT ON sys.vw_identidades_core TO erp_app")
    db.execute(
        "INSERT INTO sys.usuarios_perfis(usuario_id,perfil_id) SELECT 101,id FROM sys.perfis WHERE nome='role_dba'"
    )
    return db


@pytest.fixture
def client():
    with TestClient(app) as cli:
        yield cli


@pytest.fixture
def admin(identities, client):
    response = client.post(
        "/api/v1/sys/login",
        json={"email": "admin@teste.invalid", "senha": "SomenteTeste123"},
    )
    assert response.status_code == 200, response.text
    return {"Authorization": "Bearer " + response.json()["access_token"]}
