import hashlib
import hmac
import json
import os
import time
from datetime import datetime, timezone
from uuid import uuid4
import httpx
import pytest
import psycopg
from app.integracoes.service import (
    valid_signature,
    enqueue,
    deliver_one,
    connector_config,
)

pytestmark = pytest.mark.integ


def signature(secret, raw, stamp):
    return (
        "sha256="
        + hmac.new(
            secret.encode(), str(stamp).encode() + b"." + raw, hashlib.sha256
        ).hexdigest()
    )


def test_assinatura_rejeita_adulteracao_e_replay():
    raw = b'{"valor":1}'
    stamp = 1000
    sig = signature("segredo", raw, stamp)
    assert valid_signature(raw, str(stamp), sig, "segredo", now=1000)
    assert not valid_signature(b"alterado", str(stamp), sig, "segredo", now=1000)
    assert not valid_signature(raw, str(stamp), sig, "segredo", now=1400)


def test_conector_sem_https_bloqueado(monkeypatch):
    monkeypatch.setenv(
        "CONNECTORS_JSON", json.dumps({"x": {"url": "http://localhost"}})
    )
    with pytest.raises(ValueError):
        connector_config()


def test_webhook_idempotente(db, client, monkeypatch):
    monkeypatch.setenv("WEBHOOK_SECRETS_JSON", json.dumps({"teste": "segredo"}))
    raw = b'{"pedido":1}'
    stamp = str(int(time.time()))
    headers = {
        "X-Timestamp": stamp,
        "X-Signature": signature("segredo", raw, stamp),
        "Idempotency-Key": "evento-teste",
    }
    one = client.post("/api/v1/integ/webhooks/teste", content=raw, headers=headers)
    two = client.post("/api/v1/integ/webhooks/teste", content=raw, headers=headers)
    assert one.status_code == 202 and one.json()["novo"] is True
    assert two.status_code == 202 and two.json()["novo"] is False
    assert db.execute("SELECT count(*) n FROM integ.eventos").fetchone()["n"] == 1
    changed = b'{"pedido":2}'
    headers["X-Signature"] = signature("segredo", changed, stamp)
    assert (
        client.post(
            "/api/v1/integ/webhooks/teste", content=changed, headers=headers
        ).status_code
        == 409
    )


def test_webhook_assinatura_invalida(db, client, monkeypatch):
    monkeypatch.setenv("WEBHOOK_SECRETS_JSON", '{"teste":"segredo"}')
    assert client.post("/api/v1/integ/webhooks/teste", json={}).status_code == 401


def test_canal_ausente_nao_simula(db, client, admin, monkeypatch):
    monkeypatch.setenv("CONNECTORS_JSON", "{}")
    assert (
        client.post(
            "/api/v1/integ/eventos",
            headers=admin,
            json={"canal": "banco", "chave": "1", "payload": {}},
        ).status_code
        == 409
    )


@pytest.mark.parametrize(
    "status,expected", [(200, "concluido"), (500, "pendente"), (400, "falha")]
)
def test_worker_classifica_resposta_real_por_status(db, monkeypatch, status, expected):
    monkeypatch.setenv(
        "CONNECTORS_JSON", '{"teste":{"url":"https://destino.invalid/eventos"}}'
    )
    # Substituicao apenas no teste unitario; nenhum servidor simulado e entregue.
    monkeypatch.setattr(httpx, "post", lambda *a, **kw: httpx.Response(status))
    eid, _ = enqueue(db, "teste", "chave", {"x": 1}, "saida")
    assert deliver_one()
    row = db.execute(
        "SELECT estado,tentativas FROM integ.eventos WHERE id=%s", (eid,)
    ).fetchone()
    assert row == {"estado": expected, "tentativas": 1}
    assert db.execute("SELECT count(*) n FROM integ.log_chamadas").fetchone()["n"] == 1


