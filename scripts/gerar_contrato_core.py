"""Gera V49 somente a partir do mapeamento informado do cadastro REAL de A.
Nao executa SQL, nao cria usuarios e nao cria dados ou views ficticias.
"""

import argparse
import re
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
for option in ("id", "email", "senha-hash", "ativo", "deleted-at"):
    parser.add_argument(
        "--" + option, required=True, help="Nome real da coluna em core.usuarios"
    )
parser.add_argument(
    "--saida", required=True, help="Caminho de V49__sys_contrato_core.sql"
)
args = parser.parse_args()
mapping = {
    key: getattr(args, key)
    for key in ("id", "email", "senha_hash", "ativo", "deleted_at")
}
for value in mapping.values():
    if not re.fullmatch(r"[a-z_][a-z0-9_]*", value):
        parser.error(
            "Colunas precisam seguir snake_case e conter apenas letras, numeros e underscore."
        )
out = Path(args.saida)
if out.name != "V49__sys_contrato_core.sql":
    parser.error(
        "Use o nome V49__sys_contrato_core.sql, reservado para esta integracao."
    )
if out.exists():
    parser.error(
        "Arquivo ja existe. Migracoes compartilhadas nao podem ser sobrescritas."
    )
selection = ",\n ".join(f'"{column}" AS "{alias}"' for alias, column in mapping.items())
text = f"""-- Gerada a partir do mapeamento informado; revisar com A antes de aplicar.
-- Nao altera o schema core. Banco deve conter core.usuarios real.
CREATE VIEW sys.vw_identidades_core AS SELECT
 {selection}
FROM core.usuarios;
GRANT SELECT ON sys.vw_identidades_core TO erp_app;
"""
for table in ("usuarios_perfis", "sessoes", "log_acessos"):
    text += f'''ALTER TABLE sys.{table} ADD CONSTRAINT fk_{table}_core_usuario
 FOREIGN KEY (usuario_id) REFERENCES core.usuarios("{mapping["id"]}");
'''
text += """-- Verifica duplicidade de email antes de ativar login.
DO $$ BEGIN
 IF EXISTS(SELECT lower(email) FROM sys.vw_identidades_core
 WHERE deleted_at IS NULL GROUP BY lower(email) HAVING count(*)>1) THEN
 RAISE EXCEPTION 'Email duplicado no core: corrija com a Pessoa A';
 END IF;
END $$;
"""
out.parent.mkdir(parents=True, exist_ok=True)
with out.open("x", encoding="utf-8") as stream:
    stream.write(text)
print("Migração gerada para revisão:", out)
