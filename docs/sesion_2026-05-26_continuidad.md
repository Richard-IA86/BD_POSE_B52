# Continuidad de Sesión — 2026-05-26
> **Para el agente IA:** Este documento es la memoria de arranque para la próxima sesión.
> Léelo primero antes de cualquier acción. Evita comenzar de cero.

---

## 1. Arquitectura acordada (NO discutir de nuevo)

```
M2 (Isindur, Windows)          Sauron (Linux, /opt/pose/)
──────────────────────          ──────────────────────────
ETL_BaseA2 (Fase 1 Python)      POSE_ETL/.venv Python 3.12
+ Fase 2 Excel COM (win32com)   ETL_B52 — 190/190 tests ✅
+ bifurcador.py                 PostgreSQL nativo 10.10.0.1
      │                                  │
      └── WireGuard 10.10.0.x ──────────►│ carga directa a PG
                                          │ 5432, user pose_admin
```

**Invariante:** ETL_BaseA2 = única verdad de producción HASTA que ETL_B52
produzca el mismo resultado que `BaseCostosPOSE.xlsx` partiendo de los crudos.

---

## 2. Estado al cierre (2026-05-26)

| Componente | Estado |
|---|---|
| POSE_ETL .venv en Sauron | ✅ Instalado (Python 3.12.3) |
| `config/.env` PG credentials | ✅ Creado, NO commiteado (.gitignore) |
| ETL_B52 tests en Sauron | ✅ 190/190 PASS (commit `a9cfd24`) |
| Test lag BRIC/EQUIPOS/PREST_ALQ | ✅ Corregido y pusheado |
| PostgreSQL en Sauron | ✅ Activo, dbs prod+dev creadas |
| `sistema/xlsx/` en Sauron | ❌ No existe — pendiente scp desde M2 |
| `input_raw/` en Sauron | ❌ Vacío — datos viven en M2 |
| ETL_BaseA2 ajustado para M2 | ❌ Pendiente esta sesión |
| Métricas de paridad B52/A2 | ❌ No definidas |

---

## 3. Temas pendientes para la próxima sesión

### 3.1 🔴 URGENTE — Ajustar ETL_BaseA2 en M2 (usuario va a M2 ahora)
El `menu_ejecucion.bat` y `config_normalizador.json` asumen rutas de dev local.
Hay que verificar y ajustar:
- `config/config_normalizador.json` → ¿los paths de `input` apuntan a donde están los archivos en M2?
- `menu_ejecucion.bat` → `PYTHON` apunta a `..\..\.venv\Scripts\python.exe` (un nivel arriba de ETL_BaseA2, dentro de POSE_ETL). Verificar que ese venv existe en M2.
- `config/config_automatizacion.json` → rutas de los Excel de Power Query
- Scripts Python Fase 1 (`normalizador_base_costos.py`, `alinear_para_ingesta.py`) → ¿corren sin errores en M2?
- Probar corrida completa: **Fase 1 → Fase 2 → bifurcador** y verificar que genera `output/b52/costos_b52_YYYYMMDD.csv`

**Criterio de éxito:** se genera el CSV delta en `output/b52/` correctamente.

### 3.2 🟡 Transferir `sistema/xlsx/` de M2 a Sauron
Los 3 runners estáticos de ETL_B52 necesitan estos archivos (no están en git):
```
POSE_ETL/sistema/xlsx/
  DespachosBric/Despachos BRIC_final.xlsx
  EquiposPose/Prestaciones Equipos Pose_final.xlsx
  Prestaciones y Alquileres/2026 - Incluir en costos POSE - Prest y Alq_final.xlsx
  Loockups.xlsx
```
**Comando desde M2 (WSL2):**
```bash
scp -r /mnt/.../POSE_ETL/sistema/xlsx/ root@10.10.0.1:/opt/pose/POSE_ETL/sistema/
```

### 3.3 🟡 Revisar scripts `.sh` para nueva dinámica M2/Sauron
Los `.sh` de `auditoria_ecosauron/scripts/` corren en **Sauron** y monitorean repos via git.
La nueva dinámica genera asimetrías que los scripts aún no contemplan:

| Script | Ajuste necesario |
|---|---|
| `inicio_jornada.sh` | Agregar check: "ETL_B52 tests OK?" (correr pytest en POSE_ETL) |
| `inicio_jornada.sh` | Mostrar recordatorio: Fase2/bifurcador corren en M2, no Sauron |
| `cierre_jornada.sh` | Verificar que POSE_ETL no tiene tests en rojo antes de cerrar |
| `verificar_hetzner.sh` | Agregar check PostgreSQL: `pg_isready -h 10.10.0.1 -p 5432` |
| `fix_bd_pose_b52.sh` | Referencia a `workspaces/bd_pose_b52` — revisar si ese workspace sigue activo |
| `validate_deps.sh` | Agregar validación de `.venv` en POSE_ETL |

> **Prioridad baja** — no bloquea el flujo de datos, pero mejora el monitoreo diario.

