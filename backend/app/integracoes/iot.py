from datetime import timedelta
from app.db import connection
from app.integracoes.router import mongo


def aggregate_pending():
    # Serializa agregadores. Recalculo da janela inteira evita duplicar apos crash.
    with connection() as conn, mongo() as client:
        if not conn.execute("SELECT pg_try_advisory_xact_lock(47001) ok").fetchone()[
            "ok"
        ]:
            return 0
        col = client.erp.leituras
        col.create_index([("processado", 1)])
        col.create_index(
            [("sensor", 1), ("metrica", 1), ("unidade", 1), ("instante", 1)]
        )
        pending = list(col.find({"processado": False}).limit(1000))
        groups = {}
        for row in pending:
            hour = row["instante"].replace(minute=0, second=0, microsecond=0)
            key = (row["sensor"], row["metrica"], row["unidade"], hour)
            groups.setdefault(key, []).append(row["_id"])
        done = []
        for (sensor, metric, unit, hour), ids in groups.items():
            pipeline = [
                {
                    "$match": {
                        "sensor": sensor,
                        "metrica": metric,
                        "unidade": unit,
                        "instante": {"$gte": hour, "$lt": hour + timedelta(hours=1)},
                    }
                },
                {
                    "$group": {
                        "_id": None,
                        "n": {"$sum": 1},
                        "avg": {"$avg": "$valor"},
                        "min": {"$min": "$valor"},
                        "max": {"$max": "$valor"},
                    }
                },
            ]
            row = next(col.aggregate(pipeline))
            conn.execute(
                """INSERT INTO integ.resumos_sensores(sensor,metrica,unidade,hora,quantidade,media,minimo,maximo)
            VALUES(%s,%s,%s,%s,%s,%s,%s,%s) ON CONFLICT(sensor,metrica,unidade,hora) DO UPDATE
            SET quantidade=excluded.quantidade,media=excluded.media,minimo=excluded.minimo,maximo=excluded.maximo""",
                (
                    sensor,
                    metric,
                    unit,
                    hour,
                    row["n"],
                    row["avg"],
                    row["min"],
                    row["max"],
                ),
            )
            done.extend(ids)
        conn.commit()  # O Mongo so confirma depois de gravar no PostgreSQL.
        if done:
            col.update_many({"_id": {"$in": done}}, {"$set": {"processado": True}})
    return len(done)
