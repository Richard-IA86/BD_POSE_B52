-- ============================================================================
-- DW_GrupoPOSE_B52 — Índices optimizados (PostgreSQL 16)
-- Migrado desde: 02_indices_B52.sql (SQL Server)
-- Fecha: 2026-04-14
-- Prerequisito: 01_crear_estructura_pg.sql ejecutado
-- Ejecutar con: psql -U pose_admin -d DW_GrupoPOSE_B52 -f 02_indices_pg.sql
-- ============================================================================

\connect "DW_GrupoPOSE_B52"

DO $$ BEGIN
    RAISE NOTICE '============================================================';
    RAISE NOTICE '  Creando índices optimizados...';
    RAISE NOTICE '============================================================';
END $$;

-- ============================================================================
-- PRODUCCION.costos
-- ============================================================================

CREATE INDEX IF NOT EXISTS ix_costos_particion
    ON produccion.costos (anio_dato, mes_dato, fecha)
    INCLUDE (importe, obra_pronto);
DO $$ BEGIN RAISE NOTICE '  + ix_costos_particion OK'; END $$;

CREATE INDEX IF NOT EXISTS ix_costos_obra
    ON produccion.costos (obra_pronto, anio_dato, mes_dato);
DO $$ BEGIN RAISE NOTICE '  + ix_costos_obra OK'; END $$;

-- Índice parcial: solo rows con outlier (equivalente al índice filtrado SQL Server)
CREATE INDEX IF NOT EXISTS ix_costos_ml
    ON produccion.costos (categoria_riesgo, es_outlier_estadistico)
    WHERE es_outlier_estadistico = TRUE;
DO $$ BEGIN RAISE NOTICE '  + ix_costos_ml OK'; END $$;

CREATE INDEX IF NOT EXISTS ix_costos_proveedor
    ON produccion.costos (proveedor_id, anio_dato, mes_dato);
DO $$ BEGIN RAISE NOTICE '  + ix_costos_proveedor OK'; END $$;

-- ============================================================================
-- PRODUCCION.comprobantes
-- ============================================================================

CREATE INDEX IF NOT EXISTS ix_comprobantes_particion
    ON produccion.comprobantes (anio_dato, fecha_comprobante)
    INCLUDE (importe);
DO $$ BEGIN RAISE NOTICE '  + ix_comprobantes_particion OK'; END $$;

CREATE INDEX IF NOT EXISTS ix_comprobantes_obra
    ON produccion.comprobantes (obra_pronto, anio_dato);
DO $$ BEGIN RAISE NOTICE '  + ix_comprobantes_obra OK'; END $$;

CREATE INDEX IF NOT EXISTS ix_comprobantes_numero_norm
    ON produccion.comprobantes (numero_comprobante_norm);
DO $$ BEGIN RAISE NOTICE '  + ix_comprobantes_numero_norm OK'; END $$;

-- ============================================================================
-- CATALOGO.obras
-- ============================================================================

CREATE INDEX IF NOT EXISTS ix_obras_gerencia
    ON catalogo.obras (id_gerencia)
    INCLUDE (obra_pronto, descripcion_obra);
DO $$ BEGIN RAISE NOTICE '  + ix_obras_gerencia OK'; END $$;

-- ============================================================================
-- AUDITORIA
-- ============================================================================

CREATE INDEX IF NOT EXISTS ix_periodos_tabla_fecha
    ON auditoria.periodos_carga (tabla_destino, anio, mes);
DO $$ BEGIN RAISE NOTICE '  + ix_periodos_tabla_fecha OK'; END $$;

CREATE INDEX IF NOT EXISTS ix_rechazos_log
    ON auditoria.rechazos (id_log_carga, fecha_rechazo);
DO $$ BEGIN RAISE NOTICE '  + ix_rechazos_log OK'; END $$;

-- ============================================================================
-- ML
-- ============================================================================

CREATE INDEX IF NOT EXISTS ix_alertas_fecha_tipo
    ON ml.historial_alertas (fecha_generacion, tipo_alerta, severidad);
DO $$ BEGIN RAISE NOTICE '  + ix_alertas_fecha_tipo OK'; END $$;

DO $$ BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '============================================================';
    RAISE NOTICE '  Índices creados exitosamente.';
    RAISE NOTICE '  Siguiente: 03_poblar_referencias_pg.sql';
    RAISE NOTICE '============================================================';
END $$;
