"""
03_cargar_costos_B52.py — Carga Incremental MENSUAL de PRODUCCION.costos.

Estrategia: DELETE WHERE anio_dato=X AND mes_dato=Y → INSERT batch
Basado en 03_cargar_costos_A2.py v2.1 con adaptaciones para carga incremental.
"""

import argparse
import json
import logging
import re
import sys
from datetime import datetime
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).parent.parent / "utils"))  # noqa: E402
from auditoria_incremental import (  # noqa: E402
    registrar_inicio_periodo,
    registrar_fin_periodo,
    verificar_procesado_periodo,
)
from conexion import get_connection  # noqa: E402
from metricas_rendimiento import MedidorRendimiento  # noqa: E402

# Raíz del repositorio: resuelve independientemente del directorio de instalación  # noqa: E501
REPO_ROOT = Path(__file__).resolve().parents[3]
ARCHIVO_COSTOS = REPO_ROOT / "01_input_raw" / "BaseCostosPOSE.xlsx"
HOJA_COSTOS = "BaseCostosPOSE"  # Nombre de hoja; si falla se usa índice 0
LOG_DIR = REPO_ROOT / "00_logs"
BATCH_SIZE = 5000
USUARIO = "SCRIPT_03_COSTOS_B52"

# Columnas que deben existir en el Excel
COLUMNAS_ESPERADAS = {
    "OBRA_PRONTO",
    "FECHA",
    "IMPORTE",
    "TC",
    "IMPORTE_USD",
    "GERENCIA",
    "PROVEEDOR",
    "NRO_COMPROBANTE",
    "TIPO_COMPROBANTE",
    "OBSERVACION",
    "RUBRO_CONTABLE",
    "CUENTA_CONTABLE",
    "CODIGO_CUENTA",
    "COMPENSABLE",
    "FUENTE",
    "DESCRIPCION_OBRA",
    "DETALLE",
}

MAX_IMPORTE = 100_000_000_000
MIN_IMPORTE = -100_000_000_000
MAX_TC = 10_000

LOG_FILE = (
    LOG_DIR / f"{datetime.now().strftime('%Y%m%d_%H%M%S')}_03_costos.log"
)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-8s %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(LOG_FILE, encoding="utf-8"),
    ],
)


# ---------------------------------------------------------------------------
# Conversión de tipos (igual que A2)
# ---------------------------------------------------------------------------


def _str_to_float(valor):
    """Convierte formato numérico argentino a float."""
    if pd.isna(valor) or valor == "":
        return None
    valor = str(valor).strip()
    if not valor:
        return None
    neg = -1 if valor.startswith("-") else 1
    valor = re.sub(r"[^\d,.]", "", valor)
    if "," in valor and "." in valor:
        if valor.rfind(",") > valor.rfind("."):
            valor = valor.replace(".", "").replace(",", ".")
        else:
            valor = valor.replace(",", "")
    elif "," in valor:
        partes = valor.split(",")
        if len(partes) == 2:
            valor = partes[0] + "." + partes[1]
        else:
            return None
    try:
        return float(valor) * neg
    except ValueError:
        return None


def _conv_num(val):
    if isinstance(val, (int, float)):
        return float(val) if not pd.isna(val) else None
    if isinstance(val, str):
        return _str_to_float(val)
    return None


def _conv_fecha(val):
    if pd.isna(val) or val == "":
        return None
    if isinstance(val, (datetime, pd.Timestamp)):
        return val
    for fmt in ("%d/%m/%Y", "%d/%m/%y", "%d-%m-%Y", "%d-%m-%y"):
        try:
            return datetime.strptime(str(val).strip(), fmt)
        except ValueError:
            continue
    return None


def _s(val, maxlen=None):
    """String-safe: convierte a str truncado, o None si nulo."""
    if val is None or (not isinstance(val, str) and pd.isna(val)):
        return None
    s = str(val).strip()
    if s.lower() == "nan" or s == "":
        return None
    return s[:maxlen] if maxlen else s


def _clamp(val, lo, hi):
    """Limita un valor numérico al rango [lo, hi]."""
    if val is None:
        return None
    try:
        v = float(val)
        return max(min(v, hi), lo)
    except (ValueError, OverflowError):
        return None


