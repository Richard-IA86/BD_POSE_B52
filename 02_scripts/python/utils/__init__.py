# utils/__init__.py
try:
    from .conexion import get_connection  # noqa: F401
    from .auditoria_incremental import (  # noqa: F401
        registrar_inicio,
        registrar_fin,
        registrar_inicio_periodo,
        registrar_fin_periodo,
        verificar_procesado_periodo,
    )

    _PYODBC_DISPONIBLE = True
except ImportError:
    _PYODBC_DISPONIBLE = False

from .metricas_rendimiento import MedidorRendimiento  # noqa: F401
from .validaciones import (  # noqa: F401
    validar_schema_costos,
    validar_schema_comprobantes,
)
