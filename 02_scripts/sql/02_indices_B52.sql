-- ============================================================================
-- DW_GrupoPOSE_B52 - Índices optimizados
-- Fecha: 19 de marzo de 2026
-- Versión: 1.0
-- Prerequisito: 01_crear_estructura_B52.sql ejecutado
-- ============================================================================
USE DW_GrupoPOSE_B52;
GO

PRINT '';
PRINT '============================================================';
PRINT '  Creando índices optimizados...';
PRINT '============================================================';

-- ============================================================================
-- PRODUCCION.costos
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_costos_particion' AND object_id = OBJECT_ID('PRODUCCION.costos'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_costos_particion
        ON PRODUCCION.costos (anio_dato, mes_dato, fecha)
        INCLUDE (importe, obra_pronto);
    PRINT '  + IX_costos_particion creado.';
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_costos_obra' AND object_id = OBJECT_ID('PRODUCCION.costos'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_costos_obra
        ON PRODUCCION.costos (obra_pronto, anio_dato, mes_dato);
    PRINT '  + IX_costos_obra creado.';
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_costos_ml' AND object_id = OBJECT_ID('PRODUCCION.costos'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_costos_ml
        ON PRODUCCION.costos (categoria_riesgo, es_outlier_estadistico)
        WHERE es_outlier_estadistico = 1;
    PRINT '  + IX_costos_ml creado.';
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_costos_proveedor' AND object_id = OBJECT_ID('PRODUCCION.costos'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_costos_proveedor
        ON PRODUCCION.costos (proveedor_id, anio_dato, mes_dato);
    PRINT '  + IX_costos_proveedor creado.';
END
GO

-- ============================================================================
-- PRODUCCION.comprobantes
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_comprobantes_particion' AND object_id = OBJECT_ID('PRODUCCION.comprobantes'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_comprobantes_particion
        ON PRODUCCION.comprobantes (anio_dato, fecha_comprobante)
        INCLUDE (importe);
    PRINT '  + IX_comprobantes_particion creado.';
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_comprobantes_obra' AND object_id = OBJECT_ID('PRODUCCION.comprobantes'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_comprobantes_obra
        ON PRODUCCION.comprobantes (obra_pronto, anio_dato);
    PRINT '  + IX_comprobantes_obra creado.';
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_comprobantes_numero_norm' AND object_id = OBJECT_ID('PRODUCCION.comprobantes'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_comprobantes_numero_norm
        ON PRODUCCION.comprobantes (numero_comprobante_norm);
    PRINT '  + IX_comprobantes_numero_norm creado.';
END
GO

-- ============================================================================
-- CATALOGO.obras
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_obras_gerencia' AND object_id = OBJECT_ID('CATALOGO.obras'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_obras_gerencia
        ON CATALOGO.obras (id_gerencia)
        INCLUDE (obra_pronto, descripcion_obra);
    PRINT '  + IX_obras_gerencia creado.';
END
GO

-- ============================================================================
-- AUDITORIA
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_periodos_tabla_fecha' AND object_id = OBJECT_ID('AUDITORIA.periodos_carga'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_periodos_tabla_fecha
        ON AUDITORIA.periodos_carga (tabla_destino, anio, mes);
    PRINT '  + IX_periodos_tabla_fecha creado.';
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_rechazos_log' AND object_id = OBJECT_ID('AUDITORIA.rechazos'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_rechazos_log
        ON AUDITORIA.rechazos (id_log_carga, fecha_rechazo);
    PRINT '  + IX_rechazos_log creado.';
END
GO

-- ============================================================================
-- ML
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_alertas_fecha_tipo' AND object_id = OBJECT_ID('ML.historial_alertas'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_alertas_fecha_tipo
        ON ML.historial_alertas (fecha_generacion, tipo_alerta, severidad);
    PRINT '  + IX_alertas_fecha_tipo creado.';
END
GO

PRINT '';
PRINT '============================================================';
PRINT '  Índices creados exitosamente.';
PRINT '  Siguiente: ejecutar 03_poblar_referencias_B52.sql';
PRINT '============================================================';
GO
