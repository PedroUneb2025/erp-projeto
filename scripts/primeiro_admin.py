"""Executar uma vez, depois do contrato core, no ambiente da API."""

import argparse
from app.db import connection, has_identity_contract

parser = argparse.ArgumentParser()
parser.add_argument("usuario_id", type=int)
args = parser.parse_args()
with connection(args.usuario_id) as conn:
    conn.execute("SELECT pg_advisory_xact_lock(41001)")
    if not has_identity_contract(conn):
        raise SystemExit("Integre sys.vw_identidades_core primeiro.")
    if conn.execute(
        "SELECT 1 FROM sys.usuarios_perfis up JOIN sys.perfis p ON p.id=up.perfil_id WHERE p.nome IN ('role_ceo','role_dba') AND up.deleted_at IS NULL"
    ).fetchone():
        raise SystemExit("Ja existe administrador. Use a tela de permissoes.")
    if not conn.execute(
        "SELECT id FROM sys.vw_identidades_core WHERE id=%s AND ativo AND deleted_at IS NULL",
        (args.usuario_id,),
    ).fetchone():
        raise SystemExit("Usuario real ativo nao encontrado.")
    conn.execute(
        "INSERT INTO sys.usuarios_perfis(usuario_id,perfil_id) SELECT %s,id FROM sys.perfis WHERE nome='role_dba'",
        (args.usuario_id,),
    )
print("Perfil de administrador vinculado ao usuario real informado.")
