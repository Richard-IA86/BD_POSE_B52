-- ============================================================================
-- DW_GrupoPOSE_B52 — Estructura completa (PostgreSQL 16)
-- Migrado desde: 01_crear_estructura_B52.sql (SQL Server)
-- Fecha: 2026-04-14
-- Versión: 1.0
-- Ejecutar con: psql -U pose_admin -d DW_GrupoPOSE_B52 -f 01_crear_estructura_pg.sql
-- ============================================================================

-- Crear base de datos (ejecutar solo una vez conectado a postgres)
-- CREATE DATABASE "DW_GrupoPOSE_B52" OWNER pose_admin ENCODING 'UTF8';

\connect "DW_GrupoPOSE_B52"

DO $$ BEGIN
    RAISE NOTICE '============================================================';
    RAISE NOTICE '  DW_GrupoPOSE_B52 — Creando estructura...';
    RAISE NOTICE '============================================================';
END $$;

-- ============================================================================
-- ESQUEMAS
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS catalogo;
CREATE SCHEMA IF NOT EXISTS produccion;
CREATE SCHEMA IF NOT EXISTS auditoria;
CREATE SCHEMA IF NOT EXISTS temporal;
CREATE SCHEMA IF NOT EXISTS ml;

DO $$ BEGIN
    RAISE NOTICE '  + Esquemas OK: catalogo, produccion, auditoria, temporal, ml';
END $$;

-- ============================================================================
-- CATALOGO: DIMENSIONES
-- ============================================================================

CREATE TABLE IF NOT EXISTS catalogo.gerencias (
    id_gerencia       SERIAL        PRIMARY KEY,
    codigo_gerencia   VARCHAR(50)   UNIQUE NOT NULL,
    nombre_gerencia   VARCHAR(400)  NOT NULL,
    activo            BOOLEAN       DEFAULT TRUE,
    fecha_alta        TIMESTAMP     DEFAULT NOW(),
    fecha_baja        TIMESTAMP     NULL
);
DO $$ BEGIN RAISE NOTICE '  + catalogo.gerencias OK'; END $$;

CREATE TABLE IF NOT EXISTS catalogo.obras (
    id_obra           SERIAL        PRIMARY KEY,
    obra_pronto       VARCHAR(50)   UNIQUE NOT NULL,
    descripcion_obra  VARCHAR(600)  NOT NULL,
    id_gerencia       INT           REFERENCES catalogo.gerencias(id_gerencia),
    activo            BOOLEAN       DEFAULT TRUE,
    fecha_alta        TIMESTAMP     DEFAULT NOW(),
    fecha_baja        TIMESTAMP     NULL
);
DO $$ BEGIN RAISE NOTICE '  + catalogo.obras OK'; END $$;

CREATE TABLE IF NOT EXISTS catalogo.proveedores (
    id_proveedor                BIGSERIAL     PRIMARY KEY,
    cuit                        VARCHAR(20)   UNIQUE,
    nombre_proveedor            VARCHAR(600)  NOT NULL,
    nombre_proveedor_norm       VARCHAR(600)  NOT NULL,
    codigo_proveedor            VARCHAR(100),
    categoria                   VARCHAR(50),
    tipo_entidad                VARCHAR(20),
    es_proveedor_ff             BOOLEAN       DEFAULT FALSE,
    frecuencia_transaccional    VARCHAR(20),
    total_facturado_historico   DECIMAL(18,2) DEFAULT 0,
    activo                      BOOLEAN       DEFAULT TRUE,
    fecha_alta                  TIMESTAMP     DEFAULT NOW(),
    fecha_baja                  TIMESTAMP     NULL,
    fecha_modificacion          TIMESTAMP     DEFAULT NOW(),
    usuario_carga               VARCHAR(200)
);
CREATE INDEX IF NOT EXISTS ix_proveedores_nombre_norm
    ON catalogo.proveedores(nombre_proveedor_norm);
CREATE INDEX IF NOT EXISTS ix_proveedores_categoria
    ON catalogo.proveedores(categoria);
CREATE INDEX IF NOT EXISTS ix_proveedores_cuit
    ON catalogo.proveedores(cuit)
    WHERE cuit IS NOT NULL;
DO $$ BEGIN RAISE NOTICE '  + catalogo.proveedores OK'; END $$;

