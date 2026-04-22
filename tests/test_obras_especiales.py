"""
Tests unitarios para utils/obras_especiales.py

Cubre:
  - leer_obras_config(): lectura valida, archivo ausente, campo faltante
  - upsert_gerencia(): inserta nueva, retorna existente
  - upsert_obra(): inserta nueva, idempotente si existe
  - insertar_obras_especiales(): integracion con BD simulada
"""

import json
import pytest
from unittest.mock import MagicMock

from utils.obras_especiales import (
    leer_obras_config,
    upsert_gerencia,
    upsert_obra,
    insertar_obras_especiales,
)

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

_OBRAS_VALIDAS = [
    {
        "obra_pronto": "SIN OBRA",
        "descripcion_obra": "SIN OBRA ASIGNADA",
        "gerencia": "SIN OBRA ASIGNADA",
        "nota": "test",
    },
    {
        "obra_pronto": "IMPUESTOS",
        "descripcion_obra": "IMPUESTOS",
        "gerencia": "ADMINISTRACION",
        "nota": "test",
    },
]


@pytest.fixture
def config_tmp(tmp_path):
    """Crea un obras_especiales.json temporal valido."""
    f = tmp_path / "obras_especiales.json"
    f.write_text(
        json.dumps({"obras": _OBRAS_VALIDAS}),
        encoding="utf-8",
    )
    return f


# ---------------------------------------------------------------------------
# leer_obras_config
# ---------------------------------------------------------------------------


class TestLeerObrasConfig:
    def test_lee_obras_validas(self, config_tmp):
        obras = leer_obras_config(config_tmp)
        assert len(obras) == 2
        assert obras[0]["obra_pronto"] == "SIN OBRA"
        assert obras[1]["gerencia"] == "ADMINISTRACION"

    def test_archivo_ausente_lanza_error(self, tmp_path):
        no_existe = tmp_path / "no_existe.json"
        with pytest.raises(FileNotFoundError):
            leer_obras_config(no_existe)

    def test_obras_vacias_lanza_error(self, tmp_path):
        f = tmp_path / "vacio.json"
        f.write_text(json.dumps({"obras": []}), encoding="utf-8")
        with pytest.raises(ValueError, match="no contiene obras"):
            leer_obras_config(f)

    def test_campo_faltante_lanza_error(self, tmp_path):
        f = tmp_path / "incompleto.json"
        f.write_text(
            json.dumps({"obras": [{"obra_pronto": "X"}]}),
            encoding="utf-8",
        )
        with pytest.raises(ValueError, match="campos requeridos"):
            leer_obras_config(f)

    def test_tres_campos_minimos_presentes(self, config_tmp):
        obras = leer_obras_config(config_tmp)
        for o in obras:
            assert "obra_pronto" in o
            assert "descripcion_obra" in o
            assert "gerencia" in o


# ---------------------------------------------------------------------------
# upsert_gerencia
# ---------------------------------------------------------------------------


class TestUpsertGerencia:
    def test_inserta_si_no_existe(self):
        cursor = MagicMock()
        # SELECT -> None (no existe); INSERT; SELECT -> (42,)
        cursor.fetchone.side_effect = [None, (42,)]
        id_g = upsert_gerencia(cursor, "NUEVA GERENCIA")
        assert id_g == 42
        calls_sql = [str(c.args[0]) for c in cursor.execute.call_args_list]
        assert any("INSERT" in s for s in calls_sql)

    def test_retorna_existente_sin_insertar(self):
        cursor = MagicMock()
        cursor.fetchone.return_value = (7,)
        id_g = upsert_gerencia(cursor, "ADMINISTRACION")
        assert id_g == 7
        assert cursor.execute.call_count == 1

    def test_normaliza_a_mayusculas(self):
        cursor = MagicMock()
        cursor.fetchone.return_value = (3,)
        upsert_gerencia(cursor, "  administracion  ")
        primer_call = cursor.execute.call_args_list[0]
        assert "ADMINISTRACION" in str(primer_call)

    def test_lanza_error_si_post_insert_devuelve_none(self):
        cursor = MagicMock()
        # SELECT -> None; INSERT; SELECT post-insert -> None (error)
        cursor.fetchone.side_effect = [None, None]
        with pytest.raises(RuntimeError, match="id_gerencia"):
            upsert_gerencia(cursor, "FALLA")


# ---------------------------------------------------------------------------
# upsert_obra
# ---------------------------------------------------------------------------


class TestUpsertObra:
    def test_inserta_si_no_existe(self):
        cursor = MagicMock()
        cursor.fetchone.return_value = None
        upsert_obra(cursor, "SIN OBRA", "SIN OBRA ASIGNADA", 5)
        calls_sql = [str(c.args[0]) for c in cursor.execute.call_args_list]
        assert any("INSERT" in s for s in calls_sql)

    def test_no_inserta_si_existe(self):
        cursor = MagicMock()
        cursor.fetchone.return_value = (99,)
        upsert_obra(cursor, "IMPUESTOS", "IMPUESTOS", 3)
        calls_sql = [str(c.args[0]) for c in cursor.execute.call_args_list]
        assert not any("INSERT" in s for s in calls_sql)

    def test_strips_obra_pronto(self):
        cursor = MagicMock()
        cursor.fetchone.return_value = (10,)
        upsert_obra(cursor, "  ACTIVOS PERON  ", "ACTIVOS PERON", 2)
        # Solo SELECT, el valor debe estar strip-eado
        call_str = str(cursor.execute.call_args_list[0])
        assert "ACTIVOS PERON" in call_str
        assert "  " not in call_str.split("(")[1][:30]


# ---------------------------------------------------------------------------
# insertar_obras_especiales (integracion con BD mock)
# ---------------------------------------------------------------------------


class TestInsertarObrasEspeciales:
    def test_retorna_cantidad_obras(self, config_tmp):
        conn = MagicMock()
        cursor = MagicMock()
        conn.cursor.return_value = cursor
        # gerencia SIN OBRA ASIGNADA: no existe -> (1,)
        # obra SIN OBRA: no existe
        # gerencia ADMINISTRACION: no existe -> (2,)
        # obra IMPUESTOS: no existe
        cursor.fetchone.side_effect = [
            None,
            (1,),
            None,
            None,
            (2,),
            None,
        ]
        total = insertar_obras_especiales(conn, config_tmp)
        assert total == 2
        conn.commit.assert_called_once()

    def test_idempotente_si_todo_existe(self, config_tmp):
        conn = MagicMock()
        cursor = MagicMock()
        conn.cursor.return_value = cursor
        cursor.fetchone.return_value = (99,)
        total = insertar_obras_especiales(conn, config_tmp)
        assert total == 2
        calls_sql = [str(c.args[0]) for c in cursor.execute.call_args_list]
        assert not any("INSERT" in s for s in calls_sql)
        conn.commit.assert_called_once()

    def test_config_invalido_lanza_error(self, tmp_path):
        conn = MagicMock()
        no_existe = tmp_path / "no_existe.json"
        with pytest.raises(FileNotFoundError):
            insertar_obras_especiales(conn, no_existe)
