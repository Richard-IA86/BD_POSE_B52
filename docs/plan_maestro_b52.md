# 🚀 PLAN MAESTRO: DW_GrupoPOSE_B52
## Sistema de Data Warehouse con Carga Incremental y ML Observability

**Fecha creación:** 13 de marzo de 2026  
**Versión:** 2.0 - Optimizado para Ejecución por GitHub Copilot  
**Estado:** Listo para implementación  
**Autor:** Richard + GitHub Copilot

---

## 📋 Índice

0. [**Instrucciones para GitHub Copilot (Agente Ejecutor)**](#0-instrucciones-para-github-copilot-agente-ejecutor) 🤖
1. [Resumen Ejecutivo](#1-resumen-ejecutivo)
2. [Arquitectura B52](#2-arquitectura-b52)
3. [Especificaciones Técnicas](#3-especificaciones-técnicas)
4. [Plan de Implementación por Fases](#4-plan-de-implementación-por-fases)
5. [Código SQL: Estructura Completa](#5-código-sql-estructura-completa)
7. [Sistema ML Observability](#7-sistema-ml-observability)
8. [**Configuración del Servidor de Producción**](#8-configuración-del-servidor-de-producción) ⚙️
9. [Power Query B52 - Metadata](#9-power-query-b52---metadata)
11. [**Procedimientos de Rollback y Recuperación**](#11-procedimientos-de-rollback-y-recuperación) 🔄
12. [Testing y Validación](#12-testing-y-validación)
13. [Anexos](#13-anexos)

---

## 0. Instrucciones para GitHub Copilot (Agente Ejecutor)

### 🚨 CONTEXTO CRÍTICO DE ARQUITECTURA B52
- **Rol:** Eres un Ingeniero de Datos Senior a cargo del Data Warehouse "DW_GrupoPOSE_B52".
- **Arquitectura Estricta:** Este proyecto usa DE MANERA ESTRICTA un Modelo de Estrella Puro (Star Schema) en SQL Server. Las tablas de hechos (Fact Tables) NUNCA deben contener strings/varchar (excepto descripciones crudas como `detalle`); TODAS las dimensiones se cruzan mediante Claves Foráneas de tipo `INT` (`id_obra`, `id_fuente`, `id_cuenta_contable`, etc.).
- **Stack Tecnológico:** Python (Pandas para pre-procesamiento) y `pyodbc` con `fast_executemany = True` para alta velocidad de inserción hacia SQL Server. 
- **Flujo de Trabajo:** Las dimensiones (catálogos) se extraen usando `pandas.drop_duplicates()` de los Excels y se actualizan dinámicamente con una lógica UPSERT en BDD **ANTES** de cargar las tablas de hechos.
- **Regla de oro:** Lee el resto de este documento como tu única "Fuente de la Verdad" arquitectónica. Evita sugerir lógicas viejas o desnormalizadas (sistemas A1/A2).

---

### 🎯 Objetivo General

Este documento es un **plan de implementación ejecutable paso a paso** que serás responsable de completar en el servidor de producción. Cada fase contiene:
- Validaciones automatizables que DEBES ejecutar
- Criterios de éxito medibles
- Procedimientos de rollback si algo falla

### 🔴 Principios Mandatorios de Ejecución

1. **Secuencialidad Estricta**  
   ❌ NO avances a la siguiente fase sin completar todas las validaciones  
   ✅ Solo continúa si exit code = 0

2. **Idempotencia**  
   ✅ Verifica existencia antes de crear (IF NOT EXISTS)  
   ✅ Usa UPSERT en lugar de INSERT cuando corresponda

3. **Logging Obligatorio**  
   ✅ TODOS los comandos registran salida en `C:\DW_GrupoPOSE_B52\00_logs\`  
   ✅ Incluye timestamps, parámetros usados, y resultados

4. **Manejo de Errores**  
   ✅ Captura TODAS las excepciones con stack trace completo  
   ✅ Clasifica error: SQL | PYTHON | CONEXION | DATOS  
   ✅ NO continúes automáticamente después de error crítico  
   ✅ Ejecuta procedimiento de rollback documentado en Sección 11

5. **Reporte de Estado**  
   ✅ Después de cada fase, genera reporte JSON (ver formato abajo)  
   ✅ Actualiza archivo `estado_implementacion.json` en raíz

### 📊 Formato de Reporte Esperado

Después de cada paso/fase, genera:

```json
{
  "timestamp": "2026-03-13T14:35:22",
  "fase": "Fase 1 - Paso 1.1",
  "estado": "COMPLETADO",
  "tiempo_ejecucion_min": 5.2,
  "validaciones_ejecutadas": [
    {"nombre": "check_bd_existe", "resultado": "PASS"},
    {"nombre": "check_esquemas_creados", "resultado": "PASS"},
    {"nombre": "check_indices_creados", "resultado": "PASS"}
  ],
  "metricas": {
    "esquemas_creados": 5,
    "tablas_creadas": 15,
    "indices_creados": 12
  },
  "warnings": ["Tabla calendario ya existía, se skippeó inserción"],
  "errores": [],
  "siguiente_accion": "Proceder a Paso 1.2 - Crear índices optimizados"
}
```

### ⚠️ Manejo de Errores - Protocolo

Si encuentras un error:

**1. DETENTE INMEDIATAMENTE**  
No continúes con siguientes pasos automáticamente.

**2. CAPTURA CONTEXTO COMPLETO**
```python
# Ejemplo de captura correcta
try:
    # ... operación ...
except Exception as e:
    error_info = {
        "tipo": type(e).__name__,
        "mensaje": str(e),
        "traceback": traceback.format_exc(),
        "fase": "Fase X - Paso Y",
        "archivo": __file__,
        "timestamp": datetime.now().isoformat(),
        "parametros_usados": {"periodo": periodo, "archivo": archivo}
    }
    logging.error(json.dumps(error_info, indent=2))
    # Guardar en C:\DW_GrupoPOSE_B52\00_logs\errores\
```

**3. CLASIFICA EL ERROR**
- `ERROR_SQL`: Error en base de datos (conexión, query, constraints)
- `ERROR_PYTHON`: Excepción en código Python (TypeError, ValueError, etc.)
- `ERROR_CONEXION`: Timeout, red, permisos
- `ERROR_DATOS`: Datos faltantes, formato incorrecto, validación fallida

**4. INTENTA RECUPERACIÓN AUTOMÁTICA** (solo si es seguro)
- Reintentos con backoff exponencial (max 3 intentos)
- Rollback de transacción parcial
- Skip de registro problemático (con logging)

**5. SI FALLA RECUPERACIÓN**
- Genera reporte de error detallado
- SOLICITA INSTRUCCIÓN al usuario antes de continuar

### ✅ Validaciones Automatizables

- Retorna `exit(0)` si todo OK
- Retorna `exit(1)` con mensaje si falla
- Se ejecuta ANTES de marcar fase como completa

**Ejemplo de uso:**
```bash
# Salida esperada: "✅ Fase 1 validada: 5 esquemas, 15 tablas, 12 índices, 0 errores"
# Exit code: 0
```

### 🚦 Criterios para Continuar

SOLO avanza al siguiente paso si:
- ✅ Todas las validaciones retornan exit code 0
- ✅ No hay errores críticos en logs
- ✅ Reporte de estado generado y guardado
- ✅ Métricas cumplen valores esperados (ej: registros insertados > 0)
- ✅ Tiempo de ejecución dentro de rango aceptable

### 📝 Tracking de Progreso

Mantén actualizado `C:\DW_GrupoPOSE_B52\estado_implementacion.json`:

```json
{
  "version_plan": "2.0",
  "fecha_inicio": "2026-03-13T10:00:00",
  "ultima_actualizacion": "2026-03-13T14:35:22",
  "fase_actual": "Fase 1",
  "paso_actual": "Paso 1.2",
  "progreso_porcentaje": 15,
  "fases_completadas": [
    {"fase": "Fase 1 - Paso 1.1", "completado_en": "2026-03-13T14:30:00", "duracion_min": 5.2}
  ],
  "warnings_acumulados": 2,
  "errores_acumulados": 0,
  "tiempo_total_min": 25.5
}
```

### 🎓 Buenas Prácticas Específicas

1. **Antes de crear archivos/directorios**  
   ```python
   Path(directorio).mkdir(parents=True, exist_ok=True)
   ```

2. **Antes de ejecutar SQL DDL**  
   ```sql
   IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'DW_GrupoPOSE_B52')
   BEGIN
       CREATE DATABASE DW_GrupoPOSE_B52;
   END
   ```

3. **Transacciones Atómicas y Carga Masiva Rápida**
   Las cargas incrementales requieren proteger el estado previo mediante el uso de transacciones. O todo se carga bien, o la base de datos vuelve a su estado anterior.
   Además, es CRÍTICO activar `fast_executemany` en pyodbc para acelerar las inserciones masivas de datos.
   ```python
   conn.autocommit = False
   cursor = conn.cursor()
   
   # OBLIGATORIO: Habilita inserción por lotes ultra-rápida (100x más rápido)
   cursor.fast_executemany = True 
   
   try:
       # Las dos operaciones van en el mismo bloque transaccional
       cursor.execute("DELETE FROM tabla WHERE periodo = ?", [periodo])
       cursor.executemany("INSERT INTO tabla (...) VALUES (...)", data)
       conn.commit()
   except Exception as e:
       conn.rollback() # Borrado revertido, datos originales a salvo
       raise e
   ```

4. **Validación de datos antes de cargar**  
   ```python
   # Verificar columnas requeridas existen
   columnas_requeridas = ['anio_dato', 'mes_dato', 'periodo_codigo']
   faltantes = [c for c in columnas_requeridas if c not in df.columns]
   if faltantes:
       raise ValueError(f"Columnas faltantes: {faltantes}")
   ```

### 🔍 Checkpoint de Inicio

Antes de comenzar Fase 1, ejecuta:

```bash
```

- ✅ Python 3.9+ instalado
- ✅ Librerías requeridas: pandas, pyodbc, openpyxl, psutil
- ✅ SQL Server accesible
- ✅ Usuario con permisos CREATE DATABASE
- ✅ Espacio en disco suficiente (>50GB)
- ✅ Estructura de directorios creada

**Solo si exit code = 0, inicia Fase 1.**

---

## 1. Resumen Ejecutivo

### Objetivo

Crear **DW_GrupoPOSE_B52**, un Data Warehouse de nueva generación que evoluciona desde la arquitectura A2 (FULL LOAD) hacia un sistema optimizado con:

- ✅ **Carga Incremental Mixta:** Mensual para costos, anual para comprobantes
- ✅ **ML Observability:** Detección automática de anomalías en datos
- ✅ **Dimensiones Enriquecidas:** Proveedores completos, fuentes trazables, jerarquías organizativas
- ✅ **Auditoría Avanzada:** Trazabilidad completa, alertas automáticas, métricas de rendimiento

### Comparativa A2 vs B52

| Característica | DW_GrupoPOSE_A2 | DW_GrupoPOSE_B52 |
|---|---|---|
| **Estrategia Costos** | TRUNCATE + INSERT (2 min) | DELETE mensual + INSERT (~5 seg) |
| **Estrategia Comprobantes** | TRUNCATE + INSERT | DELETE anual + INSERT (~10 seg) |
| **Proveedores** | Tabla vacía | Dimensión completa con clasificación |
| **Fuentes** | Tabla vacía | Catálogo activo con trazabilidad |
| **Jerarquías** | Campos sueltos | Dimensión organizativa estructurada |
| **ML/Alertas** | No | Z-scores, percentiles, alertas automáticas |
| **Auditoría** | Básica (log_cargas) | Avanzada (calidad, métricas, alertas) |
| **Estado** | Producción estable | Nueva implementación (paralela) |

### Estrategia de Implementación

- **Enfoque:** Desarrollo en paralelo, A2 permanece operativa como respaldo
- **Prioridad:** Pipeline incremental básico → ML Observability → Alertas
- **Rollback:** A2 disponible si B52 falla
- **Timeline estimado:** 6-8 semanas (ver Fase 7)

---

## 2. Arquitectura B52

### 2.1 Flujo de Datos End-to-End

```text
┌─────────────────────────────────────────────────────────────────┐
│ FASE 1: AutomatizacionETL (Power Query)                         │
│ · Genera Excel consolidados por período                          │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                Excel (output files)
                       │
┌──────────────────────▼──────────────────────────────────────────┐
│ FASE 2: Pre_IngestaBD (Normalizador Python)                     │
│   - Leer Excel desde carpetas por segmento                       │
│   - Normalizar: fechas, números, columnas                        │
│   - Detectar duplicados (origen vs proceso)                      │
│   - Guardar en output_normalized/ + auditoría                    │
│                                                                   │
│   - Distribuir a output_ready_for_B52/                          │
│   - Agregar metadatos para carga incremental                     │
│   - Calcular anio_dato, mes_dato                                 │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                .xlsx (normalized + metadata)
                       │
┌──────────────────────▼──────────────────────────────────────────┐
│                                                                   │
│ Auditoría:                                                        │
│ · AUDITORIA.log_cargas (por archivo)                            │
│ · AUDITORIA.periodos_carga (por partición temporal)             │
│ · AUDITORIA.metricas_rendimiento (tiempos, velocidad)           │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                   SQL Server
                       │
┌──────────────────────▼──────────────────────────────────────────┐
│ FASE 4: DW_GrupoPOSE_B52 (Base de Datos)                        │
│ Esquemas:                                                         │
│ · CATALOGO: gerencias, obras, proveedores, fuentes, jerarquias  │
│ · PRODUCCION: costos, comprobantes (con columnas ML)            │
│ · AUDITORIA: log_cargas, periodos_carga, metricas, alertas      │
│ · TEMPORAL: staging para cargas                                  │
│ · ML: parametros_calidad, umbrales_alertas, historial_alertas   │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                   Monitoring
                       │
┌──────────────────────▼──────────────────────────────────────────┐
│ FASE 5: ML Observability & Alertas                              │
│   - Z-scores por obra/proveedor                                  │
│   - Percentiles de importes                                      │
│   - Detección de outliers                                        │
│                                                                   │
│   - Proveedores nuevos > umbral                                  │
│   - Variaciones TC anormales                                     │
│   - Costos fuera de rangos históricos                            │
│   - Registrar en AUDITORIA.alertas                               │
└──────────────────────────────────────────────────────────────────┘
```

### 2.2 Esquemas y Tablas

#### CATALOGO (Dimensiones)

| Tabla | Registros Est. | Carga | Descripción |
|---|---|---|---|
| `gerencias` | ~35 | FULL | Estructura organizativa nivel 1 |
| `obras` | ~500 | FULL | Proyectos/obras con relación a gerencias |
| `proveedores` | ~5,000 | UPSERT | **NUEVA:** Catálogo completo con CUIT, categorías |
| `fuentes` | ~10 | FULL | **NUEVA:** Origen de datos con trazabilidad |
| `jerarquia_org` | ~100 | FULL | **NUEVA:** Talleres, regiones, unidades |
| `calendario` | 1,826 | INIT | Dimensión temporal (5 años) |

#### PRODUCCION (Hechos)

| Tabla | Registros Est. | Carga | Partición |
|---|---|---|---|
| `costos` | ~50K/mes | **INCREMENTAL MENSUAL** | `anio_dato + mes_dato` |
| `comprobantes` | ~20K/año | **INCREMENTAL ANUAL** | `anio_dato` |

#### AUDITORIA (Control)

| Tabla | Descripción |
|---|---|
| `log_cargas` | Registro por archivo procesado (herencia de A2) |
| `periodos_carga` | **NUEVA:** Registro por partición temporal cargada |
| `metricas_rendimiento` | **NUEVA:** Tiempos, velocidad, volumetría |
| `rechazos` | Registros con error (herencia de A2) |

#### ML (Machine Learning Observability)

| Tabla | Descripción |
|---|---|
| `parametros_calidad` | **NUEVA:** Umbrales por obra/proveedor (media, stddev) |
| `umbrales_alertas` | **NUEVA:** Configuración de alertas (min, max, variación) |
| `historial_alertas` | **NUEVA:** Log de alertas generadas |
| `anomalias_detectadas` | **NUEVA:** Registros flagged como outliers |

---

## 3. Especificaciones Técnicas

### 3.1 Particionamiento Temporal

#### Tabla: PRODUCCION.costos (MENSUAL)

```sql
-- Columnas de particionamiento
anio_dato INT NOT NULL,          -- Año del campo FECHA
mes_dato INT NOT NULL,           -- Mes del campo FECHA (1-12)
fecha_carga DATETIME2 DEFAULT GETDATE(),

-- Índice para particionamiento lógico
CREATE NONCLUSTERED INDEX IX_costos_particion 
ON PRODUCCION.costos (anio_dato, mes_dato, fecha)
INCLUDE (importe, obra_pronto);

-- Estrategia de carga
DELETE FROM PRODUCCION.costos WHERE anio_dato = @anio AND mes_dato = @mes;
INSERT INTO PRODUCCION.costos (...) VALUES (...);
```

**Ejemplo:** Cargar marzo 2026
```bash
```
→ Borra solo `WHERE anio_dato = 2026 AND mes_dato = 3`  
→ Inserta datos de marzo 2026

> 💡 **Estrategia Detección Dinámica de Particiones (Soporte Multi-Mes/Multi-Año)**
> Si llega un archivo con un gran porcentaje de años históricos modificados (ej. rearmado contable retroactivo donde se modifica el 80% de los datos de un año entero):
> 1. El script Python debe buscar en el `DataFrame` todas las combinaciones únicas de años y meses que existen.
> 2. Iterar sobre esas combinaciones únicas y lanzar el `DELETE` de esa partición específica. 
> 3. Hacer el `BULK INSERT (fast_executemany)` masivo.
> Esto toma exactamente el mismo tiempo que insertar un Excel con registros nuevos, y reemplaza de forma súper veloz años completos sin sufrir los costos computacionales de un `MERGE` o `UPSERT` individual.

#### Tabla: PRODUCCION.comprobantes (ANUAL)

```sql
-- Columnas de particionamiento
anio_dato INT NOT NULL,          -- Año del campo fecha_comprobante
fecha_carga DATETIME2 DEFAULT GETDATE(),

-- Índice
CREATE NONCLUSTERED INDEX IX_comprobantes_particion 
ON PRODUCCION.comprobantes (anio_dato, fecha_comprobante)
INCLUDE (importe, proveedor_id);

-- Estrategia de carga
DELETE FROM PRODUCCION.comprobantes WHERE anio_dato = @anio;
INSERT INTO PRODUCCION.comprobantes (...) VALUES (...);
```

**Ejemplo:** Cargar año 2026
```bash
```
→ Borra solo `WHERE anio_dato = 2026`  
→ Inserta datos del año completo

### 3.2 ML Observability - Columnas Calculadas

Cada registro en `PRODUCCION.costos` tendrá:

```sql
-- Campos ML (calculados post-carga)
z_score_importe DECIMAL(10,6),           -- (importe - media) / stddev por obra
percentil_importe INT,                   -- Percentil del importe (0-100)
dias_desde_ultima_carga INT,             -- Días desde última transacción
es_outlier_estadistico BIT DEFAULT 0,    -- Flag: |z_score| > 3
es_valor_inusual BIT DEFAULT 0,          -- Flag: fuera de rango típico
categoria_riesgo VARCHAR(20),            -- LOW, MEDIUM, HIGH, CRITICAL
```

**Ejemplo de detección:**
```python
# Post-carga: calcular features ML
df['z_score'] = (df['importe'] - df.groupby('obra_pronto')['importe'].transform('mean')) / \
                df.groupby('obra_pronto')['importe'].transform('std')
df['es_outlier'] = df['z_score'].abs() > 3
```

### 3.3 Nuevas Dimensiones - Estructuras

#### CATALOGO.proveedores

```sql
CREATE TABLE CATALOGO.proveedores (
    id_proveedor BIGINT IDENTITY(1,1) PRIMARY KEY,
    cuit NVARCHAR(20) UNIQUE,                    -- Identificador fiscal
    nombre_proveedor NVARCHAR(600) NOT NULL,
    nombre_proveedor_norm NVARCHAR(600) NOT NULL, -- Normalizado para joins
    codigo_proveedor NVARCHAR(100),               -- Código interno
    categoria VARCHAR(50),                        -- 'Materiales', 'Servicios', 'Obra'
    tipo_entidad VARCHAR(20),                     -- 'Persona Física', 'Jurídica'
    es_proveedor_ff BIT DEFAULT 0,                -- Es proveedor de Firma Futura
    frecuencia_transaccional VARCHAR(20),         -- 'Habitual', 'Ocasional', 'Único'
    total_facturado_historico DECIMAL(18,2) DEFAULT 0,
    activo BIT DEFAULT 1,
    fecha_alta DATETIME2 DEFAULT GETDATE(),
    fecha_baja DATETIME2 NULL,
    fecha_modificacion DATETIME2 DEFAULT GETDATE(),
    usuario_carga NVARCHAR(200)
);

CREATE INDEX IX_proveedores_nombre_norm ON CATALOGO.proveedores(nombre_proveedor_norm);
CREATE INDEX IX_proveedores_categoria ON CATALOGO.proveedores(categoria);
CREATE INDEX IX_proveedores_cuit ON CATALOGO.proveedores(cuit);
```

#### CATALOGO.fuentes

```sql
CREATE TABLE CATALOGO.fuentes (
    id_fuente INT IDENTITY(1,1) PRIMARY KEY,
    codigo_fuente NVARCHAR(50) UNIQUE NOT NULL,  -- 'COMP', 'OP', 'GASTOS', etc.
    nombre_fuente NVARCHAR(200) NOT NULL,
    descripcion NVARCHAR(500),
    tipo_movimiento VARCHAR(10) CHECK (tipo_movimiento IN ('INGRESO','EGRESO','MIXTO')),
    es_automatica BIT DEFAULT 0,                  -- TRUE si viene de ETL automático
    prioridad_carga INT DEFAULT 100,              -- Orden de procesamiento
    activo BIT DEFAULT 1,
    fecha_alta DATETIME2 DEFAULT GETDATE(),
    fecha_baja DATETIME2 NULL
);

-- Datos iniciales
INSERT INTO CATALOGO.fuentes (codigo_fuente, nombre_fuente, tipo_movimiento) VALUES
('COMP', 'Comprobantes de Compra', 'EGRESO'),
('OP', 'Órdenes de Pago', 'EGRESO'),
('GASTOS', 'Gastos Detallados', 'EGRESO'),
('DBG', 'Movimientos Bancarios', 'MIXTO'),
('PRONTO', 'Sistema ProntoPOSE', 'EGRESO'),
('DISTR', 'Distribución Gastos Sede', 'EGRESO');
```

#### CATALOGO.jerarquia_org

```sql
CREATE TABLE CATALOGO.jerarquia_org (
    id_jerarquia INT IDENTITY(1,1) PRIMARY KEY,
    codigo_jerarquia NVARCHAR(50) UNIQUE NOT NULL,
    taller_region NVARCHAR(100),                 -- Ej: 'Taller Norte', 'Región AMBA'
    unidad_temporal NVARCHAR(100),               -- Ej: 'UT-2024-Q1'
    codigo_centro_costo NVARCHAR(50),            -- Para contabilidad
    id_gerencia INT,                              -- FK a gerencias
    empresa VARCHAR(20),                          -- 'POSE', 'CAC', 'SYGSA', etc.
    nivel_organizativo INT,                       -- 1=Empresa, 2=Gerencia, 3=Taller, 4=Unidad
    activo BIT DEFAULT 1,
    fecha_alta DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (id_gerencia) REFERENCES CATALOGO.gerencias(id_gerencia)
);

CREATE INDEX IX_jerarquia_gerencia ON CATALOGO.jerarquia_org(id_gerencia);
```

### 3.4 Reglas de Negocio y Normalización (Herencia A2)

Para garantizar la integridad y retrocompatibilidad de los datos, la "FASE 2: Pre_IngestaBD" debe implementar estructuralmente las siguientes reglas de normalización históricas consolidadas en A2. Todo esto debe procesarse *antes* de que el dato toque la Base de Datos.

#### A) Particularidades del Campo `OBRA_PRONTO` (Crítico)
*   **Tratamiento de Tipo:** Siempre debe procesarse como `string` (`VARCHAR(50)`). **Nunca** castear o convertir a tipo numérico o intero, ya que destruye información.
*   **Leading Zeros (Ceros a la izquierda):** Si el valor es puramente numérico (ej. `00000001`), se deben **preservar rigurosamente** los ceros a la izquierda.
*   **Alfanuméricos Válidos:** Se aceptan palabras puras o con guiones/espacios (ej. `HYDRA`, `ACTIVOS PERON`, `DAVID-GUSTAV`).
*   **Formatos Mixtos PROHIBIDOS:** Rechazar inmediatamente registros que mezclen números con letras (ej. `000HYDRA` o `00TALLER`). Las validaciones exigen o "solo dígitos" o "letras/espacios".
*   **Limpieza de Nulos Ocultos:** Al hacer `astype(str)` en Pandas, los nulos (`NaN` o `None`) se convierten en el texto string `'nan'`. Se debe aplicar un filtro explícito: `df.loc[df["OBRA_PRONTO"].str.lower() == 'nan', "OBRA_PRONTO"] = None`.

#### B) Conversión de Importes ("Formato Argentino")
Los archivos Excel provienen de diversas fuentes (humanas y sistemas) con inconsistencias en los formatos numéricos y configuración regional.
*   **Limpieza Regex:** Se deben sanitizar los montos quitando cualquier carácter que no sea un dígito, un punto o una coma mediante expresiones regulares: `re.sub(r"[^\d,.]", "", valor)`.
*   **Regla de Coma y Punto Invertida:** 
    *   Si el string contiene "," y ".", y la coma está *después* del punto (ej. `1.234,56`), el punto es separador de miles. Se debe normalizar al estándar internacional float quitando puntos y cambiando la coma por punto.
    *   Si la puntuación está invertida (`1,234.56`) típico de software en inglés, se asume que el punto es decimal y se quita la coma.
*   **Límites de Seguridad (TC e Importe):** Restringir los montos entre `-100,000,000,000` y `100,000,000,000` para prevenir desbordamientos `OverflowError` en SQL. El `TC` (Tipo de Cambio) puede ser `0` pero no puede exceder `10,000`.

#### C) Normalización de Fechas (Y2K Bug local)
El sistema no puede confiar en los formatos nativos de fecha de Excel debido a errores de captura de usuario.
*   **Parseo Iterativo:** Si la fecha viene como texto, testear secuencialmente: `"%d/%m/%Y"`, `"%d/%m/%y"`, `"%d-%m-%Y"`, `"%d-%m-%y"`.
*   **Corrección de Milenios:** Existen casos donde el Excel emite años de 2 dígitos. La regla de herencia es: Si el año detectado es de 2 dígitos y menor a 50 (ej. "24"), asumir que es el siglo XXI sumándole 2000 (->2024). Si es mayor a 50 (ej. "98"), atribuirle el siglo XX (-> 1998).

#### D) Unificación de Columnas
Apenas el script de pre-ingesta cargue el DataFrame, debe estandarizar las cabeceras para prevenir errores de tipeo humano:
*   Pasar todas las columnas a `.upper()` y quitar espacios laterales (`.strip()`).
*   Reemplazar espacios múltiples en blanco por un solo guion bajo.
*   Reemplazar las diferentes codificaciones ASCII de "Número": Quitar el símbolo de grado (`°`) y estandarizar variaciones como `"N°"`, `"Nº"`, `"#"`, u otras hacia `"NRO"`.

#### E) Idempotencia de Errores (Manejo de Rechazos en Cargas Incrementales)
En un modelo incremental por reemplazo de partición, si un registro defectuoso es insertado en la tabla de `rechazos`, el usuario irá al Excel origen a solucionarlo. En su próxima ejecución, la base de datos reemplazará el mes completo con éxito, pero la tabla de rechazos debe "enterarse" de que su error histórico caducó gracias a la recarga. 
*   **Regla de Limpieza Acoplada:** Cuando en la BD se ejecuta el `DELETE` masivo de la partición (ej. Enero 2026 en Costos), en la **misma transacción atómica**, se debe ejecutar un `UPDATE` en la tabla de `AUDITORIA.rechazos` marcando como `OBSOLETO_POR_RECARGA` cualquier rechazo pendiente que perteneciera a Enero 2026.
*   **Aislamiento:** La tabla de rechazos actúa solo como *tablero de lectura para humanos*. Nunca se debe usar su contenido para intentar "reprocesar e inyectar" automáticamente a Producción (los datos siempre se corrigen en la fuente y viajan por el flujo principal normalizado).

---

### 3.5 Tablas de Auditoría Avanzada

#### AUDITORIA.rechazos (Estructura Adaptada para Carga Incremental)

```sql
CREATE TABLE AUDITORIA.rechazos (
    id_rechazo BIGINT IDENTITY(1,1) PRIMARY KEY,
    id_log_carga BIGINT,                         -- FK a log_cargas
    tabla_destino VARCHAR(100),                  -- Ej: 'PRODUCCION.costos'
    anio_dato INT NULL,                          -- Nueva clave vinculación con partición
    mes_dato INT NULL,                           -- Nueva clave vinculación con partición
    fila_excel INT,
    motivo_rechazo NVARCHAR(MAX),
    datos_rechazo NVARCHAR(MAX),                 -- JSON con la fila rechazada completa
    estado_resolucion VARCHAR(30) DEFAULT 'PENDIENTE', -- 'PENDIENTE', 'OBSOLETO_POR_RECARGA'
    fecha_rechazo DATETIME2 DEFAULT GETDATE(),
    fecha_resolucion DATETIME2 NULL
);

CREATE INDEX IX_rechazos_estado ON AUDITORIA.rechazos(tabla_destino, anio_dato, mes_dato, estado_resolucion);
```

#### AUDITORIA.periodos_carga

```sql
CREATE TABLE AUDITORIA.periodos_carga (
    id_periodo_carga BIGINT IDENTITY(1,1) PRIMARY KEY,
    tabla_destino NVARCHAR(100) NOT NULL,        -- 'PRODUCCION.costos'
    tipo_particion VARCHAR(20) NOT NULL,         -- 'MENSUAL', 'ANUAL'
    anio INT NOT NULL,
    mes INT NULL,                                 -- NULL si es anual
    periodo_codigo VARCHAR(10) NOT NULL,         -- '202603', '2026'
    registros_borrados INT DEFAULT 0,
    registros_insertados INT DEFAULT 0,
    fecha_inicio_carga DATETIME2 DEFAULT GETDATE(),
    fecha_fin_carga DATETIME2,
    duracion_segundos DECIMAL(10,2),
    velocidad_registros_seg DECIMAL(10,2),       -- registros_insertados / duracion
    estado VARCHAR(20) DEFAULT 'EN_PROCESO',     -- 'EXITOSO', 'PARCIAL', 'ERROR'
    observaciones NVARCHAR(MAX),
    usuario_carga NVARCHAR(200)
);

CREATE INDEX IX_periodos_tabla ON AUDITORIA.periodos_carga(tabla_destino, anio, mes);
```

#### AUDITORIA.metricas_rendimiento

```sql
CREATE TABLE AUDITORIA.metricas_rendimiento (
    id_metrica BIGINT IDENTITY(1,1) PRIMARY KEY,
    id_log_carga BIGINT,                         -- FK a log_cargas
    id_periodo_carga BIGINT,                     -- FK a periodos_carga
    fase_proceso VARCHAR(50) NOT NULL,           -- 'LECTURA', 'TRANSFORMACION', 'VALIDACION', 'INSERCION'
    tiempo_inicio DATETIME2 NOT NULL,
    tiempo_fin DATETIME2 NOT NULL,
    duracion_milisegundos INT,
    memoria_usada_mb DECIMAL(10,2),
    cpu_porcentaje DECIMAL(5,2),
    registros_procesados INT,
    observaciones NVARCHAR(500),
    FOREIGN KEY (id_log_carga) REFERENCES AUDITORIA.log_cargas(id_log_carga),
    FOREIGN KEY (id_periodo_carga) REFERENCES AUDITORIA.periodos_carga(id_periodo_carga)
);
```

#### ML.historial_alertas

```sql
CREATE TABLE ML.historial_alertas (
    id_alerta BIGINT IDENTITY(1,1) PRIMARY KEY,
    fecha_generacion DATETIME2 DEFAULT GETDATE(),
    tipo_alerta VARCHAR(50) NOT NULL,            -- 'OUTLIER_IMPORTE', 'PROVEEDOR_NUEVO', 'TC_ANORMAL'
    severidad VARCHAR(20) NOT NULL,              -- 'INFO', 'WARNING', 'CRITICAL'
    tabla_origen NVARCHAR(100),                  -- 'PRODUCCION.costos'
    id_registro_origen BIGINT,                   -- FK al registro que generó alerta
    descripcion NVARCHAR(MAX) NOT NULL,
    valor_detectado NVARCHAR(200),
    valor_esperado NVARCHAR(200),
    accion_tomada VARCHAR(50),                   -- 'AUTO_FLAG', 'NOTIFICACION', 'BLOQUEO'
    estado VARCHAR(20) DEFAULT 'ACTIVA',         -- 'ACTIVA', 'RESUELTA', 'DESCARTADA'
    usuario_resolucion NVARCHAR(200),
    fecha_resolucion DATETIME2
);

CREATE INDEX IX_alertas_fecha ON ML.historial_alertas(fecha_generacion);
CREATE INDEX IX_alertas_tipo ON ML.historial_alertas(tipo_alerta, severidad);
```

---

## 4. Plan de Implementación por Fases

### Fase 1: Preparación y Diseño de BD (Semana 1)

**Objetivo:** Crear estructura completa de DW_GrupoPOSE_B52 vacía



**Tareas:**
- [ ] Crear base de datos B52
- [ ] Crear esquemas: CATALOGO, PRODUCCION, AUDITORIA, TEMPORAL, ML
- [ ] Crear todas las tablas dimensionales (ver sección 5.1)
- [ ] Crear tablas de hechos con columnas ML (ver sección 5.2)
- [ ] Crear tablas de auditoría avanzada (ver sección 5.3)
- [ ] Crear esquema ML completo (ver sección 5.4)

**Verificación:**
```sql
-- Verificar estructura creada
SELECT s.name AS esquema, t.name AS tabla, 
       SUM(p.rows) AS registros
FROM sys.tables t
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
INNER JOIN sys.partitions p ON t.object_id = p.object_id
WHERE s.name IN ('CATALOGO', 'PRODUCCION', 'AUDITORIA', 'ML')
  AND p.index_id IN (0,1)
GROUP BY s.name, t.name
ORDER BY s.name, t.name;
```

**Entregable:** BD B52 creada con 0 registros, estructura completa

---

#### Paso 1.2: Crear índices optimizados


**Índices críticos para carga incremental:**
```sql
-- Costos (particionamiento mensual)
CREATE NONCLUSTERED INDEX IX_costos_particion 
ON PRODUCCION.costos (anio_dato, mes_dato, fecha)
INCLUDE (importe, obra_pronto, proveedor_id);

CREATE NONCLUSTERED INDEX IX_costos_obra 
ON PRODUCCION.costos (obra_pronto)
INCLUDE (fecha, importe);

-- Comprobantes (particionamiento anual)
CREATE NONCLUSTERED INDEX IX_comprobantes_particion 
ON PRODUCCION.comprobantes (anio_dato, fecha_comprobante)
INCLUDE (importe, proveedor_id);

-- Proveedores (búsquedas rápidas)
CREATE NONCLUSTERED INDEX IX_proveedores_nombre_norm 
ON CATALOGO.proveedores (nombre_proveedor_norm);

CREATE NONCLUSTERED INDEX IX_proveedores_cuit 
ON CATALOGO.proveedores (cuit) WHERE cuit IS NOT NULL;

-- Auditoría (queries de monitoreo)
CREATE NONCLUSTERED INDEX IX_periodos_tabla_fecha 
ON AUDITORIA.periodos_carga (tabla_destino, anio, mes, fecha_inicio_carga);

CREATE NONCLUSTERED INDEX IX_alertas_fecha_tipo 
ON ML.historial_alertas (fecha_generacion, tipo_alerta, severidad);
```

**Verificación:**
```sql
SELECT 
    SCHEMA_NAME(t.schema_id) AS esquema,
    t.name AS tabla,
    i.name AS indice,
    i.type_desc AS tipo
FROM sys.indexes i
INNER JOIN sys.tables t ON i.object_id = t.object_id
WHERE SCHEMA_NAME(t.schema_id) IN ('CATALOGO', 'PRODUCCION', 'AUDITORIA', 'ML')
  AND i.name IS NOT NULL
ORDER BY esquema, tabla, indice;
```

---

#### Paso 1.3: Poblar dimensiones de referencia


**Tareas:**
- [ ] Insertar fuentes iniciales (6-10 registros)
- [ ] Generar calendario (2019-2030)
- [ ] Crear parámetros ML por defecto

```sql
-- Fuentes iniciales
INSERT INTO CATALOGO.fuentes (codigo_fuente, nombre_fuente, tipo_movimiento, es_automatica) VALUES
('COMP', 'Comprobantes de Compra', 'EGRESO', 1),
('OP', 'Órdenes de Pago', 'EGRESO', 1),
('GASTOS', 'Gastos Detallados', 'EGRESO', 1),
('DBG', 'Movimientos Bancarios', 'MIXTO', 1),
('PRONTO', 'Sistema ProntoPOSE', 'EGRESO', 0),
('DISTR', 'Distribución Gastos Sede', 'EGRESO', 1);

-- Calendario (generación programática)
WITH fechas AS (
    SELECT CAST('2019-01-01' AS DATE) AS fecha
    UNION ALL
    SELECT DATEADD(DAY, 1, fecha)
    FROM fechas
    WHERE fecha < '2030-12-31'
)
INSERT INTO CATALOGO.calendario (fecha, anio, mes, dia, nombre_mes, trimestre, semestre, dia_semana, nombre_dia_semana, es_fin_semana, semana_anio)
SELECT 
    fecha,
    YEAR(fecha),
    MONTH(fecha),
    DAY(fecha),
    DATENAME(MONTH, fecha),
    DATEPART(QUARTER, fecha),
    CASE WHEN MONTH(fecha) <= 6 THEN 1 ELSE 2 END,
    DATEPART(WEEKDAY, fecha),
    DATENAME(WEEKDAY, fecha),
    CASE WHEN DATEPART(WEEKDAY, fecha) IN (1, 7) THEN 1 ELSE 0 END,
    DATEPART(WEEK, fecha)
FROM fechas
OPTION (MAXRECURSION 5000);

-- Umbrales ML por defecto
INSERT INTO ML.umbrales_alertas (tipo_alerta, campo_medicion, valor_min, valor_max, porcentaje_variacion_permitido) VALUES
('OUTLIER_IMPORTE', 'importe', -100000000, 100000000, 300),  -- ±300% de media
('TC_ANORMAL', 'tipo_cambio', 0, 10000, 5),                   -- ±5% variación diaria
('PROVEEDOR_NUEVO', 'importe_primera_factura', 0, 5000000, NULL),  -- Alerta si > $5M
('DIAS_SIN_ACTIVIDAD', 'dias_desde_ultima', 90, 9999, NULL);      -- Alerta si > 90 días
```

---

### Fase 2: Adaptación del Pipeline ETL (Semana 2)

**Objetivo:** Adaptar scripts Python para procesar Catálogos duales y manejar metadatos de particionamiento.

#### 2.0 Ingesta de Catálogos Dinámica (Obras, Gerencias, Compensables, Fuentes, Cuentas Contables y Tipos de Comprobantes)
La arquitectura de B52 promueve la auto-generación y normalización de catálogos sin requerir trabajo extra del usuario.

**A. Catálogos desde "Obras_Gerencias.xlsx" (Gerencias, Compensables y Obras):**
Dado que en B52 eliminamos la dependencia rígida (Foreign Key) de Gerencias a nivel Tabla Obras, usamos **este único archivo Excel** (un RDP sin desperdicio) para dar de alta registros en tres tablas en una sola pasada.

1. **Lectura única:** `df_excel = pd.read_excel('Obras_Gerencias.xlsx')`
2. **Proceso Gerencias:** 
   - Se aísla la columna `GERENCIA`, se hace un `drop_duplicates()`.
   - Se limpian strings y se insertan las nuevas en `CATALOGO.gerencias` (ignorando existentes).
3. **Proceso Compensables (NUEVA DIMENSIÓN):**
   - Se aísla la columna `COMPENSABLE`, se hace un `drop_duplicates()`.
   - Se insertan en `CATALOGO.compensables` los nuevos valores (ej. 'SI', 'NO', 'ADMINISTRACION').
4. **Proceso Obras:**
   - Se aíslan `OBRA_PRONTO`, `DESCRIPCION_OBRA`, `NRO_OBRA` y se cruzan con tablas pre-ingestadas para capturar su `id_compensable` y su `id_gerencia`.
   - Se asegura la regla "Leading Zeros" (ver 3.4.A).
   - Se insertan las obras en `CATALOGO.obras` que **no existan**, guardando TODOS sus atributos (100% RDP sin desperdicio).

**B. Catálogos Dinámicos desde "BaseCostosPOSE_B52.xlsx" (Fuentes, Cuentas Contables y Comprobantes):**
Las dimensiones internas de los hechos se auto-completarán escaneando el archivo principal de costos, implementando metodología UPSERT.

1. **Lectura parcial:** `df_base = pd.read_excel('BaseCostosPOSE_B52.xlsx', usecols=['FUENTE', 'RUBRO_CONTABLE', 'CODIGO_CUENTA', 'CUENTA_CONTABLE', 'TIPO_COMPROBANTE'])`
2. **Proceso Fuentes:**
   - `.drop_duplicates()` sobre la columna `FUENTE`, se insertan nuevas en `CATALOGO.fuentes` (`es_automatica = 1`).
3. **Proceso Tipos de Comprobantes (NUEVA DIMENSIÓN):**
   - `.drop_duplicates()` sobre `TIPO_COMPROBANTE`, se insertan nuevas nomenclaturas (facturas, nd, nc) en `CATALOGO.tipos_comprobantes`.
4. **Proceso Cuentas Contables:**
   - Se filtran y agrupan estas tres columnas combinadas: `['RUBRO_CONTABLE', 'CODIGO_CUENTA', 'CUENTA_CONTABLE']`, ejecutando un `.drop_duplicates()`.
   - Se asegura que `CODIGO_CUENTA` pueda tratar nulos o ceros adecuadamente.
   - Se insertan las combinaciones nuevas en la tabla `CATALOGO.cuentas_contables`. El match único se realiza típicAMENTE por `CODIGO_CUENTA` sumado a la descripción. Si el registro cuenta no existe, se inserta enriqueciendo el rubro y código.

*Con esto logramos mantener un diseño amigable de los archivos mantenidos por los usuarios, pero estructuramos un verdadero esquema de Data Warehouse en estrella.*

#### 2.1 Procesamiento de Particiones (Costos/Comprobantes)



**⚠️ CAMBIO IMPORTANTE:**  
Los metadatos de particionamiento (`anio_dato`, `mes_dato`, `periodo_codigo`) **YA VIENEN calculados desde Power Query B52** (ver Sección 9).  

**Funcionalidad simplificada:**
```python
"""
Adaptador para B52: Distribuye archivos a output_ready_for_B52
Los metadatos de particionamiento YA VIENEN de Power Query B52
"""
import pandas as pd
from pathlib import Path
import shutil
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def validar_metadata_B52(df, archivo_origen):
    """Valida que las columnas de metadata B52 existan (no las agrega)"""
    columnas_requeridas = ['anio_dato', 'mes_dato', 'periodo_codigo']
    faltantes = [col for col in columnas_requeridas if col not in df.columns]
    
    if faltantes:
        raise ValueError(
            f"❌ Archivo {archivo_origen} NO tiene columnas B52: {faltantes}. "
            "Verificar que se usó Power Query B52 (no A2). "
            "Ver Sección 9 del plan para configurar Power Query correctamente."
        )
    
    # Validar tipos de datos
    if df['anio_dato'].dtype not in ['int64', 'float64']:
        raise TypeError(f"❌ anio_dato debe ser numérico, encontrado: {df['anio_dato'].dtype}")
    
    if df['mes_dato'].dtype not in ['int64', 'float64']:
        raise TypeError(f"❌ mes_dato debe ser numérico, encontrado: {df['mes_dato'].dtype}")
    
    # Validar rangos lógicos
    if not df['mes_dato'].between(1, 12).all():
        valores_invalidos = df[~df['mes_dato'].between(1, 12)]['mes_dato'].unique()
        raise ValueError(f"❌ mes_dato contiene valores fuera de rango 1-12: {valores_invalidos}")
    
    logging.info(f"✅ Metadata B52 validada: {archivo_origen}")
    return True

def agregar_metadata_B52(df, archivo_origen):
    """DEPRECATED: Ya no agrega metadata, solo valida (viene de Power Query)"""
    logging.warning("⚠️  agregar_metadata_B52() es deprecated. Metadata viene de Power Query.")
    validar_metadata_B52(df, archivo_origen)
    
    # Asegurar FECHA es datetime
    df['FECHA'] = pd.to_datetime(df['FECHA'], errors='coerce')
    
    # Agregar columnas de particionamiento
    df['anio_dato'] = df['FECHA'].dt.year
    df['mes_dato'] = df['FECHA'].dt.month
    df['periodo_codigo'] = df['FECHA'].dt.strftime('%Y%m')
    
    # Metadata para auditoría
    df['archivo_origen_B52'] = archivo_origen
    df['fecha_procesamiento'] = pd.Timestamp.now()
    
    # Eliminar filas con fechas inválidas
    df_valido = df.dropna(subset=['FECHA', 'anio_dato', 'mes_dato'])
    
    print(f"✅ Metadata B52: {len(df_valido)} registros con partición temporal")
    print(f"   Períodos: {df_valido['periodo_codigo'].nunique()} únicos")
    
    return df_valido

def distribuir_a_output_B52(input_dir, output_dir):
    """Distribuye archivos normalizados a output_ready_for_B52"""
    
    input_path = Path(input_dir)
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    for archivo_excel in input_path.glob('*.xlsx'):
        print(f"\n📂 Procesando: {archivo_excel.name}")
        
        # Leer archivo normalizado
        df = pd.read_excel(archivo_excel)
        
        # Agregar metadata B52
        df_b52 = agregar_metadata_B52(df, archivo_excel.name)
        
        # Guardar en output_ready_for_B52
        output_file = output_path / f"B52_{archivo_excel.name}"
        df_b52.to_excel(output_file, index=False, engine='openpyxl')
        
        print(f"💾 Guardado: {output_file}")

if __name__ == '__main__':
    distribuir_a_output_B52(
        input_dir='../output_normalized',
        output_dir='../output_ready_for_B52'
    )
```

**Verificación:**
```bash
# Salida esperada:
# ✅ Metadata B52 validada: archivo1.xlsx
# ✅ Copiado: archivo1.xlsx → output_ready_for_B52/archivo1.xlsx
# ✅ Distribución B52 completada: N archivos procesados

# Si falla:
# ❌ Archivo X.xlsx NO tiene columnas B52: ['anio_dato', 'mes_dato']
# → Verificar que Power Query B52 esté configurado correctamente (Sección 9)
```

---

#### Paso 2.2: Modificar configuración AutomatizacionETL

**Archivo:** `c:\Dev\ProyVS_CodeRick_2026\production\AutomatizacionETL\config_automatizacion_B52.json`

```json
{
  "metadata": {
    "version": "1.0_B52",
    "fecha_creacion": "2026-03-13",
    "descripcion": "Configuracion para AutomatizacionETL hacia B52"
  },
  "rutas": {
    "base_costo_unificada": "C:/Dev/ProyVS_CodeRick_2026/production/BaseCostoUnificada/BaseCostoUnificada.xlsx",
    "output_B52": "C:/Dev/ProyVS_CodeRick_2026/production/Pre_IngestaBD/output_ready_for_B52/",
    "carpeta_backups": "C:/Dev/ProyVS_CodeRick_2026/production/AutomatizacionETL/_Backups_B52/",
    "carpeta_logs": "C:/Dev/ProyVS_CodeRick_2026/production/AutomatizacionETL/logs/B52/"
  },
  "opciones": {
    "timeout_minutos": 25,
    "crear_backup": true,
    "dias_retencion_backup": 7,
    "pausa_entre_archivos_segundos": 5,
    "excel_visible": false,
    "agregar_metadata_particionamiento": true
  },
  "bd_destino": {
    "servidor": ".\\SQLEXPRESS",
    "base_datos": "DW_GrupoPOSE_B52",
    "timeout_conexion": 30
  },
  "logs": {
    "habilitar": true,
    "nivel": "INFO",
    "formato": "%(asctime)s - %(levelname)s - %(message)s"
  }
}
```

---



#### Paso 3.1: Estructura de directorio

```text
C:\DW_GrupoPOSE_B52\
├── 00_logs/
├── 01_input_raw/
│   ├── BaseCostosPOSE_B52.xlsx
│   ├── ComprobantesPOSE_B52.xlsx
│   ├── Gerencias.xlsx
│   ├── Obras_Gerencias.xlsx
│   └── Proveedores.xlsx
│   ├── python/
│   │   ├── cargas/
│   │   ├── ml/
│   │   ├── utils/
│   │   └── validaciones/
│   └── sql/
│       ├── 01_crear_estructura_B52.sql
│       ├── 02_indices_B52.sql
│       └── 03_poblar_referencias_B52.sql
└── 03_output/
```

---



```python
"""
Orquestador Maestro de Cargas B52
Maneja estrategias incrementales mixtas (mensual + anual)
"""
import argparse
import subprocess
import sys
from datetime import datetime
from pathlib import Path

    print(f"\n{'='*70}")
    print(f"{'='*70}\n")
    
    try:
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        print(result.stdout)
        return True
    except subprocess.CalledProcessError as e:
        print(e.stderr)
        return False

def main():
    parser = argparse.ArgumentParser(
    )
    parser.add_argument(
        '--periodos',
        type=str,
        help='Períodos a cargar (formato: YYYYMM,YYYYMM). Ej: 202603,202604'
    )
    parser.add_argument(
        '--anio',
        type=int,
        help='Año para carga de comprobantes. Ej: 2026'
    )
    parser.add_argument(
        '--full',
        action='store_true',
        help='Forzar carga completa (ignora incremental)'
    )
    parser.add_argument(
        '--skip-catalogos',
        action='store_true',
        help='Omitir carga de catálogos (gerencias, obras)'
    )
    args = parser.parse_args()
    
    # Timestamp de inicio
    inicio_total = datetime.now()
    print(f"\n🏗️  INICIO CARGA DW_GrupoPOSE_B52")
    print(f"📅 Fecha: {inicio_total.strftime('%Y-%m-%d %H:%M:%S')}\n")
    
    exitos = []
    fallos = []
    
    # FASE 1: Catálogos (FULL LOAD)
    if not args.skip_catalogos:
        print("\n" + "="*70)
        print("FASE 1: CATÁLOGOS (FULL LOAD)")
        print("="*70)
        
            exitos.append('gerencias')
        else:
            fallos.append('gerencias')
        
            exitos.append('obras')
        else:
            fallos.append('obras')
        
            exitos.append('proveedores')
        else:
            fallos.append('proveedores')
    
    # FASE 2: Costos (INCREMENTAL MENSUAL)
    print("\n" + "="*70)
    print("FASE 2: COSTOS (INCREMENTAL MENSUAL)")
    print("="*70)
    
    if args.full:
        print("⚠️  Modo FULL: Cargando todos los períodos disponibles")
            exitos.append('costos_full')
        else:
            fallos.append('costos_full')
    elif args.periodos:
        periodos_list = args.periodos.split(',')
        for periodo in periodos_list:
                exitos.append(f'costos_{periodo}')
            else:
                fallos.append(f'costos_{periodo}')
    else:
        print("⚠️  Sin períodos especificados para costos. Use --periodos YYYYMM,YYYYMM")
    
    # FASE 3: Comprobantes (INCREMENTAL ANUAL)
    print("\n" + "="*70)
    print("FASE 3: COMPROBANTES (INCREMENTAL ANUAL)")
    print("="*70)
    
    if args.full:
        print("⚠️  Modo FULL: Cargando todos los años disponibles")
            exitos.append('comprobantes_full')
        else:
            fallos.append('comprobantes_full')
    elif args.anio:
            exitos.append(f'comprobantes_{args.anio}')
        else:
            fallos.append(f'comprobantes_{args.anio}')
    else:
        print("⚠️  Sin año especificado para comprobantes. Use --anio YYYY")
    
    # RESUMEN FINAL
    fin_total = datetime.now()
    duracion = (fin_total - inicio_total).total_seconds()
    
    print("\n" + "="*70)
    print("📊 RESUMEN DE EJECUCIÓN")
    print("="*70)
    print(f"\n✅ Exitosos ({len(exitos)}):")
    
    if fallos:
        print(f"\n❌ Fallidos ({len(fallos)}):")
    
    print(f"\n⏱️  Duración total: {duracion:.2f} segundos")
    print(f"🏁 Fin: {fin_total.strftime('%Y-%m-%d %H:%M:%S')}\n")
    
    # Exit code
    sys.exit(0 if not fallos else 1)

if __name__ == '__main__':
    main()
```

**Uso:**
```bash
# Cargar marzo 2026 (costos) + año 2026 (comprobantes)

# Cargar múltiples meses

# Carga completa (todos los períodos)

# Solo hechos (skip catálogos)
```

---



```python
"""
Carga Incremental MENSUAL de PRODUCCION.costos
Estrategia: DELETE por período + INSERT
"""
import argparse
import pandas as pd
import pyodbc
from datetime import datetime
from pathlib import Path
import sys

# Agregar ruta de utils
sys.path.append(str(Path(__file__).parent.parent / 'utils'))
from auditoria_incremental import (
    registrar_inicio_periodo,
    registrar_fin_periodo,
    verificar_procesado_periodo
)
from metricas_rendimiento import MedidorRendimiento
from conexion import get_connection
from validaciones import validar_schema_costos

# Constantes
ARCHIVO_COSTOS = Path(r'C:\DW_GrupoPOSE_B52\01_input_raw\BaseCostosPOSE_B52.xlsx')
BATCH_SIZE = 5000

def leer_datos_costos(archivo_path):
    """Lee  y normaliza datos de costos"""
    print(f"📂 Leyendo archivo: {archivo_path}")
    
    try:
        df = pd.read_excel(archivo_path, engine='openpyxl')
        print(f"✅ Leídos {len(df)} registros del Excel")
        
        # Normalizar columnas
        df.columns = df.columns.str.upper().str.strip()
        
        # Convertir fechas
        df['FECHA'] = pd.to_datetime(df['FECHA'], errors='coerce')
        
        # Agregar columnas de particionamiento
        df['anio_dato'] = df['FECHA'].dt.year
        df['mes_dato'] = df['FECHA'].dt.month
        df['periodo_codigo'] = df['FECHA'].dt.strftime('%Y%m')
        
        # Validar schema
        df_valido = validar_schema_costos(df)
        
        print(f"✅ {len(df_valido)} registros válidos")
        print(f"   Períodos únicos: {df_valido['periodo_codigo'].nunique()}")
        
        return df_valido
        
    except Exception as e:
        print(f"❌ Error leyendo archivo: {e}")
        raise

def borrar_periodo(conn, anio, mes):
    """Borra datos del período especificado (DELETE incremental)"""
    print(f"\n🗑️  Borrando período: {anio:04d}-{mes:02d}")
    
    cursor = conn.cursor()
    
    # Contar registros antes de borrar
    query_count = """
        SELECT COUNT(*) 
        FROM PRODUCCION.costos 
        WHERE anio_dato = ? AND mes_dato = ?
    """
    cursor.execute(query_count, anio, mes)
    registros_previos = cursor.fetchone()[0]
    
    if registros_previos > 0:
        print(f"   ⚠️  Encontrados {registros_previos} registros existentes")
        
        # Borrar período
        query_delete = """
            DELETE FROM PRODUCCION.costos 
            WHERE anio_dato = ? AND mes_dato = ?
        """
        cursor.execute(query_delete, anio, mes)
        conn.commit()
        
        print(f"   ✅ Borrados {registros_previos} registros")
    else:
        print(f"   ℹ️  Período vacío (carga inicial)")
    
    return registros_previos

def insertar_datos_batch(conn, df, anio, mes, id_log_carga):
    """Inserta datos en batches con auditoría"""
    print(f"\n💾 Insertando datos del período {anio:04d}-{mes:02d}")
    
    # Filtrar por período
    df_periodo = df[(df['anio_dato'] == anio) & (df['mes_dato'] == mes)].copy()
    
    if len(df_periodo) == 0:
        print(f"   ⚠️  Sin datos para período {anio:04d}-{mes:02d}")
        return 0
    
    print(f"   📊 Registros a insertar: {len(df_periodo)}")
    
    # Agregar metadata de auditoría
    df_periodo['id_log_carga'] = id_log_carga
    df_periodo['fecha_carga'] = datetime.now()
    df_periodo['usuario_carga'] = USUARIO_CARGA
    
    # Inserción por batches
    cursor = conn.cursor()
    total_insertados = 0
    
    query = """
        INSERT INTO PRODUCCION.costos (
            id_log_carga, obra_pronto, fecha, importe, tipo_cambio, importe_usd,
                nombre_proveedor, nombre_proveedor_norm, id_tipo_comprobante, numero_comprobante,
                numero_comprobante_norm, observacion, taller_reg, ut_otros, id_cuenta_contable,
                fuente, descripcion_obra, archivo_origen, fila_excel, fecha_carga,
                usuario_carga, anio_dato, mes_dato, detalle
            ) VALUES (
                ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
            )
        """

        for i in range(0, len(df_periodo), BATCH_SIZE):
            batch = df_periodo.iloc[i:i+BATCH_SIZE]
            
            for _, row in batch.iterrows():
                cursor.execute(query,
                    id_log_carga, row.get('OBRA_PRONTO'), row.get('FECHA'),
                    row.get('IMPORTE'), row.get('TC'), row.get('IMPORTE_USD'),
                    row.get('PROVEEDOR'), row.get('PROVEEDOR_NORM'),
                    row.get('id_tipo_comprobante'), row.get('NRO_COMPROBANTE'),
                    row.get('NRO_COMPROBANTE_NORM'), row.get('OBSERVACION'),
                    row.get('taller_reg'), row.get('ut_otros'), row.get('id_cuenta_contable'),
                    row.get('FUENTE'), row.get('DESCRIPCION_OBRA'),
                    str(ARCHIVO_COSTOS), row.get('fila_excel'),
        conn.commit()
        total_insertados += len(batch)
        print(f"   ⏳ Progreso: {total_insertados}/{len(df_periodo)} ({100*total_insertados/len(df_periodo):.1f}%)")
    
    print(f"   ✅ Insertados {total_insertados} registros")
    return total_insertados

def cargar_periodo(conn, df, anio, mes, skip_if_processed=True):
    """Carga un período específico con auditoría completa"""
    print(f"\n{'='*70}")
    print(f"📅 CARGANDO PERÍODO: {anio:04d}-{mes:02d}")
    print(f"{'='*70}")
    
    periodo_codigo = f"{anio:04d}{mes:02d}"
    
    # Verificar si ya fue procesado
    if skip_if_processed:
        ya_procesado, id_periodo_anterior = verificar_procesado_periodo(
            conn, 'PRODUCCION.costos', periodo_codigo
        )
        if ya_procesado:
            print(f"⚠️  Período ya procesado (id_periodo #{id_periodo_anterior})")
            return
    
    # Medidor de rendimiento
    medidor = MedidorRendimiento(f'costos_{periodo_codigo}')
    medidor.iniciar()
    
    try:
        # Registrar inicio en auditoría
        id_log_carga, id_periodo_carga = registrar_inicio_periodo(
            conn, 
            tabla='PRODUCCION.costos',
            tipo_particion='MENSUAL',
            anio=anio,
            mes=mes,
            periodo_codigo=periodo_codigo,
            usuario=USUARIO_CARGA
        )
        
        print(f"📝 ID Log Carga: {id_log_carga}")
        print(f"📝 ID Período Carga: {id_periodo_carga}")
        
        # DELETE incremental
        medidor.marcar_fase('DELETE')
        registros_borrados = borrar_periodo(conn, anio, mes)
        
        # INSERT por batches
        medidor.marcar_fase('INSERT')
        registros_insertados = insertar_datos_batch(conn, df, anio, mes, id_log_carga)
        
        # Registrar fin exitoso
        medidor.finalizar()
        registrar_fin_periodo(
            conn,
            id_log_carga=id_log_carga,
            id_periodo_carga=id_periodo_carga,
            registros_borrados=registros_borrados,
            registros_insertados=registros_insertados,
            duracion_segundos=medidor.duracion_total,
            estado='EXITOSO',
            observaciones=f'Carga mensual exitosa. Velocidad: {medidor.velocidad_registros_seg:.2f} reg/seg'
        )
        
        print(f"\n✅ PERÍODO {periodo_codigo} CARGADO EXITOSAMENTE")
        medidor.imprimir_resumen()
        
    except Exception as e:
        medidor.finalizar()
        registrar_fin_periodo(
            conn,
            id_log_carga=id_log_carga,
            id_periodo_carga=id_periodo_carga,
            registros_borrados=0,
            registros_insertados=0,
            duracion_segundos=medidor.duracion_total,
            estado='ERROR',
            observaciones=f'Error: {str(e)}'
        )
        print(f"\n❌ ERROR en período {periodo_codigo}: {e}")
        raise

def main():
    parser = argparse.ArgumentParser(
    )
    parser.add_argument(
        '--periodos',
        type=str,
        help='Períodos a cargar (formato: YYYYMM,YYYYMM). Ej: 202603,202604'
    )
    parser.add_argument(
        '--full',
        action='store_true',
        help='Cargar todos los períodos disponibles en el archivo'
    )
    parser.add_argument(
        '--force',
        action='store_true',
        help='Forzar recarga aunque ya esté procesado'
    )
    args = parser.parse_args()
    
    # Leer datos
    df = leer_datos_costos(ARCHIVO_COSTOS)
    
    # Conectar a BD
    conn = get_connection('DW_GrupoPOSE_B52')
    
    try:
        if args.full:
            # Cargar todos los períodos
            periodos_unicos = df[['anio_dato', 'mes_dato']].drop_duplicates().sort_values(['anio_dato', 'mes_dato'])
            print(f"\n🔄 Modo FULL: {len(periodos_unicos)} períodos detectados")
            
            for _, row in periodos_unicos.iterrows():
                cargar_periodo(conn, df, int(row['anio_dato']), int(row['mes_dato']), skip_if_processed=not args.force)
        
        elif args.periodos:
            # Cargar períodos específicos
            periodos_list = args.periodos.split(',')
            
            for periodo_str in periodos_list:
                periodo_str = periodo_str.strip()
                if len(periodo_str) != 6:
                    print(f"⚠️  Formato inválido: {periodo_str} (use YYYYMM)")
                    continue
                
                anio = int(periodo_str[:4])
                mes = int(periodo_str[4:6])
                
                cargar_periodo(conn, df, anio, mes, skip_if_processed=not args.force)
        
        else:
            print("❌ Error: Debe especificar --periodos o --full")
            sys.exit(1)
        
        print(f"\n🏁 PROCESO FINALIZADO")
        
    finally:
        conn.close()

if __name__ == '__main__':
    main()
```

**Uso:**
```bash
# Cargar marzo 2026

# Cargar múltiples meses

# Cargar todos los períodos

# Forzar recarga (ignora idempotencia)
```

---



```python
"""
Carga Incremental ANUAL de PRODUCCION.comprobantes
Estrategia: DELETE por año + INSERT
"""
import argparse
import pandas as pd
import pyodbc
from datetime import datetime
from pathlib import Path
import sys

sys.path.append(str(Path(__file__).parent.parent / 'utils'))
from auditoria_incremental import (
    registrar_inicio_periodo,
    registrar_fin_periodo,
    verificar_procesado_periodo
)
from metricas_rendimiento import MedidorRendimiento
from conexion import get_connection
from validaciones import validar_schema_comprobantes

ARCHIVO_COMPROBANTES = Path(r'C:\DW_GrupoPOSE_B52\01_input_raw\ComprobantesPOSE_B52.xlsx')
BATCH_SIZE = 3000

def borrar_anio(conn, anio):
    """Borra datos del año especificado (DELETE incremental anual)"""
    print(f"\n🗑️  Borrando año: {anio}")
    
    cursor = conn.cursor()
    
    query_count = "SELECT COUNT(*) FROM PRODUCCION.comprobantes WHERE anio_dato = ?"
    cursor.execute(query_count, anio)
    registros_previos = cursor.fetchone()[0]
    
    if registros_previos > 0:
        print(f"   ⚠️  Encontrados {registros_previos} registros existentes")
        query_delete = "DELETE FROM PRODUCCION.comprobantes WHERE anio_dato = ?"
        cursor.execute(query_delete, anio)
        conn.commit()
        print(f"   ✅ Borrados {registros_previos} registros")
    else:
        print(f"   ℹ️  Año vacío (carga inicial)")
    
    return registros_previos

def cargar_anio(conn, df, anio, skip_if_processed=True):
    """Carga un año específico completo"""
    print(f"\n{'='*70}")
    print(f"📅 CARGANDO AÑO: {anio}")
    print(f"{'='*70}")
    
    periodo_codigo = str(anio)
    
    # Verificar procesamiento previo
    if skip_if_processed:
        ya_procesado, _ = verificar_procesado_periodo(
            conn, 'PRODUCCION.comprobantes', periodo_codigo
        )
        if ya_procesado:
            print(f"⚠️  Año ya procesado")
            return
    
    medidor = MedidorRendimiento(f'comprobantes_{anio}')
    medidor.iniciar()
    
    try:
        # Registrar inicio
        id_log_carga, id_periodo_carga = registrar_inicio_periodo(
            conn, 
            tabla='PRODUCCION.comprobantes',
            tipo_particion='ANUAL',
            anio=anio,
            mes=None,
            periodo_codigo=periodo_codigo,
            usuario=USUARIO_CARGA
        )
        
        # DELETE incremental
        medidor.marcar_fase('DELETE')
        registros_borrados = borrar_anio(conn, anio)
        
        # Filtrar DataFrame por año
        df_anio = df[df['anio_dato'] == anio].copy()
        
        if len(df_anio) == 0:
            print(f"⚠️  Sin datos para año {anio}")
            registrar_fin_periodo(conn, id_log_carga, id_periodo_carga, 
                                registros_borrados, 0, medidor.duracion_total, 
                                'VACIO', 'Sin datos para el año')
            return
        
        print(f"📊 Registros a insertar: {len(df_anio)}")
        
        # INSERT
        medidor.marcar_fase('INSERT')
        df_anio['id_log_carga'] = id_log_carga
        df_anio['fecha_carga'] = datetime.now()
        df_anio['usuario_carga'] = USUARIO_CARGA
        
        # Inserción (código similar a costos pero para comprobantes)
        cursor = conn.cursor()
        total_insertados = 0
        
        query = """
            INSERT INTO PRODUCCION.comprobantes (
                id_log_carga, obra_pronto, numero_comprobante, numero_comprobante_norm,
                fecha_comprobante, cod_proveedor, nombre_proveedor, nombre_proveedor_norm,
                importe, archivo_origen, hoja_origen, fila_excel, fecha_carga,
                usuario_carga, id_tipo_comprobante, proveedor_ff, id_cuenta_contable,
                fecha_vto, tc, moneda, observacion, anio_dato
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        for i in range(0, len(df_anio), BATCH_SIZE):
            batch = df_anio.iloc[i:i+BATCH_SIZE]
            for _, row in batch.iterrows():
                cursor.execute(query, 
                    id_log_carga, row.get('OBRA_PRONTO'), row.get('NRO_COMPROBANTE'),
                    row.get('NRO_COMPROBANTE_NORM'), row.get('FECHA_COMPROBANTE'),
                    row.get('COD_PROVEEDOR'), row.get('PROVEEDOR'), row.get('PROVEEDOR_NORM'),
                    row.get('IMPORTE'), str(ARCHIVO_COMPROBANTES), row.get('HOJA_ORIGEN'),
                    row.get('fila_excel'), datetime.now(), USUARIO_CARGA,
                    row.get('id_tipo_comprobante'), row.get('PROVEEDOR_FF'),
                    row.get('id_cuenta_contable'), row.get('FECHA_VTO'), row.get('TC'),
                    row.get('MONEDA'), row.get('OBSERVACION'), anio
                )
            conn.commit()
            total_insertados += len(batch)
            print(f"   ⏳ {total_insertados}/{len(df_anio)} ({100*total_insertados/len(df_anio):.1f}%)")
        
        medidor.finalizar()
        registrar_fin_periodo(conn, id_log_carga, id_periodo_carga,
                            registros_borrados, total_insertados, medidor.duracion_total,
                            'EXITOSO', f'Velocidad: {medidor.velocidad_registros_seg:.2f} reg/seg')
        
        print(f"\n✅ AÑO {anio} CARGADO EXITOSAMENTE")
        medidor.imprimir_resumen()
        
    except Exception as e:
        medidor.finalizar()
        registrar_fin_periodo(conn, id_log_carga, id_periodo_carga, 0, 0,
                            medidor.duracion_total, 'ERROR', str(e))
        print(f"\n❌ ERROR en año {anio}: {e}")
        raise

def main():
    parser.add_argument('--anio', type=int, help='Año a cargar. Ej: 2026')
    parser.add_argument('--full', action='store_true', help='Cargar todos los años disponibles')
    parser.add_argument('--force', action='store_true', help='Forzar recarga')
    args = parser.parse_args()
    
    # Leer datos
    df = pd.read_excel(ARCHIVO_COMPROBANTES, engine='openpyxl')
    df.columns = df.columns.str.upper().str.strip()
    df['FECHA_COMPROBANTE'] = pd.to_datetime(df['FECHA_COMPROBANTE'], errors='coerce')
    df['anio_dato'] = df['FECHA_COMPROBANTE'].dt.year
    df = validar_schema_comprobantes(df)
    
    # Conectar
    conn = get_connection('DW_GrupoPOSE_B52')
    
    try:
        if args.full:
            anios_unicos = df['anio_dato'].dropna().unique()
            anios_unicos.sort()
            print(f"\n🔄 Modo FULL: {len(anios_unicos)} años detectados")
            for anio in anios_unicos:
                cargar_anio(conn, df, int(anio), skip_if_processed=not args.force)
        elif args.anio:
            cargar_anio(conn, df, args.anio, skip_if_processed=not args.force)
        else:
            print("❌ Error: Especificar --anio o --full")
            sys.exit(1)
        
        print("\n🏁 PROCESO FINALIZADO")
    finally:
        conn.close()

if __name__ == '__main__':
    main()
```

---



```python
"""
Carga de CATALOGO.proveedores con estrategia UPSERT
Mantiene histórico de proveedores activos
"""
import pandas as pd
from datetime import datetime
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).parent.parent / 'utils'))
from conexion import get_connection
from auditoria_incremental import registrar_inicio, registrar_fin

ARCHIVO_PROVEEDORES = Path(r'C:\DW_GrupoPOSE_B52\01_input_raw\Proveedores.xlsx')

def clasificar_proveedor(row):
    """Clasificación automática por análisis de nombre/CUIT"""
    nombre = str(row.get('nombre_proveedor', '')).upper()
    
    # Clasificación por keywords
    if any(x in nombre for x in ['MATERIALES', 'HIERRO', 'CEMENTO', 'LADRILLOS']):
        return 'Materiales'
    elif any(x in nombre for x in ['SERVICIO', 'TRANSPORTE', 'CONSULTOR']):
        return 'Servicios'
    elif any(x in nombre for x in ['CONSTRUCCION', 'OBRAS', 'INGENIERIA']):
        return 'Obra'
    else:
        return 'General'

def tipo_entidad_por_cuit(cuit):
    """Determina tipo de entidad por CUIT"""
    if pd.isna(cuit) or cuit == '':
        return 'Desconocido'
    
    cuit_str = str(cuit).replace('-', '')
    if len(cuit_str) < 2:
        return 'Desconocido'
    
    # Primeros dígitos del CUIT indican tipo
    prefijo = int(cuit_str[:2])
    if prefijo in [20, 23, 24, 27]:
        return 'Persona Física'
    elif prefijo in [30, 33, 34]:
        return 'Jurídica'
    else:
        return 'Otro'

def upsert_proveedores(conn, df):
    """UPSERT: Actualiza existentes, inserta nuevos"""
    print(f"\n💾 Ejecutando UPSERT de proveedores")
    
    cursor = conn.cursor()
    total_actualizados = 0
    total_insertados = 0
    
    for _, row in df.iterrows():
        nombre_norm = row['nombre_proveedor_norm']
        cuit = row.get('cuit')
        
        # Buscar por CUIT o nombre normalizado
        if pd.notna(cuit):
            query_buscar = "SELECT id_proveedor FROM CATALOGO.proveedores WHERE cuit = ?"
            cursor.execute(query_buscar, cuit)
        else:
            query_buscar = "SELECT id_proveedor FROM CATALOGO.proveedores WHERE nombre_proveedor_norm = ?"
            cursor.execute(query_buscar, nombre_norm)
        
        resultado = cursor.fetchone()
        
        if resultado:
            # UPDATE
            id_prov = resultado[0]
            query_update = """
                UPDATE CATALOGO.proveedores 
                SET nombre_proveedor = ?, codigo_proveedor = ?, categoria = ?, 
                    tipo_entidad = ?, fecha_modificacion = ?, activo = 1
                WHERE id_proveedor = ?
            """
            cursor.execute(query_update, 
                row['nombre_proveedor'], row.get('codigo_proveedor'),
                row['categoria'], row['tipo_entidad'], datetime.now(), id_prov
            )
            total_actualizados += 1
        else:
            # INSERT
            query_insert = """
                INSERT INTO CATALOGO.proveedores (
                    cuit, nombre_proveedor, nombre_proveedor_norm, codigo_proveedor,
                    categoria, tipo_entidad, activo, fecha_alta, usuario_carga
                ) VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)
            """
            cursor.execute(query_insert,
                cuit, row['nombre_proveedor'], nombre_norm, row.get('codigo_proveedor'),
                row['categoria'], row['tipo_entidad'], datetime.now(), USUARIO_CARGA
            )
            total_insertados += 1
    
    conn.commit()
    print(f"   ✅ Actualizados: {total_actualizados}")
    print(f"   ✅ Insertados: {total_insertados}")
    
    return total_actualizados, total_insertados

def main():
    print(f"\n{'='*70}")
    print("📦 CARGA DE PROVEEDORES (UPSERT)")
    print(f"{'='*70}\n")
    
    # Leer datos
    df = pd.read_excel(ARCHIVO_PROVEEDORES, engine='openpyxl')
    df.columns = df.columns.str.upper().str.strip()
    
    # Normalizar nombres
    df['nombre_proveedor_norm'] = df['NOMBRE_PROVEEDOR'].str.upper().str.strip()
    
    # Clasificar automáticamente
    df['categoria'] = df.apply(clasificar_proveedor, axis=1)
    df['tipo_entidad'] = df['CUIT'].apply(tipo_entidad_por_cuit)
    
    print(f"📊 Proveedores a procesar: {len(df)}")
    print(f"   Categorías: {df['categoria'].value_counts().to_dict()}")
    
    # Conectar y cargar
    conn = get_connection('DW_GrupoPOSE_B52')
    
    try:
        id_log_carga = registrar_inicio(conn, 'CATALOGO.proveedores', 
                                       str(ARCHIVO_PROVEEDORES), USUARIO_CARGA)
        
        actualizados, insertados = upsert_proveedores(conn, df)
        
        registrar_fin(conn, id_log_carga, len(df), insertados, 0, 'EXITOSO',
                     f'Actualizados: {actualizados}, Insertados: {insertados}')
        
        print(f"\n✅ PROCESO COMPLETADO")
    finally:
        conn.close()

if __name__ == '__main__':
    main()
```

---

### Fase 4: Sistema ML Observability (Semana 5)

**Objetivo:** Implementar detección automática de anomalías y generación de alertas



```python
"""
Calcula features de ML Observability post-carga
- Z-scores por obra/proveedor
- Percentiles de importes
- Detección de outliers estadísticos
"""
import pandas as pd
import numpy as np
from datetime import datetime
from pathlib import Path
import sys

sys.path.append(str(Path(__file__).parent.parent / 'utils'))
from conexion import get_connection

def calcular_z_scores(conn):
    """Calcula Z-scores de importes por obra"""
    print("\n📊 Calculando Z-scores por obra...")
    
    # Leer datos recientes
    query = """
        SELECT id_costo, obra_pronto, importe, fecha,
               anio_dato, mes_dato
        FROM PRODUCCION.costos
        WHERE z_score_importe IS NULL OR fecha_carga > DATEADD(DAY, -7, GETDATE())
    """
    df = pd.read_sql(query, conn)
    print(f"   Registros a procesar: {len(df)}")
    
    if len(df) == 0:
        print("   ℹ️  Sin registros pendientes")
        return 0
    
    # Calcular media y desv. estándar por obra
    stats = df.groupby('obra_pronto')['importe'].agg(['mean', 'std']).reset_index()
    stats.columns = ['obra_pronto', 'media', 'std']
    
    # Merge con datos originales
    df = df.merge(stats, on='obra_pronto', how='left')
    
    # Calcular Z-score
    df['z_score'] = np.where(
        df['std'] > 0,
        (df['importe'] - df['media']) / df['std'],
        0
    )
    
    # Marcar outliers (|z| > 3)
    df['es_outlier'] = df['z_score'].abs() > 3
    
    # Percentil dentro de la obra
    df['percentil'] = df.groupby('obra_pronto')['importe'].rank(pct=True) * 100
    
    # Categorizar riesgo
    def categorizar_riesgo(z_score):
        abs_z = abs(z_score)
        if abs_z <= 1:
            return 'LOW'
        elif abs_z <= 2:
            return 'MEDIUM'
        elif abs_z <= 3:
            return 'HIGH'
        else:
            return 'CRITICAL'
    
    df['categoria_riesgo'] = df['z_score'].apply(categorizar_riesgo)
    
    # Actualizar BD
    cursor = conn.cursor()
    query_update = """
        UPDATE PRODUCCION.costos
        SET z_score_importe = ?, percentil_importe = ?, 
            es_outlier_estadistico = ?, categoria_riesgo = ?
        WHERE id_costo = ?
    """
    
    registros_actualizados = 0
    for _, row in df.iterrows():
        cursor.execute(query_update,
            float(row['z_score']), int(row['percentil']),
            bool(row['es_outlier']), row['categoria_riesgo'], int(row['id_costo'])
        )
        registros_actualizados += 1
        
        if registros_actualizados % 1000 == 0:
            conn.commit()
            print(f"   ⏳ Actualizados: {registros_actualizados}/{len(df)}")
    
    conn.commit()
    print(f"   ✅ Calculados Z-scores: {registros_actualizados} registros")
    print(f"   ⚠️  Outliers detectados: {df['es_outlier'].sum()}")
    
    return registros_actualizados

def main():
    print(f"\n{'='*70}")
    print("🤖 CÁLCULO DE FEATURES ML OBSERVABILITY")
    print(f"{'='*70}\n")
    
    conn = get_connection('DW_GrupoPOSE_B52')
    
    try:
        total_procesados = calcular_z_scores(conn)
        
        print(f"\n✅ PROCESO COMPLETADO: {total_procesados} features calculadas")
    finally:
        conn.close()

if __name__ == '__main__':
    main()
```

---



```python
"""
Sistema de Alertas ML Observability
Detecta y registra anomalías automáticamente
"""
import pandas as pd
from datetime import datetime, timedelta
from pathlib import Path
import sys

sys.path.append(str(Path(__file__).parent.parent / 'utils'))
from conexion import get_connection

def generar_alerta(conn, tipo_alerta, severidad, tabla_origen, id_registro, 
                   descripcion, valor_detectado, valor_esperado):
    """Inserta alerta en ML.historial_alertas"""
    cursor = conn.cursor()
    
    query = """
        INSERT INTO ML.historial_alertas (
            tipo_alerta, severidad, tabla_origen, id_registro_origen,
            descripcion, valor_detectado, valor_esperado, accion_tomada, estado
        ) VALUES (?, ?, ?, ?, ?, ?, ?, 'AUTO_FLAG', 'ACTIVA')
    """
    
    cursor.execute(query, tipo_alerta, severidad, tabla_origen, id_registro,
                  descripcion, valor_detectado, valor_esperado)
    conn.commit()

def detectar_outliers_criticos(conn):
    """Alerta por outliers con |z-score| > 3"""
    print("\n⚠️  Detectando outliers críticos...")
    
    query = """
        SELECT id_costo, obra_pronto, importe, z_score_importe, categoria_riesgo
        FROM PRODUCCION.costos
        WHERE categoria_riesgo = 'CRITICAL'
          AND fecha_carga > DATEADD(DAY, -1, GETDATE())
          AND id_costo NOT IN (SELECT id_registro_origen FROM ML.historial_alertas 
                                WHERE tipo_alerta = 'OUTLIER_CRITICO' AND estado = 'ACTIVA')
    """
    df = pd.read_sql(query, conn)
    
    if len(df) == 0:
        print("   ℹ️  Sin outliers nuevos")
        return 0
    
    print(f"   🚨 Outliers críticos detectados: {len(df)}")
    
    for _, row in df.iterrows():
        generar_alerta(
            conn, 'OUTLIER_CRITICO', 'CRITICAL', 'PRODUCCION.costos', int(row['id_costo']),
            f"Costo anómalo en obra {row['obra_pronto']}: ${row['importe']:,.2f} (Z-score: {row['z_score_importe']:.2f})",
            f"${row['importe']:,.2f}", "Rangovalor típico"
        )
    
    print(f"   ✅ Generadas {len(df)} alertas críticas")
    return len(df)

def detectar_proveedores_nuevos_alto_monto(conn):
    """Alerta por proveedores nuevos con primera factura > $1M"""
    print("\n🆕 Detectando proveedores nuevos con alto monto...")
    
    query = """
        SELECT p.id_proveedor, p.nombre_proveedor, c.importe, c.id_costo
        FROM CATALOGO.proveedores p
        INNER JOIN (
            SELECT proveedor_id, MIN(id_costo) as primer_costo, MAX(importe) as max_importe
            FROM PRODUCCION.costos
            WHERE fecha_carga > DATEADD(DAY, -7, GETDATE())
            GROUP BY proveedor_id
        ) c ON p.id_proveedor = c.proveedor_id
        WHERE p.fecha_alta > DATEADD(DAY, -30, GETDATE())
          AND c.max_importe > 1000000
    """
    df = pd.read_sql(query, conn)
    
    if len(df) == 0:
        print("   ℹ️  Sin proveedores nuevos de alto monto")
        return 0
    
    print(f"   🚨 Proveedores nuevos detectados: {len(df)}")
    
    for _, row in df.iterrows():
        generar_alerta(
            conn, 'PROVEEDOR_NUEVO_ALTO_MONTO', 'WARNING', 'PRODUCCION.costos', int(row['id_costo']),
            f"Proveedor nuevo '{row['nombre_proveedor']}' con primera factura de ${row['importe']:,.2f}",
            f"${row['importe']:,.2f}", "< $1,000,000"
        )
    
    print(f"   ✅ Generadas {len(df)} alertas de proveedores")
    return len(df)

def main():
    print(f"\n{'='*70}")
    print("🚨 GENERACIÓN DE ALERTAS ML OBSERVABILITY")
    print(f"{'='*70}\n")
    
    conn = get_connection('DW_GrupoPOSE_B52')
    
    try:
        alertas_outliers = detectar_outliers_criticos(conn)
        alertas_proveedores = detectar_proveedores_nuevos_alto_monto(conn)
        
        total_alertas = alertas_outliers + alertas_proveedores
        
        print(f"\n✅ PROCESO COMPLETADO: {total_alertas} alertas generadas")
    finally:
        conn.close()

if __name__ == '__main__':
    main()
```

---

### Fase 5: Utilidades y Validaciones (Semana 6)


```python
"""
Utilidades para auditoría de cargas incrementales B52
"""
import pyodbc
from datetime import datetime

def verificar_procesado_periodo(conn, tabla_destino, periodo_codigo):
    """Verifica si un período ya fue procesado exitosamente"""
    cursor = conn.cursor()
    
    query = """
        SELECT id_periodo_carga 
        FROM AUDITORIA.periodos_carga
        WHERE tabla_destino = ? AND periodo_codigo = ? AND estado = 'EXITOSO'
    """
    cursor.execute(query, tabla_destino, periodo_codigo)
    resultado = cursor.fetchone()
    
    if resultado:
        return True, resultado[0]
    return False, None

def registrar_inicio_periodo(conn, tabla, tipo_particion, anio, mes, periodo_codigo, usuario):
    """Registra inicio de carga de período"""
    cursor = conn.cursor()
    
    # Registro en log_cargas (herencia A2)
    query_log = """
        INSERT INTO AUDITORIA.log_cargas (tabla_destino, archivo_origen, usuario_carga, estado)
        OUTPUT INSERTED.id_log_carga
        VALUES (?, ?, ?, 'EN_PROCESO')
    """
    cursor.execute(query_log, tabla, f'INCREMENTAL_{periodo_codigo}', usuario)
    id_log_carga = cursor.fetchone()[0]
    
    # Registro en periodos_carga (nuevo B52)
    query_periodo = """
        INSERT INTO AUDITORIA.periodos_carga (
            tabla_destino, tipo_particion, anio, mes, periodo_codigo, 
            estado, usuario_carga
        )
        OUTPUT INSERTED.id_periodo_carga
        VALUES (?, ?, ?, ?, ?, 'EN_PROCESO', ?)
    """
    cursor.execute(query_periodo, tabla, tipo_particion, anio, mes, periodo_codigo, usuario)
    id_periodo_carga = cursor.fetchone()[0]
    
    conn.commit()
    return id_log_carga, id_periodo_carga

def registrar_fin_periodo(conn, id_log_carga, id_periodo_carga, registros_borrados,
                         registros_insertados, duracion_segundos, estado, observaciones):
    """Registra finalización de carga de período"""
    cursor = conn.cursor()
    
    velocidad = registros_insertados / duracion_segundos if duracion_segundos > 0 else 0
    
    # Actualizar log_cargas
    query_log = """
        UPDATE AUDITORIA.log_cargas
        SET registros_insertados = ?, estado = ?, observaciones = ?
        WHERE id_log_carga = ?
    """
    cursor.execute(query_log, registros_insertados, estado, observaciones, id_log_carga)
    
    # Actualizar periodos_carga
    query_periodo = """
        UPDATE AUDITORIA.periodos_carga
        SET registros_borrados = ?, registros_insertados = ?,
            fecha_fin_carga = ?, duracion_segundos = ?,
            velocidad_registros_seg = ?, estado = ?, observaciones = ?
        WHERE id_periodo_carga = ?
    """
    cursor.execute(query_periodo, registros_borrados, registros_insertados,
                  datetime.now(), duracion_segundos, velocidad, estado,
                  observaciones, id_periodo_carga)
    
    conn.commit()
```

---


```python
"""
Medidor de rendimiento para monitorear tiempos y velocidad de carga
"""
from datetime import datetime
import psutil
import os

class MedidorRendimiento:
    def __init__(self, nombre_proceso):
        self.nombre_proceso = nombre_proceso
        self.tiempo_inicio = None
        self.tiempo_fin = None
        self.fases = {}
        self.fase_actual = None
        self.proceso = psutil.Process(os.getpid())
    
    def iniciar(self):
        """Inicia medición"""
        self.tiempo_inicio = datetime.now()
        print(f"⏱️  Iniciando medición: {self.nombre_proceso}")
    
    def marcar_fase(self, nombre_fase):
        """Marca inicio de una nueva fase"""
        ahora = datetime.now()
        
        if self.fase_actual:
            # Finalizar fase anterior
            duracion = (ahora - self.fases[self.fase_actual]['inicio']).total_seconds()
            self.fases[self.fase_actual]['fin'] = ahora
            self.fases[self.fase_actual]['duracion'] = duracion
        
        # Iniciar nueva fase
        self.fase_actual = nombre_fase
        self.fases[nombre_fase] = {
            'inicio': ahora,
            'fin': None,
            'duracion': None
        }
        print(f"   ▶️  Fase: {nombre_fase}")
    
    def finalizar(self):
        """Finaliza medición"""
        self.tiempo_fin = datetime.now()
        
        if self.fase_actual:
            duracion = (self.tiempo_fin - self.fases[self.fase_actual]['inicio']).total_seconds()
            self.fases[self.fase_actual]['fin'] = self.tiempo_fin
            self.fases[self.fase_actual]['duracion'] = duracion
    
    @property
    def duracion_total(self):
        """Duración total en segundos"""
        if self.tiempo_fin and self.tiempo_inicio:
            return (self.tiempo_fin - self.tiempo_inicio).total_seconds()
        return 0
    
    @property
    def velocidad_registros_seg(self):
        """Calcula velocidad aproximada"""
        # Implementar según registros procesados
        return 0
    
    def imprimir_resumen(self):
        """Imprime resumen de rendimiento"""
        print(f"\n📈 MÉTRICAS DE RENDIMIENTO: {self.nombre_proceso}")
        print(f"   Duración total: {self.duracion_total:.2f} segundos")
        
        for fase, datos in self.fases.items():
            if datos['duracion']:
                print(f"   - {fase}: {datos['duracion']:.2f}s")
        
        # Memoria
        mem_info = self.proceso.memory_info()
        print(f"   Memoria: {mem_info.rss / 1024 / 1024:.2f} MB")
```

---

### Fase 6: Testing y Validación (Semana 7)

#### Test 1: Carga incremental mensual

```bash
# Test básico: cargar un mes específico

# Validar en BD
SELECT anio_dato, mes_dato, COUNT(*) as total
FROM PRODUCCION.costos
GROUP BY anio_dato, mes_dato
ORDER BY anio_dato, mes_dato;

# Test idempotencia: re-ejecutar mismo mes

# Debe reemplazar datos, mismo count
```

#### Test 2: Carga incremental anual

```bash
# Cargar año 2026

# Validar
SELECT anio_dato, COUNT(*) FROM PRODUCCION.comprobantes
GROUP BY anio_dato;
```

#### Test 3: ML Observability

```bash
# Calcular features ML

# Verificar z-scores calculados
SELECT COUNT(*) FROM PRODUCCION.costos WHERE z_score_importe IS NOT NULL;

# Generar alertas

# Ver alertas generadas
SELECT * FROM ML.historial_alertas ORDER BY fecha_generacion DESC;
```

---

### Fase 7: Documentación y Despliegue (Semana 8)

#### Documento: Manual de Operación B52

**Archivo:** `05_documentacion/Manual_Operacion_B52.md`

```markdown
# Manual de Operación DW_GrupoPOSE_B52

## Carga Mensual de Costos

**Frecuencia:** Mensual (primeros 5 días del mes)
**Responsable:** Operador ETL

### Procedimiento:

1. Verificar archivo actualizado en `01_input_raw/BaseCostosPOSE_B52.xlsx`
2. Ejecutar carga del mes anterior:
   ```bash
   ```
3. Verificar log en `00_logs/`
4. Consultar auditoría:
   ```sql
   SELECT * FROM AUDITORIA.periodos_carga
   WHERE periodo_codigo = '202603';
   ```

## Carga Anual de Comprobantes

**Frecuencia:** Anual (enero)
**Responsable:** Operador ETL

### Procedimiento:

1. Verificar archivo en `01_input_raw/ComprobantesPOSE_B52.xlsx`
2. Ejecutar carga del año completo:
   ```bash
   ```
3. Verificar volumetría anual

## Monitoreo de Alertas

**Frecuencia:** Diaria (post-carga)

### Procedimiento:

1. Calcular features ML:
   ```bash
   ```
2. Generar alertas:
   ```bash
   ```
3. Revisar alertas críticas:
   ```sql
   SELECT * FROM ML.historial_alertas
   WHERE severidad = 'CRITICAL' AND estado = 'ACTIVA';
   ```

## Rollback a A2

En caso de fallo en B52:

1. Reconectar aplicaciones a `DW_GrupoPOSE_A2`
2. Investigar error en B52
3. Corregir y re-testear
4. Volver a B52 cuando esté estable
```

---

## 5. Código SQL: Estructura Completa

### Archivo: `01_crear_estructura_B52.sql`

```sql
-- ============================================================================
-- DW_GrupoPOSE_B52 - Estructura Completa
-- Fecha: 13 de marzo de 2026
-- Versión: 1.0
-- Descripción: Data Warehouse con carga incremental y ML Observability
-- ============================================================================

-- Crear base de datos
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'DW_GrupoPOSE_B52')
BEGIN
    CREATE DATABASE DW_GrupoPOSE_B52;
END
GO

USE DW_GrupoPOSE_B52;
GO

-- ============================================================================
-- ESQUEMAS
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'CATALOGO')
    EXEC('CREATE SCHEMA CATALOGO');
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'PRODUCCION')
    EXEC('CREATE SCHEMA PRODUCCION');
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'AUDITORIA')
    EXEC('CREATE SCHEMA AUDITORIA');
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'TEMPORAL')
    EXEC('CREATE SCHEMA TEMPORAL');
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'ML')
    EXEC('CREATE SCHEMA ML');
GO

-- ============================================================================
-- CATALOGO: DIMENSIONES
-- ============================================================================

-- Gerencias (herencia de A2)
CREATE TABLE CATALOGO.gerencias (
    id_gerencia INT IDENTITY(1,1) PRIMARY KEY,
    codigo_gerencia NVARCHAR(50) UNIQUE NOT NULL,
    nombre_gerencia NVARCHAR(400) NOT NULL,
    activo BIT DEFAULT 1,
    fecha_alta DATETIME2 DEFAULT GETDATE(),
    fecha_baja DATETIME2 NULL
);

-- Compensables (NUEVA DIMENSION AUTO-GENERADA DESDE OBRAS)
CREATE TABLE CATALOGO.compensables (
    id_compensable INT IDENTITY(1,1) PRIMARY KEY,
    estado_compensable NVARCHAR(100) UNIQUE NOT NULL, -- ej: 'SI', 'NO', 'ADMINISTRACION'
    activo BIT DEFAULT 1,
    fecha_alta DATETIME2 DEFAULT GETDATE()
);

-- Tipos de Comprobantes (NUEVA DIMENSION AUTO-GENERADA)
CREATE TABLE CATALOGO.tipos_comprobantes (
    id_tipo_comprobante INT IDENTITY(1,1) PRIMARY KEY,
    tipo_comprobante NVARCHAR(200) UNIQUE NOT NULL,
    es_automatica BIT DEFAULT 1,
    activo BIT DEFAULT 1,
    fecha_alta DATETIME2 DEFAULT GETDATE()
);

-- Obras (herencia de A2 adaptada a B52, RDP puro)
CREATE TABLE CATALOGO.obras (
    id_obra INT IDENTITY(1,1) PRIMARY KEY,
    obra_pronto VARCHAR(50) UNIQUE NOT NULL,
    descripcion_obra NVARCHAR(600) NOT NULL,
    nro_obra INT, -- Campo propio extraído de RDP de obras
    id_compensable INT, -- FK mapeada hacia tabla compensables (RDP)
    id_gerencia INT, -- FK mapeada hacia la gerencia que la administra (RDP completo sin desperdicio)
    activo BIT DEFAULT 1,
    fecha_alta DATETIME2 DEFAULT GETDATE(),
    fecha_baja DATETIME2 NULL,
    FOREIGN KEY (id_compensable) REFERENCES CATALOGO.compensables(id_compensable),
    FOREIGN KEY (id_gerencia) REFERENCES CATALOGO.gerencias(id_gerencia)
);

-- Proveedores (NUEVA DIMENSION COMPLETA)
CREATE TABLE CATALOGO.proveedores (
    id_proveedor BIGINT IDENTITY(1,1) PRIMARY KEY,
    cuit NVARCHAR(20) UNIQUE,
    nombre_proveedor NVARCHAR(600) NOT NULL,
    nombre_proveedor_norm NVARCHAR(600) NOT NULL,
    codigo_proveedor NVARCHAR(100),
    categoria VARCHAR(50),  -- 'Materiales', 'Servicios', 'Obra', 'General'
    tipo_entidad VARCHAR(20),  -- 'Persona Física', 'Jurídica', 'Desconocido'
    es_proveedor_ff BIT DEFAULT 0,
    frecuencia_transaccional VARCHAR(20), -- 'Habitual', 'Ocasional', 'Único'
    total_facturado_historico DECIMAL(18,2) DEFAULT 0,
    activo BIT DEFAULT 1,
    fecha_alta DATETIME2 DEFAULT GETDATE(),
    fecha_baja DATETIME2 NULL,
    fecha_modificacion DATETIME2 DEFAULT GETDATE(),
    usuario_carga NVARCHAR(200)
);

CREATE INDEX IX_proveedores_nombre_norm ON CATALOGO.proveedores(nombre_proveedor_norm);
CREATE INDEX IX_proveedores_categoria ON CATALOGO.proveedores(categoria);
CREATE INDEX IX_proveedores_cuit ON CATALOGO.proveedores(cuit) WHERE cuit IS NOT NULL;

-- Fuentes (NUEVA DIMENSION)
CREATE TABLE CATALOGO.fuentes (
    id_fuente INT IDENTITY(1,1) PRIMARY KEY,
    codigo_fuente NVARCHAR(50) UNIQUE NOT NULL,
    nombre_fuente NVARCHAR(200) NOT NULL,
    descripcion NVARCHAR(500),
    tipo_movimiento VARCHAR(10) CHECK (tipo_movimiento IN ('INGRESO','EGRESO','MIXTO')),
    es_automatica BIT DEFAULT 0,
    prioridad_carga INT DEFAULT 100,
    activo BIT DEFAULT 1,
    fecha_alta DATETIME2 DEFAULT GETDATE(),
    fecha_baja DATETIME2 NULL
);

-- Cuentas Contables (NUEVA DIMENSION AUTO-GENERADA)
CREATE TABLE CATALOGO.cuentas_contables (
    id_cuenta_contable INT IDENTITY(1,1) PRIMARY KEY,
    rubro_contable NVARCHAR(150),
    codigo_cuenta NVARCHAR(100),
    cuenta_contable NVARCHAR(400),
    es_automatica BIT DEFAULT 1,
    activo BIT DEFAULT 1,
    fecha_alta DATETIME2 DEFAULT GETDATE()
);

-- Jerarquía Organizativa (NUEVA DIMENSION)
CREATE TABLE CATALOGO.jerarquia_org (
    id_jerarquia INT IDENTITY(1,1) PRIMARY KEY,
    codigo_jerarquia NVARCHAR(50) UNIQUE NOT NULL,
    taller_region NVARCHAR(100),
    unidad_temporal NVARCHAR(100),
    codigo_centro_costo NVARCHAR(50),
    id_gerencia INT,
    empresa VARCHAR(20),
    nivel_organizativo INT, -- 1=Empresa, 2=Gerencia, 3=Taller, 4=Unidad
    activo BIT DEFAULT 1,
    fecha_alta DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (id_gerencia) REFERENCES CATALOGO.gerencias(id_gerencia)
);

CREATE INDEX IX_jerarquia_gerencia ON CATALOGO.jerarquia_org(id_gerencia);

-- Calendario
CREATE TABLE CATALOGO.calendario (
    fecha DATE PRIMARY KEY,
    anio INT NOT NULL,
    mes INT NOT NULL,
    dia INT NOT NULL,
    nombre_mes NVARCHAR(20) NOT NULL,
    trimestre INT NOT NULL,
    semestre INT NOT NULL,
    dia_semana INT NOT NULL,
    nombre_dia_semana NVARCHAR(20) NOT NULL,
    es_fin_semana BIT NOT NULL,
    semana_anio INT NOT NULL
);

-- ============================================================================
-- PRODUCCION: HECHOS CON ML OBSERVABILITY
-- ============================================================================

-- Costos (INCREMENTAL MENSUAL)
CREATE TABLE PRODUCCION.costos (
    id_costo BIGINT IDENTITY(1,1) PRIMARY KEY,
    id_log_carga BIGINT NOT NULL,
    
    -- Dimensiones
    obra_pronto VARCHAR(50) NOT NULL,
      id_gerencia INT,  -- B52: Ahora la dimensionalidad cruzada Obra-Gerencia ocurre a nivel del Hecho
    fuente_id INT,
    
    -- Métricas
    importe DECIMAL(18,2),
    tipo_cambio DECIMAL(10,6),
    importe_usd DECIMAL(18,2),
    
    nombre_proveedor NVARCHAR(600),
    nombre_proveedor_norm NVARCHAR(600),
    id_tipo_comprobante INT, -- B52: Dimensión Tipos de Comprobantes extraída
    numero_comprobante NVARCHAR(200),
    numero_comprobante_norm NVARCHAR(200),
    observacion NVARCHAR(MAX),
    detalle NVARCHAR(1000),
    
    -- Clasificación
    taller_reg NVARCHAR(400),
    ut_otros NVARCHAR(400),
    id_cuenta_contable INT, -- B52: Dimensión Cuentas Contables extraída
    -- compensable migrado como atributo directo de la dimensión Obras (id_compensable)
    fuente NVARCHAR(100),
    descripcion_obra NVARCHAR(600),
    
    -- Particionamiento MENSUAL
    anio_dato INT NOT NULL,
    mes_dato INT NOT NULL,
    
    -- ML Observability
    z_score_importe DECIMAL(10,6),
    percentil_importe INT,
    dias_desde_ultima_carga INT,
    es_outlier_estadistico BIT DEFAULT 0,
    es_valor_inusual BIT DEFAULT 0,
    categoria_riesgo VARCHAR(20), -- 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'
    
    -- Auditoría
    archivo_origen NVARCHAR(510) NOT NULL,
    fila_excel INT,
    fecha_carga DATETIME2 DEFAULT GETDATE(),
    usuario_carga NVARCHAR(200),
    
    FOREIGN KEY (obra_pronto) REFERENCES CATALOGO.obras(obra_pronto),
    FOREIGN KEY (proveedor_id) REFERENCES CATALOGO.proveedores(id_proveedor)
);

-- Índices para particionamiento mensual
CREATE NONCLUSTERED INDEX IX_costos_particion 
ON PRODUCCION.costos (anio_dato, mes_dato, fecha)
INCLUDE (importe, obra_pronto, proveedor_id);

CREATE NONCLUSTERED INDEX IX_costos_obra 
ON PRODUCCION.costos (obra_pronto)
INCLUDE (fecha, importe);

CREATE NONCLUSTERED INDEX IX_costos_ml 
ON PRODUCCION.costos (categoria_riesgo, es_outlier_estadistico)
WHERE categoria_riesgo IN ('HIGH', 'CRITICAL');

-- Comprobantes (INCREMENTAL ANUAL)
CREATE TABLE PRODUCCION.comprobantes (
    id_comprobante BIGINT IDENTITY(1,1) PRIMARY KEY,
    id_log_carga BIGINT NOT NULL,
    
    -- Dimensiones
    obra_pronto VARCHAR(50),
    fecha_comprobante DATE NOT NULL,
    proveedor_id BIGINT,
    
    -- Datos
    numero_comprobante NVARCHAR(200) NOT NULL,
    numero_comprobante_norm NVARCHAR(200) NOT NULL,
    cod_proveedor NVARCHAR(100),
    nombre_proveedor NVARCHAR(600),
    nombre_proveedor_norm NVARCHAR(600),
    importe DECIMAL(18,2) NOT NULL,
    
    -- Clasificación
    id_tipo_comprobante INT,
    proveedor_ff VARCHAR(200),
    id_cuenta_contable INT,
    fecha_vto DATE,
    tc DECIMAL(10,6),
    moneda VARCHAR(10),
    observacion VARCHAR(500),
    
    -- Particionamiento ANUAL
    anio_dato INT NOT NULL,
    
    -- Auditoría
    archivo_origen NVARCHAR(510) NOT NULL,
    hoja_origen NVARCHAR(200),
    fila_excel INT,
    fecha_carga DATETIME2 DEFAULT GETDATE(),
    usuario_carga NVARCHAR(200),
    
    FOREIGN KEY (obra_pronto) REFERENCES CATALOGO.obras(obra_pronto),
    FOREIGN KEY (proveedor_id) REFERENCES CATALOGO.proveedores(id_proveedor)
);

-- Índices para particionamiento anual
CREATE NONCLUSTERED INDEX IX_comprobantes_particion 
ON PRODUCCION.comprobantes (anio_dato, fecha_comprobante)
INCLUDE (importe, proveedor_id);

-- Restricción de unicidad
CREATE UNIQUE INDEX UQ_comprobantes_key 
ON PRODUCCION.comprobantes (nombre_proveedor_norm, numero_comprobante_norm, fecha_comprobante, obra_pronto);

-- ============================================================================
-- AUDITORIA: CONTROL AVANZADO
-- ============================================================================

-- Log de cargas (herencia A2)
CREATE TABLE AUDITORIA.log_cargas (
    id_log_carga BIGINT IDENTITY(1,1) PRIMARY KEY,
    tabla_destino NVARCHAR(100) NOT NULL,
    archivo_origen NVARCHAR(500) NOT NULL,
    registros_procesados INT DEFAULT 0,
    registros_insertados INT DEFAULT 0,
    registros_rechazados INT DEFAULT 0,
    fecha_carga DATETIME2 DEFAULT GETDATE(),
    usuario_carga NVARCHAR(200),
    estado NVARCHAR(50) DEFAULT 'PENDIENTE',
    observaciones NVARCHAR(MAX)
);

-- Períodos carga (NUEVA - CARGA INCREMENTAL)
CREATE TABLE AUDITORIA.periodos_carga (
    id_periodo_carga BIGINT IDENTITY(1,1) PRIMARY KEY,
    tabla_destino NVARCHAR(100) NOT NULL,
    tipo_particion VARCHAR(20) NOT NULL, -- 'MENSUAL', 'ANUAL'
    anio INT NOT NULL,
    mes INT NULL,
    periodo_codigo VARCHAR(10) NOT NULL, -- '202603', '2026'
    registros_borrados INT DEFAULT 0,
    registros_insertados INT DEFAULT 0,
    fecha_inicio_carga DATETIME2 DEFAULT GETDATE(),
    fecha_fin_carga DATETIME2,
    duracion_segundos DECIMAL(10,2),
    velocidad_registros_seg DECIMAL(10,2),
    estado VARCHAR(20) DEFAULT 'EN_PROCESO',
    observaciones NVARCHAR(MAX),
    usuario_carga NVARCHAR(200)
);

CREATE INDEX IX_periodos_tabla ON AUDITORIA.periodos_carga(tabla_destino, anio, mes);

-- Métricas de rendimiento (NUEVA)
CREATE TABLE AUDITORIA.metricas_rendimiento (
    id_metrica BIGINT IDENTITY(1,1) PRIMARY KEY,
    id_log_carga BIGINT,
    id_periodo_carga BIGINT,
    fase_proceso VARCHAR(50) NOT NULL,
    tiempo_inicio DATETIME2 NOT NULL,
    tiempo_fin DATETIME2 NOT NULL,
    duracion_milisegundos INT,
    memoria_usada_mb DECIMAL(10,2),
    cpu_porcentaje DECIMAL(5,2),
    registros_procesados INT,
    observaciones NVARCHAR(500),
    FOREIGN KEY (id_log_carga) REFERENCES AUDITORIA.log_cargas(id_log_carga),
    FOREIGN KEY (id_periodo_carga) REFERENCES AUDITORIA.periodos_carga(id_periodo_carga)
);

-- Rechazos (herencia A2)
CREATE TABLE AUDITORIA.rechazos (
    id_rechazo BIGINT IDENTITY(1,1) PRIMARY KEY,
    id_log_carga BIGINT NOT NULL,
    fila_excel INT,
    motivo_rechazo NVARCHAR(MAX) NOT NULL,
    datos_rechazo NVARCHAR(MAX),
    fecha_rechazo DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (id_log_carga) REFERENCES AUDITORIA.log_cargas(id_log_carga)
);

-- ============================================================================
-- ML: MACHINE LEARNING OBSERVABILITY
-- ============================================================================

-- Parámetros de calidad por obra/proveedor
CREATE TABLE ML.parametros_calidad (
    id_parametro BIGINT IDENTITY(1,1) PRIMARY KEY,
    entidad_tipo VARCHAR(20) NOT NULL, -- 'OBRA', 'PROVEEDOR'
    entidad_id NVARCHAR(100) NOT NULL,
    metrica VARCHAR(50) NOT NULL, -- 'importe', 'tipo_cambio'
    valor_medio DECIMAL(18,2),
    desviacion_estandar DECIMAL(18,2),
    valor_min DECIMAL(18,2),
    valor_max DECIMAL(18,2),
    percentil_25 DECIMAL(18,2),
    percentil_50 DECIMAL(18,2),
    percentil_75 DECIMAL(18,2),
    registros_muestra INT,
    fecha_calculo DATETIME2 DEFAULT GETDATE()
);

CREATE INDEX IX_parametros_entidad ON ML.parametros_calidad(entidad_tipo, entidad_id);

-- Umbrales de alertas
CREATE TABLE ML.umbrales_alertas (
    id_umbral INT IDENTITY(1,1) PRIMARY KEY,
    tipo_alerta VARCHAR(50) UNIQUE NOT NULL,
    campo_medicion NVARCHAR(100) NOT NULL,
    valor_min DECIMAL(18,2),
    valor_max DECIMAL(18,2),
    porcentaje_variacion_permitido DECIMAL(5,2),
    severidad_default VARCHAR(20) DEFAULT 'WARNING',
    activo BIT DEFAULT 1,
    fecha_creacion DATETIME2 DEFAULT GETDATE()
);

-- Historial de alertas
CREATE TABLE ML.historial_alertas (
    id_alerta BIGINT IDENTITY(1,1) PRIMARY KEY,
    fecha_generacion DATETIME2 DEFAULT GETDATE(),
    tipo_alerta VARCHAR(50) NOT NULL,
    severidad VARCHAR(20) NOT NULL, -- 'INFO', 'WARNING', 'CRITICAL'
    tabla_origen NVARCHAR(100),
    id_registro_origen BIGINT,
    descripcion NVARCHAR(MAX) NOT NULL,
    valor_detectado NVARCHAR(200),
    valor_esperado NVARCHAR(200),
    accion_tomada VARCHAR(50),
    estado VARCHAR(20) DEFAULT 'ACTIVA', -- 'ACTIVA', 'RESUELTA', 'DESCARTADA'
    usuario_resolucion NVARCHAR(200),
    fecha_resolucion DATETIME2
);

CREATE INDEX IX_alertas_fecha ON ML.historial_alertas(fecha_generacion);
CREATE INDEX IX_alertas_tipo ON ML.historial_alertas(tipo_alerta, severidad);

-- Anomalías detectadas
CREATE TABLE ML.anomalias_detectadas (
    id_anomalia BIGINT IDENTITY(1,1) PRIMARY KEY,
    tabla_origen NVARCHAR(100) NOT NULL,
    id_registro_origen BIGINT NOT NULL,
    tipo_anomalia VARCHAR(50) NOT NULL,
    score_anomalia DECIMAL(10,6),
    descripcion NVARCHAR(MAX),
    fecha_deteccion DATETIME2 DEFAULT GETDATE(),
    revisada BIT DEFAULT 0,
    es_anomalia_real BIT
);

-- ============================================================================
-- TEMPORAL: STAGING
-- ============================================================================

-- Staging costos
CREATE TABLE TEMPORAL.costos_carga (
    id_costo_temp BIGINT IDENTITY(1,1) PRIMARY KEY,
    obra_pronto VARCHAR(50),
    fecha DATE,
    importe DECIMAL(18,2),
    tipo_cambio DECIMAL(10,6),
    importe_usd DECIMAL(18,2),
    nombre_proveedor NVARCHAR(600),
    id_tipo_comprobante INT, -- Mapeado desde python para la inserción
    numero_comprobante NVARCHAR(200),
    observacion NVARCHAR(MAX),
    taller_reg NVARCHAR(400),
    ut_otros NVARCHAR(400),
    id_cuenta_contable INT, -- Mapeado desde python cruzando con CATALOGO.cuentas_contables
    -- compensable migrado como atributo directo de la dimensión Obras (id_compensable)
    fuente NVARCHAR(100),
    descripcion_obra NVARCHAR(600),
    id_gerencia INT, -- Mapeado desde python para insercion limpia
-- Staging comprobantes
CREATE TABLE TEMPORAL.comprobantes_carga (
    id_comprobante_temp BIGINT IDENTITY(1,1) PRIMARY KEY,
    obra_pronto VARCHAR(50),
    numero_comprobante NVARCHAR(200),
    fecha_comprobante DATE,
    cod_proveedor NVARCHAR(100),
    nombre_proveedor NVARCHAR(600),
    importe DECIMAL(18,2),
    hoja_origen NVARCHAR(200),
    fila_excel INT,
    id_tipo_comprobante INT,
    proveedor_ff VARCHAR(200),
    id_cuenta_contable INT,
    fecha_vto DATE,
    tc DECIMAL(10,6),
    moneda VARCHAR(10),
    observacion VARCHAR(500)
);

PRINT '✅ Estructura DW_GrupoPOSE_B52 creada exitosamente';
GO
```

---



### Estructura de Módulos

```text
├── ml/                          # ML Observability
├── utils/                       # Utilidades compartidas
    └── ...
```

### Convenciones de Código

- ✅ Usar logging con formato estándar
- ✅ Generar logs en `C:\DW_GrupoPOSE_B52\00_logs\`
- ✅ Implementar manejo de errores con try/except
- ✅ Retornar exit codes apropiados (0=éxito, 1=error)
- ✅ Documentar parámetros con argparse
- ✅ Incluir docstrings en funciones principales

---

## 7. Sistema ML Observability

> Esta sección documenta la arquitectura del sistema de detección de anomalías.

### Arquitectura ML

```text
Post-Carga → Calcular Features → Generar Alertas → Registrar en BD
```

### Features Calculados

| Feature | Tabla | Cálculo | Umbral |
|---------|-------|---------|--------|
| z_score_importe | costos | (importe - μ) / σ por obra | ±3 |
| percentil_importe | costos | Percentil 0-100 | - |
| es_outlier_estadistico | costos | \|z_score\| > 3 | Boolean |
| categoria_riesgo | costos | Clasificación por rango | LOW/MEDIUM/HIGH/CRITICAL |

### Tipos de Alertas

1. **OUTLIER_IMPORTE**: Importe con z-score > 3
2. **PROVEEDOR_NUEVO**: Primera factura > $5M
3. **TC_ANORMAL**: Variación tipo cambio > 5% diario
4. **DIAS_SIN_ACTIVIDAD**: Obra sin movimientos > 90 días

---

## 8. Configuración del Servidor de Producción

### 8.1 Prerequisitos Técnicos

**Validar ANTES de iniciar implementación:**

```bash
```

**Checklist automático:**

| Requisito | Versión Mínima | Comando Verificación |
|-----------|----------------|---------------------|
| Python | 3.9+ | `python --version` |
| pandas | 1.5+ | `pip show pandas` |
| pyodbc | 4.0+ | `pip show pyodbc` |
| openpyxl | 3.0+ | `pip show openpyxl` |
| psutil | 5.9+ | `pip show psutil` |
| SQL Server | 2019+ | `sqlcmd -Q "SELECT @@VERSION"` |
| Espacio disco | 50 GB | `Get-PSDrive C` |
| Memoria RAM | 16 GB | `(Get-CimInstance Win32_PhysicalMemory \| Measure-Object -Property capacity -Sum).sum /1gb` |


```bash
# Ejecutar en PowerShell como Administrador
pip install --upgrade pandas==2.1.4 pyodbc==5.0.1 openpyxl==3.1.2 psutil==5.9.6
```

### 8.2 Estructura de Directorios del Servidor

**Crear estructura base:**

```powershell
$raiz = "C:\DW_GrupoPOSE_B52"

$directorios = @(
    "$raiz\00_logs",
    "$raiz\00_logs\cargas",
    "$raiz\00_logs\ml",
    "$raiz\00_logs\validaciones",
    "$raiz\00_logs\errores",
    "$raiz\01_input_raw",
    "$raiz\03_output\reportes_auditoria",
    "$raiz\04_backups",
    "$raiz\05_documentacion"
)

foreach ($dir in $directorios) {
    New-Item -ItemType Directory -Path $dir -Force -ErrorAction SilentlyContinue
    Write-Host "✅ Creado: $dir" -ForegroundColor Green
}

Write-Host "`n✅ Estructura de directorios creada exitosamente" -ForegroundColor Green
```

**Ejecutar:**
```powershell
```

### 8.3 Archivo de Configuración Principal

**Archivo:** `C:\DW_GrupoPOSE_B52\config_produccion.json`

```json
{
  "version": "2.0.0",
  "ambiente": "PRODUCCION",
  "fecha_creacion": "2026-03-13",
  
  "servidor_sql": {
    "host": ".\\SQLEXPRESS",
    "base_datos_B52": "DW_GrupoPOSE_B52",
    "base_datos_A2_backup": "DW_GrupoPOSE_A2",
    "timeout_conexion_segundos": 30,
    "driver": "SQL Server",
    "autenticacion": "Windows",
    "usuario": "",
    "password": ""
  },
  
  "rutas": {
    "raiz_proyecto": "C:/DW_GrupoPOSE_B52",
    "logs": "C:/DW_GrupoPOSE_B52/00_logs",
    "input_raw": "C:/DW_GrupoPOSE_B52/01_input_raw",
    "output": "C:/DW_GrupoPOSE_B52/03_output",
    "backups": "C:/DW_GrupoPOSE_B52/04_backups"
  },
  
  "archivos_entrada": {
    "costos_B52": "C:/DW_GrupoPOSE_B52/01_input_raw/BaseCostosPOSE_B52.xlsx",
    "comprobantes_B52": "C:/DW_GrupoPOSE_B52/01_input_raw/ComprobantesPOSE_B52.xlsx",
    "gerencias": "C:/DW_GrupoPOSE_B52/01_input_raw/Gerencias.xlsx",
    "obras": "C:/DW_GrupoPOSE_B52/01_input_raw/Obras_Gerencias.xlsx",
    "proveedores": "C:/DW_GrupoPOSE_B52/01_input_raw/Proveedores.xlsx"
  },
  
  "parametros_carga": {
    "batch_size_costos": 5000,
    "batch_size_comprobantes": 3000,
    "timeout_carga_minutos": 30,
    "reintentos_max": 3,
    "pausa_entre_reintentos_segundos": 10,
    "habilitar_validacion_schema": true,
    "habilitar_idempotencia": true
  },
  
  "ml_observability": {
    "habilitar": true,
    "umbral_z_score_critico": 3.0,
    "umbral_alerta_importe_nuevo_proveedor": 5000000,
    "dias_inactividad_obra": 90,
    "ejecutar_post_carga": true
  },
  
  "logging": {
    "nivel": "INFO",
    "formato": "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    "rotacion_archivos": true,
    "max_size_mb": 50,
    "backups_antiguos": 30
  },
  
  "notificaciones": {
    "habilitar_email": false,
    "email_destino": "ops@example.com",
    "smtp_server": "",
    "smtp_port": 587,
    "habilitar_log_detallado": true
  },
  
  "seguridad": {
    "cifrar_credenciales": false,
    "validar_certificados_ssl": true,
    "auditoria_completa": true
  }
}
```


```python
import json
from pathlib import Path

def validar_config():
    """Valida que config_produccion.json sea válido"""
    config_path = Path("C:/DW_GrupoPOSE_B52/config_produccion.json")
    
    if not config_path.exists():
        raise FileNotFoundError(f"❌ No existe: {config_path}")
    
    with open(config_path, 'r', encoding='utf-8') as f:
        config = json.load(f)
    
    # Validar campos requeridos
    assert 'servidor_sql' in config, "❌ Falta sección 'servidor_sql'"
    assert 'rutas' in config, "❌ Falta sección 'rutas'"
    assert 'archivos_entrada' in config, "❌ Falta sección 'archivos_entrada'"
    
    print("✅ Configuración válida")
    return config

if __name__ == '__main__':
    validar_config()
```

### 8.4 Variables de Entorno

**Configurar en el servidor (opcional):**

```powershell
# Variables de entorno para seguridad (evita hardcodear credenciales)
[System.Environment]::SetEnvironmentVariable('DW_B52_CONNECTION_STRING', 
    'DRIVER={SQL Server};SERVER=.\\SQLEXPRESS;DATABASE=DW_GrupoPOSE_B52;Trusted_Connection=yes', 
    'Machine')

[System.Environment]::SetEnvironmentVariable('DW_B52_LOG_LEVEL', 'INFO', 'Machine')

[System.Environment]::SetEnvironmentVariable('DW_B52_CONFIG_PATH', 
    'C:\DW_GrupoPOSE_B52\config_produccion.json', 
    'Machine')

Write-Host "✅ Variables de entorno configuradas" -ForegroundColor Green
```

**Leer desde Python:**

```python
import os
import json

# Opción 1: Variable de entorno
config_path = os.getenv('DW_B52_CONFIG_PATH', 'C:/DW_GrupoPOSE_B52/config_produccion.json')

# Opción 2: Archivo de configuración
with open(config_path, 'r', encoding='utf-8') as f:
    config = json.load(f)

# Obtener connection string
conn_str = config['servidor_sql']
```

### 8.5 Permissions y Seguridad

**Permisos del usuario SQL Server:**

```sql
-- Ejecutar como sysadmin en SQL Server
USE master;
GO

-- Verificar usuario Windows actual tiene permisos
EXEC sp_helplogins @LoginNamePattern = 'DOMAIN\Username';

-- Si es necesario, crear login y asignar permisos
CREATE LOGIN [DOMAIN\Username] FROM WINDOWS;
GO

-- Permisos en B52
USE DW_GrupoPOSE_B52;
GO

CREATE USER [DOMAIN\Username] FOR LOGIN [DOMAIN\Username];
ALTER ROLE db_owner ADD MEMBER [DOMAIN\Username];  -- Solo para implementación inicial

-- Después de implementación, reducir a permisos mínimos:
-- ALTER ROLE db_datareader ADD MEMBER [DOMAIN\Username];
-- ALTER ROLE db_datawriter ADD MEMBER [DOMAIN\Username];
-- GRANT EXECUTE ON SCHEMA::AUDITORIA TO [DOMAIN\Username];
```

**Permisos del filesystem:**

```powershell
$ruta = "C:\DW_GrupoPOSE_B52"
$usuario = "$env:USERDOMAIN\$env:USERNAME"

$acl = Get-Acl $ruta
$regla = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $usuario, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
)
$acl.SetAccessRule($regla)
Set-Acl $ruta $acl

Write-Host "✅ Permisos asignados a $usuario en $ruta" -ForegroundColor Green
```

---

## 9. Power Query B52 - Configuración de Metadata

### 9.1 Objetivo

Crear consulta Power Query que **agregue las 3 columnas de metadata** necesarias para carga incremental:
- `anio_dato`: Año extraído de campo FECHA
- `mes_dato`: Mes extraído de campo FECHA (1-12)
- `periodo_codigo`: String concatenado "YYYYMM" (ej: "202603")

### 9.2 Ubicación del Archivo

**Archivo:** `BaseCostosPOSE_B52.xlsx`  
**Ubicación sugerida:** `C:\DW_GrupoPOSE_B52\01_input_raw\BaseCostosPOSE_B52.xlsx`  
**Alternativa:** OneDrive si se requiere acceso compartido

### 9.3 Código Power Query Completo

**Query Name:** `BaseCostosPOSE_B52_Query`

```powerquery
let
    // ============================================================
    // FUENTE: BaseCostoUnificada.xlsx (generado por AutomatizacionETL)
    // ============================================================
    Origen = Excel.Workbook(
        File.Contents("C:\Dev\ProyVS_CodeRick_2026\production\BaseCostoUnificada\BaseCostoUnificada.xlsx"), 
        null, 
        true
    ),
    
    // Seleccionar tabla consolidada
    Archiv_Consolidado_Final_Table = Origen{[Item="Archiv_Consolidado_Final",Kind="Table"]}[Data],
    
    // ============================================================
    // TIPADO INICIAL (IDÉNTICO A PIPELINE A2)
    // ============================================================
    #"Tipo cambiado" = Table.TransformColumnTypes(
        Archiv_Consolidado_Final_Table,
        {
            {"Name", type text}, 
            {"ID_UNICO", type text}, 
            {"OBRA_PRONTO", type text}, 
            {"FECHA", type date},               // ⚠️ CRÍTICO: debe ser tipo date
            {"IMPORTE", type number}, 
            {"TC", type number}, 
            {"IMPORTE_USD", type number}, 
            {"GERENCIA", type text}, 
            {"FUENTE", type text}, 
            {"PROVEEDOR", type text}, 
            {"NRO_COMPROBANTE", type text}, 
            {"TIPO_COMPROBANTE", type text}, 
            {"DESCRIPCION_OBRA", type text}, 
            {"DETALLE", type any}, 
            {"OBSERVACION", type text}, 
            {"RUBRO_CONTABLE", type text}, 
            {"CUENTA_CONTABLE", type text}, 
            {"CODIGO_CUENTA", Int64.Type}, 
            {"COMPENSABLE", type text}
        }
    ),
    
    // ============================================================
    // LIMPIEZA (IDÉNTICO A PIPELINE A2)
    // ============================================================
    #"Columnas quitadas" = Table.RemoveColumns(
        #"Tipo cambiado",
        {"Name", "ID_UNICO"}
    ),
    
    // ============================================================
    // ⭐ AGREGAR METADATOS B52 (DIFERENCIA CON A2) ⭐
    // ============================================================
    
    // 1. anio_dato (INT): Año de la fecha
    #"anio_dato agregado" = Table.AddColumn(
        #"Columnas quitadas", 
        "anio_dato", 
        each Date.Year([FECHA]), 
        Int64.Type
    ),
    
    // 2. mes_dato (INT): Mes de la fecha (1-12)
    #"mes_dato agregado" = Table.AddColumn(
        #"anio_dato agregado", 
        "mes_dato", 
        each Date.Month([FECHA]), 
        Int64.Type
    ),
    
    // 3. periodo_codigo (TEXT): Concatenación "YYYYMM"
    #"periodo_codigo agregado" = Table.AddColumn(
        #"mes_dato agregado", 
        "periodo_codigo", 
        each 
            Number.ToText(Date.Year([FECHA])) & 
            Text.PadStart(Number.ToText(Date.Month([FECHA])), 2, "0"), 
        type text
    ),
    
    // ============================================================
    // RESULTADO FINAL: 20 columnas (17 originales + 3 metadata)
    // ============================================================
    #"Output B52" = #"periodo_codigo agregado"
in
    #"Output B52"
```

### 9.4 Columnas del Output

**Total: 20 columnas**

| # | Columna | Tipo | Origen |
|---|---------|------|--------|
| 1 | OBRA_PRONTO | text | A2 |
| 2 | FECHA | date | A2 |
| 3 | IMPORTE | number | A2 |
| 4 | TC | number | A2 |
| 5 | IMPORTE_USD | number | A2 |
| 6 | GERENCIA | text | A2 |
| 7 | FUENTE | text | A2 |
| 8 | PROVEEDOR | text | A2 |
| 9 | NRO_COMPROBANTE | text | A2 |
| 10 | TIPO_COMPROBANTE | text | A2 |
| 11 | DESCRIPCION_OBRA | text | A2 |
| 12 | DETALLE | any | A2 |
| 13 | OBSERVACION | text | A2 |
| 14 | RUBRO_CONTABLE | text | A2 |
| 15 | CUENTA_CONTABLE | text | A2 |
| 16 | CODIGO_CUENTA | int64 | A2 |
| 17 | COMPENSABLE | text | A2 |
| 18 | **anio_dato** | int64 | **B52 ⭐** |
| 19 | **mes_dato** | int64 | **B52 ⭐** |
| 20 | **periodo_codigo** | text | **B52 ⭐** |

### 9.5 Validación del Query

**En Power Query Editor:**

```powerquery
// Agregar paso de validación al final
#"Validación B52" = 
    if List.Count(Table.ColumnNames(#"periodo_codigo agregado")) <> 20 
    then error "❌ Error: se esperan 20 columnas, encontradas: " & 
               Number.ToText(List.Count(Table.ColumnNames(#"periodo_codigo agregado")))
    else if not List.Contains(Table.ColumnNames(#"periodo_codigo agregado"), "anio_dato")
    then error "❌ Error: columna 'anio_dato' no encontrada"
    else if not List.Contains(Table.ColumnNames(#"periodo_codigo agregado"), "mes_dato")
    then error "❌ Error: columna 'mes_dato' no encontrada"
    else if not List.Contains(Table.ColumnNames(#"periodo_codigo agregado"), "periodo_codigo")
    then error "❌ Error: columna 'periodo_codigo' no encontrada"
    else #"periodo_codigo agregado"
```

### 9.6 Refresh del Archivo Excel

**Opción 1: Manual (Power Query Desktop)**

1. Abrir `BaseCostosPOSE_B52.xlsx` en Excel
2. Data → Refresh All
3. Guardar y cerrar

**Opción 2: Automatizado (PowerShell)**

```powershell
$excelPath = "C:\DW_GrupoPOSE_B52\01_input_raw\BaseCostosPOSE_B52.xlsx"

# Abrir Excel
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false

try {
    Write-Host "📊 Abriendo: $excelPath" -ForegroundColor Cyan
    $workbook = $excel.Workbooks.Open($excelPath)
    
    Write-Host "🔄 Refrescando consultas Power Query..." -ForegroundColor Cyan
    $workbook.RefreshAll()
    
    # Esperar a que termine refresh
    $excel.CalculateUntilAsyncQueriesDone()
    
    Write-Host "💾 Guardando cambios..." -ForegroundColor Cyan
    $workbook.Save()
    $workbook.Close()
    
    Write-Host "✅ Refresh completado exitosamente" -ForegroundColor Green
}
catch {
    Write-Host "❌ Error en refresh: $_" -ForegroundColor Red
    exit 1
}
finally {
    $excel.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
}
```

**Opción 3: Desde Python (usando win32com)**

```python
# Incluido en AutomatizacionETL
import win32com.client
import time

def refresh_power_query_B52(archivo_excel):
    """Refresca Power Query en archivo Excel"""
    excel = win32com.client.Dispatch("Excel.Application")
    excel.Visible = False
    excel.DisplayAlerts = False
    
    try:
        print(f"📊 Abriendo: {archivo_excel}")
        workbook = excel.Workbooks.Open(archivo_excel)
        
        print("🔄 Refrescando Power Query...")
        workbook.RefreshAll()
        excel.CalculateUntilAsyncQueriesDone()
        
        print("💾 Guardando...")
        workbook.Save()
        workbook.Close()
        
        print("✅ Refresh completado")
        return True
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return False
        
    finally:
        excel.Quit()
```

### 9.7 Ejemplo de Datos de Salida

```text
| OBRA_PRONTO | FECHA      | IMPORTE  | anio_dato | mes_dato | periodo_codigo |
|-------------|------------|----------|-----------|----------|----------------|
| G01-001     | 2026-03-15 | 125000.50| 2026      | 3        | 202603         |
| G02-045     | 2026-03-20 | 87500.00 | 2026      | 3        | 202603         |
| G01-002     | 2026-04-05 | 230000.75| 2026      | 4        | 202604         |
```

### 9.8 Troubleshooting

**Error: "Columna FECHA no es tipo date"**
```powerquery
// Solución: Forzar conversión
#"Fecha corregida" = Table.TransformColumns(
    #"Columnas quitadas",
    {{"FECHA", each Date.From(_), type date}}
)
```

**Error: "periodo_codigo tiene valores null"**
```powerquery
// Solución: Filtrar nulls antes de agregar metadata
#"Filas filtradas" = Table.SelectRows(
    #"Columnas quitadas", 
    each [FECHA] <> null
)
```

**Error: "Refresh muy lento (>10 min)"**
- Verificar que BaseCostoUnificada.xlsx no tenga >500K filas
- Considerar segmentar por período en fuente
- Deshabilitar caché de consultas si archivo es volátil

---


### 10.1 Validador de Prerequisitos


```python
"""
Validador de Prerequisitos para Implementación B52
Ejecutar ANTES de iniciar Fase 1
"""
import sys
import subprocess
import platform
from pathlib import Path
import pyodbc

def validar_python():
    """Valida versión de Python"""
    version = sys.version_info
    if version.major < 3 or (version.major == 3 and version.minor < 9):
        print(f"❌ Python {version.major}.{version.minor} detectado. Se requiere 3.9+")
        return False
    print(f"✅ Python {version.major}.{version.minor}.{version.micro}")
    return True

def validar_librerias():
    """Valida librerías Python requeridas"""
    librerias_requeridas = {
        'pandas': '1.5.0',
        'pyodbc': '4.0.0',
        'openpyxl': '3.0.0',
        'psutil': '5.9.0'
    }
    
    for lib, version_min in librerias_requeridas.items():
        try:
            resultado = subprocess.run(
                [sys.executable, '-m', 'pip', 'show', lib],
                capture_output=True, text=True
            )
            if resultado.returncode != 0:
                print(f"❌ {lib} no instalado")
                return False
            print(f"✅ {lib} instalado")
        except Exception as e:
            print(f"❌ Error verificando {lib}: {e}")
            return False
    return True

def validar_sql_server():
    """Valida conexión a SQL Server"""
    try:
        conn = pyodbc.connect(
            'DRIVER={SQL Server};SERVER=.\\SQLEXPRESS;Trusted_Connection=yes',
            timeout=10
        )
        cursor = conn.cursor()
        cursor.execute("SELECT @@VERSION")
        version = cursor.fetchone()[0]
        conn.close()
        
        print(f"✅ SQL Server accesible")
        print(f"   Versión: {version[:50]}...")
        return True
    except Exception as e:
        print(f"❌ No se puede conectar a SQL Server: {e}")
        return False

def validar_permisos_sql():
    """Valida permisos para crear base de datos"""
    try:
        conn = pyodbc.connect(
            'DRIVER={SQL Server};SERVER=.\\SQLEXPRESS;Trusted_Connection=yes'
        )
        cursor = conn.cursor()
        
        # Verificar si usuario puede crear BD
        cursor.execute("""
            SELECT HAS_PERMS_BY_NAME(NULL, NULL, 'CREATE DATABASE')
        """)
        tiene_permiso = cursor.fetchone()[0]
        conn.close()
        
        if tiene_permiso:
            print(f"✅ Usuario tiene permiso CREATE DATABASE")
            return True
        else:
            print(f"❌ Usuario NO tiene permiso CREATE DATABASE")
            return False
    except Exception as e:
        print(f"❌ Error verificando permisos: {e}")
        return False

def validar_espacio_disco():
    """Valida espacio disponible en disco C:"""
    import psutil
    disk = psutil.disk_usage('C:\\')
    gb_disponibles = disk.free / (1024**3)
    
    if gb_disponibles < 50:
        print(f"❌ Espacio insuficiente: {gb_disponibles:.1f} GB (se requieren 50 GB)")
        return False
    print(f"✅ Espacio en disco: {gb_disponibles:.1f} GB disponibles")
    return True

def validar_directorios():
    """Valida que estructura de directorios exista"""
    raiz = Path("C:/DW_GrupoPOSE_B52")
    dirs_requeridos = [
        "00_logs",
        "01_input_raw",
        "03_output"
    ]
    
    if not raiz.exists():
        print(f"❌ Directorio raíz no existe: {raiz}")
        print(f"   Ejecutar: 01_crear_estructura_directorios.ps1")
        return False
    
    for dir_rel in dirs_requeridos:
        dir_path = raiz / dir_rel
        if not dir_path.exists():
            print(f"❌ Falta directorio: {dir_path}")
            return False
    
    print(f"✅ Estructura de directorios completa")
    return True

def main():
    print("\n" + "="*70)
    print("🔍 VALIDADOR DE PREREQUISITOS - DW_GrupoPOSE_B52")
    print("="*70 + "\n")
    
    validaciones = [
        ("Python 3.9+", validar_python),
        ("Librerías Python", validar_librerias),
        ("SQL Server", validar_sql_server),
        ("Permisos SQL", validar_permisos_sql),
        ("Espacio en disco", validar_espacio_disco),
        ("Estructura directorios", validar_directorios)
    ]
    
    resultados = []
    for nombre, funcion in validaciones:
        print(f"\n🔹 Validando: {nombre}")
        resultado = funcion()
        resultados.append(resultado)
    
    print("\n" + "="*70)
    total = len(resultados)
    pasadas = sum(resultados)
    
    if pasadas == total:
        print(f"✅ TODAS las validaciones pasaron ({pasadas}/{total})")
        print("="*70)
        return 0
    else:
        fallidas = total - pasadas
        print(f"❌ {fallidas} validación(es) FALLARON ({pasadas}/{total})")
        print("="*70)
        print("\nCorregir los errores antes de continuar con Fase 1")
        return 1

if __name__ == '__main__':
    sys.exit(main())
```

### 10.2 Validador Fase 1


```python
"""
Valida que Fase 1 (Estructura BD) se completó correctamente
"""
import pyodbc
import sys

def validar_base_datos_existe():
    """Verifica que BD B52 existe"""
    try:
        conn = pyodbc.connect('DRIVER={SQL Server};SERVER=.\\SQLEXPRESS;Trusted_Connection=yes')
        cursor = conn.cursor()
        cursor.execute("SELECT name FROM sys.databases WHERE name = 'DW_GrupoPOSE_B52'")
        resultado = cursor.fetchone()
        conn.close()
        
        if resultado:
            print("✅ Base de datos DW_GrupoPOSE_B52 existe")
            return True
        else:
            print("❌ Base de datos DW_GrupoPOSE_B52 NO existe")
            return False
    except Exception as e:
        print(f"❌ Error verificando BD: {e}")
        return False

def validar_esquemas():
    """Verifica que todos los esquemas existen"""
    try:
        conn = pyodbc.connect(
            'DRIVER={SQL Server};SERVER=.\\SQLEXPRESS;DATABASE=DW_GrupoPOSE_B52;Trusted_Connection=yes'
        )
        cursor = cursor.execute("""
            SELECT name FROM sys.schemas 
            WHERE name IN ('CATALOGO','PRODUCCION','AUDITORIA','ML','TEMPORAL')
            ORDER BY name
        """)
        esquemas = [row[0] for row in cursor.fetchall()]
        conn.close()
        
        esperados = ['AUDITORIA', 'CATALOGO', 'ML', 'PRODUCCION', 'TEMPORAL']
        if esquemas == esperados:
            print(f"✅ {len(esquemas)} esquemas creados: {', '.join(esquemas)}")
            return True
        else:
            faltantes = set(esperados) - set(esquemas)
            print(f"❌ Esquemas faltantes: {faltantes}")
            return False
    except Exception as e:
        print(f"❌ Error verificando esquemas: {e}")
        return False

def validar_tablas_criticas():
    """Verifica que tablas críticas existen"""
    tablas_criticas = [
        'CATALOGO.gerencias',
        'CATALOGO.obras',
        'CATALOGO.proveedores',
        'CATALOGO.fuentes',
        'PRODUCCION.costos',
        'PRODUCCION.comprobantes',
        'AUDITORIA.log_cargas',
        'AUDITORIA.periodos_carga',
        'ML.historial_alertas'
    ]
    
    try:
        conn = pyodbc.connect(
            'DRIVER={SQL Server};SERVER=.\\SQLEXPRESS;DATABASE=DW_GrupoPOSE_B52;Trusted_Connection=yes'
        )
        cursor = conn.cursor()
        
        for tabla in tablas_criticas:
            schema, nombre = tabla.split('.')
            cursor.execute(f"""
                SELECT COUNT(*) FROM sys.tables t
                JOIN sys.schemas s ON t.schema_id = s.schema_id
                WHERE s.name = '{schema}' AND t.name = '{nombre}'
            """)
            existe = cursor.fetchone()[0] > 0
            
            if not existe:
                print(f"❌ Tabla faltante: {tabla}")
                conn.close()
                return False
        
        conn.close()
        print(f"✅ {len(tablas_criticas)} tablas críticas creadas")
        return True
        
    except Exception as e:
        print(f"❌ Error verificando tablas: {e}")
        return False

def validar_indices():
    """Verifica que índices críticos existen"""
    try:
        conn = pyodbc.connect(
            'DRIVER={SQL Server};SERVER=.\\SQLEXPRESS;DATABASE=DW_GrupoPOSE_B52;Trusted_Connection=yes'
        )
        cursor = conn.cursor()
        cursor.execute("""
            SELECT COUNT(*) FROM sys.indexes i
            JOIN sys.tables t ON i.object_id = t.object_id
            JOIN sys.schemas s ON t.schema_id = s.schema_id
            WHERE s.name = 'PRODUCCION' AND t.name = 'costos' 
              AND i.name = 'IX_costos_particion'
        """)
        tiene_indice_particion = cursor.fetchone()[0] > 0
        conn.close()
        
        if tiene_indice_particion:
            print("✅ Índice IX_costos_particion creado")
            return True
        else:
            print("❌ Índice IX_costos_particion faltante")
            return False
    except Exception as e:
        print(f"❌ Error verificando índices: {e}")
        return False

def main():
    print("\n" + "="*70)
    print("🔍 VALIDACIÓN FASE 1 - Estructura de Base de Datos")
    print("="*70 + "\n")
    
    validaciones = [
        validar_base_datos_existe,
        validar_esquemas,
        validar_tablas_criticas,
        validar_indices
    ]
    
    resultados = [val() for val in validaciones]
    
    print("\n" + "="*70)
    if all(resultados):
        print(f"✅ Fase 1 VALIDADA: {sum(resultados)}/{len(resultados)} checks pasados")
        print("="*70)
        return 0
    else:
        print(f"❌ Fase 1 FALLIDA: {sum(resultados)}/{len(resultados)} checks pasados")
        print("="*70)
        return 1

if __name__ == '__main__':
    sys.exit(main())
```

---

## 11. Procedimientos de Rollback y Recuperación

### 11.1 Rollback Completo a A2

**Situación:** B52 falla completamente, necesitas volver a operar con A2.


```powershell
# ============================================================================
# ROLLBACK COMPLETO: Restaurar Operación en A2
# ============================================================================

Write-Host "`n============================================================" -ForegroundColor Yellow
Write-Host "🔄 INICIANDO ROLLBACK COMPLETO A DW_GrupoPOSE_A2" -ForegroundColor Yellow
Write-Host "============================================================`n" -ForegroundColor Yellow

# 1. Verificar que A2 está operativa
Write-Host "📋 Paso 1: Verificando estado de A2..." -ForegroundColor Cyan
$queryTest = "SELECT COUNT(*) FROM PRODUCCION.costos"
$resultadoA2 = sqlcmd -S ".\SQLEXPRESS" -d "DW_GrupoPOSE_A2" -Q $queryTest -h -1

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ ERROR CRÍTICO: A2 no está operativa" -ForegroundColor Red
    Write-Host "No se puede hacer rollback. Contactar DBA urgentemente." -ForegroundColor Red
    exit 1
}

Write-Host "✅ A2 está operativa: $resultadoA2 registros en costos" -ForegroundColor Green

# 2. Crear backup de B52 (por si se necesita investigar)
Write-Host "`n📋 Paso 2: Creando backup de B52..." -ForegroundColor Cyan
$backupPath = "C:\DW_GrupoPOSE_B52\04_backups\DW_GrupoPOSE_B52_ROLLBACK_$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"

$backupQuery = @"
BACKUP DATABASE [DW_GrupoPOSE_B52] 
TO DISK = '$backupPath'
WITH FORMAT, INIT, SKIP, NOREWIND, NOUNLOAD, STATS = 10;
"@

sqlcmd -S ".\SQLEXPRESS" -Q $backupQuery

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Backup B52 creado: $backupPath" -ForegroundColor Green
} else {
    Write-Host "⚠️  Warning: No se pudo crear backup de B52" -ForegroundColor Yellow
}

# 3. Apuntar aplicaciones/reportes a A2 (actualizar connection strings)
Write-Host "`n📋 Paso 3: Redirigiendo conexiones a A2..." -ForegroundColor Cyan

# Actualizar archivo de configuración (si existe)
$configPath = "C:\DW_GrupoPOSE_B52\config_produccion.json"
if (Test-Path $configPath) {
    $config = Get-Content $configPath | ConvertFrom-Json
    $config.servidor_sql.base_datos_activa = "DW_GrupoPOSE_A2"
    $config.servidor_sql.usar_B52 = $false
    $config.servidor_sql.rollback_activado = $true
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath
    
    Write-Host "✅ Configuración actualizada para usar A2" -ForegroundColor Green
} else {
    Write-Host "⚠️  Archivo configuración no encontrado: $configPath" -ForegroundColor Yellow
}


} else {
}

# 5. Registrar rollback en log
Write-Host "`n📋 Paso 5: Registrando rollback en auditoría..." -ForegroundColor Cyan
$logEntry = @"
INSERT INTO AUDITORIA.log_cargas 
(tabla_destino, archivo_origen, estado, observaciones, fecha_carga) 
VALUES 
('ROLLBACK_A2', 'OPERACION_MANUAL', 'ROLLBACK_EJECUTADO',
 'Rollback completo a A2 ejecutado desde PowerShell. B52 deshabilitado.',
 GETDATE());
"@

sqlcmd -S ".\SQLEXPRESS" -d "DW_GrupoPOSE_A2" -Q $logEntry

# 6. Resumen final
Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "✅ ROLLBACK COMPLETADO EXITOSAMENTE" -ForegroundColor Green
Write-Host "============================================================`n" -ForegroundColor Green
Write-Host "Estado actual:" -ForegroundColor Cyan
Write-Host "  • Sistema activo: DW_GrupoPOSE_A2" -ForegroundColor White
Write-Host "  • Backup B52: $backupPath" -ForegroundColor White
Write-Host "`nPróximos pasos:" -ForegroundColor Cyan
Write-Host "  1. Investigar causa de fallo en B52" -ForegroundColor White
Write-Host "  2. Corregir problemas identificados" -ForegroundColor White
Write-Host "  3. Re-testear B52 en ambiente de prueba" -ForegroundColor White
Write-Host "  4. Cuando esté estable, ejecutar restauración a B52`n" -ForegroundColor White

exit 0
```

### 11.2 Rollback Parcial (Solo Período Específico)

**Situación:** Una carga incremental específica falló, necesitas revertir solo ese período.


```python
"""
Rollback de período específico en B52
"""
import argparse
import pyodbc
from datetime import datetime
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def rollback_costos_periodo(conn, anio, mes, periodo_codigo):
    """Rollback de período mensual en PRODUCCION.costos"""
    cursor = conn.cursor()
    
    # 1. Verificar si El período existe
    cursor.execute("""
        SELECT COUNT(*) FROM PRODUCCION.costos 
        WHERE anio_dato = ? AND mes_dato = ?
    """, (anio, mes))
    count_actual = cursor.fetchone()[0]
    
    if count_actual == 0:
        logging.warning(f"⚠️  Período {periodo_codigo} ya está vacío (0 registros)")
        return 0
    
    logging.info(f"📊 Período {periodo_codigo} tiene {count_actual:,} registros")
    
    # 2. Borrar registros del período
    logging.info(f"🗑️  Borrando registros de {periodo_codigo}...")
    cursor.execute("""
        DELETE FROM PRODUCCION.costos 
        WHERE anio_dato = ? AND mes_dato = ?
    """, (anio, mes))
    
    registros_borrados = cursor.rowcount
    
    # 3. Registrar rollback en auditoría
    cursor.execute("""
        INSERT INTO AUDITORIA.periodos_carga 
        (tabla_destino, tipo_particion, anio, mes, periodo_codigo, 
         registros_borrados, registros_insertados, estado, observaciones, usuario_carga)
        VALUES 
        (?, ?, ?, ?, ?, ?, 0, 'ROLLBACK_MANUAL', ?, ?)
    """, ('PRODUCCION.costos', 'MENSUAL', anio, mes, periodo_codigo, 
    
    conn.commit()
    
    logging.info(f"✅ Rollback completado: {registros_borrados:,} registros borrados")
    return registros_borrados

def rollback_comprobantes_anio(conn, anio):
    """Rollback de año completo en PRODUCCION.comprobantes"""
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT COUNT(*) FROM PRODUCCION.comprobantes WHERE anio_dato = ?
    """, (anio,))
    count_actual = cursor.fetchone()[0]
    
    if count_actual == 0:
        logging.warning(f"⚠️  Año {anio} ya está vacío (0 registros)")
        return 0
    
    logging.info(f"📊 Año {anio} tiene {count_actual:,} registros")
    logging.info(f"🗑️  Borrando registros de {anio}...")
    
    cursor.execute("""
        DELETE FROM PRODUCCION.comprobantes WHERE anio_dato = ?
    """, (anio,))
    
    registros_borrados = cursor.rowcount
    
    cursor.execute("""
        INSERT INTO AUDITORIA.periodos_carga 
        (tabla_destino, tipo_particion, anio, mes, periodo_codigo, 
         registros_borrados, registros_insertados, estado, observaciones, usuario_carga)
        VALUES 
        (?, ?, ?, NULL, ?, ?, 0, 'ROLLBACK_MANUAL', ?, ?)
    """, ('PRODUCCION.comprobantes', 'ANUAL', anio, str(anio), 
    
    conn.commit()
    
    logging.info(f"✅ Rollback completado: {registros_borrados:,} registros borrados")
    return registros_borrados

def main():
    parser.add_argument('--tabla', required=True, choices=['costos', 'comprobantes'],
                       help='Tabla destino (costos o comprobantes)')
    parser.add_argument('--periodo', help='Período mensual YYYYMM (para costos)')
    parser.add_argument('--anio', type=int, help='Año YYYY (para comprobantes)')
    
    args = parser.parse_args()
    
    print("\n" + "="*70)
    print("🔄 ROLLBACK DE PERÍODO - DW_GrupoPOSE_B52")
    print("="*70 + "\n")
    
    # Conectar a BD
    conn = pyodbc.connect(
        'DRIVER={SQL Server};SERVER=.\\SQLEXPRESS;DATABASE=DW_GrupoPOSE_B52;Trusted_Connection=yes'
    )
    
    try:
        if args.tabla == 'costos':
            if not args.periodo or len(args.periodo) != 6:
                print("❌ Error: --periodo requerido para costos (formato: YYYYMM)")
                return 1
            
            anio = int(args.periodo[:4])
            mes = int(args.periodo[4:])
            
            logging.info(f"🎯 Tabla: PRODUCCION.costos")
            logging.info(f"📅 Período: {args.periodo} (anio={anio}, mes={mes})")
            
            borrados = rollback_costos_periodo(conn, anio, mes, args.periodo)
            
        elif args.tabla == 'comprobantes':
            if not args.anio:
                print("❌ Error: --anio requerido para comprobantes")
                return 1
            
            logging.info(f"🎯 Tabla: PRODUCCION.comprobantes")
            logging.info(f"📅 Año: {args.anio}")
            
            borrados = rollback_comprobantes_anio(conn, args.anio)
        
        print("\n" + "="*70)
        print(f"✅ ROLLBACK EXITOSO: {borrados:,} registros borrados")
        print("="*70 + "\n")
        return 0
        
    except Exception as e:
        logging.error(f"❌ Error durante rollback: {e}")
        conn.rollback()
        return 1
    finally:
        conn.close()

if __name__ == '__main__':
    import sys
    sys.exit(main())
```

**Uso:**
```bash
# Rollback período mensual de costos

# Rollback año completo de comprobantes
```

### 11.3 Restauración desde Backup

**Situación:** Base de datos B52 corrupta, necesitas restaurar desde backup.

```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$BackupFile
)

Write-Host "`n🔄 Restaurando DW_GrupoPOSE_B52 desde backup..." -ForegroundColor Cyan
Write-Host "Backup: $BackupFile`n" -ForegroundColor White

if (-not (Test-Path $BackupFile)) {
    Write-Host "❌ Archivo de backup no existe: $BackupFile" -ForegroundColor Red
    exit 1
}

# 1. Cerrar conexiones activas
sqlcmd -S ".\SQLEXPRESS" -Q @"
ALTER DATABASE [DW_GrupoPOSE_B52] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
"@

# 2. Restaurar backup
$restoreQuery = @"
RESTORE DATABASE [DW_GrupoPOSE_B52] 
FROM DISK = '$BackupFile'
WITH REPLACE, RECOVERY;
"@

sqlcmd -S ".\SQLEXPRESS" -Q $restoreQuery

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Restauración completada exitosamente" -ForegroundColor Green
    
    # 3. Volver a modo multi-usuario
    sqlcmd -S ".\SQLEXPRESS" -Q @"
    ALTER DATABASE [DW_GrupoPOSE_B52] SET MULTI_USER;
"@
    
    exit 0
} else {
    Write-Host "❌ Error en restauración" -ForegroundColor Red
    exit 1
}
```

---

## 12. Testing y Validación

### Suite de Tests de Integración


```python
"""
Test Suite para validar carga incremental B52
"""
import pandas as pd
import pyodbc
from datetime import datetime

def test_carga_mensual_costos():
    """Test: cargar período mensual y verificar idempotencia"""
    print("\n🧪 TEST 1: Carga Mensual Costos - Idempotencia")
    
    # Ejecutar carga
    import subprocess
    resultado = subprocess.run([
    ], capture_output=True, text=True)
    
    assert resultado.returncode == 0, "Carga falló"
    
    # Verificar volumetría
    conn = pyodbc.connect('DRIVER={SQL Server};SERVER=.\\SQLEXPRESS;DATABASE=DW_GrupoPOSE_B52')
    query = "SELECT COUNT(*) FROM PRODUCCION.costos WHERE anio_dato=2026 AND mes_dato=3"
    count_1 = pd.read_sql(query, conn).iloc[0,0]
    
    # Re-ejecutar (idempotencia)
    resultado2 = subprocess.run([
    ], capture_output=True, text=True)
    
    count_2 = pd.read_sql(query, conn).iloc[0,0]
    
    assert count_1 == count_2, f"Idempotencia fallada: {count_1} != {count_2}"
    print(f"   ✅ Idempotencia OK: {count_1} registros consistentes")
    
    conn.close()

def test_ml_features():
    """Test: calcular z-scores y verificar alertas"""
    print("\n🧪 TEST 2: ML Features - Z-scores y Alertas")
    
    # Ejecutar cálculo de ML
    import subprocess
    resultado = subprocess.run([
    ], capture_output=True, text=True)
    
    assert resultado.returncode == 0, "Cálculo ML falló"
    
    # Verificar z-scores calculados
    conn = pyodbc.connect('DRIVER={SQL Server};SERVER=.\\SQLEXPRESS;DATABASE=DW_GrupoPOSE_B52')
    query = "SELECT COUNT(*) FROM PRODUCCION.costos WHERE z_score_importe IS NOT NULL"
    count_z = pd.read_sql(query, conn).iloc[0,0]
    
    assert count_z > 0, "No se calcularon z-scores"
    print(f"   ✅ Z-scores calculados: {count_z} registros")
    
    # Generar alertas
    resultado2 = subprocess.run([
    ], capture_output=True, text=True)
    
    query_alertas = "SELECT COUNT(*) FROM ML.historial_alertas"
    count_alertas = pd.read_sql(query_alertas, conn).iloc[0,0]
    
    print(f"   ℹ️  Alertas generadas: {count_alertas}")
    
    conn.close()

if __name__ == '__main__':
    test_carga_mensual_costos()
    test_ml_features()
    print("\n✅ TODOS LOS TESTS PASARON")
```

---

## 13. Anexos

### A. Timeline de Implementación

| Semana | Fase | Entregable | Horas Est. |
|--------|------|------------|------------|
| 1 | Preparación BD | Estructura completa B52 creada | 16h |
| 5 | ML Observability | Detección anomalías funcionando | 24h |
| 6 | Utilidades | Auditoría y métricas completas | 16h |
| 7 | Testing | Suite de tests aprobada | 20h |
| 8 | Documentación | Manuales y despliegue | 12h |
| **TOTAL** | | | **148 horas** |

### B. Checklist de Entrega

**Infraestructura:**
- [ ] Base de datos B52 creada en SQL Server
- [ ] Esquemas CATALOGO, PRODUCCION, AUDITORIA, ML, TEMPORAL
- [ ] Índices optimizados para particionamiento
- [ ] Tabla calendario poblada (2019-2030)
- [ ] Fuentes iniciales cargadas


**Utilidades:**

**Testing:**
- [ ] Suite de tests de integración
- [ ] Tests de idempotencia
- [ ] Tests de ML features
- [ ] Validación de rendimiento

**Documentación:**
- [ ] Manual de Operación B52
- [ ] Guía de Despliegue
- [ ] Troubleshooting común
- [ ] Plan de rollback a A2

### C. Contactos y Responsables

| Rol | Responsable | Contacto |
|-----|-------------|----------|
| **Arquitecto BD** | Richard | richard@example.com |
| **Desarrollador ETL** | Richard | - |
| **Operador Cargas** | TBD | - |
| **Revisor Testing** | TBD | - |

### D. Riesgos y Mitigaciones

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| Fallo en BD B52 | Media | Alto | Mantener A2 operativa como respaldo |
| Datos inconsistentes | Baja | Alto | Tests exhaustivos pre-despliegue |
| Performance degradado | Media | Medio | Índices optimizados + monitoreo |
| Alertas ML incorrectas | Alta | Bajo | Revisión manual de alertas críticas |

---

**FIN DEL PLAN MAESTRO DW_GrupoPOSE_B52 v2.0**

**Optimizado para Ejecución por GitHub Copilot**

Documento completo actualizado:
- **Versión:** 2.0  
- **Líneas:** 3,500+ (expandido desde 2,368)
- **Nuevas secciones:** 7 (0, 6, 7, 8, 9, 10, 11)
- **Fecha actualización:** 13 de marzo de 2026  
- **Autor:** Richard + GitHub Copilot  
- **Listo para:** Implementación en servidor de producción

**Cambios principales v2.0:**
- ✅ Sección 0: Instrucciones completas para agente IA ejecutor
- ✅ Sección 8: Configuración del servidor de producción
- ✅ Sección 9: Power Query B52 con código M completo
- ✅ Sección 11: Procedimientos de rollback y recuperación
- ✅ Fase 2.1 actualizada: Metadata viene de Power Query (no Python)
- ✅ Formato de reportes JSON para tracking de progreso
- ✅ Manejo de errores estructurado con clasificación
- ✅ Validaciones post-fase obligatorias

