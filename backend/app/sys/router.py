from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from psycopg.types.json import Jsonb
from app.db import connection
from app.sys.auth import current_user, permission, issue_token, require_contract

router = APIRouter(prefix="/api/v1/sys", tags=["Administracao"])


class Login(BaseModel):
    email: str = Field(min_length=3, max_length=254)
    senha: str = Field(min_length=1, max_length=72)


class Parametro(BaseModel):
    chave: str = Field(min_length=1, max_length=100, pattern=r"^[a-zA-Z0-9_.-]+$")
    valor: dict | list | str | int | float | bool | None
    descricao: str = Field(default="", max_length=500)


class Vinculo(BaseModel):
    usuario_id: int = Field(gt=0)
    perfil_id: int = Field(gt=0)


class PermissaoPerfil(BaseModel):
    perfil_id: int = Field(gt=0)
    permissao_id: int = Field(gt=0)


@router.post("/login")
def login(body: Login):
    with connection() as conn:
        require_contract(conn)
        row = conn.execute(
            """SELECT id FROM sys.vw_identidades_core WHERE lower(email)=lower(%s)
          AND ativo AND deleted_at IS NULL AND senha_hash=crypt(%s,senha_hash)""",
            (body.email, body.senha),
        ).fetchone()
        if not row:
            raise HTTPException(401, "Email ou senha invalidos")
        token, jti, end = issue_token(row["id"])
        conn.execute(
            "INSERT INTO sys.sessoes(usuario_id,jti,expira_em,created_by) VALUES(%s,%s,%s,%s)",
            (row["id"], jti, end, row["id"]),
        )
    return {"access_token": token, "token_type": "bearer"}


@router.get("/me")
def me(user=Depends(current_user)):
    with connection(user["id"]) as conn:
        perms = conn.execute(
            "SELECT codigo FROM sys.permissoes WHERE sys.fn_usuario_tem_permissao(%s,codigo)",
            (user["id"],),
        ).fetchall()
    return {
        "id": user["id"],
        "email": user["email"],
        "permissoes": [p["codigo"] for p in perms],
    }


@router.post("/logout")
def logout(user=Depends(current_user)):
    with connection(user["id"]) as conn:
        conn.execute(
            "UPDATE sys.sessoes SET revogada_em=now(),updated_at=now() WHERE jti=%s",
            (user["jti"],),
        )
    return {"ok": True}


@router.get("/usuarios")
def usuarios(user=Depends(permission("sys.ler"))):
    with connection(user["id"]) as conn:
        return conn.execute("""SELECT u.id,u.email,u.ativo,coalesce(p.perfis,'{}') perfis
          FROM sys.vw_identidades_core u LEFT JOIN sys.vw_usuarios_perfis p ON p.usuario_id=u.id
          WHERE u.deleted_at IS NULL ORDER BY u.id LIMIT 500""").fetchall()


@router.get("/perfis")
def perfis(user=Depends(permission("sys.ler"))):
    with connection(user["id"]) as conn:
        return conn.execute(
            "SELECT id,nome FROM sys.perfis WHERE deleted_at IS NULL ORDER BY id"
        ).fetchall()


@router.get("/permissoes")
def permissoes(user=Depends(permission("sys.ler"))):
    with connection(user["id"]) as conn:
        return conn.execute(
            "SELECT id,codigo,descricao FROM sys.permissoes WHERE deleted_at IS NULL ORDER BY id"
        ).fetchall()


@router.get("/perfis-permissoes")
def permissoes_perfis(user=Depends(permission("sys.ler"))):
    with connection(user["id"]) as conn:
        return conn.execute(
            "SELECT perfil_id,permissao_id FROM sys.perfis_permissoes WHERE deleted_at IS NULL ORDER BY perfil_id,permissao_id"
        ).fetchall()


@router.put("/usuarios-perfis")
def vincular(body: Vinculo, user=Depends(permission("sys.escrever"))):
    with connection(user["id"]) as conn:
        if not conn.execute(
            "SELECT id FROM sys.vw_identidades_core WHERE id=%s AND ativo AND deleted_at IS NULL",
            (body.usuario_id,),
        ).fetchone():
            raise HTTPException(404, "Usuario ativo nao encontrado no core")
        conn.execute(
            "INSERT INTO sys.usuarios_perfis(usuario_id,perfil_id) VALUES(%s,%s) ON CONFLICT(usuario_id,perfil_id) DO UPDATE SET deleted_at=NULL",
            (body.usuario_id, body.perfil_id),
        )
    return {"ok": True}


