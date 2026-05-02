-- ============================================================================
-- DW_GrupoPOSE_B52 - MASTER SCRIPT PARA POSTGRESQL 16
-- Fecha: 29 de abril de 2026
-- ============================================================================

-- 1. ESQUEMAS
CREATE SCHEMA IF NOT EXISTS catalogo;
CREATE SCHEMA IF NOT EXISTS produccion;
CREATE SCHEMA IF NOT EXISTS auditoria;
CREATE SCHEMA IF NOT EXISTS temporal;
CREATE SCHEMA IF NOT EXISTS ml;

-- 2. CATALOGO: DIMENSIONES
CREATE TABLE IF NOT EXISTS catalogo.gerencias (
    id_gerencia SERIAL PRIMARY KEY,
    codigo_gerencia VARCHAR(50) UNIQUE NOT NULL,
    nombre_gerencia VARCHAR(400) NOT NULL,
    activo BOOLEAN DEFAULT TRUE,
    fecha_alta TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_baja TIMESTAMP NULL
);

CREATE TABLE IF NOT EXISTS catalogo.obras (
    id_obra SERIAL PRIMARY KEY,
    obra_pronto VARCHAR(50) UNIQUE NOT NULL,
    descripcion_obra VARCHAR(600) NOT NULL,
    id_gerencia INT REFERENCES catalogo.gerencias(id_gerencia),
    activo BOOLEAN DEFAULT TRUE,
    fecha_alta TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_baja TIMESTAMP NULL
);

CREATE TABLE IF NOT EXISTS catalogo.proveedores (
    id_proveedor BIGSERIAL PRIMARY KEY,
    cuit VARCHAR(20) UNIQUE,
    nombre_proveedor VARCHAR(600) NOT NULL,
    nombre_proveedor_norm VARCHAR(600) NOT NULL,
    codigo_proveedor VARCHAR(100),
    categoria VARCHAR(50),
    tipo_entidad VARCHAR(20),
    es_proveedor_ff BOOLEAN DEFAULT FALSE,
    frecuencia_transaccional VARCHAR(20),
    total_facturado_historico DECIMAL(18,2) DEFAULT 0,
    activo BOOLEAN DEFAULT TRUE,
    fecha_alta TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_baja TIMESTAMP NULL,
    fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    usuario_carga VARCHAR(200)
);

CREATE INDEX IF NOT EXISTS ix_proveedores_nombre_norm ON catalogo.proveedores(nombre_proveedor_norm);
CREATE INDEX IF NOT EXISTS ix_proveedores_categoria ON catalogo.proveedores(categoria);
CREATE INDEX IF NOT EXISTS ix_proveedores_cuit ON catalogo.proveedores(cuit) WHERE cuit IS NOT NULL;

CREATE TABLE IF NOT EXISTS catalogo.fuentes (
    id_fuente SERIAL PRIMARY KEY,
    codigo_fuente VARCHAR(50) UNIQUE NOT NULL,
    nombre_fuente VARCHAR(200) NOT NULL,
    descripcion VARCHAR(500),
    tipo_movimiento VARCHAR(10) CHECK (tipo_movimiento IN ('INGRESO','EGRESO','MIXTO')),
    es_automatica BOOLEAN DEFAULT FALSE,
    prioridad_carga INT DEFAULT 100,
    activo BOOLEAN DEFAULT TRUE,
    fecha_alta TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_baja TIMESTAMP NULL
);

