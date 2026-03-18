"""
metricas_rendimiento.py — Medición de tiempos y recursos para scripts B52.
"""
import time
import logging
from typing import Optional

try:
    import psutil
    _PSUTIL = True
except ImportError:
    _PSUTIL = False


class MedidorRendimiento:
    """Mide duración por fases y calcula velocidad de inserción."""

    def __init__(self, nombre: str) -> None:
        self.nombre = nombre
        self._inicio: Optional[float] = None
        self._fases: dict[str, float] = {}
        self._fase_actual: Optional[str] = None
        self.duracion_total: float = 0.0

    # ------------------------------------------------------------------
    def iniciar(self) -> None:
        self._inicio = time.perf_counter()
        logging.debug("[Medidor:%s] inicio", self.nombre)

    def marcar_fase(self, nombre_fase: str) -> None:
        ahora = time.perf_counter()
        if self._fase_actual:
            elapsed = ahora - self._fases.get(f"_ini_{self._fase_actual}", ahora)
            self._fases[self._fase_actual] = elapsed
            logging.debug("[Medidor:%s] fase '%s' = %.2fs", self.nombre, self._fase_actual, elapsed)
        self._fase_actual = nombre_fase
        self._fases[f"_ini_{nombre_fase}"] = ahora

    def finalizar(self) -> None:
        ahora = time.perf_counter()
        if self._fase_actual:
            elapsed = ahora - self._fases.get(f"_ini_{self._fase_actual}", ahora)
            self._fases[self._fase_actual] = elapsed
        self.duracion_total = ahora - (self._inicio or ahora)
        logging.debug("[Medidor:%s] total = %.2fs", self.nombre, self.duracion_total)

    # ------------------------------------------------------------------
    @property
    def velocidad_registros_seg(self) -> float:
        """Registros por segundo de la fase INSERT (si existe)."""
        return 0.0  # Se calcula externamente con total_insertados / duracion_total

    def calcular_velocidad(self, total_registros: int) -> float:
        if self.duracion_total > 0:
            return total_registros / self.duracion_total
        return 0.0

    def memoria_mb(self) -> Optional[float]:
        if _PSUTIL:
            try:
                import os
                proc = psutil.Process(os.getpid())
                return proc.memory_info().rss / 1_048_576
            except Exception:
                pass
        return None

    def imprimir_resumen(self) -> None:
        print(f"\n  ⏱️  Resumen Medidor [{self.nombre}]")
        print(f"     Duración total : {self.duracion_total:.2f}s")
        fases_limpias = {k: v for k, v in self._fases.items() if not k.startswith("_ini_")}
        for fase, dur in fases_limpias.items():
            print(f"     Fase {fase:<18}: {dur:.2f}s")
        mem = self.memoria_mb()
        if mem is not None:
            print(f"     Memoria uso    : {mem:.1f} MB")
