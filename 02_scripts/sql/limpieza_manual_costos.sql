-- ============================================================
-- Script de limpieza manual para PRODUCCION.costos
-- Fecha: 2026-03-14
-- Propósito: Eliminar duplicados acumulados y dejar solo última carga
-- Arquitectura: DW_GrupoPOSE_B52 (carga incremental por anio_dato/mes_dato)
--
-- IMPORTANTE: Limpia en cascada respetando FKs:
--   ML.anomalias_detectadas → PRODUCCION.costos
--   AUDITORIA.rechazos      → AUDITORIA.log_cargas
--   AUDITORIA.metricas_rendimiento → AUDITORIA.log_cargas + AUDITORIA.periodos_carga
--   PRODUCCION.costos       → AUDITORIA.log_cargas
--   AUDITORIA.log_cargas    (tabla destino = 'PRODUCCION.costos')
--   AUDITORIA.periodos_carga (tabla destino = 'PRODUCCION.costos') ← CRÍTICO para recarga
-- ============================================================

USE DW_GrupoPOSE_B52;
GO

-- ============================================================
-- DIAGNÓSTICO ANTES
-- ============================================================
PRINT '🔍 ── Estado ANTES de limpieza ──────────────────────────';

PRINT '';
PRINT '  [PRODUCCION.costos]';
SELECT
    COUNT(*)                        AS total_registros,
    COUNT(DISTINCT id_log_carga)    AS cargas_distintas,
    MIN(fecha_carga)                AS primera_carga,
    MAX(fecha_carga)                AS ultima_carga
FROM PRODUCCION.costos;

PRINT '';
PRINT '  [PRODUCCION.costos] — Detalle por periodo:';
SELECT
    anio_dato,
    mes_dato,
    COUNT(*)    AS registros,
    MIN(fecha_carga) AS primera_carga,
    MAX(fecha_carga) AS ultima_carga
FROM PRODUCCION.costos
GROUP BY anio_dato, mes_dato
ORDER BY anio_dato, mes_dato;

PRINT '';
PRINT '  [AUDITORIA.periodos_carga] para PRODUCCION.costos:';
SELECT
    periodo_codigo,
    estado,
    registros_insertados,
    fecha_inicio_carga,
    fecha_fin_carga
FROM AUDITORIA.periodos_carga
WHERE tabla_destino = 'PRODUCCION.costos'
ORDER BY anio, mes;

PRINT '';
PRINT '  [AUDITORIA.rechazos] vinculados a PRODUCCION.costos:';
SELECT COUNT(*) AS total_rechazos
FROM AUDITORIA.rechazos r
WHERE r.id_log_carga IN (
    SELECT id_log_carga FROM AUDITORIA.log_cargas
    WHERE tabla_destino = 'PRODUCCION.costos'
);

PRINT '';
PRINT '  [ML.anomalias_detectadas] vinculadas a PRODUCCION.costos:';
SELECT COUNT(*) AS total_anomalias
FROM ML.anomalias_detectadas
WHERE tabla_origen = 'PRODUCCION.costos';
GO

-- ============================================================
-- LIMPIEZA EN CASCADA (orden respeta FKs)
-- ============================================================
PRINT '';
PRINT '🗑️  ── Iniciando limpieza en cascada ────────────────────';
BEGIN TRANSACTION;
BEGIN TRY

    -- 1) ML: anomalías referenciadas a registros de PRODUCCION.costos
    PRINT '  1/6 Eliminando ML.anomalias_detectadas...';
    DELETE FROM ML.anomalias_detectadas
    WHERE tabla_origen = 'PRODUCCION.costos';
    PRINT CONCAT('      Filas eliminadas: ', @@ROWCOUNT);

    -- 2) Tabla principal
    PRINT '  2/6 Eliminando PRODUCCION.costos...';
    DELETE FROM PRODUCCION.costos;
    PRINT CONCAT('      Filas eliminadas: ', @@ROWCOUNT);

    -- 3) Rechazos vinculados a cargas de PRODUCCION.costos
    PRINT '  3/6 Eliminando AUDITORIA.rechazos vinculados...';
    DELETE FROM AUDITORIA.rechazos
    WHERE id_log_carga IN (
        SELECT id_log_carga FROM AUDITORIA.log_cargas
        WHERE tabla_destino = 'PRODUCCION.costos'
    );
    PRINT CONCAT('      Filas eliminadas: ', @@ROWCOUNT);

    -- 4) Métricas de rendimiento vinculadas (FK a log_cargas Y periodos_carga)
    PRINT '  4/6 Eliminando AUDITORIA.metricas_rendimiento vinculadas...';
    DELETE FROM AUDITORIA.metricas_rendimiento
    WHERE id_log_carga IN (
        SELECT id_log_carga FROM AUDITORIA.log_cargas
        WHERE tabla_destino = 'PRODUCCION.costos'
    )
    OR id_periodo_carga IN (
        SELECT id_periodo_carga FROM AUDITORIA.periodos_carga
        WHERE tabla_destino = 'PRODUCCION.costos'
    );
    PRINT CONCAT('      Filas eliminadas: ', @@ROWCOUNT);

    -- 5) Log de cargas de PRODUCCION.costos (ya sin FK dependientes)
    PRINT '  5/6 Eliminando AUDITORIA.log_cargas para PRODUCCION.costos...';
    DELETE FROM AUDITORIA.log_cargas
    WHERE tabla_destino = 'PRODUCCION.costos';
    PRINT CONCAT('      Filas eliminadas: ', @@ROWCOUNT);

    -- 6) CRÍTICO: periodos_carga — el cargador incremental verifica esta tabla
    --    Si no se limpia, 03_cargar_costos_B52.py saltea todos los periodos
    PRINT '  6/6 Eliminando AUDITORIA.periodos_carga para PRODUCCION.costos (CRITICO)...';
    DELETE FROM AUDITORIA.periodos_carga
    WHERE tabla_destino = 'PRODUCCION.costos';
    PRINT CONCAT('      Filas eliminadas: ', @@ROWCOUNT);

    COMMIT TRANSACTION;
    PRINT '';
    PRINT '✅ Transacción confirmada.';

END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    PRINT '';
    PRINT '❌ ERROR — Transacción revertida.';
    PRINT CONCAT('   Mensaje: ', ERROR_MESSAGE());
    PRINT CONCAT('   Línea:   ', ERROR_LINE());
END CATCH;
GO

-- ============================================================
-- DIAGNÓSTICO DESPUÉS
-- ============================================================
PRINT '';
PRINT '✅ ── Estado DESPUÉS de limpieza ────────────────────────';

SELECT COUNT(*) AS costos_restantes         FROM PRODUCCION.costos;
SELECT COUNT(*) AS periodos_restantes        FROM AUDITORIA.periodos_carga WHERE tabla_destino = 'PRODUCCION.costos';
SELECT COUNT(*) AS log_cargas_restantes      FROM AUDITORIA.log_cargas    WHERE tabla_destino = 'PRODUCCION.costos';
SELECT COUNT(*) AS rechazos_restantes        FROM AUDITORIA.rechazos r
    WHERE r.id_log_carga IN (SELECT id_log_carga FROM AUDITORIA.log_cargas WHERE tabla_destino = 'PRODUCCION.costos');
GO

PRINT '';
PRINT '✅ PRODUCCION.costos lista para recibir nueva carga incremental.';
PRINT '   Ejecutá ahora: python .\02_scripts\python\cargas\03_cargar_costos_B52.py';
GO
