import sys
from pathlib import Path
import pandas as pd

# Agregar utils al path
sys.path.insert(0, str(Path(__file__).parent.parent / "utils"))  # noqa: E402
from conexion import get_connection  # noqa: E402

# ============================================================
# Script: 01_cargar_catalogos_B52.py
# Propósito: Ingesta dinámica de catálogos desde Excel funcionales
#             sin desperdicio
# Archivos Origen: Obras_Gerencias.xlsx y BaseCostosPOSE.xlsx
# Arquitectura B52: Desnormaliza las FK estáticas en catálogos y aplica UPSERT
# ============================================================

# Raíz del repositorio: resuelve independientemente
# del directorio de instalación
_REPO_ROOT = Path(__file__).resolve().parents[3]
FILE_OBRAS_GERENCIAS = _REPO_ROOT / "01_input_raw" / "Obras_Gerencias.xlsx"
FILE_COSTOS = _REPO_ROOT / "01_input_raw" / "BaseCostosPOSE.xlsx"


def upsert_catalogo(conn, tabla, campos_insert, valores_data, key_column):
    """
    Función genérica para aplicar Insert-If-Not-Exists
    Usamos fast_executemany con tablas temporales para alto rendimiento
    """
    cursor = conn.cursor()
    cursor.fast_executemany = True

    # Creamos string para los signos de interrogacion
    qmarks = ",".join(["?" for _ in campos_insert])
    cols_str = ",".join(campos_insert)

    # Lógica rudimentaria pero robusta en python puro via NOT EXISTS SQL:
    for row in valores_data:
        # Extraemos clave
        key_val = row[
            0
        ]  # asumiendo que el índice 0 de campos_insert es la natural key

        # Check if exists
        cursor.execute(
            f"SELECT 1 FROM {tabla} WHERE {key_column} = ?", (key_val,)
        )
        if not cursor.fetchone():
            sql = f"INSERT INTO {tabla} ({cols_str}) VALUES ({qmarks})"
            cursor.execute(sql, tuple(row))
    conn.commit()


def procesar_obras_gerencias(conn):
    print("🚀 Procesando RDP: Obras y Gerencias...")
    df = pd.read_excel(FILE_OBRAS_GERENCIAS)

    # 1. Gerencias - NORMALIZADO A MAYÚSCULAS
    print("   -> Gerencias")
    df_gerencias = df[["GERENCIA"]].dropna().drop_duplicates()
    gerencias_data = [
        (
            str(row["GERENCIA"]).upper().strip(),
            str(row["GERENCIA"]).upper().strip(),
        )
        for _, row in df_gerencias.iterrows()
    ]
    upsert_catalogo(
        conn,
        "CATALOGO.gerencias",
        ["codigo_gerencia", "nombre_gerencia"],
        gerencias_data,
        "codigo_gerencia",
    )

    # 2. Compensables - NORMALIZADO A MAYÚSCULAS
    print("   -> Compensables")
    df_comp = df[["COMPENSABLE"]].dropna().drop_duplicates()
    comp_data = [
        (str(row["COMPENSABLE"]).upper().strip(),)
        for _, row in df_comp.iterrows()
    ]
    upsert_catalogo(
        conn,
        "CATALOGO.compensables",
        ["estado_compensable"],
        comp_data,
        "estado_compensable",
    )

    # 3. Obras (mapear FKs a gerencias y compensables)
    print("   -> Obras (mapeo de FKs)")

    # Normalizar obra_pronto (zerofill para códigos numéricos)
    df["OBRA_PRONTO"] = (
        df["OBRA_PRONTO"].astype(str).str.replace(r"\.0$", "", regex=True)
    )
    df.loc[df["OBRA_PRONTO"].str.lower() == "nan", "OBRA_PRONTO"] = None
    df["OBRA_PRONTO"] = df["OBRA_PRONTO"].apply(
        lambda x: (
            str(x).strip().zfill(8)
            if str(x).strip().isdigit()
            else str(x).strip() if x else None
        )
    )

    # Normalizar GERENCIA, COMPENSABLE y DESCRIPCION_OBRA a MAYÚSCULAS
    df["GERENCIA"] = df["GERENCIA"].apply(
        lambda x: str(x).upper().strip() if pd.notna(x) else None
    )
    df["COMPENSABLE"] = df["COMPENSABLE"].apply(
        lambda x: str(x).upper().strip() if pd.notna(x) else None
    )
    df["DESCRIPCION_OBRA"] = df["DESCRIPCION_OBRA"].apply(
        lambda x: str(x).upper().strip() if pd.notna(x) else None
    )

    # Leer mapeos de catálogos recién insertados
    cursor = conn.cursor()
    cursor.execute(
        "SELECT codigo_gerencia, id_gerencia"
        " FROM CATALOGO.gerencias WHERE activo=1"
    )
    gerencia_map = {str(r[0]).upper().strip(): r[1] for r in cursor.fetchall()}

    cursor.execute(
        "SELECT estado_compensable, id_compensable"
        " FROM CATALOGO.compensables WHERE activo=1"
    )
    compensable_map = {
        str(r[0]).upper().strip(): r[1] for r in cursor.fetchall()
    }

    # Preparar datos de obras con FKs resueltas
    df_obras = (
        df[
            [
                "OBRA_PRONTO",
                "DESCRIPCION_OBRA",
                "NRO_OBRA",
                "COMPENSABLE",
                "GERENCIA",
            ]
        ]
        .dropna(subset=["OBRA_PRONTO"])
        .drop_duplicates(subset=["OBRA_PRONTO"])
    )

    insertadas = 0
    for _, row in df_obras.iterrows():
        obra_pronto = str(row["OBRA_PRONTO"]).strip()
        if not obra_pronto or obra_pronto.lower() == "nan":
            continue

        # Resolver FKs (ya normalizados a MAYÚSCULAS)
        gerencia_txt = (
            str(row.get("GERENCIA", "")).strip()
            if pd.notna(row.get("GERENCIA"))
            else None
        )
        compensable_txt = (
            str(row.get("COMPENSABLE", "")).strip()
            if pd.notna(row.get("COMPENSABLE"))
            else None
        )
        id_gerencia = gerencia_map.get(gerencia_txt) if gerencia_txt else None
        id_compensable = (
            compensable_map.get(compensable_txt) if compensable_txt else None
        )

        # Check si ya existe
        cursor.execute(
            "SELECT 1 FROM CATALOGO.obras WHERE obra_pronto = ?",
            (obra_pronto,),
        )
        if cursor.fetchone():
            continue  # Skip duplicado

        # Insert nueva obra (descripcion_obra ya está en MAYÚSCULAS)
        cursor.execute(
            """INSERT INTO CATALOGO.obras
               (obra_pronto, descripcion_obra, nro_obra,
                id_compensable, id_gerencia, activo)
               VALUES (?, ?, ?, ?, ?, 1)""",
            obra_pronto,
            (
                str(row.get("DESCRIPCION_OBRA", ""))[:600]
                if pd.notna(row.get("DESCRIPCION_OBRA"))
                else None
            ),
            int(row["NRO_OBRA"]) if pd.notna(row.get("NRO_OBRA")) else None,
            id_compensable,
            id_gerencia,
        )
        insertadas += 1

    conn.commit()
    print(
        f"   ✓ {insertadas} obras insertadas"
        " (total en catálogo con duplicados omitidos)"
    )