# ---------------------------------------------------------------------------
# Lectura y normalización (basado en A2.normalizar_dataframe)
# ---------------------------------------------------------------------------


def leer_y_normalizar() -> pd.DataFrame:
    logging.info(
        "Leyendo: %s  (%.1f MB)",
        ARCHIVO_COSTOS,
        ARCHIVO_COSTOS.stat().st_size / 1_048_576,
    )

    # Leer importes como string para evitar pérdida de precisión (igual que A2)
    dtype_str = {"IMPORTE": str, "TC": str, "IMPORTE_USD": str}
    try:
        df = pd.read_excel(
            ARCHIVO_COSTOS,
            sheet_name=HOJA_COSTOS,
            engine="openpyxl",
            dtype=dtype_str,
        )
        logging.info("Hoja '%s' cargada.", HOJA_COSTOS)
    except Exception:
        logging.warning(
            "Hoja '%s' no encontrada — usando índice 0.", HOJA_COSTOS
        )
        df = pd.read_excel(
            ARCHIVO_COSTOS, sheet_name=0, engine="openpyxl", dtype=dtype_str
        )

    logging.info("Filas leídas: %d", len(df))

    # Normalizar nombres de columnas (igual que A2)
    df.columns = (
        df.columns.str.upper()
        .str.strip()
        .str.replace(r"\s+", "_", regex=True)
        .str.replace(r"_+", "_", regex=True)
        .str.replace("°", "", regex=False)
        .str.replace("N°", "NRO", regex=False)
        .str.replace("Nº", "NRO", regex=False)
    )

    # Reporte de columnas
    faltantes = COLUMNAS_ESPERADAS - set(df.columns)
    if faltantes:
        logging.warning("Columnas NO encontradas: %s", sorted(faltantes))
    extras = set(df.columns) - COLUMNAS_ESPERADAS
    if extras:
        logging.info("Columnas extra (ignoradas): %s", sorted(extras))

    # Convertir tipos
    df["FECHA"] = (
        df["FECHA"].apply(_conv_fecha) if "FECHA" in df.columns else None
    )
    df["IMPORTE"] = (
        df["IMPORTE"].apply(_conv_num) if "IMPORTE" in df.columns else None
    )
    df["TC"] = df["TC"].apply(_conv_num) if "TC" in df.columns else None
    df["IMPORTE_USD"] = (
        df["IMPORTE_USD"].apply(_conv_num)
        if "IMPORTE_USD" in df.columns
        else None
    )

    if "OBRA_PRONTO" in df.columns:

        def _norm_op(v):
            s = str(v).strip()
            if s.lower() in ("nan", ""):
                return None
            return s.zfill(8) if s.isdigit() else s

        df["OBRA_PRONTO"] = df["OBRA_PRONTO"].apply(_norm_op)

    # Columnas de partición
    fechas_ts = pd.to_datetime(df["FECHA"], errors="coerce")
    df["anio_dato"] = fechas_ts.dt.year.astype("Int64")
    df["mes_dato"] = fechas_ts.dt.month.astype("Int64")
    df["periodo_codigo"] = fechas_ts.dt.strftime("%Y%m")

    n_periodos = df["periodo_codigo"].nunique()
    logging.info("Períodos únicos en archivo: %d", n_periodos)
    return df


# ---------------------------------------------------------------------------
# Validación por fila (igual que A2)
# ---------------------------------------------------------------------------


def validar_fila(row, idx, obras_validas: set):
    errores = []
    if not row.get("OBRA_PRONTO") or pd.isna(row.get("OBRA_PRONTO")):
        errores.append("OBRA_PRONTO vacío")
    elif (
        obras_validas and str(row["OBRA_PRONTO"]).strip() not in obras_validas
    ):
        errores.append(
            f"OBRA_PRONTO no existe en catálogo: [{row['OBRA_PRONTO']}]"
        )

    if not row.get("FECHA") or pd.isna(row.get("FECHA")):
        errores.append("FECHA vacía o inválida")

    imp = row.get("IMPORTE")
    if imp is not None and not pd.isna(imp):
        if imp > MAX_IMPORTE or imp < MIN_IMPORTE:
            errores.append(f"IMPORTE fuera de rango: {imp}")

    tc = row.get("TC")
    if tc is not None and not pd.isna(tc):
        if tc > MAX_TC or tc < 0:
            errores.append(f"TC fuera de rango: {tc}")

    return (True, None) if not errores else (False, "; ".join(errores))


