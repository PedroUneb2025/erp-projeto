"""Gera segredos locais. Nunca sobrescreve .env existente."""

from pathlib import Path
import secrets

root = Path(__file__).resolve().parents[1]
out = root / ".env"
if out.exists():
    print(".env ja existe; mantido sem alteracoes.")
else:
    text = (root / ".env.example").read_text()
    for key in ["POSTGRES", "APP", "BI", "METABASE", "MONGO", "JWT"]:
        text = text.replace("CHANGE_ME_" + key, secrets.token_hex(32))
    out.write_text(text)
    out.chmod(0o600)
    print(".env criado com segredos locais. Nao envie esse arquivo ao GitHub.")
