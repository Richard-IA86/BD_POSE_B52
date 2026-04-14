# Migración SQL Server → PostgreSQL 16

> **Rama activa:** `feature/postgresql-migration`
> **Estado:** En progreso — solo esquema, sin datos en producción.

---

## Estructura de la rama

```text
02_scripts/
  sql/
    *.sql               ← SQL Server originales — NO modificar
    pg/
      01_crear_estructura_pg.sql   ← tu tarea principal
      02_indices_pg.sql
      03_poblar_referencias_pg.sql
  python/
    utils/
      conexion.py       ← SQL Server original — NO modificar
      conexion_pg.py    ← reemplazo PostgreSQL — editar aquí
    cargas/
      01_cargar_catalogos_B52_v2.py   ← adaptar: ? → %s
      03_cargar_costos_B52.py         ← adaptar: ? → %s
      04_cargar_comprobantes_B52.py   ← adaptar: ? → %s
```

---

## Cómo commitear en cada paso

### Paso A — Scripts SQL (carpeta `pg/`)

Cada SQL que termines y valides va en un commit separado:

```bash
# Después de validar 01_crear_estructura_pg.sql:
git add 02_scripts/sql/pg/01_crear_estructura_pg.sql
git commit -m "feat(pg): estructura de tablas DW_GrupoPOSE_B52"

# Después de validar 02_indices_pg.sql:
git add 02_scripts/sql/pg/02_indices_pg.sql
git commit -m "feat(pg): índices optimizados"

# Después de validar 03_poblar_referencias_pg.sql:
git add 02_scripts/sql/pg/03_poblar_referencias_pg.sql
git commit -m "feat(pg): datos de referencia (fuentes + umbrales + calendario)"
```

### Paso B — conexion_pg.py (utils/)

```bash
git add 02_scripts/python/utils/conexion_pg.py
git commit -m "feat(pg): fábrica de conexiones psycopg2"
```

### Paso C — Scripts de carga Python (cargas/)

Adaptar cada script: `?` → `%s`, `fast_executemany` →
`psycopg2.extras.execute_batch`.

Un commit por script:

```bash
git add 02_scripts/python/cargas/01_cargar_catalogos_B52_v2.py
git commit -m "feat(pg): adaptar carga catálogos a psycopg2"

git add 02_scripts/python/cargas/03_cargar_costos_B52.py
git commit -m "feat(pg): adaptar carga costos a psycopg2"

git add 02_scripts/python/cargas/04_cargar_comprobantes_B52.py
git commit -m "feat(pg): adaptar carga comprobantes a psycopg2"
```

### Paso D — requirements.txt

```bash
# Reemplazar pyodbc por psycopg2-binary
git add requirements.txt
git commit -m "chore(deps): pyodbc → psycopg2-binary"
```

### Paso E — conexion.json template

```bash
git add config/conexion.template.json
git commit -m "chore(config): template conexion PostgreSQL"
```

---

## Equivalencias T-SQL → PostgreSQL (referencia rápida)

| T-SQL (SQL Server) | PostgreSQL 16 |
|--------------------|---------------|
| `IDENTITY(1,1)` | `GENERATED ALWAYS AS IDENTITY` o `SERIAL` |
| `NVARCHAR(n)` | `VARCHAR(n)` |
| `DATETIME2` | `TIMESTAMP` |
| `BIT DEFAULT 1` | `BOOLEAN DEFAULT TRUE` |
| `GETDATE()` | `NOW()` |
| `SYSTEM_USER` | `CURRENT_USER` |
| `PRINT '...'` | `RAISE NOTICE '...'` |
| `IF NOT EXISTS ... BEGIN ... END` | `CREATE TABLE IF NOT EXISTS ...` |
| `sys.objects` / `sys.schemas` | No aplica — usar `IF NOT EXISTS` |
| `GO` | No existe — eliminar |
| `USE nombre_bd;` | `\connect nombre_bd` (psql) |
| `NONCLUSTERED INDEX` | `INDEX` (todos son B-tree por defecto) |
| `WHERE filtro` en índice | `WHERE filtro` — igual en PostgreSQL |
| `INCLUDE (col)` en índice | `INCLUDE (col)` — igual |
| `WHILE @var <= val` | `generate_series(inicio, fin, paso)` |
| `DECLARE @var TYPE` | Variables en bloque `DO $$ DECLARE ... $$` |
| `pyodbc` + `?` params | `psycopg2` + `%s` params |
| `cursor.fast_executemany` | `psycopg2.extras.execute_batch()` |
| `Trusted_Connection=yes` | user/password en conexion.json |

---

## Cómo validar un SQL antes de commitear

```bash
# En el servidor CX33 (cuando esté activo):
psql -U pose_admin -d DW_GrupoPOSE_B52 \
    -f 02_scripts/sql/pg/01_crear_estructura_pg.sql

# En local (si tenés PostgreSQL instalado para pruebas):
psql -U postgres -c "CREATE DATABASE \"DW_GrupoPOSE_B52_test\";"
psql -U postgres -d "DW_GrupoPOSE_B52_test" \
    -f 02_scripts/sql/pg/01_crear_estructura_pg.sql
```

---

## Al terminar toda la rama

```bash
# Asegurarse que QA pasa:
black 02_scripts/python/
flake8 02_scripts/python/
mypy 02_scripts/python/
pytest

# Push y PR:
git push -u origin feature/postgresql-migration
# Abrir PR → main desde GitHub
```

> Los archivos SQL originales (`02_scripts/sql/*.sql`) se conservan
> como referencia histórica. NO se eliminan en esta rama.