@router.delete("/usuarios/{usuario_id}/perfis/{perfil_id}")
def desvincular(
    usuario_id: int, perfil_id: int, user=Depends(permission("sys.escrever"))
):
    with connection(user["id"]) as conn:
        conn.execute("SELECT pg_advisory_xact_lock(41001)")
        target = conn.execute(
            "SELECT nome FROM sys.perfis WHERE id=%s", (perfil_id,)
        ).fetchone()
        if target and target["nome"] in ("role_ceo", "role_dba"):
            other = conn.execute(
                """SELECT 1 FROM sys.usuarios_perfis up JOIN sys.perfis p ON p.id=up.perfil_id
             JOIN sys.vw_identidades_core u ON u.id=up.usuario_id
             WHERE up.deleted_at IS NULL AND p.nome IN ('role_ceo','role_dba') AND u.ativo AND u.deleted_at IS NULL
             AND NOT(up.usuario_id=%s AND up.perfil_id=%s) LIMIT 1""",
                (usuario_id, perfil_id),
            ).fetchone()
            if not other:
                raise HTTPException(
                    409, "Nao e permitido remover o ultimo administrador ativo"
                )
        conn.execute(
            "UPDATE sys.usuarios_perfis SET deleted_at=now() WHERE usuario_id=%s AND perfil_id=%s",
            (usuario_id, perfil_id),
        )
        conn.execute("CALL sys.sp_revogar_sessoes(%s)", (usuario_id,))
    return {"ok": True}


@router.put("/perfis-permissoes")
def conceder(body: PermissaoPerfil, user=Depends(permission("sys.escrever"))):
    with connection(user["id"]) as conn:
        conn.execute(
            "INSERT INTO sys.perfis_permissoes(perfil_id,permissao_id) VALUES(%s,%s) ON CONFLICT(perfil_id,permissao_id) DO UPDATE SET deleted_at=NULL",
            (body.perfil_id, body.permissao_id),
        )
    return {"ok": True}


@router.delete("/perfis/{perfil_id}/permissoes/{permissao_id}")
def revogar(
    perfil_id: int, permissao_id: int, user=Depends(permission("sys.escrever"))
):
    with connection(user["id"]) as conn:
        conn.execute(
            "UPDATE sys.perfis_permissoes SET deleted_at=now() WHERE perfil_id=%s AND permissao_id=%s",
            (perfil_id, permissao_id),
        )
    return {"ok": True}


@router.get("/parametros")
def parametros(user=Depends(permission("sys.ler"))):
    with connection(user["id"]) as conn:
        return conn.execute(
            "SELECT chave,valor,descricao FROM sys.parametrizacoes WHERE deleted_at IS NULL ORDER BY chave"
        ).fetchall()


@router.put("/parametros")
def parametro(body: Parametro, user=Depends(permission("sys.escrever"))):
    with connection(user["id"]) as conn:
        conn.execute(
            "INSERT INTO sys.parametrizacoes(chave,valor,descricao) VALUES(%s,%s,%s) ON CONFLICT(chave) DO UPDATE SET valor=excluded.valor,descricao=excluded.descricao,deleted_at=NULL",
            (body.chave, Jsonb(body.valor), body.descricao),
        )
    return {"ok": True}


@router.delete("/parametros/{chave}")
def excluir_parametro(chave: str, user=Depends(permission("sys.escrever"))):
    with connection(user["id"]) as conn:
        conn.execute(
            "UPDATE sys.parametrizacoes SET deleted_at=now() WHERE chave=%s", (chave,)
        )
    return {"ok": True}


@router.get("/monitoramento")
def monitoramento(user=Depends(permission("sys.ler"))):
    with connection(user["id"]) as conn:
        return conn.execute("SELECT * FROM sys.vw_consultas_lentas LIMIT 50").fetchall()


@router.get("/acessos")
def acessos(user=Depends(permission("sys.ler"))):
    with connection(user["id"]) as conn:
        return conn.execute(
            "SELECT usuario_id,evento,created_at FROM sys.log_acessos ORDER BY id DESC LIMIT 100"
        ).fetchall()
