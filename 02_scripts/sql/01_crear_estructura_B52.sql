-- ============================================================================
-- DW_GrupoPOSE_B52 - Estructura Completa
-- Fecha: 13 de marzo de 2026
-- Versión: 1.1
-- Descripción: Data Warehouse con carga incremental y ML Observability
-- ============================================================================
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- Crear base de datos
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'DW_GrupoPOSE_B52')
BEGIN
    CREATE DATABASE DW_GrupoPOSE_B52;
    PRINT '  + Base de datos DW_GrupoPOSE_B52 creada.';
END
ELSE
BEGIN
    PRINT '  ~ Base de datos DW_GrupoPOSE_B52 ya existe (se omite creación).';
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

PRINT '  + Esquemas creados: CATALOGO, PRODUCCION, AUDITORIA, TEMPORAL, ML';
GO

-- ============================================================================
-- CATALOGO: DIMENSIONES
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'CATALOGO.gerencias') AND type = 'U')
BEGIN
    CREATE TABLE CATALOGO.gerencias (
        id_gerencia INT IDENTITY(1,1) PRIMARY KEY,
        codigo_gerencia NVARCHAR(50) UNIQUE NOT NULL,
        nombre_gerencia NVARCHAR(400) NOT NULL,
        activo BIT DEFAULT 1,
        fecha_alta DATETIME2 DEFAULT GETDATE(),
        fecha_baja DATETIME2 NULL
    );
    PRINT '  + Tabla CATALOGO.gerencias creada.';
END
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'CATALOGO.obras') AND type = 'U')
BEGIN
    CREATE TABLE CATALOGO.obras (
        id_obra INT IDENTITY(1,1) PRIMARY KEY,
        obra_pronto VARCHAR(50) UNIQUE NOT NULL,
        descripcion_obra NVARCHAR(600) NOT NULL,
        id_gerencia INT,
        activo BIT DEFAULT 1,
        fecha_alta DATETIME2 DEFAULT GETDATE(),
        fecha_baja DATETIME2 NULL,
        FOREIGN KEY (id_gerencia) REFERENCES CATALOGO.gerencias(id_gerencia)
    );
    PRINT '  + Tabla CATALOGO.obras creada.';
END
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'CATALOGO.proveedores') AND type = 'U')
BEGIN
    CREATE TABLE CATALOGO.proveedores (
        id_proveedor BIGINT IDENTITY(1,1) PRIMARY KEY,
        cuit NVARCHAR(20) UNIQUE,
        nombre_proveedor NVARCHAR(600) NOT NULL,
        nombre_proveedor_norm NVARCHAR(600) NOT NULL,
        codigo_proveedor NVARCHAR(100),
        categoria VARCHAR(50),              -- 'Materiales', 'Servicios', 'Obra', 'General'
        tipo_entidad VARCHAR(20),           -- 'Persona Física', 'Jurídica', 'Desconocido'
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
    PRINT '  + Tabla CATALOGO.proveedores creada.';
END
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'CATALOGO.fuentes') AND type = 'U')
BEGIN
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
    PRINT '  + Tabla CATALOGO.fuentes creada.';
END
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'CATALOGO.jerarquia_org') AND type = 'U')
BEGIN
    CREATE TABLE CATALOGO.jerarquia_org (
        id_jerarquia INT IDENTITY(1,1) PRIMARY KEY,
        codigo_jerarquia NVARCHAR(50) UNIQUE NOT NULL,
        taller_region NVARCHAR(100),
        unidad_temporal NVARCHAR(100),
        codigo_centro_costo NVARCHAR(50),
        id_gerencia INT,
        empresa VARCHAR(20),
        nivel_organizativo INT,             -- 1=Empresa, 2=Gerencia, 3=Taller, 4=Unidad
        activo BIT DEFAULT 1,
        fecha_alta DATETIME2 DEFAULT GETDATE(),
        FOREIGN KEY (id_gerencia) REFERENCES CATALOGO.gerencias(id_gerencia)
    );
    CREATE INDEX IX_jerarquia_gerencia ON CATALOGO.jerarquia_org(id_gerencia);
    PRINT '  + Tabla CATALOGO.jerarquia_org creada.';
END
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'CATALOGO.calendario') AND type = 'U')
BEGIN
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
    PRINT '  + Tabla CATALOGO.calendario creada.';
END
GO

