# Análisis de Implementación — DW_GrupoPOSE_B52
**Fecha:** 14 de marzo de 2026  
**Basado en:** PLAN_MAESTRO_B52.md v2.0  
**Estado del análisis:** Listo para revisión y decisión

---

## 1. Estado Actual de los Artefactos

### Archivos SQL

| Archivo | Estado | Cobertura del Plan |
|---|---|---|
| `02_scripts/sql/00_ddl_inicial_B52.sql` | ⚠️ Funcional parcial | ~40% |
| `02_scripts/sql/limpieza_manual_costos.sql` | ℹ️ Existe (fuera de plan formal) | — |
| `02_scripts/sql/simular_limpieza_costos.sql` | ℹ️ Existe (fuera de plan formal) | — |

### Archivos Python

| Archivo | Estado | Descripción |
|---|---|---|
| `cargas/01_cargar_catalogos_B52.py` | ⚠️ Esqueleto incompleto | Dos bloques funcionales sin terminar |
| `cargas/03_cargar_costos_B52.py` | ✅ Funcional básico | Incremental mensual operativo, sin auditoría |
| `cargas/04_cargar_comprobantes_B52.py` | ✅ Funcional básico | Incremental anual operativo, sin auditoría |
| `utils/conexion.py` | ✅ Completo | Detecta driver ODBC automáticamente |
| `utils/__init__.py` | ✅ Existe | Vacío |

---

## 2. Brecha Bloqueante — Decisión Requerida

### ⚠️ INCONSISTENCIA ARQUITECTÓNICA entre DDL implementado y Plan Maestro

Hay una divergencia en cómo se vincula `PRODUCCION.costos` con la dimensión de obras:

| Elemento | DDL Actual (`00_ddl_inicial_B52.sql`) | Plan Maestro (Sección 5) |
|---|---|---|
| Clave natural en `CATALOGO.obras` | `codigo_obra_origen VARCHAR(20)` | `obra_pronto VARCHAR(50)` |
| FK en `PRODUCCION.costos` | `id_obra INT` → `obras(id_obra)` | `obra_pronto VARCHAR(50)` → `obras(obra_pronto)` |
| FK en `PRODUCCION.comprobantes` | `id_obra INT` (igual) | `obra_pronto VARCHAR(50)` (igual) |
| Columnas de importe en costos | `importe_original` + `importe_actualizado_12no_mes` | `importe` + `tipo_cambio` + `importe_usd` |
| `proveedor_id` en costos | ❌ Ausente | ✅ `BIGINT FK → proveedores` |

Los scripts Python actuales (`03_` y `04_`) **siguen el DDL implementado**, es decir, mapean `OBRA_PRONTO → id_obra INT` antes de insertar.

### Opciones de Decisión

#### Opción A — Mantener DDL actual (Star Schema puro con `id_obra INT`)
- ✅ Más correcto en teoría de DW: la FK numérica es más eficiente en joins y storage
- ✅ Los scripts Python existentes ya están alineados
- ⚠️ Requiere renombrar `codigo_obra_origen` a `obra_pronto` en la tabla `CATALOGO.obras` para alinear con Plan (cambio menor)
- ⚠️ El Plan Maestro deberá considerarse la referencia conceptual pero la FK física seguirá siendo `id_obra INT`

#### Opción B — Adoptar diseño del Plan Maestro (`obra_pronto VARCHAR` como FK)
- ✅ FK legible directamente en la tabla de hechos sin necesidad de join a catálogo para identificar la obra
- ❌ Rompe el Star Schema estricto declarado en el principio mandatorio del Plan ("NUNCA deben contener strings/varchar excepto descripciones crudas")
- ❌ Requiere reescribir los scripts `03_` y `04_` que ya mapean a `id_obra INT`
- ❌ Mayor storage y menor performance en queries analíticas grandes

> **Recomendación técnica:** Opción A, manteniendo `id_obra INT` como FK (Star Schema puro). Renombrar `codigo_obra_origen` → `obra_pronto` para alinear la nomenclatura con el resto del sistema.

---

## 3. Brechas en el DDL (Fase 1 incompleta)

El `00_ddl_inicial_B52.sql` existente **no crea** los siguientes objetos definidos en el Plan:

### Esquemas faltantes
- `AUDITORIA` — Bloqueante para auditoría de cargas
- `ML` — Bloqueante para Fase 4 (Observability)
- `TEMPORAL` — Staging para cargas

### Tablas faltantes en CATALOGO
| Tabla | Plan (Sección) | Prioridad |
|---|---|---|
| `CATALOGO.proveedores` | Sección 3.3 / 5 | Alta |
| `CATALOGO.fuentes` | Sección 5 | Alta (usada en `03_costos`) |
| `CATALOGO.jerarquia_org` | Sección 3.3 | Media |
| `CATALOGO.calendario` | Sección 4 Paso 1.3 | Media |

