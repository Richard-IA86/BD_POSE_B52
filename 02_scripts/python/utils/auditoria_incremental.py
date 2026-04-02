"""
auditoria_incremental.py — Funciones de auditoría para carga incremental B52.

Provee:
  - registrar_inicio / registrar_fin   → log_cargas (nivel archivo)
  - registrar_inicio_periodo / registrar_fin_periodo → periodos_carga (nivel partición)  # noqa: E501
  - verificar_procesado_periodo        → idempotencia
"""

import logging
from typing import Optional, Tuple

import pyodbc

# ---------------------------------------------------------------------------
# log_cargas  (nivel archivo)
# ---------------------------------------------------------------------------


def registrar_inicio(
    conn: pyodbc.Connection,
    tabla_destino: str,
    archivo_origen: str,
    usuario_carga: str,
) -> int:
    """Inserta registro en AUDITORIA.log_cargas y devuelve id_log_carga."""
    cursor = conn.cursor()
    cursor.execute(
        """
        INSERT INTO AUDITORIA.log_cargas
            (tabla_destino, archivo_origen, usuario_carga, estado, fecha_carga)
        OUTPUT INSERTED.id_log_carga
        VALUES (?, ?, ?, 'EN_PROCESO', GETDATE())
        """,
        tabla_destino,
        archivo_origen,
        usuario_carga,
    )
    id_log = int(cursor.fetchone()[0])
    conn.commit()
    logging.info(
        "Auditoría inicio: id_log_carga=%d tabla=%s", id_log, tabla_destino
    )
    return id_log


def registrar_fin(
    conn: pyodbc.Connection,
    id_log_carga: int,
    registros_procesados: int,
    registros_insertados: int,
    registros_rechazados: int,
    estado: str,
    observaciones: Optional[str] = None,
) -> None:
    """Actualiza AUDITORIA.log_cargas al finalizar un archivo."""
    cursor = conn.cursor()
    cursor.execute(
        """
        UPDATE AUDITORIA.log_cargas
           SET registros_procesados = ?,
               registros_insertados = ?,
               registros_rechazados = ?,
               estado = ?,
               observaciones = ?
         WHERE id_log_carga = ?
        """,
        registros_procesados,
        registros_insertados,
        registros_rechazados,
        estado,
        observaciones,
        id_log_carga,
    )
    conn.commit()
    logging.info(
        "Auditoría fin: id_log_carga=%d estado=%s", id_log_carga, estado
    )


# ---------------------------------------------------------------------------
# periodos_carga  (nivel partición temporal)
# ---------------------------------------------------------------------------


def registrar_inicio_periodo(
    conn: pyodbc.Connection,
    tabla: str,
    tipo_particion: str,
    anio: int,
    mes: Optional[int],
    periodo_codigo: str,
    usuario: str,
) -> Tuple[int, int]:
    """
    Inserta en AUDITORIA.log_cargas + AUDITORIA.periodos_carga.

    Returns:
        (id_log_carga, id_periodo_carga)
    """
    # Crear log_carga genérico para este período
    id_log = registrar_inicio(
        conn,
        tabla_destino=tabla,
        archivo_origen=f"periodo:{periodo_codigo}",
        usuario_carga=usuario,
    )

    cursor = conn.cursor()
    cursor.execute(
        """
        INSERT INTO AUDITORIA.periodos_carga
            (tabla_destino, tipo_particion, anio, mes, periodo_codigo,
             estado, fecha_inicio_carga, usuario_carga)
        OUTPUT INSERTED.id_periodo_carga
        VALUES (?, ?, ?, ?, ?, 'EN_PROCESO', GETDATE(), ?)
        """,
        tabla,
        tipo_particion,
        anio,
        mes,
        periodo_codigo,
        usuario,
    )
    id_periodo = int(cursor.fetchone()[0])
    conn.commit()
    logging.info(
        "Período inicio: id_periodo=%d periodo=%s", id_periodo, periodo_codigo
    )
    return id_log, id_periodo


def registrar_fin_periodo(
    conn: pyodbc.Connection,
    id_log_carga: int,
    id_periodo_carga: int,
    registros_borrados: int,
    registros_insertados: int,
    duracion_segundos: float,
    estado: str,
    observaciones: Optional[str] = None,
) -> None:
    """Cierra AUDITORIA.periodos_carga y AUDITORIA.log_cargas."""
    velocidad = (
        registros_insertados / duracion_segundos
        if duracion_segundos and duracion_segundos > 0
        else 0.0
    )
    cursor = conn.cursor()
    cursor.execute(
        """
        UPDATE AUDITORIA.periodos_carga
           SET registros_borrados       = ?,
               registros_insertados     = ?,
               fecha_fin_carga          = GETDATE(),
               duracion_segundos        = ?,
               velocidad_registros_seg  = ?,
               estado                   = ?,
               observaciones            = ?
         WHERE id_periodo_carga = ?
        """,
        registros_borrados,
        registros_insertados,
        round(duracion_segundos, 2),
        round(velocidad, 2),
        estado,
        observaciones,
        id_periodo_carga,
    )
    conn.commit()

    # Actualizar log_carga con totales
    registrar_fin(
        conn,
        id_log_carga=id_log_carga,
        registros_procesados=registros_insertados,
        registros_insertados=registros_insertados,
        registros_rechazados=0,
        estado=estado,
        observaciones=observaciones,
    )
    logging.info(
        "Período fin: id_periodo=%d estado=%s insertados=%d dur=%.2fs",
        id_periodo_carga,
        estado,
        registros_insertados,
        duracion_segundos,
    )


# ---------------------------------------------------------------------------
# Idempotencia
# ---------------------------------------------------------------------------


def verificar_procesado_periodo(
    conn: pyodbc.Connection,
    tabla: str,
    periodo_codigo: str,
) -> Tuple[bool, Optional[int]]:
    """
    Detecta si un período ya fue procesado exitosamente.

    Returns:
        (ya_procesado: bool, id_periodo_carga: int | None)
    """
    cursor = conn.cursor()
    cursor.execute(
        """
        SELECT TOP 1 id_periodo_carga
          FROM AUDITORIA.periodos_carga
         WHERE tabla_destino = ?
           AND periodo_codigo = ?
           AND estado = 'EXITOSO'
         ORDER BY id_periodo_carga DESC
        """,
        tabla,
        periodo_codigo,
    )
    row = cursor.fetchone()
    if row:
        return True, row[0]
    return False, None
