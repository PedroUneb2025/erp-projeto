import hashlib
import hmac
import json
import os
import time
from urllib.parse import urlsplit
import httpx
from psycopg.types.json import Jsonb
from app.db import connection


def valid_signature(raw: bytes, timestamp: str, signature: str, secret: str, now=None):
    try:
        stamp = int(timestamp)
    except (ValueError, TypeError):
        return False
    if abs((time.time() if now is None else now) - stamp) > 300:
        return False
    expected = hmac.new(
        secret.encode(), timestamp.encode() + b"." + raw, hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(signature, "sha256=" + expected)


def connector_config():
    configs = json.loads(os.environ.get("CONNECTORS_JSON", "{}"))
    for name, cfg in configs.items():
        url = urlsplit(cfg["url"])
        if (
            url.scheme != "https"
            or not url.hostname
            or url.username
            or url.password
            or url.fragment
        ):
            raise ValueError("Conectores exigem URL HTTPS sem credenciais na URL")
        if not name or not isinstance(cfg.get("token_env", ""), str):
            raise ValueError("Configuracao de conector invalida")
    return configs


def enqueue(conn, canal, key, payload, direction):
    row = conn.execute(
        """INSERT INTO integ.eventos(canal,chave,payload,direcao,estado)
      VALUES(%s,%s,%s,%s,%s) ON CONFLICT(canal,chave,direcao) DO NOTHING RETURNING id""",
        (
            canal,
            key,
            Jsonb(payload),
            direction,
            "recebido" if direction == "entrada" else "pendente",
        ),
    ).fetchone()
    if row:
        return row["id"], True
    existing = conn.execute(
        "SELECT id,payload FROM integ.eventos WHERE canal=%s AND chave=%s AND direcao=%s",
        (canal, key, direction),
    ).fetchone()
    if existing["payload"] != payload:
        raise ValueError("Chave de idempotencia reutilizada com outro conteudo")
    return existing["id"], False


def deliver_one():
    configs = connector_config()
    if not configs:
        return False
    with connection() as conn:
        row = conn.execute(
            """SELECT * FROM integ.eventos WHERE estado='pendente' AND direcao='saida'
          AND deleted_at IS NULL AND proxima_tentativa<=now() AND canal=ANY(%s)
          ORDER BY id FOR UPDATE SKIP LOCKED LIMIT 1""",
            (list(configs),),
        ).fetchone()
        if not row:
            return False
        cfg = configs[row["canal"]]
        headers = {"Idempotency-Key": row["chave"]}
        token = os.environ.get(cfg.get("token_env", ""), "")
        if token:
            headers["Authorization"] = "Bearer " + token
        start = time.monotonic()
        status = None
        error = None
        try:
            response = httpx.post(
                cfg["url"],
                json=row["payload"],
                headers=headers,
                timeout=10,
                follow_redirects=False,
            )
            status = response.status_code
            if not 200 <= status < 300:
                error = "http_" + str(status)
        except httpx.HTTPError as exc:
            error = type(exc).__name__
        attempt = row["tentativas"] + 1
        retryable = status is None or status in (408, 425, 429) or status >= 500
        state = (
            "concluido"
            if error is None
            else ("pendente" if retryable and attempt < 5 else "falha")
        )
        conn.execute(
            "INSERT INTO integ.log_chamadas(evento_id,tentativa,http_status,erro,duracao_ms) VALUES(%s,%s,%s,%s,%s)",
            (row["id"], attempt, status, error, int((time.monotonic() - start) * 1000)),
        )
        conn.execute(
            "UPDATE integ.eventos SET tentativas=%s,estado=%s,proxima_tentativa=now()+integ.fn_atraso_retry(%s)*interval '1 second' WHERE id=%s",
            (attempt, state, attempt, row["id"]),
        )
    return True
