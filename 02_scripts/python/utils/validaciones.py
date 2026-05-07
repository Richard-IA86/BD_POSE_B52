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


def validar_obras_en_datos(
    obras_en_catalogo: set[str],
    df: pd.DataFrame,
) -> None:
    """
    Valida que todos los OBRA_PRONTO del DataFrame existan en el
    catálogo activo antes de iniciar cualquier carga.

    Estrategia fail-fast: aborta con ValueError y reporte detallado
    si hay obras no mapeadas. No modifica la BD.
    Llamar en 03_cargar_costos_B52.py, antes de cualquier INSERT.

    Args:
        obras_en_catalogo: set de obra_pronto activas en CATALOGO.obras.
        df: DataFrame normalizado con columna OBRA_PRONTO.

    Raises:
        ValueError: si hay obras en el Excel sin registro
            en CATALOGO.obras activo.
    """
    if "OBRA_PRONTO" not in df.columns:
        return

    en_datos: set[str] = {
        str(v).strip()
        for v in df["OBRA_PRONTO"].dropna().unique()
        if str(v).strip().lower() not in ("", "nan")
    }

    faltantes = en_datos - obras_en_catalogo
    if not faltantes:
        logging.info(
            "Validacion obras: %d unicas en datos — todas en catalogo.",
            len(en_datos),
        )
        return

    conteos = (
        df[df["OBRA_PRONTO"].isin(faltantes)]
        .groupby("OBRA_PRONTO")
        .size()
        .sort_values(ascending=False)
    )
    lineas = [
        f"  {obra:<30} -> {cnt:>6} registros" for obra, cnt in conteos.items()
    ]
    detalle = "\n".join(lineas)
    raise ValueError(
        f"ABORT — {len(faltantes)} obra(s) no en catalogo:\n"
        f"{detalle}\n"
        "Accion: ejecutar 05_insertar_obras_especiales.py "
        "o agregar a config/obras_especiales.json."
    )
