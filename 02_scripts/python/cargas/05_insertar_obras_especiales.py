"""
05_insertar_obras_especiales.py -- Lanzador: UPSERT obras no registradas
en ProntoNet.

La logica reside en utils/obras_especiales.py; este script es solo
el punto de entrada para ejecucion en el SERVIDOR.

Ejecutar antes de 03_cargar_costos_B52.py:
  python 02_scripts/python/cargas/05_insertar_obras_especiales.py
"""

import logging
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "utils"))  # noqa: E402
from conexion import get_connection  # noqa: E402
from obras_especiales import (  # noqa: E402
    insertar_obras_especiales,
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-8s %(message)s",
    handlers=[logging.StreamHandler()],
)


def main() -> None:
    logging.info("Iniciando carga de obras especiales.")
    conn = get_connection()
    try:
        total = insertar_obras_especiales(conn)
        logging.info("Finalizado OK -- %d obras procesadas.", total)
    finally:
        conn.close()


if __name__ == "__main__":
    main()
    sys.exit(0)