def procesar_dimensiones_dinamicas(conn):
    print(
        "🚀 Procesando Dimensiones desde Archivo Base de Costos"
        " (Solo Columnas Categoricas)..."
    )
    # Para optimizar RAM en B52, solo leemos estas columnas
    # CODIGO_CUENTA se lee como string para evitar conversión a float
    df = pd.read_excel(
        FILE_COSTOS,
        usecols=[
            "FUENTE",
            "TIPO_COMPROBANTE",
            "RUBRO_CONTABLE",
            "CODIGO_CUENTA",
            "CUENTA_CONTABLE",
        ],
        dtype={"CODIGO_CUENTA": str},
    )

    # 1. Fuentes - NORMALIZADO A MAYÚSCULAS
    print("   -> Fuentes")
    df_f = df[["FUENTE"]].dropna().drop_duplicates()
    f_data = [
        (
            str(row["FUENTE"]).upper().strip(),
            str(row["FUENTE"]).upper().strip(),
        )
        for _, row in df_f.iterrows()
    ]
    upsert_catalogo(
        conn,
        "CATALOGO.fuentes",
        ["codigo_fuente", "nombre_fuente"],
        f_data,
        "codigo_fuente",
    )

    # 2. Tipos de Comprobantes - NORMALIZADO A MAYÚSCULAS
    print("   -> Tipos Comprobantes")
    df_tc = df[["TIPO_COMPROBANTE"]].dropna().drop_duplicates()
    tc_data = [
        (str(row["TIPO_COMPROBANTE"]).upper().strip(),)
        for _, row in df_tc.iterrows()
    ]
    upsert_catalogo(
        conn,
        "CATALOGO.tipos_comprobantes",
        ["tipo_comprobante"],
        tc_data,
        "tipo_comprobante",
    )

    # 3. Cuentas Contables - NORMALIZADO A MAYÚSCULAS
    print("   -> Cuentas Contables")
    df_cc = (
        df[["RUBRO_CONTABLE", "CODIGO_CUENTA", "CUENTA_CONTABLE"]]
        .dropna(subset=["CODIGO_CUENTA"])
        .drop_duplicates()
    )

    # Limpiar código_cuenta: eliminar ".0" al final si existe
    # (ej: "521300002.0" → "521300002")
    def limpiar_codigo(val):
        s = str(val).strip()
        if s.endswith(".0"):
            return s[:-2]
        return s

    cc_data = [
        (
            (
                str(row["RUBRO_CONTABLE"]).upper().strip()[:150]
                if pd.notna(row.get("RUBRO_CONTABLE"))
                else None
            ),
            limpiar_codigo(row["CODIGO_CUENTA"])[:100],
            (
                str(row["CUENTA_CONTABLE"]).upper().strip()[:400]
                if pd.notna(row.get("CUENTA_CONTABLE"))
                else None
            ),
        )
        for _, row in df_cc.iterrows()
    ]
    upsert_catalogo(
        conn,
        "CATALOGO.cuentas_contables",
        ["rubro_contable", "codigo_cuenta", "cuenta_contable"],
        cc_data,
        "codigo_cuenta",
    )


def main():
    print(f"\n{'='*70}\n[B52] INGESTA DE CATÁLOGOS DINÁMICOS\n{'='*70}")
    conn = get_connection()
    try:
        procesar_obras_gerencias(conn)
        procesar_dimensiones_dinamicas(conn)
        print("\n✅ Finalizado B52 Catálogos!")
    except Exception as e:
        print(f"❌ Error: {e}")
        conn.rollback()
    finally:
        conn.close()


if __name__ == "__main__":
    main()
