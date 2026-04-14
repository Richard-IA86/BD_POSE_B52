"""
conexion_pg.py — Fábrica de conexiones PostgreSQL para DW_GrupoPOSE_B52

Reemplaza conexion.py (pyodbc/SQL Server) en la rama
feature/postgresql-migration.

Requiere en config/conexion.json:
{
    "host":     "localhost",
    "port":     5432,
    "database": "DW_GrupoPOSE_B52",
    "user":     "pose_admin",
    "password": "***"
}

Instalar: pip install psycopg2-binary
"""

import json
import logging
from pathlib import Path

import psycopg2
import psycopg2.extensions

_CONFIG_FILE = Path(__file__).resolve().parents[3] / "config" / "conexion.json"

_DEFAULTS: dict[str, str | int] = {
    "host": "localhost",
    "port": 5432,
    "database": "DW_GrupoPOSE_B52",
    "user": "pose_admin",
    "password": "",
}


def _get_config() -> dict[str, str | int]:
    if _CONFIG_FILE.exists():
        try:
            with open(_CONFIG_FILE, encoding="utf-8") as f:
                return {**_DEFAULTS, **json.load(f)}
        except Exception as e:
            logging.warning(
                "No se pudo leer %s: %s — usando defaults",
                _CONFIG_FILE,
                e,
            )
    return dict(_DEFAULTS)


def get_connection(
    database: str | None = None,
) -> psycopg2.extensions.connection:
    """
    Devuelve una conexión psycopg2 a PostgreSQL.

    Args:
        database: Nombre de la BD. Si None, usa el valor de conexion.json.

    Returns:
        psycopg2.connection con autocommit=False
    """
    cfg = _get_config()
    if database:
        cfg["database"] = database
    logging.debug(
        "Conectando a %s@%s:%s", cfg["database"], cfg["host"], cfg["port"]
    )
    conn = psycopg2.connect(
        host=str(cfg["host"]),
        port=int(cfg["port"]),
        dbname=str(cfg["database"]),
        user=str(cfg["user"]),
        password=str(cfg["password"]),
        connect_timeout=30,
    )
    conn.autocommit = False
    return conn
