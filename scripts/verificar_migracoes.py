"""Bloqueia edicao/remocao de migracoes presentes na branch base do PR."""

import subprocess
import sys

base = sys.argv[1]
old = subprocess.check_output(
    ["git", "ls-tree", "-r", "--name-only", base, "db/migrations"], text=True
).splitlines()
for path in old:
    previous = subprocess.check_output(["git", "show", base + ":" + path])
    from pathlib import Path

    current = Path(path)
    if not current.exists() or current.read_bytes() != previous:
        raise SystemExit("Migracao publicada foi alterada ou removida: " + path)
print("Migracoes anteriores preservadas.")
