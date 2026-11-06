import logging
import time
from app.integracoes.service import deliver_one
from app.integracoes.iot import aggregate_pending


def run():
    while True:
        try:
            deliver_one()
        except Exception:
            logging.exception("Falha no processamento de integracoes")
        try:
            aggregate_pending()
        except Exception:
            logging.exception("Falha na agregacao IoT")
        time.sleep(5)


if __name__ == "__main__":
    run()
