-- ============================================================================
-- DW_GrupoPOSE_B52 — Datos de referencia iniciales (PostgreSQL 16)
-- Migrado desde: 03_poblar_referencias_B52.sql (SQL Server)
-- Fecha: 2026-04-14
-- Prerequisito: 01_crear_estructura_pg.sql ejecutado
-- Ejecutar con: psql -U pose_admin -d DW_GrupoPOSE_B52 -f 03_poblar_referencias_pg.sql
-- ============================================================================

\connect "DW_GrupoPOSE_B52"

DO $$ BEGIN
    RAISE NOTICE '============================================================';
    RAISE NOTICE '  Poblando tablas de referencia...';
    RAISE NOTICE '============================================================';
END $$;

-- ============================================================================
-- catalogo.fuentes — 6 fuentes del sistema (Sección 3.3 del Plan)
-- ============================================================================

INSERT INTO catalogo.fuentes
    (codigo_fuente, nombre_fuente, descripcion, tipo_movimiento,
     es_automatica, prioridad_carga)
SELECT * FROM (VALUES
    ('COSTOS_SAP',
     'Costos SAP',
     'Costos extraídos de SAP - archivo Excel mensual',
     'EGRESO',  FALSE, 10),
    ('COMPROBANTES_SAP',
     'Comprobantes SAP',
     'Comprobantes extraídos de SAP - archivo por año',
     'EGRESO',  FALSE, 20),
    ('CATALOGO_OBRAS',
     'Catálogo de Obras',
     'Maestro de obras y gerencias',
     'MIXTO',   FALSE, 1),
    ('CATALOGO_PROV',
     'Catálogo de Proveedores',
     'Maestro de proveedores normalizados',
     'MIXTO',   FALSE, 2),
    ('MANUAL',
     'Carga Manual',
     'Registros ingresados manualmente por el usuario',
     'MIXTO',   FALSE, 99),
    ('SISTEMA',
     'Sistema Interno',
     'Generado automáticamente por el sistema',
     'MIXTO',   TRUE,  5)
) AS v(codigo_fuente, nombre_fuente, descripcion,
       tipo_movimiento, es_automatica, prioridad_carga)
WHERE NOT EXISTS (
    SELECT 1 FROM catalogo.fuentes
    WHERE codigo_fuente = v.codigo_fuente
);

DO $$ BEGIN RAISE NOTICE '  + catalogo.fuentes OK (6 fuentes)'; END $$;

-- ============================================================================
-- ml.umbrales_alertas — valores de referencia para detección de anomalías
-- ============================================================================

INSERT INTO ml.umbrales_alertas
    (tipo_alerta, campo_medicion, porcentaje_variacion_permitido,
     severidad_default)
SELECT * FROM (VALUES
    ('IMPORTE_OUTLIER',       'importe',         300.00, 'WARNING'),
    ('IMPORTE_CRITICO',       'importe',         500.00, 'CRITICAL'),
    ('TIPO_CAMBIO_VARIACION', 'tipo_cambio',      15.00, 'WARNING'),
    ('VOLUMEN_CARGA_BAJO',    'registros_carga',  50.00, 'INFO')
) AS v(tipo_alerta, campo_medicion,
       porcentaje_variacion_permitido, severidad_default)
WHERE NOT EXISTS (
    SELECT 1 FROM ml.umbrales_alertas
    WHERE tipo_alerta = v.tipo_alerta
);

DO $$ BEGIN RAISE NOTICE '  + ml.umbrales_alertas OK (4 umbrales)'; END $$;

-- ============================================================================
-- catalogo.calendario — fechas 2019-01-01 a 2030-12-31
-- Usa generate_series (nativo PostgreSQL — equivale al WHILE loop T-SQL)
-- ============================================================================

INSERT INTO catalogo.calendario
    (fecha, anio, mes, dia, nombre_mes, trimestre, semestre,
     dia_semana, nombre_dia_semana, es_fin_semana, semana_anio)
SELECT
    d::DATE,
    EXTRACT(YEAR    FROM d)::INT,
    EXTRACT(MONTH   FROM d)::INT,
    EXTRACT(DAY     FROM d)::INT,
    TO_CHAR(d, 'TMMonth'),
    EXTRACT(QUARTER FROM d)::INT,
    CASE WHEN EXTRACT(MONTH FROM d) <= 6 THEN 1 ELSE 2 END,
    EXTRACT(ISODOW  FROM d)::INT,
    TO_CHAR(d, 'TMDay'),
    EXTRACT(ISODOW  FROM d) IN (6, 7),
    EXTRACT(WEEK    FROM d)::INT
FROM generate_series(
    '2019-01-01'::DATE,
    '2030-12-31'::DATE,
    '1 day'::INTERVAL
) AS gs(d)
ON CONFLICT (fecha) DO NOTHING;

DO $$ BEGIN
    RAISE NOTICE '  + catalogo.calendario OK (2019-2030)';
END $$;

DO $$ BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '============================================================';
    RAISE NOTICE '  Referencias pobladas exitosamente.';
    RAISE NOTICE '  La estructura DW_GrupoPOSE_B52 está lista para Fase 2.';
    RAISE NOTICE '============================================================';
END $$;
