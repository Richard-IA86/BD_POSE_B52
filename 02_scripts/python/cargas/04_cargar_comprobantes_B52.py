"""
04_cargar_comprobantes_B52.py — Carga Incremental ANUAL de PRODUCCION.comprobantes.  # noqa: E501

Estrategia: DELETE WHERE anio_dato=X → INSERT batch
"""

import argparse
import logging
import sys
from datetime import datetime
from pathlib import Path

import pandas as pd
import pyodbc

sys.path.insert(0, str(Path(__file__).parent.parent / "utils"))
from auditoria_incremental import (  # noqa: E402
    registrar_inicio_periodo,
    registrar_fin_periodo,
    verificar_procesado_periodo,
)
from conexion import get_connection  # noqa: E402
from metricas_rendimiento import MedidorRendimiento  # noqa: E402
from validaciones import validar_schema_comprobantes  # type: ignore[attr-defined]  # noqa: E402, E501

# Raíz del repositorio: resuelve independientemente del directorio de instalación  # noqa: E501
REPO_ROOT = Path(__file__).resolve().parents[3]
ARCHIVO = REPO_ROOT / "01_input_raw" / "ComprobantesPOSE_Acum.xlsx"
HOJA = "Hoja1"
LOG_DIR = REPO_ROOT / "00_logs"
BATCH_SIZE = 5000
USUARIO = "SCRIPT_04_COMPROBANTES_B52"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-8s %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(
            LOG_DIR
            / f"{datetime.now().strftime('%Y%m%d_%H%M%S')}_04_comprobantes.log",  # noqa: E501
            encoding="utf-8",
        ),
    ],
)


# ---------------------------------------------------------------------------
# Mapeo de claves naturales a surrogate keys (Star Schema v2.1)
# ---------------------------------------------------------------------------


def cargar_mapeo_obras(conn) -> dict:
    """Carga mapeo obra_pronto → id_obra para resolución de FK."""
    cursor = conn.cursor()
    cursor.execute(
        "SELECT obra_pronto, id_obra FROM CATALOGO.obras WHERE activo=1"
    )  # noqa: E501
    mapeo = {
        str(r[0]).strip().upper(): r[1] for r in cursor.fetchall() if r[0]
    }  # noqa: E501
    logging.info("Obras cargadas en mapeo: %d", len(mapeo))
    return mapeo


def leer_comprobantes() -> pd.DataFrame:
    """Lee comprobantes desde Excel (patrón A2)"""
    logging.info("Leyendo: %s", ARCHIVO)

    # Leer Excel con openpyxl (igual que A2)
    df = pd.read_excel(ARCHIVO, sheet_name=HOJA, engine="openpyxl")

    # Mapeo de columnas (nombres exactos del Excel)
    mapeo_columnas = {
        "Fecha comp.": "FECHA_COMPROBANTE",
        "Obras": "OBRA_PRONTO",
        "Numero": "NRO_COMPROBANTE",
        "Proveedor / Cuenta": "PROVEEDOR",
        "Cod.prov.": "COD_PROVEEDOR",
        "Total": "IMPORTE",
    }

    # Renombrar columnas según mapeo
    df.rename(columns=mapeo_columnas, inplace=True)

    df["FECHA_COMPROBANTE"] = pd.to_datetime(
        df["FECHA_COMPROBANTE"], errors="coerce"
    )  # noqa: E501
    df["anio_dato"] = df["FECHA_COMPROBANTE"].dt.year.astype("Int64")
    df = validar_schema_comprobantes(df)
    logging.info(
        "Registros válidos: %d | Años únicos: %d",
        len(df),
        df["anio_dato"].nunique(),
    )
    return df


def borrar_anio(conn, anio: int) -> int:
    cursor = conn.cursor()
    cursor.execute(
        "SELECT COUNT(*) FROM PRODUCCION.comprobantes WHERE anio_dato=?", anio
    )
    n = cursor.fetchone()[0]
    if n > 0:
        cursor.execute(
            "DELETE FROM PRODUCCION.comprobantes WHERE anio_dato=?", anio
        )  # noqa: E501
        conn.commit()
        logging.info("  Borrados %d registros (año %d)", n, anio)
    else:
        logging.info("  Año %d vacío (carga inicial)", anio)
    return n


