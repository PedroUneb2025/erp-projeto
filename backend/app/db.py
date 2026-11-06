import os
from contextlib import contextmanager
import psycopg
from psycopg.rows import dict_row


@contextmanager
def connection(actor=None):
    with psycopg.connect(os.environ["DATABASE_URL"], row_factory=dict_row) as conn:
        if actor is not None:
            conn.execute("SELECT set_config('app.usuario_id',%s,true)", (str(actor),))
        yield conn


def has_identity_contract(conn):
    return conn.execute(
        "SELECT to_regclass('sys.vw_identidades_core') IS NOT NULL ok"
    ).fetchone()["ok"]
