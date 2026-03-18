-- ============================================================
-- SIMULACIÓN: limpieza_manual_costos.sql
-- Fecha: 2026-03-14
-- Propósito: Verificar en DW_GrupoPOSE_B52 que la limpieza
--            en cascada funciona correctamente.
--
-- SEGURO: TODO se revierte con ROLLBACK al finalizar.
--         La base de datos queda sin cambios.
--
-- Cómo ejecutar:
--   SSMS → Ejecutar este archivo completo (F5)
--   Revisar la salida de mensajes para ver EXITOSA / CON ERRORES
-- ============================================================

USE DW_GrupoPOSE_B52;
GO

SET NOCOUNT ON;
GO

PRINT '╔══════════════════════════════════════════════════════════════╗';
PRINT '║   SIMULACIÓN — limpieza_manual_costos.sql                   ║';
PRINT '║   Todos los cambios serán REVERTIDOS al finalizar.          ║';
PRINT '╚══════════════════════════════════════════════════════════════╝';
PRINT '';

-- ============================================================
-- Todo el bloque en UNA sola transacción → ROLLBACK al final
-- ============================================================
BEGIN TRANSACTION sim_limpieza;

-- Variables de control
DECLARE @ok         BIT   = 1;
DECLARE @real       INT;
DECLARE @paso       NVARCHAR(100);

-- IDs de datos sintéticos (capturados con SCOPE_IDENTITY)
DECLARE @id_log_1    BIGINT,  -- log carga PRODUCCION.costos nro 1
        @id_log_2    BIGINT,  -- log carga PRODUCCION.costos nro 2
        @id_log_otro BIGINT;  -- log carga OTRA tabla (control de aislamiento)

DECLARE @id_per_1    BIGINT,  -- periodo carga costos nov
        @id_per_2    BIGINT,  -- periodo carga costos dic
        @id_per_otro BIGINT;  -- periodo carga OTRA tabla (control de aislamiento)

DECLARE @id_costo_1  BIGINT;  -- id primer costo SIM (para ML.anomalias)

-- Estado real ANTES de insertar datos sintéticos
-- (se usa para verificar que el ROLLBACK restaura la base)
DECLARE @pre_costos    INT = (SELECT COUNT(*) FROM PRODUCCION.costos);
DECLARE @pre_periodos  INT = (SELECT COUNT(*) FROM AUDITORIA.periodos_carga WHERE tabla_destino = 'PRODUCCION.costos');
DECLARE @pre_logs      INT = (SELECT COUNT(*) FROM AUDITORIA.log_cargas      WHERE tabla_destino = 'PRODUCCION.costos');
DECLARE @pre_anomalias INT = (SELECT COUNT(*) FROM ML.anomalias_detectadas   WHERE tabla_origen  = 'PRODUCCION.costos');

PRINT CONCAT('Estado inicial registrado → costos: ', @pre_costos,
             ' | periodos: ', @pre_periodos,
             ' | logs: ', @pre_logs,
             ' | anomalias: ', @pre_anomalias);
PRINT '';

-- ============================================================
-- FASE 1 — Insertar datos sintéticos de prueba
-- ============================================================
PRINT '── FASE 1: Insertando datos sintéticos ──────────────────────';

-- 1a. Dos cargas de PRODUCCION.costos
INSERT INTO AUDITORIA.log_cargas
    (tabla_destino, archivo_origen, registros_procesados, registros_insertados, registros_rechazados, estado)
VALUES ('PRODUCCION.costos', 'SIM_BaseCostos_202511.xlsx', 100, 95, 5, 'EXITOSO');
SET @id_log_1 = SCOPE_IDENTITY();

INSERT INTO AUDITORIA.log_cargas
    (tabla_destino, archivo_origen, registros_procesados, registros_insertados, registros_rechazados, estado)
VALUES ('PRODUCCION.costos', 'SIM_BaseCostos_202512.xlsx', 200, 198, 2, 'EXITOSO');
SET @id_log_2 = SCOPE_IDENTITY();

-- 1b. Una carga de OTRA tabla (debe sobrevivir la limpieza)
INSERT INTO AUDITORIA.log_cargas
    (tabla_destino, archivo_origen, registros_procesados, registros_insertados, registros_rechazados, estado)