> **Nota:** `CATALOGO.fuentes` ya tiene estructura en el DDL actual como parte del CATALOGO pero **sin datos iniciales** (los 6 registros del INSERT en Sección 3.3 no están ejecutados).

### Columnas ML faltantes en `PRODUCCION.costos`
Según Sección 3.2, la tabla de hechos debe tener estas columnas que hoy no existen:
```sql
z_score_importe       DECIMAL(10,6)
percentil_importe     INT
dias_desde_ultima_carga INT
es_outlier_estadistico  BIT DEFAULT 0
es_valor_inusual        BIT DEFAULT 0
categoria_riesgo        VARCHAR(20)   -- 'LOW','MEDIUM','HIGH','CRITICAL'
```

### Tablas AUDITORIA faltantes
| Tabla | Descripción |
|---|---|
| `AUDITORIA.log_cargas` | Herencia A2 — requerida por scripts actuales |
| `AUDITORIA.periodos_carga` | Nueva B52 — trazabilidad incremental |
| `AUDITORIA.metricas_rendimiento` | Nueva B52 — tiempos y velocidad |
| `AUDITORIA.rechazos` | Versión B52 con `anio_dato`, `mes_dato`, `estado_resolucion` |

### Tablas ML faltantes
| Tabla | Descripción |
|---|---|
| `ML.parametros_calidad` | Umbrales por obra/proveedor (media, stddev) |
| `ML.umbrales_alertas` | Configuración de alertas |
| `ML.historial_alertas` | Log de alertas generadas |
| `ML.anomalias_detectadas` | Registros flaggeados como outliers |

### Tablas TEMPORAL faltantes
| Tabla | Descripción |
|---|---|
| `TEMPORAL.costos_carga` | Staging de costos |
| `TEMPORAL.comprobantes_carga` | Staging de comprobantes |

### Índices faltantes (Paso 1.2 del Plan)
Los índices actuales son `CLUSTERED` básicos. Faltan los `NONCLUSTERED` del Plan:
```sql
IX_costos_particion          -- (anio_dato, mes_dato, fecha) INCLUDE (importe, obra_pronto)
IX_costos_ml                 -- (categoria_riesgo, es_outlier_estadistico) WHERE criticos
IX_comprobantes_particion    -- (anio_dato, fecha_comprobante) INCLUDE (importe)
IX_proveedores_nombre_norm   -- (nombre_proveedor_norm)
IX_proveedores_cuit          -- (cuit) WHERE cuit IS NOT NULL
IX_periodos_tabla_fecha      -- en AUDITORIA.periodos_carga
IX_alertas_fecha_tipo        -- en ML.historial_alertas
```

---

## 4. Brechas en Scripts Python

### `01_cargar_catalogos_B52.py` — Incompleto

**Bloque 1 — `procesar_obras_gerencias()`:**
```python
# Estado actual: termina con `pass` — las obras NUNCA se insertan
pass
# ... código de cruce y guardado ...
```
Falta implementar el cruce de `id_compensable` + `id_gerencia` para construir las filas de obras y ejecutar el upsert en `CATALOGO.obras`.

**Bloque 2 — `procesar_dimensiones_dinamicas()`:**
```python
# El upsert de cuentas_contables no tiene cierre
cc_data = [(str(row['CODIGO_CUENTA']), str(row['RUBRO_CONTABLE']), str(row['CUENTA_CONTABLE'])) for ...]
# Implementar insert lógico...   ← comentario sin código
```

### `03_cargar_costos_B52.py` — Funcional pero incompleto

| Funcionalidad | Estado |
|---|---|
| DELETE + INSERT incremental mensual | ✅ Implementado |
| `fast_executemany = True` | ✅ Implementado |
| Mapeo clave VARCHAR → INT (Star Schema) | ✅ Implementado |
| Argumento `--periodos YYYYMM,YYYYMM` | ❌ Falta |
| Argumento `--force` | ❌ Falta (requerido para pendiente `00000365`) |
| Argumento `--full` | ❌ Falta |
| Registro en `AUDITORIA.log_cargas` | ❌ Falta (tabla ni existe en el DDL) |
| Registro en `AUDITORIA.periodos_carga` | ❌ Falta |
| Limpieza de rechazos acoplada al DELETE | ❌ Falta (Regla 3.4.E del Plan) |
| Rollback transaccional en bloque `except` | ❌ Falta (`conn.rollback()` no está) |
| Logging a `00_logs/` | ❌ Falta |

### `04_cargar_comprobantes_B52.py` — Mismas brechas que `03_`

