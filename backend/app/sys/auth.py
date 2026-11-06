import os
from datetime import datetime, timedelta, timezone
from uuid import uuid4
import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.db import connection, has_identity_contract

bearer = HTTPBearer(auto_error=False)


def secret():
    value = os.environ.get("JWT_SECRET", "")
    if len(value) < 32:
        raise HTTPException(503, "Configure JWT_SECRET com pelo menos 32 caracteres")
    return value


def require_contract(conn):
    if not has_identity_contract(conn):
        raise HTTPException(
            503, "Cadastro core ainda nao integrado. Consulte docs/CONTRATOS.md."
        )


def issue_token(usuario_id):
    now = datetime.now(timezone.utc)
    jti = str(uuid4())
    end = now + timedelta(minutes=30)
    token = jwt.encode(
        {
            "sub": str(usuario_id),
            "jti": jti,
            "iat": now,
            "exp": end,
            "iss": "erp",
            "aud": "erp-api",
        },
        secret(),
        algorithm="HS256",
    )
    return token, jti, end


def current_user(credentials: HTTPAuthorizationCredentials = Depends(bearer)):
    if not credentials:
        raise HTTPException(401, "Autenticacao obrigatoria")
    try:
        claims = jwt.decode(
            credentials.credentials,
            secret(),
            algorithms=["HS256"],
            audience="erp-api",
            issuer="erp",
            options={"require": ["sub", "jti", "exp", "iat", "aud", "iss"]},
        )
        uid = int(claims["sub"])
        from uuid import UUID

        UUID(claims["jti"])
    except (jwt.PyJWTError, ValueError, TypeError):
        raise HTTPException(401, "Token invalido ou expirado") from None
    with connection(uid) as conn:
        require_contract(conn)
        row = conn.execute(
            """SELECT u.id,u.email FROM sys.vw_identidades_core u JOIN sys.sessoes s
          ON s.usuario_id=u.id WHERE u.id=%s AND u.ativo AND u.deleted_at IS NULL
          AND s.jti=%s AND s.revogada_em IS NULL AND s.expira_em>now()""",
            (uid, claims["jti"]),
        ).fetchone()
        if not row:
            raise HTTPException(401, "Sessao revogada ou usuario inativo")
    return {**row, "jti": claims["jti"]}


def permission(code):
    def dependency(user=Depends(current_user)):
        with connection(user["id"]) as conn:
            allowed = conn.execute(
                "SELECT sys.fn_usuario_tem_permissao(%s,%s) ok", (user["id"], code)
            ).fetchone()["ok"]
        if not allowed:
            raise HTTPException(403, "Permissao insuficiente")
        return user

    return dependency