VALUES ('PRODUCCION.comprobantes', 'SIM_Comprobantes_2026.xlsx', 50, 50, 0, 'EXITOSO');
SET @id_log_otro = SCOPE_IDENTITY();

PRINT CONCAT('   ✓ AUDITORIA.log_cargas: ids ', @id_log_1, ', ', @id_log_2,
             ' (costos) | ', @id_log_otro, ' (comprobantes)');

-- 1c. Dos periodos de PRODUCCION.costos
INSERT INTO AUDITORIA.periodos_carga
    (tabla_destino, tipo_particion, anio, mes, periodo_codigo, registros_insertados, estado)
VALUES ('PRODUCCION.costos', 'MENSUAL', 2025, 11, '202511', 95, 'EXITOSO');
SET @id_per_1 = SCOPE_IDENTITY();

INSERT INTO AUDITORIA.periodos_carga
    (tabla_destino, tipo_particion, anio, mes, periodo_codigo, registros_insertados, estado)
VALUES ('PRODUCCION.costos', 'MENSUAL', 2025, 12, '202512', 198, 'EXITOSO');
SET @id_per_2 = SCOPE_IDENTITY();

-- 1d. Un periodo de OTRA tabla (debe sobrevivir la limpieza)
INSERT INTO AUDITORIA.periodos_carga
    (tabla_destino, tipo_particion, anio, mes, periodo_codigo, registros_insertados, estado)
VALUES ('PRODUCCION.comprobantes', 'ANUAL', 2025, NULL, '2025', 50, 'EXITOSO');
SET @id_per_otro = SCOPE_IDENTITY();

PRINT CONCAT('   ✓ AUDITORIA.periodos_carga: ids ', @id_per_1, ', ', @id_per_2,
             ' (costos) | ', @id_per_otro, ' (comprobantes)');

-- 1e. Cinco filas en PRODUCCION.costos (3 en nov, 2 en dic)
INSERT INTO PRODUCCION.costos
    (id_log_carga, obra_pronto, fecha, importe, tipo_cambio, importe_usd,
     nombre_proveedor, nombre_proveedor_norm,
     tipo_comprobante, numero_comprobante, numero_comprobante_norm,
     taller_reg, ut_otros, rubro_contable, cuenta_contable,
     codigo_cuenta, compensable, fuente, descripcion_obra, gerencia,
     anio_dato, mes_dato, archivo_origen, fila_excel, usuario_carga)
VALUES
    (@id_log_1,'00000001','2025-11-05', 150000.00,1050.50,  142.79,'PROV SIM A','PROV SIM A','FC','0001-00001234','0001-00001234','TALLER SIM','UT01','MATERIALES','6101','C001','SI','FF','OBR SIM 1','GERENCIA SIM',2025,11,'SIM_BaseCostos_202511.xlsx',2,'SIM'),
    (@id_log_1,'00000002','2025-11-10', 230000.00,1050.50,  219.04,'PROV SIM B','PROV SIM B','FC','0001-00001235','0001-00001235','TALLER SIM','UT01','SERVICIOS', '6201','C002','NO','FF','OBR SIM 2','GERENCIA SIM',2025,11,'SIM_BaseCostos_202511.xlsx',3,'SIM'),
    (@id_log_1,'00000001','2025-11-20', 500000.00,1060.00,  471.70,'PROV SIM C','PROV SIM C','ND','0001-00001236','0001-00001236','TALLER SIM','UT02','OBRA',       '6301','C003','NO','FF','OBR SIM 1','GERENCIA SIM',2025,11,'SIM_BaseCostos_202511.xlsx',4,'SIM'),
    (@id_log_2,'00000003','2025-12-05', 180000.00,1100.00,  163.63,'PROV SIM A','PROV SIM A','FC','0001-00001300','0001-00001300','TALLER SIM','UT01','MATERIALES','6101','C001','SI','FF','OBR SIM 3','GERENCIA SIM',2025,12,'SIM_BaseCostos_202512.xlsx',2,'SIM'),
    (@id_log_2,'00000004','2025-12-15', 750000.00,1100.00,  681.81,'PROV SIM D','PROV SIM D','FC','0001-00001301','0001-00001301','TALLER SIM','UT02','OBRA',       '6301','C003','NO','FF','OBR SIM 4','GERENCIA SIM',2025,12,'SIM_BaseCostos_202512.xlsx',3,'SIM');

