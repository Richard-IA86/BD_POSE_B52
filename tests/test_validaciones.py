"""
Pruebas unitarias para el módulo validaciones.py de bd_pose_b52.
"""

import pytest
import pandas as pd

from utils.validaciones import (
    validar_schema_costos,
    validar_schema_comprobantes,
    validar_obras_en_datos,
)


@pytest.fixture
def base_costos():
    return pd.DataFrame(
        {
            "FECHA": ["2026-01-01", "2026-02-01"],
            "OBRA_PRONTO": ["OBRA_01", "OBRA_02"],
            "IMPORTE": [100.0, 200.0],
            "anio_dato": [2026, 2026],
            "mes_dato": [1, 2],
            "periodo_codigo": ["202601", "202602"],
        }
    )


@pytest.fixture
def base_comprobantes():
    return pd.DataFrame(
        {
            "FECHA_COMPROBANTE": ["2026-01-15", "2026-02-15"],
            "NRO_COMPROBANTE": ["FC-001", "FC-002"],
            "IMPORTE": [500.0, 1000.0],
            "anio_dato": [2026, 2026],
        }
    )


class TestValidarSchemaCostos:
    def test_esquema_valido(self, base_costos):
        """Verifica que un DataFrame ideal devuelva lo mismo."""
        df_out = validar_schema_costos(base_costos)
        assert len(df_out) == 2
        assert list(df_out.columns) == list(base_costos.columns)

    def test_falta_columna_lanza_error(self, base_costos):
        """Verifica ValueError si falta una columna requerida."""
        df_incompleto = base_costos.drop(columns=["periodo_codigo"])
        with pytest.raises(ValueError, match="periodo_codigo"):
            validar_schema_costos(df_incompleto)

    def test_mes_dato_fuera_de_rango(self, base_costos):
        """Verifica ValueError si el mes no está entre 1 y 12."""
        df_malo = base_costos.copy()
        df_malo.loc[0, "mes_dato"] = 13
        with pytest.raises(ValueError, match="mes_dato fuera de rango"):
            validar_schema_costos(df_malo)

    def test_descarta_nulos(self, base_costos):
        """Verifica limpieza de nulos en clave FECHA, IMPORTE o OBRA_PRONTO."""
        df_con_nulos = pd.concat(
            [
                base_costos,
                pd.DataFrame(
                    {
                        "FECHA": [None],
                        "OBRA_PRONTO": ["OBRA_03"],
                        "IMPORTE": [300.0],
                        "anio_dato": [2026],
                        "mes_dato": [3],
                        "periodo_codigo": ["202603"],
                    }
                ),
            ],
            ignore_index=True,
        )
        df_out = validar_schema_costos(df_con_nulos)
        # La fila 3 (nula en FECHA) debería haber sido eliminada
        assert len(df_out) == 2


class TestValidarSchemaComprobantes:
    def test_esquema_valido(self, base_comprobantes):
        df_out = validar_schema_comprobantes(base_comprobantes)
        assert len(df_out) == 2

    def test_falta_columna_lanza_error(self, base_comprobantes):
        df_incompleto = base_comprobantes.drop(columns=["FECHA_COMPROBANTE"])
        with pytest.raises(ValueError, match="FECHA_COMPROBANTE"):
            validar_schema_comprobantes(df_incompleto)

    def test_descarta_nulos(self, base_comprobantes):
        df_con_nulos = base_comprobantes.copy()
        df_con_nulos.loc[1, "NRO_COMPROBANTE"] = None
        df_out = validar_schema_comprobantes(df_con_nulos)
        # La fila con nulo se borra, debe quedar 1
        assert len(df_out) == 1


# ---------------------------------------------------------------------------
# TestValidarObrasEnDatos
# ---------------------------------------------------------------------------


class TestValidarObrasEnDatos:
    def test_pasa_si_todas_mapeadas(self):
        catalogo = {"OBRA_01", "OBRA_02", "OBRA_03"}
        df = pd.DataFrame({"OBRA_PRONTO": ["OBRA_01", "OBRA_02", "OBRA_01"]})
        validar_obras_en_datos(catalogo, df)  # no debe lanzar

    def test_aborta_si_hay_faltantes(self):
        catalogo = {"OBRA_01"}
        df = pd.DataFrame({"OBRA_PRONTO": ["OBRA_01", "SIN OBRA"] * 5})
        with pytest.raises(ValueError, match="ABORT"):
            validar_obras_en_datos(catalogo, df)

    def test_reporte_incluye_conteo_filas(self):
        catalogo = {"OBRA_01"}
        df = pd.DataFrame({"OBRA_PRONTO": ["SIN OBRA"] * 3 + ["OBRA_01"]})
        with pytest.raises(ValueError, match="3"):
            validar_obras_en_datos(catalogo, df)

    def test_multiples_obras_faltantes(self):
        catalogo = {"OBRA_01"}
        df = pd.DataFrame(
            {"OBRA_PRONTO": ["SIN OBRA", "IMPUESTOS", "OBRA_01"]}
        )
        with pytest.raises(ValueError, match="2"):
            validar_obras_en_datos(catalogo, df)

    def test_ignora_nulos_y_vacios(self):
        catalogo = {"OBRA_01"}
        df = pd.DataFrame({"OBRA_PRONTO": ["OBRA_01", None, ""]})
        validar_obras_en_datos(catalogo, df)  # no debe lanzar

    def test_sin_columna_obra_pronto_no_lanza(self):
        catalogo: set[str] = set()
        df = pd.DataFrame({"OTRA_COL": [1, 2, 3]})
        validar_obras_en_datos(catalogo, df)  # no debe lanzar

    def test_catalogo_vacio_aborta(self):
        catalogo: set[str] = set()
        df = pd.DataFrame({"OBRA_PRONTO": ["OBRA_01"]})
        with pytest.raises(ValueError, match="ABORT"):
            validar_obras_en_datos(catalogo, df)
