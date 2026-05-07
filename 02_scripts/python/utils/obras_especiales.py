"""
utils/obras_especiales.py — Lógica de UPSERT para obras no registradas
en ProntoNet.

Las obras especiales (ej: SIN OBRA, IMPUESTOS, ACTIVOS PERON) no existen
en el catálogo de ProntoNet pero aparecen en los datos de costos.
Las definiciones se leen desde config/obras_especiales.json (sin hardcoding).

Patrón: usado por 05_insertar_obras_especiales.py (lanzador) y
testeado directamente como módulo utils.
"""

import json
import logging
from pathlib import Path
from typing import Any

_REPO_ROOT = Path(__file__).resolve().parents[3]
_CONFIG_DEFAULT = _REPO_ROOT / "config" / "obras_especiales.json"


def leer_obras_config(
    config_path: Path | None = None,
) -> list[dict[str, Any]]:
    """
    Lee y valida el archivo de obras especiales.

    Args:
        config_path: ruta al JSON. Si es None, usa la ruta por defecto.

    Returns:
        Lista de dicts con keys: obra_pronto, descripcion_obra, gerencia.

    Raises:
        FileNotFoundError: si el archivo no existe.
        ValueError: si el array está vacío o falta algún campo requerido.
    """
    ruta = config_path or _CONFIG_DEFAULT
    if not ruta.exists():
        raise FileNotFoundError(
            f"Config no encontrado: {ruta}\n"
            "Asegurarse de que el repo incluya "
            "config/obras_especiales.json."
        )
    with ruta.open(encoding="utf-8") as f:
        data = json.load(f)
    obras: list[dict[str, Any]] = data.get("obras", [])
    if not obras:
        raise ValueError("obras_especiales.json no contiene obras.")
    campos_req = {"obra_pronto", "descripcion_obra", "gerencia"}
    for i, o in enumerate(obras):
        faltantes = campos_req - set(o.keys())
        if faltantes:
            raise ValueError(
                f"Obra índice {i} sin campos requeridos: {faltantes}"
            )
    return obras


def upsert_gerencia(cursor: Any, nombre: str) -> int:
    """
    Inserta gerencia si no existe. Retorna id_gerencia.

    Args:
        cursor: cursor de conexión activa.
        nombre: nombre de la gerencia (se normaliza a MAYÚSCULAS).

    Returns:
        id_gerencia existente o recién insertado.
    """
    nombre = nombre.strip().upper()
    cursor.execute(
        "SELECT id_gerencia FROM CATALOGO.gerencias"
        " WHERE codigo_gerencia = %s",
        (nombre,),
    )
    row = cursor.fetchone()
    if row:
        return int(row[0])
    cursor.execute(
        "INSERT INTO CATALOGO.gerencias"
        " (codigo_gerencia, nombre_gerencia)"
        " VALUES (%s, %s)",
        (nombre, nombre),
    )
    cursor.execute(
        "SELECT id_gerencia FROM CATALOGO.gerencias"
        " WHERE codigo_gerencia = %s",
        (nombre,),
    )
    fila = cursor.fetchone()
    if fila is None:
        raise RuntimeError(f"No se pudo obtener id_gerencia para '{nombre}'")
    logging.info("Gerencia nueva insertada: %s", nombre)
    return int(fila[0])


def upsert_obra(
    cursor: Any,
    obra_pronto: str,
    descripcion: str,
    id_gerencia: int,
) -> None:
    """
    Inserta obra si no existe (por obra_pronto). Idempotente.

    Args:
        cursor: cursor de conexión activa.
        obra_pronto: clave natural de la obra.
        descripcion: descripción de la obra.
        id_gerencia: FK a CATALOGO.gerencias.
    """
    obra_pronto = obra_pronto.strip()
    cursor.execute(
        "SELECT id_obra FROM CATALOGO.obras" " WHERE obra_pronto = %s",
        (obra_pronto,),
    )
    if cursor.fetchone():
        logging.info("Obra ya existe, sin cambios: %s", obra_pronto)
        return
    cursor.execute(
        "INSERT INTO CATALOGO.obras"
        " (obra_pronto, descripcion_obra, id_gerencia, activo)"
        " VALUES (%s, %s, %s, 1)",
        (obra_pronto, descripcion.strip(), id_gerencia),
    )
    logging.info("Obra especial insertada: %s", obra_pronto)


def insertar_obras_especiales(
    conn: Any,
    config_path: Path | None = None,
) -> int:
    """
    Carga todas las obras del config en CATALOGO.obras.

    Args:
        conn: conexión activa a la BD.
        config_path: ruta al JSON (opcional, para tests).

    Returns:
        Cantidad de obras procesadas.
    """
    obras = leer_obras_config(config_path)
    cursor = conn.cursor()
    procesadas = 0
    for obra in obras:
        id_ger = upsert_gerencia(cursor, obra["gerencia"])
        upsert_obra(
            cursor,
            obra["obra_pronto"],
            obra["descripcion_obra"],
            id_ger,
        )
        procesadas += 1
    conn.commit()
    logging.info(
        "UPSERT completado: %d obras especiales procesadas.",
        procesadas,
    )
    return procesadas