-- Guardar id del primer costo para las anomalías ML
SET @id_costo_1 = SCOPE_IDENTITY() - 4;  -- primer de los 5 insertados

PRINT CONCAT('   ✓ PRODUCCION.costos: 5 filas (id base: ', @id_costo_1, ')');

-- 1f. Dos rechazos (uno por cada log de costos)
INSERT INTO AUDITORIA.rechazos (id_log_carga, fila_excel, motivo_rechazo, datos_rechazo)
VALUES
    (@id_log_1, 5, 'OBRA_PRONTO no encontrada en CATALOGO.obras', '{"obra":"99999999"}'),
    (@id_log_2, 4, 'IMPORTE supera MAX_IMPORTE',                   '{"importe":200000000000}');
PRINT '   ✓ AUDITORIA.rechazos: 2 filas';

-- 1g. Dos metricas_rendimiento (combinando FKs a log y periodo)
INSERT INTO AUDITORIA.metricas_rendimiento
    (id_log_carga, id_periodo_carga, fase_proceso, tiempo_inicio, tiempo_fin, duracion_milisegundos, registros_procesados)
VALUES
    (@id_log_1, @id_per_1, 'LECTURA_EXCEL',     GETDATE(), GETDATE(), 1200, 100),
    (@id_log_2, @id_per_2, 'INSERT_PRODUCCION', GETDATE(), GETDATE(), 3400, 198);
PRINT '   ✓ AUDITORIA.metricas_rendimiento: 2 filas';

-- 1h. Dos anomalías ML en PRODUCCION.costos + una en otra tabla (aislamiento)
INSERT INTO ML.anomalias_detectadas
    (tabla_origen, id_registro_origen, tipo_anomalia, score_anomalia, descripcion)
VALUES
    ('PRODUCCION.costos',       @id_costo_1,     'Z_SCORE_ALTO', 3.45, 'Importe supera 3 desvíos estándar [SIM]'),
    ('PRODUCCION.costos',       @id_costo_1 + 1, 'OUTLIER_TC',   2.80, 'Tipo de cambio inusual [SIM]'),
    ('PRODUCCION.comprobantes', 99999,            'Z_SCORE_ALTO', 4.10, 'Anomalía en comprobante [SIM — NO debe borrarse]');
PRINT '   ✓ ML.anomalias_detectadas: 3 filas (2 costos + 1 comprobantes)';
PRINT '';

-- ============================================================
-- FASE 2 — Verificar estado ANTES de limpieza (assertions pre)
-- ============================================================
PRINT '── FASE 2: Estado ANTES de limpieza ─────────────────────────';

SET @real = (SELECT COUNT(*) FROM PRODUCCION.costos WHERE usuario_carga = 'SIM');
PRINT CONCAT('   PRODUCCION.costos          (SIM)           = ', @real, '  [esperado: 5]');
IF @real <> 5 BEGIN PRINT '   ❌ FALLO PRE'; SET @ok = 0; END

SET @real = (SELECT COUNT(*) FROM AUDITORIA.log_cargas WHERE tabla_destino = 'PRODUCCION.costos' AND archivo_origen LIKE 'SIM%');
PRINT CONCAT('   AUDITORIA.log_cargas       (SIM costos)    = ', @real, '  [esperado: 2]');
IF @real <> 2 BEGIN PRINT '   ❌ FALLO PRE'; SET @ok = 0; END

SET @real = (SELECT COUNT(*) FROM AUDITORIA.periodos_carga WHERE tabla_destino = 'PRODUCCION.costos' AND periodo_codigo IN ('202511','202512'));
PRINT CONCAT('   AUDITORIA.periodos_carga   (SIM costos)    = ', @real, '  [esperado: 2]');
IF @real <> 2 BEGIN PRINT '   ❌ FALLO PRE'; SET @ok = 0; END

