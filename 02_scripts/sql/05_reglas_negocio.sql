-- =============================================================================
-- 05_reglas_negocio.sql
-- Motor de reglas de negocio para enriquecimiento ETL en PostgreSQL
-- Schema: CATALOGO | Proyecto: BD_POSE_B52
-- Autor: Richard IA86 | Sprint A — 2026-05-07
-- =============================================================================
-- Propósito:
--   Centraliza las reglas de mapeo/corrección que hoy viven en Loockups.xlsx
--   y en código Python hardcodeado. La API FastAPI consulta estas tablas para
--   enriquecer los datos del pipeline ETL antes de persistir en PRODUCCION.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tabla principal de reglas
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS CATALOGO.reglas_negocio (
    id              SERIAL          PRIMARY KEY,
    tipo_regla      VARCHAR(50)     NOT NULL,
    -- Ejemplos: GERENCIA_EQUIV | TIPO_CAMBIO | EXCEPCION_GERENCIA | OBRA_MAPEO

    clave           VARCHAR(200)    NOT NULL,
    -- Valor de entrada sobre el que aplica la regla (ej: nombre de gerencia)

    valor           VARCHAR(500)    NOT NULL,
    -- Valor de salida / resultado de la regla

    descripcion     VARCHAR(500),
    -- Texto libre para documentar el motivo de la regla

    activo          BOOLEAN         NOT NULL DEFAULT TRUE,
    fecha_desde     DATE,
    fecha_hasta     DATE,
    -- NULL en fecha_hasta = sin vencimiento (regla permanente)

    fuente          VARCHAR(100)    DEFAULT 'manual',
    -- Origen: 'manual' | 'Loockups_xlsx' | 'api' | 'etl'

    creado_en       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    actualizado_en  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_regla_tipo_clave
        UNIQUE (tipo_regla, clave, fecha_desde)
);

COMMENT ON TABLE CATALOGO.reglas_negocio IS
    'Motor de reglas de negocio centralizadas para el pipeline ETL POSE. '
    'Reemplaza las reglas dispersas en Loockups.xlsx y código Python.';

-- -----------------------------------------------------------------------------
-- 2. Índices de soporte para consultas frecuentes de la API
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_rn_tipo_activo
    ON CATALOGO.reglas_negocio (tipo_regla, activo);

CREATE INDEX IF NOT EXISTS idx_rn_tipo_clave
    ON CATALOGO.reglas_negocio (tipo_regla, clave);

-- -----------------------------------------------------------------------------
-- 3. Semilla inicial — 2 reglas de ejemplo por tipo
-- -----------------------------------------------------------------------------
INSERT INTO CATALOGO.reglas_negocio
    (tipo_regla, clave, valor, descripcion, activo, fuente)
VALUES
    (
        'GERENCIA_EQUIV',
        'GERENCIA OBRAS',
        'OBRAS',
        'Equivalencia estándar para agrupación de reportes',
        TRUE,
        'Loockups_xlsx'
    ),
    (
        'GERENCIA_EQUIV',
        'GERENCIA MANTENIMIENTO',
        'MANTENIMIENTO',
        'Equivalencia estándar para agrupación de reportes',
        TRUE,
        'Loockups_xlsx'
    ),
    (
        'OBRA_MAPEO',
        '00000001',
        'OBRA PILOTO B52',
        'Mapeo inicial de obra de prueba',
        TRUE,
        'manual'
    ),
    (
        'EXCEPCION_GERENCIA',
        '00000099',
        'SIN_GERENCIA',
        'Obra sin asignación de gerencia — excluir de totales',
        TRUE,
        'manual'
    )
ON CONFLICT (tipo_regla, clave, fecha_desde) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 4. Vista de consulta rápida para la API
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW CATALOGO.v_reglas_vigentes AS
SELECT
    id,
    tipo_regla,
    clave,
    valor,
    descripcion,
    fuente,
    creado_en
FROM CATALOGO.reglas_negocio
WHERE
    activo = TRUE
    AND (fecha_desde IS NULL OR fecha_desde <= CURRENT_DATE)
    AND (fecha_hasta IS NULL OR fecha_hasta >= CURRENT_DATE);

COMMENT ON VIEW CATALOGO.v_reglas_vigentes IS
    'Reglas de negocio activas y vigentes a la fecha de consulta.';
