"""
validaciones.py — Validación de esquemas de datos para B52.
"""

import logging
import pandas as pd

# ---------------------------------------------------------------------------
# Columnas mínimas requeridas
# ---------------------------------------------------------------------------

_COSTOS_REQUERIDAS = [
    "FECHA",
    "OBRA_PRONTO",
    "IMPORTE",
    "anio_dato",
    "mes_dato",
    "periodo_codigo",
]

_COMPROBANTES_REQUERIDAS = [
    "FECHA_COMPROBANTE",
    "NRO_COMPROBANTE",
    "IMPORTE",
    "anio_dato",
]


def validar_schema_costos(df: pd.DataFrame) -> pd.DataFrame:
    """
    Valida columnas requeridas en el DataFrame de costos.

    - Verifica columnas mínimas.
    - Descarta filas con FECHA o IMPORTE nulo.
    - Loguea advertencias sobre registros problemáticos.

    Returns:
        DataFrame filtrado y listo para insertar.
    Raises:
        ValueError si faltan columnas estructurales.
    """
    faltantes = [c for c in _COSTOS_REQUERIDAS if c not in df.columns]
    if faltantes:
        raise ValueError(
            f"Columnas requeridas ausentes en costos: {faltantes}. "
            "Verificar que el archivo fue generado con Power Query B52."
        )

    # Validar rangos de partición
    if not df["mes_dato"].between(1, 12).all():
        invalidos = df[~df["mes_dato"].between(1, 12)]["mes_dato"].unique()
        raise ValueError(f"mes_dato fuera de rango 1-12: {invalidos}")

    n_antes = len(df)
    df_valido = df.dropna(subset=["FECHA", "IMPORTE", "OBRA_PRONTO"]).copy()
    descartados = n_antes - len(df_valido)
    if descartados:
        logging.warning(
            "Costos: %d filas descartadas (FECHA/IMPORTE/OBRA_PRONTO nulo)",
            descartados,
        )

    logging.info("Costos validados: %d registros OK", len(df_valido))
    return df_valido


def validar_schema_comprobantes(df: pd.DataFrame) -> pd.DataFrame:
    """
    Valida columnas requeridas en el DataFrame de comprobantes.

    Returns:
        DataFrame filtrado y listo para insertar.
    Raises:
        ValueError si faltan columnas estructurales.
    """
    faltantes = [c for c in _COMPROBANTES_REQUERIDAS if c not in df.columns]
    if faltantes:
        raise ValueError(
            f"Columnas requeridas ausentes en comprobantes: {faltantes}."
        )

    n_antes = len(df)
    df_valido = df.dropna(
        subset=["FECHA_COMPROBANTE", "NRO_COMPROBANTE", "IMPORTE"]
    ).copy()
    descartados = n_antes - len(df_valido)
    if descartados:
        logging.warning(
            "Comprobantes: %d filas descartadas (FECHA/NRO_COMPROBANTE/IMPORTE nulo)",  # noqa: E501
            descartados,
        )

    logging.info("Comprobantes validados: %d registros OK", len(df_valido))
    return df_valido