SET @real = (SELECT COUNT(*) FROM AUDITORIA.rechazos WHERE id_log_carga IN (@id_log_1, @id_log_2));
PRINT CONCAT('   AUDITORIA.rechazos         (SIM)           = ', @real, '  [esperado: 2]');
IF @real <> 2 BEGIN PRINT '   ❌ FALLO PRE'; SET @ok = 0; END

SET @real = (SELECT COUNT(*) FROM AUDITORIA.metricas_rendimiento WHERE id_log_carga IN (@id_log_1, @id_log_2));
PRINT CONCAT('   AUDITORIA.metricas_rend.   (SIM)           = ', @real, '  [esperado: 2]');
IF @real <> 2 BEGIN PRINT '   ❌ FALLO PRE'; SET @ok = 0; END

SET @real = (SELECT COUNT(*) FROM ML.anomalias_detectadas WHERE tabla_origen = 'PRODUCCION.costos' AND descripcion LIKE '%[SIM]%');
PRINT CONCAT('   ML.anomalias_detectadas    (SIM costos)    = ', @real, '  [esperado: 2]');
IF @real <> 2 BEGIN PRINT '   ❌ FALLO PRE'; SET @ok = 0; END

SET @real = (SELECT COUNT(*) FROM ML.anomalias_detectadas WHERE tabla_origen = 'PRODUCCION.comprobantes');
PRINT CONCAT('   ML.anomalias               (comprobantes)  = ', @real, '  [esperado: 1 — aislamiento]');
IF @real <> 1 BEGIN PRINT '   ❌ FALLO PRE'; SET @ok = 0; END
PRINT '';

-- ============================================================
-- FASE 3 — Ejecutar la lógica exacta del script de limpieza
-- ============================================================
PRINT '── FASE 3: Ejecutando lógica de limpieza (réplica exacta) ───';

DECLARE @n INT;

-- Paso 1/6: ML anomalías
DELETE FROM ML.anomalias_detectadas WHERE tabla_origen = 'PRODUCCION.costos';
SET @n = @@ROWCOUNT;
PRINT CONCAT('   1/6 ML.anomalias_detectadas eliminadas:          ', @n);

-- Paso 2/6: tabla principal
DELETE FROM PRODUCCION.costos;
SET @n = @@ROWCOUNT;
PRINT CONCAT('   2/6 PRODUCCION.costos eliminadas:                ', @n);

-- Paso 3/6: rechazos vinculados
DELETE FROM AUDITORIA.rechazos
WHERE id_log_carga IN (
    SELECT id_log_carga FROM AUDITORIA.log_cargas WHERE tabla_destino = 'PRODUCCION.costos'
);
SET @n = @@ROWCOUNT;
PRINT CONCAT('   3/6 AUDITORIA.rechazos eliminados:               ', @n);

-- Paso 4/6: metricas_rendimiento vinculadas
DELETE FROM AUDITORIA.metricas_rendimiento
WHERE id_log_carga IN (
    SELECT id_log_carga FROM AUDITORIA.log_cargas WHERE tabla_destino = 'PRODUCCION.costos'
)
OR id_periodo_carga IN (
    SELECT id_periodo_carga FROM AUDITORIA.periodos_carga WHERE tabla_destino = 'PRODUCCION.costos'
);
SET @n = @@ROWCOUNT;
PRINT CONCAT('   4/6 AUDITORIA.metricas_rendimiento eliminadas:   ', @n);

-- Paso 5/6: log_cargas
DELETE FROM AUDITORIA.log_cargas WHERE tabla_destino = 'PRODUCCION.costos';
SET @n = @@ROWCOUNT;
PRINT CONCAT('   5/6 AUDITORIA.log_cargas eliminados:             ', @n);

-- Paso 6/6: periodos_carga (CRÍTICO para recarga incremental)
DELETE FROM AUDITORIA.periodos_carga WHERE tabla_destino = 'PRODUCCION.costos';
SET @n = @@ROWCOUNT;
PRINT CONCAT('   6/6 AUDITORIA.periodos_carga eliminados:         ', @n);
PRINT '';

-- ============================================================
-- FASE 4 — Assertions post-limpieza
-- ============================================================
PRINT '── FASE 4: Verificaciones post-limpieza ─────────────────────';

