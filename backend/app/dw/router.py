from fastapi import APIRouter, Depends, HTTPException
from app.db import connection
from app.sys.auth import permission

router = APIRouter(prefix="/api/v1/dw", tags=["BI"])
VIEWS = {
    "vendas": "vw_vendas_por_mes",
    "financeiro": "vw_financeiro_por_mes",
    "estoque": "vw_estoque_atual",
    "producao": "vw_producao_por_mes",
}


@router.get("/paineis/{modulo}")
def painel(modulo: str, user=Depends(permission("dw.ler"))):
    if modulo not in VIEWS:
        raise HTTPException(404, "Painel inexistente")
    with connection(user["id"]) as conn:
        return conn.execute(
            "SELECT * FROM dw." + VIEWS[modulo] + " LIMIT 500"
        ).fetchall()


@router.get("/previsoes")
def previsoes(user=Depends(permission("dw.ler"))):
    with connection(user["id"]) as conn:
        return conn.execute(
            "SELECT produto_id,data,quantidade,modelo,mae,treinado_ate FROM dw.previsoes_demanda WHERE deleted_at IS NULL ORDER BY data,produto_id LIMIT 500"
        ).fetchall()