# ---------------------------------------------------------------------------
# Mapeo de claves naturales a surrogate keys (Star Schema v2.1)
# ---------------------------------------------------------------------------


def cargar_mapeo_obras(conn) -> dict:
    """
    Carga mapeo obra_pronto (clave natural) → id_obra (surrogate key).
    Retorna dict {obra_pronto: id_obra} para resolución de FK.
    """
    cursor = conn.cursor()
    cursor.execute(
        "SELECT obra_pronto, id_obra FROM CATALOGO.obras WHERE activo=1"
    )
    mapeo = {str(r[0]).strip(): r[1] for r in cursor.fetchall() if r[0]}
    logging.info("Obras cargadas en mapeo: %d", len(mapeo))
    return mapeo


# ---------------------------------------------------------------------------
# INSERT batch (CORREGIDO: usa id_obra INT, no obra_pronto VARCHAR)
# ---------------------------------------------------------------------------


def _insertar_rows(
    conn, id_log: int, df_batch: pd.DataFrame, fuente_map: dict, obra_map: dict
) -> None:
    """
    Inserta batch en PRODUCCION.costos usando surrogate keys (Star Schema).

    Args:
        obra_map: dict {obra_pronto: id_obra} para mapeo de claves naturales
    """
    cursor = conn.cursor()
    for idx, row in df_batch.iterrows():
        fuente_txt = _s(row.get("FUENTE"), 100)
        fuente_id = fuente_map.get(fuente_txt) if fuente_txt else None

        # Mapeo obra_pronto → id_obra (Star Schema v2.1)
        obra_pronto_str = _s(row.get("OBRA_PRONTO"), 50)
        id_obra = obra_map.get(obra_pronto_str) if obra_pronto_str else None
        if not id_obra and obra_pronto_str:
            logging.warning(
                "Fila %d: obra_pronto '%s' no existe en catálogo (skipped)",
                idx,
                obra_pronto_str,
            )
            continue  # Skip fila si obra no existe

        try:
            cursor.execute(
                """
                INSERT INTO PRODUCCION.costos (
                    id_log_carga, id_obra, fecha, importe, tipo_cambio, importe_usd,  # noqa: E501
                    nombre_proveedor, numero_comprobante, observacion,
                    descripcion_obra, detalle,
                    archivo_origen, fila_excel, fecha_carga, usuario_carga,
                    anio_dato, mes_dato, id_fuente
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,GETDATE(),?,?,?,?)
                """,
                id_log,
                id_obra,  # ✓ INT surrogate key
                row.get("FECHA"),
                _clamp(row.get("IMPORTE"), -9.99e12, 9.99e12),
                _clamp(row.get("TC"), -9.99e12, 9.99e12),
                _clamp(row.get("IMPORTE_USD"), -9.99e12, 9.99e12),
                _s(row.get("PROVEEDOR"), 600),
                _s(row.get("NRO_COMPROBANTE"), 200),
                _s(row.get("OBSERVACION")),
                _s(row.get("DESCRIPCION_OBRA"), 600),
                _s(row.get("DETALLE"), 1000),
                str(ARCHIVO_COSTOS),
                int(idx) + 2,
                USUARIO,
                int(row["anio_dato"]),
                int(row["mes_dato"]),
                fuente_id,
            )
        except Exception as e:
            raise Exception(f"Error en fila {idx}: {e}") from e
    conn.commit()


# ---------------------------------------------------------------------------
# Sincronización automática de fuentes
# ---------------------------------------------------------------------------


