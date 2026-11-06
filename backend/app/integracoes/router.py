import json
import os
from datetime import datetime, timezone
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field, AwareDatetime
from psycopg.types.json import Jsonb
from pymongo import MongoClient
from pymongo.errors import DuplicateKeyError
from app.db import connection
from app.sys.auth import permission
from app.integracoes.service import valid_signature, enqueue, connector_config

router = APIRouter(prefix="/api/v1/integ", tags=["Integracoes"])


class Evento(BaseModel):
    canal: str = Field(pattern=r"^[a-z0-9_-]{1,50}$")
    chave: str = Field(min_length=1, max_length=128)
    payload: dict


class Bloco(BaseModel):
    dados: dict


class Leitura(BaseModel):
    evento_id: UUID
    sensor: str = Field(min_length=1, max_length=100)
    metrica: str = Field(min_length=1, max_length=50)
    unidade: str = Field(min_length=1, max_length=30)
    instante: AwareDatetime
    valor: float = Field(allow_inf_nan=False)


def mongo():
    return MongoClient(
        os.environ["MONGO_URL"], serverSelectionTimeoutMS=3000, tz_aware=True
    )


@router.post("/eventos", status_code=202)
def enviar(body: Evento, user=Depends(permission("integ.escrever"))):
    if body.canal not in connector_config():
        raise HTTPException(409, "Canal real ainda nao configurado")
    with connection(user["id"]) as conn:
        try:
            eid, new = enqueue(conn, body.canal, body.chave, body.payload, "saida")
        except ValueError as exc:
            raise HTTPException(409, str(exc)) from None
    return {"id": eid, "novo": new}


@router.post("/webhooks/{canal}", status_code=202)
async def webhook(canal: str, request: Request):
    secrets = json.loads(os.environ.get("WEBHOOK_SECRETS_JSON", "{}"))
    key = secrets.get(canal)
    if not key:
        raise HTTPException(404, "Webhook nao configurado")
    timestamp = request.headers.get("X-Timestamp", "")
    signature = request.headers.get("X-Signature", "")
    raw = await request.body()
    if not valid_signature(raw, timestamp, signature, key):
        raise HTTPException(401, "Assinatura invalida ou expirada")
    event_key = request.headers.get("Idempotency-Key", "")
    if not event_key or len(event_key) > 128:
        raise HTTPException(422, "Idempotency-Key obrigatoria, ate 128 caracteres")
    try:
        payload = json.loads(raw)
    except (ValueError, UnicodeDecodeError):
        raise HTTPException(422, "JSON invalido") from None
    if not isinstance(payload, dict):
        raise HTTPException(422, "Esperado objeto JSON")
    with connection() as conn:
        try:
            eid, new = enqueue(conn, canal, event_key, payload, "entrada")
        except ValueError as exc:
            raise HTTPException(409, str(exc)) from None
    return {"id": eid, "novo": new, "estado": "recebido"}


@router.get("/eventos")
def eventos(user=Depends(permission("integ.ler"))):
    with connection(user["id"]) as conn:
        return conn.execute(
            "SELECT id,canal,chave,direcao,estado,tentativas,updated_at FROM integ.eventos WHERE deleted_at IS NULL ORDER BY id DESC LIMIT 100"
        ).fetchall()


@router.get("/chamadas")
def chamadas(user=Depends(permission("integ.ler"))):
    with connection(user["id"]) as conn:
        return conn.execute(
            "SELECT evento_id,tentativa,http_status,erro,duracao_ms,created_at FROM integ.log_chamadas ORDER BY id DESC LIMIT 100"
        ).fetchall()


@router.post("/eventos/{evento_id}/reprocessar")
def reprocessar(evento_id: int, user=Depends(permission("integ.escrever"))):
    with connection(user["id"]) as conn:
        row = conn.execute(
            "SELECT id FROM integ.eventos WHERE id=%s AND estado='falha' AND direcao='saida' FOR UPDATE",
            (evento_id,),
        ).fetchone()
        if not row:
            raise HTTPException(409, "Evento nao reprocessavel")
        conn.execute("CALL integ.sp_reprocessar_falhas(%s)", (evento_id,))
    return {"ok": True}


@router.post("/blocos", status_code=201)
def registrar_bloco(body: Bloco, user=Depends(permission("integ.escrever"))):
    with connection(user["id"]) as conn:
        return conn.execute(
            "SELECT integ.fn_registrar_bloco(%s) id", (Jsonb(body.dados),)
        ).fetchone()


@router.get("/blocos/verificacao")
def verificar_cadeia(user=Depends(permission("integ.ler"))):
    with connection(user["id"]) as conn:
        return conn.execute(
            "SELECT integ.fn_verificar_cadeia() integra,(SELECT count(*) FROM integ.blocos) total"
        ).fetchone()


@router.post("/iot/leituras", status_code=202)
def leitura(body: Leitura, user=Depends(permission("integ.escrever"))):
    if body.instante > datetime.now(timezone.utc):
        raise HTTPException(422, "Leitura nao pode estar no futuro")
    raw = body.model_dump()
    raw["_id"] = str(raw.pop("evento_id"))
    raw["created_by"] = user["id"]
    raw["created_at"] = datetime.now(timezone.utc)
    raw["processado"] = False
    with mongo() as client:
        collection = client.erp.leituras
        try:
            collection.insert_one(raw)
            new = True
        except DuplicateKeyError:
            old = collection.find_one({"_id": raw["_id"]})
            # Mongo armazena timestamps com precisao de milissegundos.
            keys = ("sensor", "metrica", "unidade", "valor")
            same = all(old[k] == raw[k] for k in keys) and int(
                old["instante"].timestamp() * 1000
            ) == int(raw["instante"].timestamp() * 1000)
            if not same:
                raise HTTPException(
                    409, "Evento reutilizado com outra leitura"
                ) from None
            new = False
    return {"evento_id": raw["_id"], "novo": new}


@router.get("/iot/resumos")
def resumos(user=Depends(permission("integ.ler"))):
    with connection(user["id"]) as conn:
        return conn.execute(
            "SELECT * FROM integ.vw_sensores_horarios ORDER BY hora DESC LIMIT 100"
        ).fetchall()