### 3.4 🟡 Definir métricas de paridad ETL_B52 vs BaseCostosPOSE
Para declarar la "muerte de ETL_BaseA2" necesitamos comparar outputs:
- Total importe por período (mes × obra)
- Cantidad de filas por fuente
- Cobertura de obras (todas las obras del BaseCostosPOSE deben aparecer en B52)
- Zero tolerance en diferencias de IMPORTE_NETO

El script `POSE_ETL/scripts/validar_vs_a2.py` puede ser el punto de partida.

### 3.5 🟢 Cuando los datos fluyan — primera corrida de integración real
1. M2 genera `output/b52/costos_b52_YYYYMMDD.csv`
2. `scp` ese CSV a Sauron → `/opt/pose/POSE_ETL/output/b52/`
3. Sauron: `python scripts/validar_incremental_b52.py`
4. Sauron: `python scripts/cargar_incremental_b52.py --csv output/b52/costos_b52_YYYYMMDD.csv --dry-run`
5. Si dry-run OK → remover `--dry-run` y cargar prod

---

## 4. Instrucciones para M2 (Isindur)

### Entorno de trabajo en M2
```
Repositorio: POSE_ETL (git@github-rw:Richard-IA86/POSE_ETL.git)
Rama activa: main
Directorio local sugerido: C:\Users\richard\repos\POSE_ETL\

venv debe estar en: POSE_ETL\.venv\  (un nivel arriba de ETL_BaseA2)
Python requerido: 3.11+ (compatible con win32com)
Dependencias: pip install -r requirements.txt + pywin32
WireGuard: debe estar activo (10.10.0.2) para cargar a Sauron
```

### Orden de trabajo recomendado para M2
1. `git pull origin main` — bajar los últimos cambios (incluyendo fix tests)
2. Verificar que `.venv` existe y tiene `win32com` instalado
3. Revisar `ETL_BaseA2/config/config_normalizador.json` — ajustar paths a los xlsx locales de M2
4. Revisar `ETL_BaseA2/config/config_automatizacion.json` — ajustar rutas de archivos Excel
5. Correr prueba Fase 1: `python -m ETL_BaseA2.src.ingesta.normalizador_base_costos`
6. Correr Fase 2: `python ETL_BaseA2/scripts/Paso2_ActualizarPQ.py` (solo Windows)
7. Correr bifurcador: `python -m ETL_BaseA2.src.bifurcador.bifurcador`
8. Verificar que `output/b52/costos_b52_YYYYMMDD.csv` existe y tiene datos
9. Transferir a Sauron: `scp output/b52/costos_b52_YYYYMMDD.csv root@10.10.0.1:/opt/pose/POSE_ETL/output/b52/`

### Archivos que M2 debe mantener (NO van a git)
```
POSE_ETL/ETL_BaseA2/input_raw/          # ← fuentes crudas (xlsxs de negocio)
POSE_ETL/sistema/xlsx/                  # ← 3 Excel estáticos (BRIC, EQUIPOS, PREST_ALQ)
POSE_ETL/output/                        # ← outputs generados
POSE_ETL/config/.env                    # ← credenciales PG (mismo formato que Sauron)
```

---

## 5. Agenda de revisiones pendientes

### Próxima sesión (alta prioridad)
- [ ] Ajustar ETL_BaseA2 en M2 y hacer primera corrida completa
- [ ] Transferir `sistema/xlsx/` a Sauron y probar ETL_B52 con datos reales

### Mediano plazo (1–2 semanas)
- [ ] Revisar y ajustar scripts `.sh` de auditoria_ecosauron (ver tabla §3.3)
- [ ] Implementar métricas de paridad en `validar_vs_a2.py`
- [ ] sparse-checkout en M2 (solo ETL_BaseA2 + scripts, sin ETL_B52 src)

### Largo plazo (cuando haya paridad)
- [ ] Migrar load de M2 a pipeline Python puro en Sauron
- [ ] Declarar obsolescencia de ETL_BaseA2
- [ ] Archivar `Paso2_ActualizarPQ.py` como documentación histórica

---

## 6. Comandos útiles rápidos

```bash
# Sauron — correr tests ETL_B52
cd /opt/pose/POSE_ETL && .venv/bin/python -m pytest ETL_B52/tests/ -q

# Sauron — check PostgreSQL
pg_isready -h 10.10.0.1 -p 5432 -U pose_admin

# Sauron — ver última carga en tabla
psql -h 10.10.0.1 -U pose_admin -d dw_grupopose_b52_dev \
  -c "SELECT MAX(fecha_carga), COUNT(*) FROM fact_costos_b52;"

# M2 (WSL2) — transferir CSV a Sauron
scp output/b52/costos_b52_$(date +%Y%m%d).csv \
  root@10.10.0.1:/opt/pose/POSE_ETL/output/b52/

# M2 (WSL2) — transferir sistema/xlsx/ (una sola vez)
scp -r sistema/xlsx/ root@10.10.0.1:/opt/pose/POSE_ETL/sistema/
```

---

*Generado: 2026-05-26 | Sauron (El Ojo) | Sesión Sprint 17*