def sincronizar_fuentes(conn, df: pd.DataFrame) -> dict:
    """Registra en CATALOGO.fuentes las fuentes nuevas del Excel (es_automatica=1).  # noqa: E501
    Retorna dict {codigo_fuente: id_fuente} para resolución de FK en cada fila.
    """
    fuentes_excel = (
        {
            str(v).strip()
            for v in df["FUENTE"].dropna().unique()
            if str(v).strip().lower() not in ("", "nan")
        }
        if "FUENTE" in df.columns
        else set()
    )

    cursor = conn.cursor()
    cursor.execute(
        "SELECT codigo_fuente, id_fuente FROM CATALOGO.fuentes WHERE activo=1"
    )
    fuente_map = {r[0]: r[1] for r in cursor.fetchall()}

    nuevas = fuentes_excel - set(fuente_map.keys())
    for cod in sorted(nuevas):
        cursor.execute(
            """
            INSERT INTO CATALOGO.fuentes (codigo_fuente, nombre_fuente, es_automatica, activo)  # noqa: E501
            OUTPUT INSERTED.id_fuente
            VALUES (?, ?, 1, 1)
            """,
            cod,
            cod,
        )
        new_id = cursor.fetchone()[0]
        fuente_map[cod] = new_id
        logging.info("  + Fuente auto-registrada: '%s' (id=%d)", cod, new_id)
    if nuevas:
        conn.commit()
        logging.info(
            "Fuentes sincronizadas: %d nuevas, %d totales.",
            len(nuevas),
            len(fuente_map),
        )
    else:
        logging.info(
            "Fuentes en Excel: %d — todas ya registradas (%d en catálogo).",
            len(fuentes_excel),
            len(fuente_map),
        )
    return fuente_map


# ---------------------------------------------------------------------------
# Carga por período
# ---------------------------------------------------------------------------


def borrar_periodo(conn, anio: int, mes: int) -> int:
    cursor = conn.cursor()
    cursor.execute(
        "SELECT COUNT(*) FROM PRODUCCION.costos WHERE anio_dato=? AND mes_dato=?",  # noqa: E501
        anio,
        mes,
    )
    n = cursor.fetchone()[0]
    if n > 0:
        cursor.execute(
            "DELETE FROM PRODUCCION.costos WHERE anio_dato=? AND mes_dato=?",
            anio,
            mes,
        )
        conn.commit()
        logging.info("  Borrados %d registros (%04d-%02d)", n, anio, mes)
    return n


def _registrar_rechazos(conn, id_log: int, rechazos: list) -> None:
    if not rechazos:
        return
    cursor = conn.cursor()
    for idx, motivo, row in rechazos:
        cursor.execute(
            """INSERT INTO AUDITORIA.rechazos
               (id_log_carga, fila_excel, motivo_rechazo, datos_rechazo)
               VALUES (?,?,?,?)""",
            id_log,
            int(idx) + 2,
            motivo,
            json.dumps(row.to_dict(), default=str, ensure_ascii=False),
        )
    conn.commit()
    logging.info(
        "  %d rechazos registrados en AUDITORIA.rechazos", len(rechazos)
    )


