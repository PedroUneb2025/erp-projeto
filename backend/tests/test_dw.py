from datetime import date, timedelta
import pytest
import psycopg
from psycopg.types.json import Jsonb
from app.dw.forecast import predict_series

pytestmark = pytest.mark.dw


def test_previsao_recusa_historico_ausente_ou_incompleto():
    with pytest.raises(ValueError):
        predict_series([])
    with pytest.raises(ValueError):
        predict_series([{"data": date(2026, 1, 1), "quantidade": 2}])
    rows = [
        {"data": date(2026, 1, 1) + timedelta(days=i * 2), "quantidade": 2}
        for i in range(65)
    ]
    with pytest.raises(ValueError):
        predict_series(rows)


def test_previsao_separa_validacao_temporal():
    rows = [
        {"data": date(2026, 1, 1) + timedelta(days=i), "quantidade": 2 + (i % 7)}
        for i in range(70)
    ]
    pred, mae, last = predict_series(rows)
    assert len(pred) == 14 and pred[0][0] == last + timedelta(days=1)
    assert mae >= 0 and all(value >= 0 for _, value in pred)


def prepare(db):
    db.execute("CALL dw.sp_carregar_dim_tempo('2026-01-01'::date,'2026-01-02'::date)")
    db.execute(
        "CALL dw.sp_carregar_dim_clientes('teste','1','Cliente de teste unitario')"
    )
    db.execute(
        "CALL dw.sp_carregar_dim_produtos('teste','1','Produto de teste unitario')"
    )
    return {
        "origem": "teste",
        "origem_id": "pedido:1:item:1",
        "tempo_id": 1,
        "cliente_id": 1,
        "produto_id": 1,
        "quantidade": 2,
        "valor": 20,
    }


def test_carga_idempotente_e_view(db):
    row = prepare(db)
    db.execute("CALL dw.sp_carregar_fato_vendas(%s)", (Jsonb([row]),))
    db.execute("CALL dw.sp_carregar_fato_vendas(%s)", (Jsonb([{**row, "valor": 30}]),))
    assert db.execute("SELECT count(*) n FROM dw.fato_vendas").fetchone()["n"] == 1
    assert (
        db.execute("SELECT receita FROM dw.vw_vendas_por_mes").fetchone()["receita"]
        == 30
    )


def test_fk_rejeita_dimensao_inexistente(db):
    row = prepare(db)
    with pytest.raises(psycopg.errors.ForeignKeyViolation):
        db.execute(
            "CALL dw.sp_carregar_fato_vendas(%s)",
            (Jsonb([{**row, "produto_id": 999}]),),
        )
    assert db.execute("SELECT count(*) n FROM dw.fato_vendas").fetchone()["n"] == 0


def test_lote_invalido_nao_grava_metade(db):
    row = prepare(db)
    with pytest.raises(psycopg.errors.CheckViolation):
        db.execute(
            "CALL dw.sp_carregar_fato_vendas(%s)",
            (Jsonb([row, {**row, "origem_id": "outra", "valor": -1}]),),
        )
    assert db.execute("SELECT count(*) n FROM dw.fato_vendas").fetchone()["n"] == 0


def test_painel_vazio_sem_dados_falsos(db, client, admin):
    assert client.get("/api/v1/dw/paineis/vendas", headers=admin).json() == []
    assert (
        client.get("/api/v1/dw/paineis/inexistente", headers=admin).status_code == 404
    )


def test_financeiro_saldo(db):
    prepare(db)
    rows = [
        {
            "origem": "teste",
            "origem_id": "1",
            "tempo_id": 1,
            "categoria": "recebimento",
            "tipo": "entrada",
            "valor": 100,
        },
        {
            "origem": "teste",
            "origem_id": "2",
            "tempo_id": 1,
            "categoria": "pagamento",
            "tipo": "saida",
            "valor": 40,
        },
    ]
    db.execute("CALL dw.sp_carregar_fato_financeiro(%s)", (Jsonb(rows),))
    assert (
        db.execute("SELECT saldo FROM dw.vw_financeiro_por_mes").fetchone()["saldo"]
        == 60
    )


def test_sequence_identity_e_auditoria_por_modulo(db):
    for schema, table in [
        ("sys", "parametrizacoes"),
        ("integ", "eventos"),
        ("dw", "dim_produtos"),
    ]:
        seq = db.execute(
            "SELECT pg_get_serial_sequence(%s,'id') seq", (schema + "." + table,)
        ).fetchone()["seq"]
        assert seq