def test_falha_apos_cinco_tentativas_e_reprocessamento(db, monkeypatch):
    monkeypatch.setenv(
        "CONNECTORS_JSON", '{"teste":{"url":"https://destino.invalid/eventos"}}'
    )
    monkeypatch.setattr(httpx, "post", lambda *a, **kw: httpx.Response(503))
    eid, _ = enqueue(db, "teste", "chave", {}, "saida")
    db.execute("UPDATE integ.eventos SET tentativas=4 WHERE id=%s", (eid,))
    assert deliver_one()
    assert (
        db.execute("SELECT estado FROM integ.eventos").fetchone()["estado"] == "falha"
    )
    db.execute("CALL integ.sp_reprocessar_falhas(%s)", (eid,))
    assert db.execute("SELECT estado,tentativas FROM integ.eventos").fetchone() == {
        "estado": "pendente",
        "tentativas": 0,
    }


def test_cadeia_bloqueia_mutacao_e_detecta_tamper(db):
    db.execute("SELECT integ.fn_registrar_bloco(jsonb_build_object('contrato',1))")
    db.execute("SELECT integ.fn_registrar_bloco(jsonb_build_object('contrato',2))")
    assert db.execute("SELECT integ.fn_verificar_cadeia() ok").fetchone()["ok"]
    with pytest.raises(psycopg.errors.RaiseException):
        db.execute("UPDATE integ.blocos SET dados='{}'")
    with pytest.raises(psycopg.errors.RaiseException):
        db.execute("TRUNCATE integ.blocos")
    # O dono do banco simula adulteracao privilegiada somente nesta fixture.
    db.execute("ALTER TABLE integ.blocos DISABLE TRIGGER USER")
    try:
        db.execute(
            "UPDATE integ.blocos SET dados='{}' WHERE id=(SELECT min(id) FROM integ.blocos)"
        )
    finally:
        db.execute("ALTER TABLE integ.blocos ENABLE TRIGGER USER")
    assert db.execute("SELECT integ.fn_verificar_cadeia() ok").fetchone()["ok"] is False


def test_iot_model_rejeita_naive_e_nan():
    from app.integracoes.router import Leitura
    from pydantic import ValidationError

    with pytest.raises(ValidationError):
        Leitura(
            evento_id=uuid4(),
            sensor="sensor",
            metrica="temperatura",
            unidade="C",
            instante=datetime(2026, 1, 1),
            valor=10,
        )
    with pytest.raises(ValidationError):
        Leitura(
            evento_id=uuid4(),
            sensor="sensor",
            metrica="temperatura",
            unidade="C",
            instante=datetime.now(timezone.utc),
            valor=float("nan"),
        )


def test_iot_idempotencia_e_agregacao(db, client, admin):
    if not os.environ.get("MONGO_URL"):
        pytest.skip("MongoDB real nao disponivel")
    from app.integracoes.router import mongo
    from app.integracoes.iot import aggregate_pending

    with mongo() as m:
        m.erp.leituras.delete_many({})
    base = {
        "evento_id": str(uuid4()),
        "sensor": "teste",
        "metrica": "temperatura",
        "unidade": "C",
        "instante": "2026-01-01T10:10:00Z",
        "valor": 10,
    }
    assert (
        client.post("/api/v1/integ/iot/leituras", headers=admin, json=base).status_code
        == 202
    )
    assert (
        client.post("/api/v1/integ/iot/leituras", headers=admin, json=base).json()[
            "novo"
        ]
        is False
    )
    assert (
        client.post(
            "/api/v1/integ/iot/leituras", headers=admin, json={**base, "valor": 11}
        ).status_code
        == 409
    )
    assert aggregate_pending() == 1
    late = {**base, "evento_id": str(uuid4()), "valor": 20}
    assert (
        client.post("/api/v1/integ/iot/leituras", headers=admin, json=late).status_code
        == 202
    )
    assert aggregate_pending() == 1
    row = db.execute("SELECT quantidade,media FROM integ.resumos_sensores").fetchone()
    assert row["quantidade"] == 2 and row["media"] == 15
    assert aggregate_pending() == 0