def cargar_periodo(
    conn,
    df: pd.DataFrame,
    obras_validas: set,
    fuente_map: dict,
    obra_map: dict,
    anio: int,
    mes: int,
    force: bool = False,
) -> None:
    periodo_codigo = f"{anio:04d}{mes:02d}"
    logging.info("=" * 60)
    logging.info("PERÍODO: %s", periodo_codigo)

    if not force:
        ya, id_prev = verificar_procesado_periodo(
            conn, "PRODUCCION.costos", periodo_codigo
        )
        if ya:
            logging.info(
                "  ⚠ Ya procesado (id_periodo=%s) — use --force.", id_prev
            )
            return

    medidor = MedidorRendimiento(f"costos_{periodo_codigo}")
    medidor.iniciar()
    id_log, id_periodo = registrar_inicio_periodo(
        conn,
        "PRODUCCION.costos",
        "MENSUAL",
        anio,
        mes,
        periodo_codigo,
        USUARIO,
    )
    try:
        df_p = df[(df["anio_dato"] == anio) & (df["mes_dato"] == mes)].copy()
        if len(df_p) == 0:
            logging.warning("  Sin datos para período %s", periodo_codigo)
            registrar_fin_periodo(
                conn,
                id_log,
                id_periodo,
                0,
                0,
                0.0,
                "VACIO",
                "Sin datos en Excel",
            )
            return

        # Validar filas del período
        validas, rechazos = [], []
        for idx, row in df_p.iterrows():
            ok, motivo = validar_fila(row, idx, obras_validas)
            if ok:
                validas.append(idx)
            else:
                rechazos.append((idx, motivo, row))

        logging.info(
            "  Válidas: %d | Rechazadas: %d", len(validas), len(rechazos)
        )

        if not validas:
            _registrar_rechazos(conn, id_log, rechazos)
            registrar_fin_periodo(
                conn,
                id_log,
                id_periodo,
                0,
                0,
                0.0,
                "VACIO",
                "Sin filas válidas",
            )
            return

        medidor.marcar_fase("DELETE")
        borrados = borrar_periodo(conn, anio, mes)

        medidor.marcar_fase("INSERT")
        df_validas = df_p.loc[validas]
        insertados = 0
        for i in range(0, len(df_validas), BATCH_SIZE):
            batch = df_validas.iloc[i : i + BATCH_SIZE]  # noqa: E203
            _insertar_rows(conn, id_log, batch, fuente_map, obra_map)
            insertados += len(batch)
            logging.info(
                "  Inserción: %d/%d (%.0f%%)",
                insertados,
                len(df_validas),
                100 * insertados / len(df_validas),
            )

        _registrar_rechazos(conn, id_log, rechazos)

        # Verificación de integridad: filas en BD deben coincidir con insertados  # noqa: E501
        cur_check = conn.cursor()
        cur_check.execute(
            "SELECT COUNT(*) FROM PRODUCCION.costos WHERE anio_dato=? AND mes_dato=?",  # noqa: E501
            anio,
            mes,
        )
        filas_en_bd = cur_check.fetchone()[0]
        if filas_en_bd != insertados:
            logging.warning(
                "  ⚠ DISCREPANCIA en %s: Python insertó %d filas pero BD tiene %d",  # noqa: E501
                periodo_codigo,
                insertados,
                filas_en_bd,
            )
            estado_final = "ADVERTENCIA"
        else:
            logging.info(
                "  ✔ Verificación OK: %d filas en BD == %d insertadas",
                filas_en_bd,
                insertados,
            )
            estado_final = "EXITOSO"

        medidor.finalizar()
        vel = medidor.calcular_velocidad(insertados)
        registrar_fin_periodo(
            conn,
            id_log,
            id_periodo,
            borrados,
            insertados,
            medidor.duracion_total,
            estado_final,
            f"Val:{len(validas)} Rech:{len(rechazos)} BD:{filas_en_bd} Vel:{vel:.0f}reg/s",  # noqa: E501
        )
        logging.info(
            "  ✅ %s — %d insertados, %d rechazados, %.1fs",
            periodo_codigo,
            insertados,
            len(rechazos),
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
            str(exc)[:500],
        )
        logging.error("  ❌ Error período %s: %s", periodo_codigo, exc)
        raise


# ---------------------------------------------------------------------------
# Recuperación retroactiva de rechazos al dar de alta una obra
# ---------------------------------------------------------------------------


