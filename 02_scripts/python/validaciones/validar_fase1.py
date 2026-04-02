"""
validar_fase1.py — Verifica que la Fase 1 (estructura BD) esté completa.

Comprueba:
  ✅ BD DW_GrupoPOSE_B52 existe
  ✅ Los 5 esquemas existen
  ✅ Las tablas clave existen (al menos 15)
  ✅ CATALOGO.fuentes tiene registros
  ✅ CATALOGO.calendario tiene registros

Salida:
  exit(0) si todo OK
  exit(1) con detalle del problema
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "utils"))
from conexion import get_connection  # noqa: E402

VERDE = "\033[92m"
ROJO = "\033[91m"
RESET = "\033[0m"
OK = f"{VERDE}✅{RESET}"
FAIL = f"{ROJO}❌{RESET}"

errores: list[str] = []


def chk(condicion: bool, descripcion: str) -> None:
    print(f"  {'✅' if condicion else '❌'}  {descripcion}")
    if not condicion:
        errores.append(descripcion)


print("\n🔍 Validando Fase 1 — Estructura DW_GrupoPOSE_B52...\n")

try:
    # Conectar a master para verificar BD
    conn_master = get_connection("master")
    cursor = conn_master.cursor()
    cursor.execute(
        "SELECT COUNT(*) FROM sys.databases WHERE name='DW_GrupoPOSE_B52'"
    )
    bd_existe = cursor.fetchone()[0] > 0
    chk(bd_existe, "BD DW_GrupoPOSE_B52 existe")
    conn_master.close()

    if not bd_existe:
        print(
            f"\n{ROJO}❌ Fase 1 INCOMPLETA — BD no existe. Ejecutar 01_crear_estructura_B52.sql{RESET}"  # noqa: E501
        )
        sys.exit(1)

    # Conectar a la BD
    conn = get_connection("DW_GrupoPOSE_B52")
    cursor = conn.cursor()

    # Esquemas
    ESQUEMAS = ("CATALOGO", "PRODUCCION", "AUDITORIA", "TEMPORAL", "ML")
    cursor.execute(
        f"SELECT name FROM sys.schemas WHERE name IN ({','.join(['?']*len(ESQUEMAS))})",  # noqa: E501
        *ESQUEMAS,
    )
    esquemas_encontrados = {row[0] for row in cursor.fetchall()}
    for esq in ESQUEMAS:
        chk(esq in esquemas_encontrados, f"Esquema {esq} existe")

    # Tablas críticas
    TABLAS = [
        "CATALOGO.gerencias",
        "CATALOGO.obras",
        "CATALOGO.proveedores",
        "CATALOGO.fuentes",
        "CATALOGO.calendario",
        "PRODUCCION.costos",
        "PRODUCCION.comprobantes",
        "AUDITORIA.log_cargas",
        "AUDITORIA.periodos_carga",
        "ML.umbrales_alertas",
        "ML.historial_alertas",
        "TEMPORAL.costos_carga",
    ]
    cursor.execute("""
        SELECT SCHEMA_NAME(schema_id) + '.' + name AS full_name
        FROM sys.tables
        WHERE SCHEMA_NAME(schema_id) IN ('CATALOGO','PRODUCCION','AUDITORIA','TEMPORAL','ML')  # noqa: E501
        """)
    tablas_bd = {row[0] for row in cursor.fetchall()}
    chk(
        len(tablas_bd) >= 12,
        f"Mínimo 12 tablas creadas (encontradas: {len(tablas_bd)})",
    )
    for tbl in TABLAS:
        chk(tbl in tablas_bd, f"Tabla {tbl} existe")

    # Datos de referencia
    cursor.execute("SELECT COUNT(*) FROM CATALOGO.fuentes")
    n_fuentes = cursor.fetchone()[0]
    chk(
        n_fuentes >= 6,
        f"CATALOGO.fuentes con datos (encontrados: {n_fuentes})",
    )

    cursor.execute("SELECT COUNT(*) FROM CATALOGO.calendario")
    n_cal = cursor.fetchone()[0]
    chk(n_cal > 4000, f"CATALOGO.calendario con datos (encontrados: {n_cal})")

    cursor.execute("SELECT COUNT(*) FROM ML.umbrales_alertas")
    n_um = cursor.fetchone()[0]
    chk(n_um >= 4, f"ML.umbrales_alertas con datos (encontrados: {n_um})")

    conn.close()

except Exception as e:
    chk(False, f"Error de conexión o validación: {e}")

# Resultado
print()
if errores:
    print(f"{ROJO}❌ Fase 1 INCOMPLETA — {len(errores)} problema(s):{RESET}")
    for err in errores:
        print(f"   • {err}")
    sys.exit(1)
else:
    tablas_count = len(tablas_bd) if "tablas_bd" in dir() else "?"
    print(
        f"{VERDE}✅ Fase 1 validada: esquemas={len(ESQUEMAS)}, "
        f"tablas={tablas_count}, fuentes={n_fuentes}, calendario={n_cal} registros{RESET}\n"  # noqa: E501
    )
    sys.exit(0)
