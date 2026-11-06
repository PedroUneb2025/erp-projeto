from datetime import timedelta
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error
from app.db import connection


def features(day):
    return [day.toordinal(), day.weekday(), day.month]


def predict_series(rows, horizon=14):
    if not rows:
        raise ValueError("Sem historico real de vendas")
    # Exige dados diarios completos: nao supoe que dias ausentes sao vendas zero.
    rows = sorted(rows, key=lambda r: r["data"])
    if len(rows) < 60 or any(
        (b["data"] - a["data"]).days != 1 for a, b in zip(rows, rows[1:])
    ):
        raise ValueError(
            "Necessarios ao menos 60 dias consecutivos e completos por produto"
        )
    x = np.array([features(r["data"]) for r in rows])
    y = np.array([float(r["quantidade"]) for r in rows])
    if not np.isfinite(y).all() or (y < 0).any():
        raise ValueError("Historico invalido")
    model = RandomForestRegressor(
        n_estimators=100, min_samples_leaf=3, random_state=42, n_jobs=1
    )
    model.fit(x[:-14], y[:-14])
    mae = float(mean_absolute_error(y[-14:], model.predict(x[-14:])))
    model.fit(x, y)
    days = [rows[-1]["data"] + timedelta(days=i) for i in range(1, horizon + 1)]
    predictions = model.predict([features(d) for d in days])
    return (
        [(d, max(0, float(v))) for d, v in zip(days, predictions)],
        mae,
        rows[-1]["data"],
    )


def run():
    results = []
    with connection() as conn:
        products = conn.execute(
            "SELECT DISTINCT produto_id FROM dw.fato_vendas WHERE deleted_at IS NULL"
        ).fetchall()
        for product in products:
            pid = product["produto_id"]
            rows = conn.execute(
                "SELECT t.data,sum(f.quantidade) quantidade FROM dw.fato_vendas f JOIN dw.dim_tempo t ON t.id=f.tempo_id WHERE f.produto_id=%s AND f.deleted_at IS NULL GROUP BY t.data ORDER BY t.data",
                (pid,),
            ).fetchall()
            try:
                predictions, mae, last = predict_series(rows)
            except ValueError as exc:
                results.append({"produto_id": pid, "pendente": str(exc)})
                continue
            for day, value in predictions:
                conn.execute(
                    "INSERT INTO dw.previsoes_demanda(produto_id,data,quantidade,modelo,mae,treinado_ate) VALUES(%s,%s,%s,'RandomForest-v1',%s,%s) ON CONFLICT(produto_id,data) DO UPDATE SET quantidade=excluded.quantidade,modelo=excluded.modelo,mae=excluded.mae,treinado_ate=excluded.treinado_ate,updated_at=now()",
                    (pid, day, value, mae, last),
                )
            results.append(
                {"produto_id": pid, "previsoes": len(predictions), "mae": mae}
            )
    return results


if __name__ == "__main__":
    print(run())
