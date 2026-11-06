import logging
import os
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from psycopg import OperationalError, IntegrityError
from pymongo.errors import PyMongoError
from app.db import connection, has_identity_contract
from app.sys.router import router as sys_router
from app.integracoes.router import router as integ_router
from app.dw.router import router as dw_router

app = FastAPI(title="ERP - Pessoa D", version="0.1.0")
app.include_router(sys_router)
app.include_router(integ_router)
app.include_router(dw_router)


@app.middleware("http")
async def limit_body(request: Request, call_next):
    # Limita tambem corpos enviados sem Content-Length (chunked).
    if request.method in ("POST", "PUT", "PATCH"):
        chunks = []
        size = 0
        async for chunk in request.stream():
            size += len(chunk)
            if size > 262144:
                return JSONResponse(
                    status_code=413, content={"detail": "Corpo excede 256 KiB"}
                )
            chunks.append(chunk)
        request._body = b"".join(chunks)
    return await call_next(request)


@app.exception_handler(OperationalError)
async def database_unavailable(request, exc):
    logging.error("Banco indisponivel: %s", type(exc).__name__)
    return JSONResponse(status_code=503, content={"detail": "Banco indisponivel"})


@app.exception_handler(IntegrityError)
async def invalid_reference(request, exc):
    return JSONResponse(
        status_code=409,
        content={
            "detail": "Referencia inexistente, valor invalido ou registro duplicado"
        },
    )


@app.exception_handler(PyMongoError)
async def mongo_unavailable(request, exc):
    return JSONResponse(
        status_code=503, content={"detail": "Armazenamento IoT indisponivel"}
    )


@app.get("/health")
def health():
    with connection() as conn:
        conn.execute("SELECT 1")
    return {"status": "ok"}


@app.get("/api/v1/status")
def status():
    with connection() as conn:
        core = has_identity_contract(conn)
    return {
        "banco": "conectado",
        "autenticacao_core": "integrada" if core else "pendente",
        "cargas_dos_colegas": "pendentes de mapeamento",
        "dados_demonstracao": False,
        "jwt_configurado": len(os.environ.get("JWT_SECRET", "")) >= 32,
    }
