-- ============================================================================
-- DW_GrupoPOSE_B52 - Datos de referencia iniciales
-- Fecha: 19 de marzo de 2026
-- Versión: 1.0
-- Prerequisito: 01_crear_estructura_B52.sql ejecutado
-- ============================================================================
USE DW_GrupoPOSE_B52;
GO

PRINT '';
PRINT '============================================================';
PRINT '  Poblando tablas de referencia...';
PRINT '============================================================';

-- ============================================================================
-- CATALOGO.fuentes — 6 fuentes del sistema (Sección 3.3 del Plan)
-- ============================================================================

IF NOT EXISTS (SELECT * FROM CATALOGO.fuentes WHERE codigo_fuente = 'COSTOS_SAP')
BEGIN
    INSERT INTO CATALOGO.fuentes (codigo_fuente, nombre_fuente, descripcion, tipo_movimiento, es_automatica, prioridad_carga)
    VALUES
        ('COSTOS_SAP',       'Costos SAP',               'Costos extraídos de SAP - archivo Excel mensual',  'EGRESO',  0, 10),
        ('COMPROBANTES_SAP', 'Comprobantes SAP',          'Comprobantes extraídos de SAP - archivo por año',  'EGRESO',  0, 20),
        ('CATALOGO_OBRAS',   'Catálogo de Obras',         'Maestro de obras y gerencias',                     'MIXTO',   0, 1),
        ('CATALOGO_PROV',    'Catálogo de Proveedores',   'Maestro de proveedores normalizados',               'MIXTO',   0, 2),
        ('MANUAL',           'Carga Manual',              'Registros ingresados manualmente por el usuario',  'MIXTO',   0, 99),
        ('SISTEMA',          'Sistema Interno',           'Generado automáticamente por el sistema',          'MIXTO',   1, 5);
    PRINT '  + 6 registros en CATALOGO.fuentes insertados.';
END
ELSE
    PRINT '  ~ CATALOGO.fuentes ya tiene datos (omitido).';
GO

-- ============================================================================
-- ML.umbrales_alertas — valores de referencia para detección de anomalías
-- ============================================================================

IF NOT EXISTS (SELECT * FROM ML.umbrales_alertas WHERE tipo_alerta = 'IMPORTE_OUTLIER')
BEGIN
    INSERT INTO ML.umbrales_alertas (tipo_alerta, campo_medicion, porcentaje_variacion_permitido, severidad_default)
    VALUES
        ('IMPORTE_OUTLIER',      'importe',          300.00, 'WARNING'),
        ('IMPORTE_CRITICO',      'importe',          500.00, 'CRITICAL'),
        ('TIPO_CAMBIO_VARIACION','tipo_cambio',       15.00, 'WARNING'),
        ('VOLUMEN_CARGA_BAJO',   'registros_carga',  50.00,  'INFO');
    PRINT '  + 4 registros en ML.umbrales_alertas insertados.';
END
ELSE
    PRINT '  ~ ML.umbrales_alertas ya tiene datos (omitido).';
GO

-- ============================================================================
-- CATALOGO.calendario — fechas 2019-01-01 a 2030-12-31
-- ============================================================================

IF NOT EXISTS (SELECT * FROM CATALOGO.calendario WHERE fecha = '2019-01-01')
BEGIN
    DECLARE @fecha DATE = '2019-01-01';
    DECLARE @fecha_fin DATE = '2030-12-31';

    WHILE @fecha <= @fecha_fin
    BEGIN
        INSERT INTO CATALOGO.calendario (
            fecha, anio, mes, dia, nombre_mes, trimestre,
            semestre, dia_semana, nombre_dia_semana, es_fin_semana, semana_anio
        )
        VALUES (
            @fecha,
            YEAR(@fecha),
            MONTH(@fecha),
            DAY(@fecha),
            DATENAME(MONTH, @fecha),
            DATEPART(QUARTER, @fecha),
            CASE WHEN MONTH(@fecha) <= 6 THEN 1 ELSE 2 END,
            DATEPART(WEEKDAY, @fecha),
            DATENAME(WEEKDAY, @fecha),
            CASE WHEN DATEPART(WEEKDAY, @fecha) IN (1, 7) THEN 1 ELSE 0 END,
            DATEPART(ISO_WEEK, @fecha)
        );
        SET @fecha = DATEADD(DAY, 1, @fecha);
    END

    DECLARE @total INT = DATEDIFF(DAY, '2019-01-01', '2030-12-31') + 1;
    PRINT '  + ' + CAST(@total AS VARCHAR) + ' registros en CATALOGO.calendario insertados (2019-2030).';
END
ELSE
    PRINT '  ~ CATALOGO.calendario ya tiene datos (omitido).';
GO

PRINT '';
PRINT '============================================================';
PRINT '  Referencias pobladas exitosamente.';
PRINT '  La estructura DW_GrupoPOSE_B52 está lista para Fase 2.';
PRINT '============================================================';
GO
