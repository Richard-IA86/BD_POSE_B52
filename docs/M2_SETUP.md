# POSE_ETL — Configuración M2 (Isindur)
> **Leé esto primero.** Instrucciones para arrancar en M2 después del trabajo en Sauron (sesión 2026-05-26).

---

## Arquitectura (no re-discutir)

```
M2 (Windows, este equipo)          Sauron (Linux 178.104.226.136)
─────────────────────────          ──────────────────────────────
ETL_BaseA2  ← trabajás acá         ETL_B52 — 190/190 tests ✅
  Fase 1: Python puro               PostgreSQL 10.10.0.1:5432
  Fase 2: Excel COM (win32com)      user: pose_admin
  bifurcador.py                     dbs: dw_grupopose_b52_prod/dev
       │
       └─── WireGuard ──────────► carga directa a PostgreSQL
```

**Regla:** ETL_BaseA2 es la única fuente verdadera de carga a producción.
ETL_B52 en Sauron reemplazará a ETL_BaseA2 solo cuando produzca el mismo resultado.

---

## Checklist de entorno (hacer una sola vez en M2)

### 1. Clonar POSE_ETL
```bat
git clone git@github-rw:Richard-IA86/POSE_ETL.git
cd POSE_ETL
```

### 2. Crear venv
El `menu_ejecucion.bat` busca el venv en `POSE_ETL\.venv\Scripts\python.exe`
(un nivel arriba de `ETL_BaseA2\`).

```bat
:: Desde raíz de POSE_ETL
python -m venv .venv
.venv\Scripts\pip install -r requirements.txt
.venv\Scripts\pip install pywin32
```

### 3. Verificar WireGuard
```
IP de M2 en la VPN: 10.10.0.2
IP de Sauron:       10.10.0.1
```
WireGuard debe estar activo antes de intentar cargar datos a Sauron.

### 4. Crear `config\.env` en POSE_ETL (NO va a git)
Guardar en `POSE_ETL\config\.env` (ya está en `.gitignore`):
```
PG_HOST=10.10.0.1
PG_PORT=5432
PG_USER=pose_admin
PG_PASS=PoseAdmin2026!
PG_DB_PROD=dw_grupopose_b52_prod
PG_DB_DEV=dw_grupopose_b52_dev
```

### 5. Verificar `ETL_BaseA2\config\config_normalizador.json`
Los paths de `"input"` deben apuntar a donde están los xlsx en M2.
Si los archivos están en otra ruta, actualizar cada clave `"input"`.

### 6. Verificar `ETL_BaseA2\config\config_automatizacion.json`
```json
"base_costo_unificada": "../power_query/BaseCostoUnificada.xlsx",
"reservorio":           "../output/director/BaseCostosPOSE.xlsx"
```
Confirmar que `power_query\BaseCostoUnificada.xlsx` existe en M2.

---

## Flujo de trabajo diario en M2

```
Fase 1  →  Fase 2  →  bifurcador  →  scp a Sauron
```

### Opción A — menú interactivo
```bat
cd POSE_ETL\ETL_BaseA2
scripts\menu_ejecucion.bat
```
- Opción 6 = ETL COMPLETO (Fase 1 + Fase 2 + Bifurcador)
- Opción 1 = solo Fase 1 (normalizar + alinear)
- Opción 5 = solo Fase 2 (Power Query)

### Opción B — comandos directos desde raíz de POSE_ETL
```bat
:: Fase 1
.venv\Scripts\python -m ETL_BaseA2.src.ingesta.normalizador_base_costos
.venv\Scripts\python -m ETL_BaseA2.src.ingesta.alinear_para_ingesta

:: Fase 2 (requiere Excel instalado en Windows)
.venv\Scripts\python ETL_BaseA2\scripts\Paso2_ActualizarPQ.py

:: Bifurcador — genera output\b52\costos_b52_YYYYMMDD.csv
.venv\Scripts\python -m ETL_BaseA2.src.bifurcador.bifurcador
```

### Transferir CSV a Sauron
```bash
# WSL2
scp output/b52/costos_b52_$(date +%Y%m%d).csv \
    root@10.10.0.1:/opt/pose/POSE_ETL/output/b52/
```
```powershell
# PowerShell
scp output\b52\costos_b52_20260527.csv `
    root@10.10.0.1:/opt/pose/POSE_ETL/output/b52/
```

### Transferir `sistema\xlsx\` a Sauron (hacer una sola vez)
Los 3 Excel estáticos que necesita ETL_B52 en Sauron:
```bash
# WSL2 — ajustar ruta local
scp -r sistema/xlsx/ root@10.10.0.1:/opt/pose/POSE_ETL/sistema/
```

---

## Archivos locales de M2 (NO van a git — están en .gitignore)

```
POSE_ETL\ETL_BaseA2\input_raw\     ← xlsx crudos de negocio
POSE_ETL\sistema\xlsx\             ← 3 Excel estáticos para ETL_B52
POSE_ETL\output\                   ← outputs generados
POSE_ETL\config\.env               ← credenciales PostgreSQL
```

---

## Pendientes activos (al 2026-05-26)

- [ ] Clonar POSE_ETL en M2 y crear venv
- [ ] Verificar y ajustar `config_normalizador.json` con paths reales de M2
- [ ] Primera corrida completa Fase1 → Fase2 → bifurcador sin errores
- [ ] Transferir `sistema\xlsx\` a Sauron (una sola vez)
- [ ] Primer `scp` de CSV delta a Sauron y validar carga con `--dry-run`

---

*Generado en Sauron 2026-05-26 | Próxima revisión: primera corrida exitosa*
