-- ============================================================================
-- DW_GrupoPOSE_B52 - Tabla CATALOGO.tipo_cambio
-- Fecha: 19 de marzo de 2026
-- Versión: 1.0
-- Descripción: Agrega tabla de tipo de cambio diario (TC).
--              Tabla maestra de referencia para conversión ARS/USD.
--              Permite unificar el TC en vez de depender del valor
--              embebido en cada fila de PRODUCCION.costos.
-- ============================================================================
USE DW_GrupoPOSE_B52;
GO

IF NOT EXISTS (
    SELECT * FROM sys.objects
     WHERE object_id = OBJECT_ID(N'CATALOGO.tipo_cambio')
       AND type = 'U'
)
BEGIN
    CREATE TABLE CATALOGO.tipo_cambio (
        id_tc            INT           IDENTITY(1,1) PRIMARY KEY,

        -- Clave de negocio
        fecha            DATE          NOT NULL,
        moneda           VARCHAR(10)   NOT NULL DEFAULT 'USD',  -- USD, EUR, etc.

        -- Cotizaciones
        tc_compra        DECIMAL(12,4) NULL,
        tc_venta         DECIMAL(12,4) NULL,
        tc_oficial       DECIMAL(12,4) NULL,  -- BNA / BCRA oficial

        -- Metadatos
        fuente           NVARCHAR(100) NULL,  -- 'BNA', 'BCRA', 'manual', etc.
        fecha_carga      DATETIME2     DEFAULT GETDATE(),
        usuario_carga    NVARCHAR(200) DEFAULT SYSTEM_USER,
        observacion      NVARCHAR(500) NULL,

        -- Restricción: una sola fila por fecha+moneda
        CONSTRAINT UQ_tipo_cambio_fecha_moneda UNIQUE (fecha, moneda)
    );

    CREATE NONCLUSTERED INDEX IX_tc_fecha
        ON CATALOGO.tipo_cambio (fecha);

    CREATE NONCLUSTERED INDEX IX_tc_fecha_moneda
        ON CATALOGO.tipo_cambio (fecha, moneda)
        INCLUDE (tc_oficial, tc_venta);

    PRINT '  + Tabla CATALOGO.tipo_cambio creada con índices.';
END
ELSE
BEGIN
    PRINT '  ~ Tabla CATALOGO.tipo_cambio ya existe (se omite creación).';
END
GO