-- ============================================================================
-- AUDITORIA: LOG BASE (debe ir antes de PRODUCCION por FK)
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'AUDITORIA.log_cargas') AND type = 'U')
BEGIN
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
    PRINT '  + Tabla AUDITORIA.log_cargas creada.';
END
GO

-- ============================================================================
-- PRODUCCION: HECHOS CON ML OBSERVABILITY
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'PRODUCCION.costos') AND type = 'U')
BEGIN
    CREATE TABLE PRODUCCION.costos (
        id_costo BIGINT IDENTITY(1,1) PRIMARY KEY,
        id_log_carga BIGINT NOT NULL,

        -- Dimensiones
        obra_pronto VARCHAR(50) NOT NULL,
        fecha DATE NOT NULL,
        proveedor_id BIGINT,
        fuente_id INT,

        -- Métricas
        importe DECIMAL(18,2),
        tipo_cambio DECIMAL(10,6),
        importe_usd DECIMAL(18,2),

        -- Descriptivos
        nombre_proveedor NVARCHAR(600),
        nombre_proveedor_norm NVARCHAR(600),
        tipo_comprobante NVARCHAR(200),
        numero_comprobante NVARCHAR(200),
        numero_comprobante_norm NVARCHAR(200),
        observacion NVARCHAR(MAX),
        detalle NVARCHAR(1000),

        -- Clasificación
        taller_reg NVARCHAR(400),
        ut_otros NVARCHAR(400),
        rubro_contable NVARCHAR(100),
        cuenta_contable NVARCHAR(400),
        codigo_cuenta NVARCHAR(100),
        compensable NVARCHAR(100),
        fuente NVARCHAR(100),
        descripcion_obra NVARCHAR(600),
        gerencia NVARCHAR(400),

        -- Particionamiento MENSUAL
        anio_dato INT NOT NULL,
        mes_dato INT NOT NULL,

        -- ML Observability (calculados post-carga)
        z_score_importe DECIMAL(10,6),
        percentil_importe INT,
        dias_desde_ultima_carga INT,
        es_outlier_estadistico BIT DEFAULT 0,
        es_valor_inusual BIT DEFAULT 0,
        categoria_riesgo VARCHAR(20),        -- 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'

        -- Auditoría
        archivo_origen NVARCHAR(510) NOT NULL,
        fila_excel INT,
        fecha_carga DATETIME2 DEFAULT GETDATE(),
        usuario_carga NVARCHAR(200),

        FOREIGN KEY (id_log_carga) REFERENCES AUDITORIA.log_cargas(id_log_carga)
        -- FKs a obras y proveedores se agregan en Paso 1.2 (después de poblar catálogos)
    );
    PRINT '  + Tabla PRODUCCION.costos creada.';
END
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'PRODUCCION.comprobantes') AND type = 'U')
BEGIN
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
        tipo_comprobante VARCHAR(10),
        proveedor_ff VARCHAR(200),
        cuenta_contable VARCHAR(100),
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

        FOREIGN KEY (id_log_carga) REFERENCES AUDITORIA.log_cargas(id_log_carga)
    );
    PRINT '  + Tabla PRODUCCION.comprobantes creada.';
END
GO

-- ============================================================================
-- AUDITORIA: CONTROL AVANZADO
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'AUDITORIA.periodos_carga') AND type = 'U')
BEGIN
    CREATE TABLE AUDITORIA.periodos_carga (
        id_periodo_carga BIGINT IDENTITY(1,1) PRIMARY KEY,
        tabla_destino NVARCHAR(100) NOT NULL,
        tipo_particion VARCHAR(20) NOT NULL,    -- 'MENSUAL', 'ANUAL'
        anio INT NOT NULL,
        mes INT NULL,
        periodo_codigo VARCHAR(10) NOT NULL,    -- '202603', '2026'
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
    PRINT '  + Tabla AUDITORIA.periodos_carga creada.';
END
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'AUDITORIA.metricas_rendimiento') AND type = 'U')
BEGIN
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
    PRINT '  + Tabla AUDITORIA.metricas_rendimiento creada.';
END
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'AUDITORIA.rechazos') AND type = 'U')
BEGIN
    CREATE TABLE AUDITORIA.rechazos (
        id_rechazo BIGINT IDENTITY(1,1) PRIMARY KEY,
        id_log_carga BIGINT NOT NULL,
        fila_excel INT,
        motivo_rechazo NVARCHAR(MAX) NOT NULL,
        datos_rechazo NVARCHAR(MAX),
        fecha_rechazo DATETIME2 DEFAULT GETDATE(),
        FOREIGN KEY (id_log_carga) REFERENCES AUDITORIA.log_cargas(id_log_carga)
    );
    PRINT '  + Tabla AUDITORIA.rechazos creada.';
