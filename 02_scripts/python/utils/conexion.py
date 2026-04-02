"""
conexion.py — Fábrica de conexiones para DW_GrupoPOSE_B52
"""

import json
import logging
import pyodbc
from pathlib import Path

# Driver preferido (se prueba en orden)
_DRIVERS = [
    "ODBC Driver 18 for SQL Server",
    "ODBC Driver 17 for SQL Server",
    "SQL Server",
]

# Lee el servidor desde config/conexion.json si existe (ignorado en Git).
# Permite que cada entorno (dev local / servidor) use su propia instancia
# sin modificar código fuente.
# Si el archivo no existe, usa el default .\SQLEXPRESS (válido en DEV-DIRECTORIO).  # noqa: E501
_CONFIG_FILE = Path(__file__).resolve().parents[3] / "config" / "conexion.json"


def _get_server() -> str:
    if _CONFIG_FILE.exists():
        try:
            with open(_CONFIG_FILE, encoding="utf-8") as f:
                return json.load(f).get("server", r".\SQLEXPRESS")
        except Exception as e:
            logging.warning(
                "No se pudo leer %s: %s — usando default", _CONFIG_FILE, e
            )
    return r".\SQLEXPRESS"


_SERVER = _get_server()


def _find_driver() -> str:
    disponibles = [d for d in pyodbc.drivers() if "SQL Server" in d]
    for preferido in _DRIVERS:
        if preferido in disponibles:
            return preferido
    if disponibles:
        return disponibles[-1]
    raise RuntimeError(
        "No se encontró driver ODBC para SQL Server. "
        f"Drivers instalados: {pyodbc.drivers()}"
    )


def get_connection(
    database: str = "DW_GrupoPOSE_B52", server: str = _SERVER
) -> pyodbc.Connection:
    """
    Devuelve una conexión pyodbc al servidor SQL Server.

    Args:
        database: Nombre de la base de datos. Default: 'DW_GrupoPOSE_B52'
        server:   Nombre/instancia del servidor. Default: '.\\SQLEXPRESS'

    Returns:
        pyodbc.Connection con autocommit=False
    """
    driver = _find_driver()
    conn_str = (
        f"DRIVER={{{driver}}};"
        f"SERVER={server};"
        f"DATABASE={database};"
        "Trusted_Connection=yes;"
        "TrustServerCertificate=yes;"
        "Connection Timeout=30;"
    )
    logging.debug("Conectando con: %s", conn_str)
    conn = pyodbc.connect(conn_str)
    conn.autocommit = False
    return conn