CREATE TABLE IF NOT EXISTS catalogo.fuentes (
    id_fuente           SERIAL        PRIMARY KEY,
    codigo_fuente       VARCHAR(50)   UNIQUE NOT NULL,
    nombre_fuente       VARCHAR(200)  NOT NULL,
    descripcion         VARCHAR(500),
    tipo_movimiento     VARCHAR(10)
        CHECK (tipo_movimiento IN ('INGRESO', 'EGRESO', 'MIXTO')),
    es_automatica       BOOLEAN       DEFAULT FALSE,
    prioridad_carga     INT           DEFAULT 100,
    activo              BOOLEAN       DEFAULT TRUE,
    fecha_alta          TIMESTAMP     DEFAULT NOW(),
    fecha_baja          TIMESTAMP     NULL
);
DO $$ BEGIN RAISE NOTICE '  + catalogo.fuentes OK'; END $$;

CREATE TABLE IF NOT EXISTS catalogo.jerarquia_org (
    id_jerarquia            SERIAL       PRIMARY KEY,
    codigo_jerarquia        VARCHAR(50)  UNIQUE NOT NULL,
    taller_region           VARCHAR(100),
    unidad_temporal         VARCHAR(100),
    codigo_centro_costo     VARCHAR(50),
    id_gerencia             INT          REFERENCES catalogo.gerencias(id_gerencia),
    empresa                 VARCHAR(20),
    nivel_organizativo      INT,
    activo                  BOOLEAN      DEFAULT TRUE,
    fecha_alta              TIMESTAMP    DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS ix_jerarquia_gerencia
    ON catalogo.jerarquia_org(id_gerencia);
DO $$ BEGIN RAISE NOTICE '  + catalogo.jerarquia_org OK'; END $$;

CREATE TABLE IF NOT EXISTS catalogo.calendario (
    fecha               DATE         PRIMARY KEY,
    anio                INT          NOT NULL,
    mes                 INT          NOT NULL,
    dia                 INT          NOT NULL,
    nombre_mes          VARCHAR(20)  NOT NULL,
    trimestre           INT          NOT NULL,
    semestre            INT          NOT NULL,
    dia_semana          INT          NOT NULL,
    nombre_dia_semana   VARCHAR(20)  NOT NULL,
    es_fin_semana       BOOLEAN      NOT NULL,
    semana_anio         INT          NOT NULL
);
DO $$ BEGIN RAISE NOTICE '  + catalogo.calendario OK'; END $$;

CREATE TABLE IF NOT EXISTS catalogo.tipo_cambio (
    id_tc           SERIAL          PRIMARY KEY,
    fecha           DATE            NOT NULL,
    moneda          VARCHAR(10)     NOT NULL DEFAULT 'USD',
    tc_compra       DECIMAL(12,4)   NULL,
    tc_venta        DECIMAL(12,4)   NULL,
    tc_oficial      DECIMAL(12,4)   NULL,
    fuente          VARCHAR(100)    NULL,
    fecha_carga     TIMESTAMP       DEFAULT NOW(),
    usuario_carga   VARCHAR(200)    DEFAULT CURRENT_USER,
    observacion     VARCHAR(500)    NULL,
    CONSTRAINT uq_tipo_cambio_fecha_moneda UNIQUE (fecha, moneda)
);
CREATE INDEX IF NOT EXISTS ix_tc_fecha
    ON catalogo.tipo_cambio(fecha);
CREATE INDEX IF NOT EXISTS ix_tc_fecha_moneda
    ON catalogo.tipo_cambio(fecha, moneda)
    INCLUDE (tc_oficial, tc_venta);
DO $$ BEGIN RAISE NOTICE '  + catalogo.tipo_cambio OK'; END $$;

-- ============================================================================
-- AUDITORIA: LOG BASE (debe ir antes de PRODUCCION por FK)
-- ============================================================================

CREATE TABLE IF NOT EXISTS auditoria.log_cargas (
    id_log_carga            BIGSERIAL    PRIMARY KEY,
    tabla_destino           VARCHAR(100) NOT NULL,
    archivo_origen          VARCHAR(500) NOT NULL,
    registros_procesados    INT          DEFAULT 0,
    registros_insertados    INT          DEFAULT 0,
    registros_rechazados    INT          DEFAULT 0,
    fecha_carga             TIMESTAMP    DEFAULT NOW(),
    usuario_carga           VARCHAR(200),
    estado                  VARCHAR(50)  DEFAULT 'PENDIENTE',
    observaciones           TEXT
);
DO $$ BEGIN RAISE NOTICE '  + auditoria.log_cargas OK'; END $$;

CREATE TABLE IF NOT EXISTS auditoria.periodos_carga (
    id_periodo_carga            BIGSERIAL    PRIMARY KEY,
    tabla_destino               VARCHAR(100) NOT NULL,
    tipo_particion              VARCHAR(20)  NOT NULL,
    anio                        INT          NOT NULL,
    mes                         INT          NULL,
    periodo_codigo              VARCHAR(10)  NOT NULL,
    registros_borrados          INT          DEFAULT 0,
    registros_insertados        INT          DEFAULT 0,
    fecha_inicio_carga          TIMESTAMP    DEFAULT NOW(),
    fecha_fin_carga             TIMESTAMP,
    duracion_segundos           DECIMAL(10,2),
    velocidad_registros_seg     DECIMAL(10,2),
    estado                      VARCHAR(20)  DEFAULT 'EN_PROCESO',
    observaciones               TEXT,
    usuario_carga               VARCHAR(200)
);
CREATE INDEX IF NOT EXISTS ix_periodos_tabla
    ON auditoria.periodos_carga(tabla_destino, anio, mes);
DO $$ BEGIN RAISE NOTICE '  + auditoria.periodos_carga OK'; END $$;

CREATE TABLE IF NOT EXISTS auditoria.metricas_rendimiento (
    id_metrica              BIGSERIAL    PRIMARY KEY,
    id_log_carga            BIGINT       REFERENCES auditoria.log_cargas(id_log_carga),
    id_periodo_carga        BIGINT       REFERENCES auditoria.periodos_carga(id_periodo_carga),
    fase_proceso            VARCHAR(50)  NOT NULL,
    tiempo_inicio           TIMESTAMP    NOT NULL,
    tiempo_fin              TIMESTAMP    NOT NULL,
    duracion_milisegundos   INT,
    memoria_usada_mb        DECIMAL(10,2),
    cpu_porcentaje          DECIMAL(5,2),
    registros_procesados    INT,
    observaciones           VARCHAR(500)
);
DO $$ BEGIN RAISE NOTICE '  + auditoria.metricas_rendimiento OK'; END $$;

CREATE TABLE IF NOT EXISTS auditoria.rechazos (
    id_rechazo      BIGSERIAL    PRIMARY KEY,
    id_log_carga    BIGINT       NOT NULL
        REFERENCES auditoria.log_cargas(id_log_carga),
    fila_excel      INT,
    motivo_rechazo  TEXT         NOT NULL,
    datos_rechazo   TEXT,
    fecha_rechazo   TIMESTAMP    DEFAULT NOW()
);
DO $$ BEGIN RAISE NOTICE '  + auditoria.rechazos OK'; END $$;

-- ============================================================================
-- PRODUCCION: HECHOS CON ML OBSERVABILITY
-- ============================================================================

CREATE TABLE IF NOT EXISTS produccion.costos (
    id_costo                    BIGSERIAL    PRIMARY KEY,
    id_log_carga                BIGINT       NOT NULL
        REFERENCES auditoria.log_cargas(id_log_carga),

    -- Dimensiones
    obra_pronto                 VARCHAR(50)  NOT NULL,
    fecha                       DATE         NOT NULL,
    proveedor_id                BIGINT,
    fuente_id                   INT,

    -- Métricas
    importe                     DECIMAL(18,2),
    tipo_cambio                 DECIMAL(10,6),
    importe_usd                 DECIMAL(18,2),

    -- Descriptivos
    nombre_proveedor            VARCHAR(600),
    nombre_proveedor_norm       VARCHAR(600),
    tipo_comprobante            VARCHAR(200),
    numero_comprobante          VARCHAR(200),
    numero_comprobante_norm     VARCHAR(200),
    observacion                 TEXT,
    detalle                     VARCHAR(1000),

    -- Clasificación
    taller_reg                  VARCHAR(400),
    ut_otros                    VARCHAR(400),
    rubro_contable              VARCHAR(100),
    cuenta_contable             VARCHAR(400),
    codigo_cuenta               VARCHAR(100),
    compensable                 VARCHAR(100),
    fuente                      VARCHAR(100),
    descripcion_obra            VARCHAR(600),
    gerencia                    VARCHAR(400),

    -- Particionamiento MENSUAL
    anio_dato                   INT          NOT NULL,
    mes_dato                    INT          NOT NULL,

    -- ML Observability
    z_score_importe             DECIMAL(10,6),
    percentil_importe           INT,
    dias_desde_ultima_carga     INT,
    es_outlier_estadistico      BOOLEAN      DEFAULT FALSE,
    es_valor_inusual            BOOLEAN      DEFAULT FALSE,
    categoria_riesgo            VARCHAR(20),

    -- Auditoría
    archivo_origen              VARCHAR(510) NOT NULL,
    fila_excel                  INT,
    fecha_carga                 TIMESTAMP    DEFAULT NOW(),
    usuario_carga               VARCHAR(200)
);
DO $$ BEGIN RAISE NOTICE '  + produccion.costos OK'; END $$;

CREATE TABLE IF NOT EXISTS produccion.comprobantes (
    id_comprobante              BIGSERIAL    PRIMARY KEY,
    id_log_carga                BIGINT       NOT NULL
        REFERENCES auditoria.log_cargas(id_log_carga),

    -- Dimensiones
    obra_pronto                 VARCHAR(50),
    fecha_comprobante           DATE         NOT NULL,
    proveedor_id                BIGINT,

    -- Datos
    numero_comprobante          VARCHAR(200) NOT NULL,
    numero_comprobante_norm     VARCHAR(200) NOT NULL,
    cod_proveedor               VARCHAR(100),
    nombre_proveedor            VARCHAR(600),
    nombre_proveedor_norm       VARCHAR(600),
    importe                     DECIMAL(18,2) NOT NULL,

    -- Clasificación
    tipo_comprobante            VARCHAR(10),
    proveedor_ff                VARCHAR(200),
    cuenta_contable             VARCHAR(100),
    fecha_vto                   DATE,
    tc                          DECIMAL(10,6),
    moneda                      VARCHAR(10),
    observacion                 VARCHAR(500),

    -- Particionamiento ANUAL
    anio_dato                   INT          NOT NULL,

    -- Auditoría
    archivo_origen              VARCHAR(510) NOT NULL,
    hoja_origen                 VARCHAR(200),
    fila_excel                  INT,
    fecha_carga                 TIMESTAMP    DEFAULT NOW(),
    usuario_carga               VARCHAR(200)
);
DO $$ BEGIN RAISE NOTICE '  + produccion.comprobantes OK'; END $$;

-- ============================================================================
-- ML: MACHINE LEARNING OBSERVABILITY
-- ============================================================================

CREATE TABLE IF NOT EXISTS ml.parametros_calidad (
    id_parametro            BIGSERIAL    PRIMARY KEY,
    entidad_tipo            VARCHAR(20)  NOT NULL,
    entidad_id              VARCHAR(100) NOT NULL,
    metrica                 VARCHAR(50)  NOT NULL,
    valor_medio             DECIMAL(18,2),
    desviacion_estandar     DECIMAL(18,2),
    valor_min               DECIMAL(18,2),
    valor_max               DECIMAL(18,2),
    percentil_25            DECIMAL(18,2),
    percentil_50            DECIMAL(18,2),
    percentil_75            DECIMAL(18,2),
    registros_muestra       INT,
    fecha_calculo           TIMESTAMP    DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS ix_parametros_entidad
    ON ml.parametros_calidad(entidad_tipo, entidad_id);
DO $$ BEGIN RAISE NOTICE '  + ml.parametros_calidad OK'; END $$;

CREATE TABLE IF NOT EXISTS ml.umbrales_alertas (
    id_umbral                       SERIAL       PRIMARY KEY,
    tipo_alerta                     VARCHAR(50)  UNIQUE NOT NULL,
    campo_medicion                  VARCHAR(100) NOT NULL,
    valor_min                       DECIMAL(18,2),
    valor_max                       DECIMAL(18,2),
    porcentaje_variacion_permitido  DECIMAL(5,2),
    severidad_default               VARCHAR(20)  DEFAULT 'WARNING',
    activo                          BOOLEAN      DEFAULT TRUE,
    fecha_creacion                  TIMESTAMP    DEFAULT NOW()
);
DO $$ BEGIN RAISE NOTICE '  + ml.umbrales_alertas OK'; END $$;

CREATE TABLE IF NOT EXISTS ml.historial_alertas (
    id_alerta               BIGSERIAL    PRIMARY KEY,
    fecha_generacion        TIMESTAMP    DEFAULT NOW(),
    tipo_alerta             VARCHAR(50)  NOT NULL,
    severidad               VARCHAR(20)  NOT NULL,
    tabla_origen            VARCHAR(100),
    id_registro_origen      BIGINT,
    descripcion             TEXT         NOT NULL,
    valor_detectado         VARCHAR(200),
    valor_esperado          VARCHAR(200),
    accion_tomada           VARCHAR(50),
    estado                  VARCHAR(20)  DEFAULT 'ACTIVA',
    usuario_resolucion      VARCHAR(200),
    fecha_resolucion        TIMESTAMP
);
CREATE INDEX IF NOT EXISTS ix_alertas_fecha
    ON ml.historial_alertas(fecha_generacion);
CREATE INDEX IF NOT EXISTS ix_alertas_tipo
    ON ml.historial_alertas(tipo_alerta, severidad);
DO $$ BEGIN RAISE NOTICE '  + ml.historial_alertas OK'; END $$;

CREATE TABLE IF NOT EXISTS ml.anomalias_detectadas (
    id_anomalia             BIGSERIAL    PRIMARY KEY,
    tabla_origen            VARCHAR(100) NOT NULL,
    id_registro_origen      BIGINT       NOT NULL,
    tipo_anomalia           VARCHAR(50)  NOT NULL,
    score_anomalia          DECIMAL(10,6),
    descripcion             TEXT,
    fecha_deteccion         TIMESTAMP    DEFAULT NOW(),
    revisada                BOOLEAN      DEFAULT FALSE,
    es_anomalia_real        BOOLEAN
);
DO $$ BEGIN RAISE NOTICE '  + ml.anomalias_detectadas OK'; END $$;

-- ============================================================================
-- TEMPORAL: STAGING
-- ============================================================================

CREATE TABLE IF NOT EXISTS temporal.costos_carga (
    id_costo_temp       BIGSERIAL    PRIMARY KEY,
    obra_pronto         VARCHAR(50),
    fecha               DATE,
    importe             DECIMAL(18,2),
    tipo_cambio         DECIMAL(10,6),
    importe_usd         DECIMAL(18,2),
    nombre_proveedor    VARCHAR(600),
    tipo_comprobante    VARCHAR(200),
    numero_comprobante  VARCHAR(200),
    observacion         TEXT,
    taller_reg          VARCHAR(400),
    ut_otros            VARCHAR(400),
    rubro_contable      VARCHAR(100),
    cuenta_contable     VARCHAR(400),
    codigo_cuenta       VARCHAR(100),
    compensable         VARCHAR(100),
    fuente              VARCHAR(100),
    descripcion_obra    VARCHAR(600),
    gerencia            VARCHAR(400),
    fila_excel          INT
);
DO $$ BEGIN RAISE NOTICE '  + temporal.costos_carga OK'; END $$;

CREATE TABLE IF NOT EXISTS temporal.comprobantes_carga (
    id_comprobante_temp BIGSERIAL    PRIMARY KEY,
    obra_pronto         VARCHAR(50),
    numero_comprobante  VARCHAR(200),
    fecha_comprobante   DATE,
    cod_proveedor       VARCHAR(100),
    nombre_proveedor    VARCHAR(600),
    importe             DECIMAL(18,2),
    hoja_origen         VARCHAR(200),
    fila_excel          INT,
    tipo_comprobante    VARCHAR(10),
    proveedor_ff        VARCHAR(200),
    cuenta_contable     VARCHAR(100),
    fecha_vto           DATE,
    tc                  DECIMAL(10,6),
    moneda              VARCHAR(10),
    observacion         VARCHAR(500)
);
DO $$ BEGIN RAISE NOTICE '  + temporal.comprobantes_carga OK'; END $$;

DO $$ BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '============================================================';
    RAISE NOTICE '  DW_GrupoPOSE_B52 — Estructura creada exitosamente.';
    RAISE NOTICE '  Siguiente: 02_indices_pg.sql';
    RAISE NOTICE '============================================================';
END $$;