END
GO

-- ============================================================================
-- ML: MACHINE LEARNING OBSERVABILITY
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'ML.parametros_calidad') AND type = 'U')
BEGIN
    CREATE TABLE ML.parametros_calidad (
        id_parametro BIGINT IDENTITY(1,1) PRIMARY KEY,
        entidad_tipo VARCHAR(20) NOT NULL,      -- 'OBRA', 'PROVEEDOR'
        entidad_id NVARCHAR(100) NOT NULL,
        metrica VARCHAR(50) NOT NULL,           -- 'importe', 'tipo_cambio'
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
    PRINT '  + Tabla ML.parametros_calidad creada.';
END
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'ML.umbrales_alertas') AND type = 'U')
BEGIN
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
    PRINT '  + Tabla ML.umbrales_alertas creada.';
END
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'ML.historial_alertas') AND type = 'U')
BEGIN
    CREATE TABLE ML.historial_alertas (
        id_alerta BIGINT IDENTITY(1,1) PRIMARY KEY,
        fecha_generacion DATETIME2 DEFAULT GETDATE(),
        tipo_alerta VARCHAR(50) NOT NULL,
        severidad VARCHAR(20) NOT NULL,         -- 'INFO', 'WARNING', 'CRITICAL'
        tabla_origen NVARCHAR(100),
        id_registro_origen BIGINT,
        descripcion NVARCHAR(MAX) NOT NULL,
        valor_detectado NVARCHAR(200),
        valor_esperado NVARCHAR(200),
        accion_tomada VARCHAR(50),
        estado VARCHAR(20) DEFAULT 'ACTIVA',    -- 'ACTIVA', 'RESUELTA', 'DESCARTADA'
        usuario_resolucion NVARCHAR(200),
        fecha_resolucion DATETIME2
    );
    CREATE INDEX IX_alertas_fecha ON ML.historial_alertas(fecha_generacion);
    CREATE INDEX IX_alertas_tipo ON ML.historial_alertas(tipo_alerta, severidad);
    PRINT '  + Tabla ML.historial_alertas creada.';
END
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'ML.anomalias_detectadas') AND type = 'U')
BEGIN
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
    PRINT '  + Tabla ML.anomalias_detectadas creada.';
END
GO

-- ============================================================================
-- TEMPORAL: STAGING
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'TEMPORAL.costos_carga') AND type = 'U')
BEGIN
    CREATE TABLE TEMPORAL.costos_carga (
        id_costo_temp BIGINT IDENTITY(1,1) PRIMARY KEY,
        obra_pronto VARCHAR(50),
        fecha DATE,
        importe DECIMAL(18,2),
        tipo_cambio DECIMAL(10,6),
        importe_usd DECIMAL(18,2),
        nombre_proveedor NVARCHAR(600),
        tipo_comprobante NVARCHAR(200),
        numero_comprobante NVARCHAR(200),
        observacion NVARCHAR(MAX),
        taller_reg NVARCHAR(400),
        ut_otros NVARCHAR(400),
        rubro_contable NVARCHAR(100),
        cuenta_contable NVARCHAR(400),
        codigo_cuenta NVARCHAR(100),
        compensable NVARCHAR(100),
        fuente NVARCHAR(100),
        descripcion_obra NVARCHAR(600),
        gerencia NVARCHAR(400),
        fila_excel INT
    );
    PRINT '  + Tabla TEMPORAL.costos_carga creada.';
END
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'TEMPORAL.comprobantes_carga') AND type = 'U')
BEGIN
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
        tipo_comprobante VARCHAR(10),
        proveedor_ff VARCHAR(200),
        cuenta_contable VARCHAR(100),
        fecha_vto DATE,
        tc DECIMAL(10,6),
        moneda VARCHAR(10),
        observacion VARCHAR(500)
    );
    PRINT '  + Tabla TEMPORAL.comprobantes_carga creada.';
END
GO

PRINT '';
PRINT '============================================================';
PRINT '  DW_GrupoPOSE_B52 - Estructura creada exitosamente';
PRINT '  Ejecutar 02_indices_B52.sql y 03_poblar_referencias_B52.sql';
PRINT '============================================================';
GO