def recuperar_rechazos_obra(
    conn,
    obra_pronto: str,
    df: pd.DataFrame,
    obras_validas: set,
    fuente_map: dict,
    obra_map: dict,
) -> None:
    """Recupera registros rechazados de una obra recién dada de alta en catálogo.  # noqa: E501

    Consulta AUDITORIA.rechazos para obtener los períodos donde la obra fue
    rechazada, luego fuerza la recarga de esos períodos con force=True.
    Esta vez la obra ya está en el catálogo → el registro pasa validación.
    """
    cursor = conn.cursor()
    cursor.execute(
        """
        SELECT DISTINCT
            YEAR(CAST(JSON_VALUE(datos_rechazo, '$.FECHA') AS datetime))  AS anio,  # noqa: E501
            MONTH(CAST(JSON_VALUE(datos_rechazo, '$.FECHA') AS datetime)) AS mes  # noqa: E501
        FROM AUDITORIA.rechazos
        WHERE JSON_VALUE(datos_rechazo, '$.OBRA_PRONTO') = ?
          AND JSON_VALUE(datos_rechazo, '$.FECHA') IS NOT NULL
        ORDER BY anio, mes
        """,
        obra_pronto,
    )
    periodos = cursor.fetchall()

    if not periodos:
        logging.warning(
            "No se encontraron rechazos para obra '%s'. "
            "¿Ya fue recuperada o el código es incorrecto?",
            obra_pronto,
        )
        return

    if obra_pronto not in obras_validas:
        logging.error(
            "Obra '%s' NO está en catálogo activo. "
            "Dar de alta la obra primero y luego ejecutar --recuperar-obra.",
            obra_pronto,
        )
        return

    logging.info(
        "Obra '%s': %d período(s) con rechazos → forzando recarga.",
        obra_pronto,
        len(periodos),
    )
    for anio, mes in periodos:
        cargar_periodo(
            conn,
            df,
            obras_validas,
            fuente_map,
            obra_map,
            int(anio),
            int(mes),
            force=True,
        )
    logging.info("✅ Recuperación obra '%s' completada.", obra_pronto)


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(
        description="Carga incremental MENSUAL de costos B52"
    )
    parser.add_argument("--periodos", type=str, help="YYYYMM,YYYYMM,...")
    parser.add_argument(
        "--full", action="store_true", help="Todos los períodos del archivo"
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Re-cargar aunque ya esté procesado",
    )
    parser.add_argument(
        "--recuperar-obra",
        type=str,
        metavar="OBRA_PRONTO",
        help="Recupera rechazos históricos de una obra recién dada de alta",
    )
    args = parser.parse_args()

    if not ARCHIVO_COSTOS.exists():
        logging.error("Archivo no encontrado: %s", ARCHIVO_COSTOS)
        sys.exit(1)

    df = leer_y_normalizar()
    conn = get_connection()
    try:
        # Cargar catálogo de obras válidas para validación referencial
        cursor = conn.cursor()
        cursor.execute("SELECT obra_pronto FROM CATALOGO.obras WHERE activo=1")
        obras_validas = {
            v.zfill(8) if v.isdigit() else v
            for r in cursor.fetchall()
            for v in [str(r[0]).strip()]
        }
        logging.info(
            "Catálogo: %d obras activas cargadas.", len(obras_validas)
        )

        # Cargar mapeo obra_pronto → id_obra (Star Schema v2.1)
        obra_map = cargar_mapeo_obras(conn)

        # Sincronizar fuentes automáticamente desde el Excel
        fuente_map = sincronizar_fuentes(conn, df)

        if args.recuperar_obra:
            obra = args.recuperar_obra.strip()
            obra = obra.zfill(8) if obra.isdigit() else obra
            logging.info("Modo RECUPERAR-OBRA: '%s'", obra)
            recuperar_rechazos_obra(
                conn, obra, df, obras_validas, fuente_map, obra_map
            )
        elif args.full:
            unicos = (
                df[["anio_dato", "mes_dato"]]
                .dropna()
                .drop_duplicates()
                .sort_values(["anio_dato", "mes_dato"])
            )
            logging.info("Modo FULL: %d períodos a procesar", len(unicos))
            for _, row in unicos.iterrows():
                cargar_periodo(
                    conn,
                    df,
                    obras_validas,
                    fuente_map,
                    obra_map,
                    int(row["anio_dato"]),
                    int(row["mes_dato"]),
                    args.force,
                )
        elif args.periodos:
            for p in args.periodos.split(","):
                p = p.strip()
                if len(p) != 6 or not p.isdigit():
                    logging.warning("Formato inválido: '%s' — use YYYYMM", p)
                    continue
                cargar_periodo(
                    conn,
                    df,
                    obras_validas,
                    fuente_map,
                    obra_map,
                    int(p[:4]),
                    int(p[4:]),
                    args.force,
                )
        else:
            logging.error(
                "Especificar --periodos YYYYMM,... o --full o --recuperar-obra OBRA"  # noqa: E501
            )
            sys.exit(1)
    finally:
        conn.close()

    logging.info("PROCESO COSTOS FINALIZADO. Log: %s", LOG_FILE)


if __name__ == "__main__":
    main()
