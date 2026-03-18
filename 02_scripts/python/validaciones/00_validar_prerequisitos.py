"""
00_validar_prerequisitos.py — Verifica entorno antes de iniciar Fase 1.

Comprueba:
  ✅ Python 3.9+
  ✅ Librerías: pandas, pyodbc, openpyxl, psutil
  ✅ SQL Server accesible (.\SQLEXPRESS)
  ✅ Permisos CREATE DATABASE
  ✅ Espacio en disco > 2 GB en C:\
  ✅ Estructura de directorios B52 presente

Salida:
  exit(0) si todo OK
  exit(1) con descripción del problema
"""
import sys
import shutil
from pathlib import Path

# Raíz del repositorio: resuelve independientemente del directorio de instalación
REPO_ROOT = Path(__file__).resolve().parents[3]

VERDE = "\033[92m"
ROJO  = "\033[91m"
RESET = "\033[0m"
OK    = f"{VERDE}✅{RESET}"
FAIL  = f"{ROJO}❌{RESET}"

errores: list[str] = []


def chk(condicion: bool, descripcion: str) -> None:
    simbolo = OK if condicion else FAIL
    print(f"  {simbolo}  {descripcion}")
    if not condicion:
        errores.append(descripcion)


# ── Python version ────────────────────────────────────────────────────────────
print("\n🔍 Verificando prerequisitos DW_GrupoPOSE_B52...\n")
major, minor = sys.version_info[:2]
chk(major == 3 and minor >= 9, f"Python 3.9+ (detectado {major}.{minor})")

# ── Librerías ────────────────────────────────────────────────────────────────
for lib in ("pandas", "pyodbc", "openpyxl"):
    try:
        __import__(lib)
        chk(True, f"Librería {lib} disponible")
    except ImportError:
        chk(False, f"Librería {lib} NO instalada — pip install {lib}")

try:
    import psutil
    chk(True, "Librería psutil disponible (métricas de memoria)")
except ImportError:
    print(f"  ⚠️  psutil no instalada — métricas de memoria deshabilitadas (no crítico)")

# ── SQL Server ───────────────────────────────────────────────────────────────
try:
    import pyodbc
    drivers = [d for d in pyodbc.drivers() if "SQL Server" in d]
    chk(bool(drivers), f"Driver ODBC SQL Server encontrado: {drivers[-1] if drivers else 'NINGUNO'}")

    # Intentar conexión real
    import sys as _sys
    _sys.path.insert(0, str(Path(__file__).parent.parent / "utils"))
    from conexion import get_connection
    try:
        conn = get_connection("master")
        cursor = conn.cursor()
        cursor.execute("SELECT @@SERVERNAME, @@VERSION")
        row = cursor.fetchone()
        chk(True, f"SQL Server conectado: {row[0]}")

        # Verificar permiso CREATE DATABASE
        cursor.execute(
            "SELECT HAS_PERMS_BY_NAME(NULL, 'DATABASE', 'CREATE') AS puede_crear"
        )
        puede = cursor.fetchone()[0]
        chk(bool(puede), "Permiso CREATE DATABASE disponible")

        conn.close()
    except Exception as e:
        chk(False, f"Error conectando a SQL Server: {e}")
except Exception as e:
    chk(False, f"pyodbc error: {e}")

# ── Espacio en disco ──────────────────────────────────────────────────────────
drv = REPO_ROOT.anchor  # letra de unidad donde está instalado el repo
total, usado, libre = shutil.disk_usage(drv)
libre_gb = libre / (1024 ** 3)
chk(libre_gb >= 2.0, f"Espacio libre en {drv} {libre_gb:.1f} GB (mínimo 2 GB)")

# ── Directorios ────────────────────────────────────────────
dirs_requeridos = [
    REPO_ROOT / "00_logs",
    REPO_ROOT / "01_input_raw",
    REPO_ROOT / "02_scripts" / "sql",
    REPO_ROOT / "02_scripts" / "python" / "cargas",
    REPO_ROOT / "02_scripts" / "python" / "utils",
    REPO_ROOT / "03_output",
]
for d in dirs_requeridos:
    chk(d.exists(), f"Directorio existente: {d}")

# ── Resultado ─────────────────────────────────────────────────────────────────
print()
if errores:
    print(f"{ROJO}❌ {len(errores)} prerequisito(s) fallaron:{RESET}")
    for e in errores:
        print(f"   • {e}")
    sys.exit(1)
else:
    print(f"{VERDE}✅ Todos los prerequisitos OK — puede iniciar Fase 1.{RESET}\n")
    sys.exit(0)