| Funcionalidad | Estado |
|---|---|
| DELETE + INSERT incremental anual | ✅ Implementado |
| `fast_executemany = True` | ✅ Implementado |
| Argumento `--anio YYYY` | ❌ Falta |
| Argumento `--force` / `--full` | ❌ Falta |
| Registro en auditoría | ❌ Falta |
| Rollback transaccional en `except` | ❌ Falta |

---

## 5. Módulos Python faltantes (no creados aún)

```text
02_scripts/python/
├── utils/
│   ├── auditoria_incremental.py   ← requerido por 03_ y 04_ (registrar inicio/fin)
│   └── metricas_rendimiento.py    ← clase MedidorRendimiento
├── ml/
│   ├── calcular_features.py       ← Z-scores, percentiles, flags outliers (Fase 4)
│   └── generar_alertas.py         ← Detección anomalías y escritura en ML.historial_alertas
├── cargas/
│   └── 00_orquestador_B52.py      ← Orquestador maestro con argparse
└── validaciones/
    ├── validar_prerequisitos.py   ← Sección 10.1 del Plan
    └── validar_fase1.py           ← Sección 10.2 del Plan
```

---

## 6. Archivos de configuración faltantes

| Archivo | Definido en | Estado |
|---|---|---|
| `config_produccion.json` | Sección 8.3 | ❌ No existe |
| `estado_implementacion.json` | Sección 0 | ❌ No existe |

---

## 7. Pendiente de Diseño registrado (Memoria Repo)

El archivo de memoria del repositorio documenta el siguiente pendiente que **depende** de completar la infraestructura de auditoría:

> **Obra `00000365`** (gerencia CALDERON): tiene 3 registros en `AUDITORIA.rechazos` (periodos 2021-01, 2021-12, 2022-01, importe ~$20M ARS) que no se reprocesarán automáticamente al dar de alta la obra en el catálogo.
>
> **Solución propuesta:** Agregar argumento `--recuperar-obra OBRA_PRONTO` a `03_cargar_costos_B52.py`.
>
> **Dependencias bloqueantes:**
> 1. `AUDITORIA.rechazos` debe existir (Fase 1 DDL)
> 2. Argumento `--force` debe implementarse en `03_cargar_costos_B52.py` (Fase 3)

---

## 8. Mapa de Prioridades y Secuencia de Implementación

```text
┌─────────────────────────────────────────────────────┐
│  DECISIÓN PREVIA (hoy)                              │
│  ¿Opción A (id_obra INT) o Opción B (VARCHAR FK)?   │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│  FASE 1 — Completar DDL (Bloqueante para todo)      │
│  • Renombrar campo (si Opción A)                    │
│  • Agregar esquemas AUDITORIA + ML + TEMPORAL       │
│  • Agregar tablas faltantes                         │
│  • Agregar columnas ML a PRODUCCION.costos          │
│  • Agregar índices del Plan (Paso 1.2)              │
│  • Poblar fuentes iniciales + calendario            │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│  FASE 2 — Completar catálogos                       │
│  • Terminar bloque Obras en 01_cargar_catalogos     │
│  • Terminar inserción cuentas contables             │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│  FASE 3 — Auditoría + Robustez en cargas            │
│  • Implementar utils/auditoria_incremental.py       │
│  • Integrar auditoría en 03_ y 04_                  │
│  • Agregar limpieza de rechazos acoplada al DELETE  │
│  • Agregar argparse (--periodos, --force, --full)   │
│  • Agregar rollback transaccional correcto          │
│  → Esto desbloquea el pendiente obra 00000365       │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│  FASE 4 — ML Observability                          │
│  • ml/calcular_features.py                         │
│  • ml/generar_alertas.py                           │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│  FASE 5 — Orquestador + Config + Validaciones       │
│  • 00_orquestador_B52.py                           │
│  • config_produccion.json                          │
│  • validaciones/                                   │
└─────────────────────────────────────────────────────┘
```

---

## 9. Resumen Ejecutivo

| Dimensión | Estado |
|---|---|
| **DDL SQL** | ~40% completado — faltan 3 esquemas enteros y ~12 tablas |
| **Scripts cargas** | ~60% — la carga core funciona, falta auditoría y argparse |
| **Módulos utils/ml** | 1 de 6 archivos existe (`conexion.py`) |
| **Configuración** | 0% — ningún archivo de config creado |
| **Decisión bloqueante** | Pendiente confirmación de FK design |

**Estimación de trabajo restante para pipeline operativo básico (Fases 1–3):**
- DDL completo: ~3–4 hs
- Completar catálogos: ~1–2 hs
- Auditoría + robustez en cargas: ~4–6 hs

**Estimación para ML Observability (Fase 4):**
- ~6–8 hs adicionales

---

*Documento generado por GitHub Copilot el 14/03/2026 a partir del análisis de PLAN_MAESTRO_B52.md y los artefactos existentes en el workspace.*