-- 4a. Tablas objetivo deben estar en 0
SET @real = (SELECT COUNT(*) FROM PRODUCCION.costos);
PRINT CONCAT('   PRODUCCION.costos                          = ', @real, '  [esperado: 0]');
IF @real <> 0 BEGIN PRINT '   ❌ FALLO'; SET @ok = 0; END

SET @real = (SELECT COUNT(*) FROM AUDITORIA.periodos_carga WHERE tabla_destino = 'PRODUCCION.costos');
PRINT CONCAT('   AUDITORIA.periodos_carga  (costos)         = ', @real, '  [esperado: 0]  ← crítico para recarga');
IF @real <> 0 BEGIN PRINT '   ❌ FALLO'; SET @ok = 0; END

SET @real = (SELECT COUNT(*) FROM AUDITORIA.log_cargas WHERE tabla_destino = 'PRODUCCION.costos');
PRINT CONCAT('   AUDITORIA.log_cargas      (costos)         = ', @real, '  [esperado: 0]');
IF @real <> 0 BEGIN PRINT '   ❌ FALLO'; SET @ok = 0; END

SET @real = (SELECT COUNT(*) FROM AUDITORIA.rechazos r
             WHERE r.id_log_carga IN (SELECT id_log_carga FROM AUDITORIA.log_cargas WHERE tabla_destino = 'PRODUCCION.costos'));
PRINT CONCAT('   AUDITORIA.rechazos        (costos)         = ', @real, '  [esperado: 0]');
IF @real <> 0 BEGIN PRINT '   ❌ FALLO'; SET @ok = 0; END

SET @real = (SELECT COUNT(*) FROM ML.anomalias_detectadas WHERE tabla_origen = 'PRODUCCION.costos');
PRINT CONCAT('   ML.anomalias_detectadas   (costos)         = ', @real, '  [esperado: 0]');
IF @real <> 0 BEGIN PRINT '   ❌ FALLO'; SET @ok = 0; END

-- 4b. AISLAMIENTO: datos de otras tablas NO deben tocarse
PRINT '';
PRINT '   -- Aislamiento (datos de otras tablas intactos) -----------';

SET @real = (SELECT COUNT(*) FROM AUDITORIA.log_cargas WHERE id_log_carga = @id_log_otro);
PRINT CONCAT('   log_cargas  comprobantes (id=', @id_log_otro, ')      = ', @real, '  [esperado: 1]');
IF @real <> 1 BEGIN PRINT '   ❌ FALLO AISLAMIENTO'; SET @ok = 0; END

SET @real = (SELECT COUNT(*) FROM AUDITORIA.periodos_carga WHERE id_periodo_carga = @id_per_otro);
PRINT CONCAT('   periodos    comprobantes (id=', @id_per_otro, ')      = ', @real, '  [esperado: 1]');
IF @real <> 1 BEGIN PRINT '   ❌ FALLO AISLAMIENTO'; SET @ok = 0; END

SET @real = (SELECT COUNT(*) FROM ML.anomalias_detectadas WHERE tabla_origen = 'PRODUCCION.comprobantes');
PRINT CONCAT('   ML.anomalias comprobantes                  = ', @real, '  [esperado: 1]');
IF @real <> 1 BEGIN PRINT '   ❌ FALLO AISLAMIENTO'; SET @ok = 0; END
PRINT '';

-- ============================================================
-- RESULTADO FINAL
-- ============================================================
IF @ok = 1
BEGIN
    PRINT '╔══════════════════════════════════════════════════════════════╗';
    PRINT '║  ✅  SIMULACIÓN EXITOSA — Todas las verificaciones pasaron  ║';
    PRINT '║      limpieza_manual_costos.sql funciona correctamente.     ║';
    PRINT '╚══════════════════════════════════════════════════════════════╝';
END
ELSE
BEGIN
    PRINT '╔══════════════════════════════════════════════════════════════╗';
    PRINT '║  ❌  SIMULACIÓN CON ERRORES — Revisar marcas ❌ arriba       ║';
    PRINT '╚══════════════════════════════════════════════════════════════╝';
END

-- SIEMPRE revertir — la base de datos queda exactamente igual que antes
ROLLBACK TRANSACTION sim_limpieza;
PRINT '';
PRINT '↩️  Transacción revertida — Base de datos sin cambios reales.';
GO