def insertar_batch(
    conn, df_anio: pd.DataFrame, id_log_carga: int, anio: int, obra_map: dict
) -> int:
    """
    Inserta batch en PRODUCCION.comprobantes usando surrogate keys (Star Schema).  # noqa: E501

    Args:
        obra_map: dict {obra_pronto: id_obra} para mapeo de claves naturales
    """
    cursor = conn.cursor()
    query = """
        INSERT INTO PRODUCCION.comprobantes (
            id_log_carga, id_obra, obra_pronto_crudo, numero_comprobante, numero_comprobante_norm,  # noqa: E501
            fecha_comprobante, cod_proveedor, nombre_proveedor, nombre_proveedor_norm,  # noqa: E501
            importe, archivo_origen, hoja_origen, fila_excel, fecha_carga,
            usuario_carga, anio_dato
        ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,GETDATE(),?,?)
    """
    total = 0
    skipped = 0
    for i in range(0, len(df_anio), BATCH_SIZE):
        batch = df_anio.iloc[i : i + BATCH_SIZE]  # noqa: E203
        rows_batch = []

        for idx, row in batch.iterrows():
            # Extraer dato crudo de obra (mantener original)
            obra_pronto_raw = row.get("OBRA_PRONTO")
            if pd.notna(obra_pronto_raw):
                obra_pronto_crudo = str(obra_pronto_raw).strip()[:200]
            else:
                obra_pronto_crudo = None

            # Intentar mapeo obra_pronto → id_obra (Star Schema v2.1)
            # Solo si es valor único y válido, sino id_obra=NULL
            obra_pronto_str = (
                obra_pronto_crudo.upper() if obra_pronto_crudo else None
            )  # noqa: E501
            id_obra = (
                obra_map.get(obra_pronto_str) if obra_pronto_str else None
            )  # noqa: E501

            # Si no se puede resolver FK, seguir con id_obra=NULL (NO rechazar)
            if not id_obra and obra_pronto_str and " " not in obra_pronto_str:
                logging.debug(
                    "Fila %d: obra_pronto '%s' no en catálogo → id_obra=NULL",
                    idx,
                    obra_pronto_str[:50],
                )

            try:
                # Convertir Timestamp a datetime nativo (pyodbc no soporta pandas Timestamp)  # noqa: E501
                fecha_comp = row.get("FECHA_COMPROBANTE")
                if pd.notna(fecha_comp):
                    fecha_comp = (
                        fecha_comp.to_pydatetime()
                        if hasattr(fecha_comp, "to_pydatetime")
                        else fecha_comp
                    )
                else:
                    fecha_comp = None

                # Normalizar campos de texto (patrón A2 - manejar NaN explícitamente)  # noqa: E501
                nro_comp = (
                    str(row.get("NRO_COMPROBANTE", "")).strip()
                    if pd.notna(row.get("NRO_COMPROBANTE"))
                    else None
                )
                nro_comp_norm = row.get("NRO_COMPROBANTE_NORM")
                if pd.isna(nro_comp_norm) and nro_comp:
                    nro_comp_norm = nro_comp.upper()
                elif pd.isna(nro_comp_norm):
                    nro_comp_norm = None
                else:
                    nro_comp_norm = str(nro_comp_norm)

                cod_prov = (
                    str(row.get("COD_PROVEEDOR"))[:100]
                    if pd.notna(row.get("COD_PROVEEDOR"))
                    else None
                )

                proveedor_val = row.get("PROVEEDOR")
                proveedor = (
                    str(proveedor_val)[:600]
                    if pd.notna(proveedor_val)
                    else None  # noqa: E501
                )

                proveedor_norm_val = row.get("PROVEEDOR_NORM")
                if pd.isna(proveedor_norm_val) and proveedor:
                    proveedor_norm = proveedor.upper()[:600]
                elif pd.notna(proveedor_norm_val):
                    proveedor_norm = str(proveedor_norm_val)[:600]
                else:
                    proveedor_norm = None

                # Agregar a batch (tupla con todos los parámetros)
                rows_batch.append(
                    (
                        id_log_carga,
                        id_obra,  # NULL si no se pudo resolver FK
                        obra_pronto_crudo,  # Dato original del Excel
                        nro_comp,
                        nro_comp_norm,
                        fecha_comp,
                        cod_prov,
                        proveedor,
                        proveedor_norm,
                        row.get(
                            "IMPORTE"
                        ),  # Directo del DataFrame (patrón A2)  # noqa: E501
                        str(ARCHIVO.name),
                        HOJA,  # hoja_origen (Excel)
                        int(idx)
                        + 2,  # fila_excel (header=row 1, data starts row 2)  # noqa: E501
                        USUARIO,
                        anio,
                    )
                )
            except Exception as e:
                logging.error(
                    f"  Error preparando fila {row.get('NRO_COMPROBANTE')}: {str(e)[:200]}"  # noqa: E501
                )
                skipped += 1
                continue

        # Insertar registros uno por uno para manejar duplicados (patrón A2)
        for row_data in rows_batch:
            try:
                cursor.execute(query, row_data)
                total += 1
            except pyodbc.IntegrityError as e:
                if "UQ_comprobantes_key" in str(e):
                    # Duplicado - ignorar silenciosamente
                    skipped += 1
                else:
                    logging.error(f"  Error integridad: {str(e)[:150]}")
                    skipped += 1
            except Exception as e:
                logging.error(f"  Error SQL: {str(e)[:150]}")
                skipped += 1

        # Commit cada batch de 5000
        conn.commit()
        if (i // BATCH_SIZE) % 2 == 1:  # Log cada 2 batches (10K registros)
            logging.info(
                f"    Procesados {min(i + BATCH_SIZE, len(df_anio))}/{len(df_anio)} registros..."  # noqa: E501
            )

    logging.info(
        "  Inserción: %d/%d (%.0f%%) [%d skipped]",
        total,
        len(df_anio),
        100 * total / len(df_anio) if len(df_anio) > 0 else 0,
        skipped,
    )

    if skipped > 0:
        logging.warning(
            "  ⚠ %d registros omitidos por obra_pronto inválido", skipped
        )  # noqa: E501
    return total


def cargar_anio(
    conn, df: pd.DataFrame, obra_map: dict, anio: int, force: bool = False
) -> None:
    periodo_codigo = str(anio)
    logging.info("=" * 60)
    logging.info("AÑO: %d", anio)

    if not force:
        ya, id_prev = verificar_procesado_periodo(
            conn, "PRODUCCION.comprobantes", periodo_codigo
        )
        if ya:
            logging.info(
                "  ⚠ Ya procesado (id=%s) — use --force para recargar.",
                id_prev,
            )
            return

    medidor = MedidorRendimiento(f"comprobantes_{anio}")
    medidor.iniciar()
    id_log, id_periodo = registrar_inicio_periodo(
        conn,
        "PRODUCCION.comprobantes",
        "ANUAL",
        anio,
        None,
        periodo_codigo,
        USUARIO,
    )
    try:
        medidor.marcar_fase("DELETE")
        borrados = borrar_anio(conn, anio)

        df_a = df[df["anio_dato"] == anio].copy()
        if len(df_a) == 0:
            logging.warning("  Sin datos para año %d", anio)
            registrar_fin_periodo(
                conn,
                id_log,
                id_periodo,
                borrados,
                0,
                medidor.duracion_total,
                "VACIO",
                "Sin datos en Excel",
            )
            return

        medidor.marcar_fase("INSERT")
        insertados = insertar_batch(conn, df_a, id_log, anio, obra_map)

        medidor.finalizar()
        vel = medidor.calcular_velocidad(insertados)
        registrar_fin_periodo(
            conn,
            id_log,
            id_periodo,
            borrados,
            insertados,
            medidor.duracion_total,
            "EXITOSO",
            f"Vel: {vel:.1f} reg/s",
        )
        logging.info(
            "  ✅ Año %d OK — %d insertados en %.2fs",
            anio,
            insertados,
            medidor.duracion_total,
        )
        medidor.imprimir_resumen()

    except Exception as exc:
        medidor.finalizar()
        registrar_fin_periodo(
            conn,
            id_log,
            id_periodo,
            0,
            0,
            medidor.duracion_total,
            "ERROR",
            str(exc),
        )
        logging.error("  ❌ Error año %d: %s", anio, exc)
        raise


def main():
    parser = argparse.ArgumentParser(
        description="Carga incremental ANUAL de comprobantes B52"
    )
    parser.add_argument("--anio", type=int, help="Año a cargar (YYYY)")
    parser.add_argument(
        "--full", action="store_true", help="Todos los años del archivo"
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Re-cargar aunque ya esté procesado",
    )
    args = parser.parse_args()

    df = leer_comprobantes()
    conn = get_connection()
    try:
        # Cargar mapeo obra_pronto → id_obra (Star Schema v2.1)
        obra_map = cargar_mapeo_obras(conn)

        if args.full:
            anios = sorted(df["anio_dato"].dropna().unique().astype(int))
            logging.info("Modo FULL: %d años detectados", len(anios))
            for anio in anios:
                cargar_anio(conn, df, obra_map, int(anio), args.force)
        elif args.anio:
            cargar_anio(conn, df, obra_map, args.anio, args.force)
        else:
            logging.error("Especificar --anio YYYY o --full")
            sys.exit(1)
    finally:
        conn.close()
    logging.info("PROCESO COMPROBANTES FINALIZADO")


if __name__ == "__main__":
    main()