CREATE TABLE IF NOT EXISTS catalogo.jerarquia_org (
    id_jerarquia SERIAL PRIMARY KEY,
    codigo_jerarquia VARCHAR(50) UNIQUE NOT NULL,
    taller_region VARCHAR(100),
    unidad_temporal VARCHAR(100),
    codigo_centro_costo VARCHAR(50),
    id_gerencia INT REFERENCES catalogo.gerencias(id_gerencia),
    empresa VARCHAR(20),
    nivel_organizativo INT,
    activo BOOLEAN DEFAULT TRUE,
    fecha_alta TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS ix_jerarquia_gerencia ON catalogo.jerarquia_org(id_gerencia);

CREATE TABLE IF NOT EXISTS catalogo.calendario (
    fecha DATE PRIMARY KEY,
    anio INT NOT NULL,
    mes INT NOT NULL,
    dia INT NOT NULL,
    nombre_mes VARCHAR(20) NOT NULL,
    trimestre INT NOT NULL,
    semestre INT NOT NULL,
    dia_semana INT NOT NULL,
    nombre_dia_semana VARCHAR(20) NOT NULL,
    es_fin_semana BOOLEAN NOT NULL,
    semana_anio INT NOT NULL
);

-- 3. AUDITORIA: LOG BASE
CREATE TABLE IF NOT EXISTS auditoria.log_cargas (
    id_log_carga BIGSERIAL PRIMARY KEY,
    tabla_destino VARCHAR(100) NOT NULL,
    archivo_origen VARCHAR(500) NOT NULL,
    registros_procesados INT DEFAULT 0,
    registros_insertados INT DEFAULT 0,
    registros_rechazados INT DEFAULT 0,
    fecha_carga TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    usuario_carga VARCHAR(200),
    estado VARCHAR(50) DEFAULT 'PENDIENTE',
    observaciones TEXT
);

-- 4. PRODUCCION: HECHOS CON ML OBSERVABILITY
CREATE TABLE IF NOT EXISTS produccion.costos (
    id_costo BIGSERIAL PRIMARY KEY,
    id_log_carga BIGINT NOT NULL REFERENCES auditoria.log_cargas(id_log_carga),
    obra_pronto VARCHAR(50) NOT NULL,
    fecha DATE NOT NULL,
    proveedor_id BIGINT,
    fuente_id INT,
    importe DECIMAL(18,2),
    tipo_cambio DECIMAL(10,6),
    importe_usd DECIMAL(18,2),
    nombre_proveedor VARCHAR(600),
    nombre_proveedor_norm VARCHAR(600),
    tipo_comprobante VARCHAR(200),
    numero_comprobante VARCHAR(200),
    numero_comprobante_norm VARCHAR(200),
    observacion TEXT,
    detalle VARCHAR(1000),
    taller_reg VARCHAR(400),
    ut_otros VARCHAR(400),
    rubro_contable VARCHAR(100),
    cuenta_contable VARCHAR(400),
    codigo_cuenta VARCHAR(100),
    compensable VARCHAR(100),
    fuente VARCHAR(100),
    descripcion_obra VARCHAR(600),
    gerencia VARCHAR(400),
    anio_dato INT NOT NULL,
    mes_dato INT NOT NULL,
    z_score_importe DECIMAL(10,6),
    percentil_importe INT,
    dias_desde_ultima_carga INT,
    es_outlier_estadistico BOOLEAN DEFAULT FALSE,
    es_valor_inusual BOOLEAN DEFAULT FALSE,
    categoria_riesgo VARCHAR(20),
    archivo_origen VARCHAR(510) NOT NULL,
    fila_excel INT,
    fecha_carga TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    usuario_carga VARCHAR(200)
);

CREATE INDEX IF NOT EXISTS ix_costos_particion ON produccion.costos (anio_dato, mes_dato, fecha);
CREATE INDEX IF NOT EXISTS ix_costos_obra ON produccion.costos (obra_pronto, anio_dato, mes_dato);
CREATE INDEX IF NOT EXISTS ix_costos_ml ON produccion.costos (categoria_riesgo, es_outlier_estadistico) WHERE es_outlier_estadistico = TRUE;
CREATE INDEX IF NOT EXISTS ix_costos_proveedor ON produccion.costos (proveedor_id, anio_dato, mes_dato);

CREATE TABLE IF NOT EXISTS produccion.comprobantes (
    id_comprobante BIGSERIAL PRIMARY KEY,
    id_log_carga BIGINT NOT NULL REFERENCES auditoria.log_cargas(id_log_carga),
    obra_pronto VARCHAR(50),
    fecha_comprobante DATE NOT NULL,
    proveedor_id BIGINT,
    numero_comprobante VARCHAR(200) NOT NULL,
    numero_comprobante_norm VARCHAR(200) NOT NULL,
    cod_proveedor VARCHAR(100),
    nombre_proveedor VARCHAR(600),
    nombre_proveedor_norm VARCHAR(600),
    importe DECIMAL(18,2) NOT NULL,
    tipo_comprobante VARCHAR(10),
    proveedor_ff VARCHAR(200),
    cuenta_contable VARCHAR(100),
    fecha_vto DATE,
    tc DECIMAL(10,6),
    moneda VARCHAR(10),
    observacion VARCHAR(500),
    anio_dato INT NOT NULL,
    archivo_origen VARCHAR(510) NOT NULL,
    hoja_origen VARCHAR(200),
    fila_excel INT,
    fecha_carga TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    usuario_carga VARCHAR(200)
);

CREATE INDEX IF NOT EXISTS ix_comprobantes_particion ON produccion.comprobantes (anio_dato, fecha_comprobante);
CREATE INDEX IF NOT EXISTS ix_comprobantes_obra ON produccion.comprobantes (obra_pronto, anio_dato);
CREATE INDEX IF NOT EXISTS ix_comprobantes_numero_norm ON produccion.comprobantes (numero_comprobante_norm);

-- 5. AUDITORIA: CONTROL AVANZADO
CREATE TABLE IF NOT EXISTS auditoria.periodos_carga (
    id_periodo_carga BIGSERIAL PRIMARY KEY,
    tabla_destino VARCHAR(100) NOT NULL,
    tipo_particion VARCHAR(20) NOT NULL,
    anio INT NOT NULL,
    mes INT NULL,
    periodo_codigo VARCHAR(10) NOT NULL,
    registros_borrados INT DEFAULT 0,
    registros_insertados INT DEFAULT 0,
    fecha_inicio_carga TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_fin_carga TIMESTAMP,
    duracion_segundos DECIMAL(10,2),
    velocidad_registros_seg DECIMAL(10,2),
    estado VARCHAR(20) DEFAULT 'EN_PROCESO',
    observaciones TEXT,
    usuario_carga VARCHAR(200)
);
CREATE INDEX IF NOT EXISTS ix_periodos_tabla_fecha ON auditoria.periodos_carga (tabla_destino, anio, mes);

CREATE TABLE IF NOT EXISTS auditoria.metricas_rendimiento (
    id_metrica BIGSERIAL PRIMARY KEY,
    id_log_carga BIGINT REFERENCES auditoria.log_cargas(id_log_carga),
    id_periodo_carga BIGINT REFERENCES auditoria.periodos_carga(id_periodo_carga),
    fase_proceso VARCHAR(50) NOT NULL,
    tiempo_inicio TIMESTAMP NOT NULL,
    tiempo_fin TIMESTAMP NOT NULL,
    duracion_milisegundos INT,
    memoria_usada_mb DECIMAL(10,2),
    cpu_porcentaje DECIMAL(5,2),
    registros_procesados INT,
    observaciones VARCHAR(500)
);

CREATE TABLE IF NOT EXISTS auditoria.rechazos (
    id_rechazo BIGSERIAL PRIMARY KEY,
    id_log_carga BIGINT NOT NULL REFERENCES auditoria.log_cargas(id_log_carga),
    fila_excel INT,
    motivo_rechazo TEXT NOT NULL,
    datos_rechazo TEXT,
    fecha_rechazo TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS ix_rechazos_log ON auditoria.rechazos (id_log_carga, fecha_rechazo);

-- 6. ML: MACHINE LEARNING OBSERVABILITY
CREATE TABLE IF NOT EXISTS ml.parametros_calidad (
    id_parametro BIGSERIAL PRIMARY KEY,
    entidad_tipo VARCHAR(20) NOT NULL,
    entidad_id VARCHAR(100) NOT NULL,
    metrica VARCHAR(50) NOT NULL,
    valor_medio DECIMAL(18,2),
    desviacion_estandar DECIMAL(18,2),
    valor_min DECIMAL(18,2),
    valor_max DECIMAL(18,2),
    percentil_25 DECIMAL(18,2),
    percentil_50 DECIMAL(18,2),
    percentil_75 DECIMAL(18,2),
    registros_muestra INT,
    fecha_calculo TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS ix_parametros_entidad ON ml.parametros_calidad(entidad_tipo, entidad_id);

CREATE TABLE IF NOT EXISTS ml.umbrales_alertas (
    id_umbral SERIAL PRIMARY KEY,
    tipo_alerta VARCHAR(50) UNIQUE NOT NULL,
    campo_medicion VARCHAR(100) NOT NULL,
    valor_min DECIMAL(18,2),
    valor_max DECIMAL(18,2),
    porcentaje_variacion_permitido DECIMAL(5,2),
    severidad_default VARCHAR(20) DEFAULT 'WARNING',
    activo BOOLEAN DEFAULT TRUE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS ml.historial_alertas (
    id_alerta BIGSERIAL PRIMARY KEY,
    fecha_generacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    tipo_alerta VARCHAR(50) NOT NULL,
    severidad VARCHAR(20) NOT NULL,
    tabla_origen VARCHAR(100),
    id_registro_origen BIGINT,
    descripcion TEXT NOT NULL,
    valor_detectado VARCHAR(200),
    valor_esperado VARCHAR(200),
    accion_tomada VARCHAR(50),
    estado VARCHAR(20) DEFAULT 'ACTIVA',
    usuario_resolucion VARCHAR(200),
    fecha_resolucion TIMESTAMP
);
CREATE INDEX IF NOT EXISTS ix_alertas_fecha_tipo ON ml.historial_alertas(fecha_generacion, tipo_alerta, severidad);

CREATE TABLE IF NOT EXISTS ml.anomalias_detectadas (
    id_anomalia BIGSERIAL PRIMARY KEY,
    tabla_origen VARCHAR(100) NOT NULL,
    id_registro_origen BIGINT NOT NULL,
    tipo_anomalia VARCHAR(50) NOT NULL,
    score_anomalia DECIMAL(10,6),
    descripcion TEXT,
    fecha_deteccion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    revisada BOOLEAN DEFAULT FALSE,
    es_anomalia_real BOOLEAN
);

-- 7. TEMPORAL: STAGING
CREATE TABLE IF NOT EXISTS temporal.costos_carga (
    id_costo_temp BIGSERIAL PRIMARY KEY,
    obra_pronto VARCHAR(50),
    fecha DATE,
    importe DECIMAL(18,2),
    tipo_cambio DECIMAL(10,6),
    importe_usd DECIMAL(18,2),
    nombre_proveedor VARCHAR(600),
    tipo_comprobante VARCHAR(200),
    numero_comprobante VARCHAR(200),
    observacion TEXT,
    taller_reg VARCHAR(400),
    ut_otros VARCHAR(400),
    rubro_contable VARCHAR(100),
    cuenta_contable VARCHAR(400),
    codigo_cuenta VARCHAR(100),
    compensable VARCHAR(100),
    fuente VARCHAR(100),
    descripcion_obra VARCHAR(600),
    gerencia VARCHAR(400),
    fila_excel INT
);

CREATE TABLE IF NOT EXISTS temporal.comprobantes_carga (
    id_comprobante_temp BIGSERIAL PRIMARY KEY,
    obra_pronto VARCHAR(50),
    numero_comprobante VARCHAR(200),
    fecha_comprobante DATE,
    cod_proveedor VARCHAR(100),
    nombre_proveedor VARCHAR(600),
    importe DECIMAL(18,2),
    hoja_origen VARCHAR(200),
    fila_excel INT,
    tipo_comprobante VARCHAR(10),
    proveedor_ff VARCHAR(200),
    cuenta_contable VARCHAR(100),
    fecha_vto DATE,
    tc DECIMAL(10,6),
    moneda VARCHAR(10),
    observacion VARCHAR(500)
);

-- 8. POBLADO DE REFERENCIAS INICIALES
INSERT INTO catalogo.fuentes (codigo_fuente, nombre_fuente, descripcion, tipo_movimiento, es_automatica, prioridad_carga)
VALUES
    ('COSTOS_PRONTONET', 'Costos ProntoNet',         'Costos extraídos de ProntoNet - archivo mensual',  'EGRESO',  FALSE, 10),
    ('COMPROBANTES_PN',  'Comprobantes ProntoNet',   'Comprobantes extraídos de ProntoNet - por año',  'EGRESO',  FALSE, 20),
    ('CATALOGO_OBRAS',   'Catálogo de Obras',         'Maestro de obras y gerencias',                     'MIXTO',   FALSE, 1),
    ('CATALOGO_PROV',    'Catálogo de Proveedores',   'Maestro de proveedores normalizados',               'MIXTO',   FALSE, 2),
    ('MANUAL',           'Carga Manual',              'Registros ingresados manualmente por el usuario',  'MIXTO',   FALSE, 99),
    ('SISTEMA',          'Sistema Interno',           'Generado automáticamente por el sistema',          'MIXTO',   TRUE, 5)
ON CONFLICT (codigo_fuente) DO NOTHING;

INSERT INTO ml.umbrales_alertas (tipo_alerta, campo_medicion, porcentaje_variacion_permitido, severidad_default)
VALUES
    ('IMPORTE_OUTLIER',      'importe',          300.00, 'WARNING'),
    ('IMPORTE_CRITICO',      'importe',          500.00, 'CRITICAL'),
    ('TIPO_CAMBIO_VARIACION','tipo_cambio',       15.00, 'WARNING'),
    ('VOLUMEN_CARGA_BAJO',   'registros_carga',  50.00,  'INFO')
ON CONFLICT (tipo_alerta) DO NOTHING;

-- Generación automática del calendario (2019-2030)
INSERT INTO catalogo.calendario (fecha, anio, mes, dia, nombre_mes, trimestre, semestre, dia_semana, nombre_dia_semana, es_fin_semana, semana_anio)
SELECT 
    datum AS fecha,
    EXTRACT(YEAR FROM datum) AS anio,
    EXTRACT(MONTH FROM datum) AS mes,
    EXTRACT(DAY FROM datum) AS dia,
    TO_CHAR(datum, 'TMMonth') AS nombre_mes,
    EXTRACT(QUARTER FROM datum) AS trimestre,
    CASE WHEN EXTRACT(MONTH FROM datum) <= 6 THEN 1 ELSE 2 END AS semestre,
    EXTRACT(ISODOW FROM datum) AS dia_semana,
    TO_CHAR(datum, 'TMDay') AS nombre_dia_semana,
    CASE WHEN EXTRACT(ISODOW FROM datum) IN (6, 7) THEN TRUE ELSE FALSE END AS es_fin_semana,
    EXTRACT(WEEK FROM datum) AS semana_anio
FROM (SELECT generate_series('2019-01-01'::DATE, '2030-12-31'::DATE, '1 day'::INTERVAL)::DATE AS datum) d
ON CONFLICT (fecha) DO NOTHING;
