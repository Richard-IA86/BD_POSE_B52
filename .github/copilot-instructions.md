# Principio Operativo #1 — NO NEGOCIABLE

> **"Diagnósticos cortos, claros, breves y efectivos."**

- Ver el error → identificar archivo/línea → fix → verificar. Una pasada.
- Si el mismo análisis se repite: parar, cambiar enfoque.
- **"Tenemos que salir de la rotonda."**

---

# Flujo Sauron / M2 — Referencia

- **Sauron (Hetzner/M3):** diseña, escribe scripts, ejecuta CI/CD, hace commit + push. M1 iMac FUERA DE SERVICIO.
- **M2 (Asus/Windows):** ejecuta scripts SQL contra SQL Server, carga datos,
  documenta `ultimo_resultado` en `estado_proyecto.json`, hace commit + push
  de logs/estado.
- Scripts SQL → ejecutar siempre en M2 (SQL Server `RICHARD_ASUS\SQLEXPRESS`).
- `pytest` → se puede ejecutar en M2 o en Hetzner/M3.

---

# Instrucciones Copilot — bd_pose_b52

## Protocolo de Scripts Temporales — Obligatorio

Cuando crees un script Python (.py) u otro archivo para un fin
puntual (diagnóstico, análisis, escaneo, verificación, depuración,
benchmark, extracción de datos), aplica este ciclo:

### Opción A — fuera del proyecto (PREFERIDA)

1. Crea el script en `/tmp/` → `python /tmp/_temp_check.py`
2. Ejecuta y procesa la salida.
3. El archivo desaparece solo al cerrar sesión.

### Opción B — dentro del proyecto (solo si es estrictamente necesario)

1. Usa el prefijo obligatorio `_temp_` → `_temp_analisis.py`
2. Ejecuta: `python _temp_analisis.py`
3. Elimínalo inmediatamente: `rm _temp_analisis.py`
4. NUNCA hagas `git add` sobre archivos `_temp_*.py`.

### Patrones de nombre = script efímero (aplica el protocolo)

`debug_*`, `diagnostico_*`, `analisis_*`, `analizar_*`,
`analyze_*`, `scan_*`, `verificar_*`, `prueba_*`,
`test_fix_*`, `benchmark_*`, `extract_*` (cuando no es módulo).

## Estándares de Código Python — Obligatorios

El pipeline QA usa **black** + **flake8** + **mypy**
(`max-line-length = 79`, `extend-ignore = E203, W503`).
Todo código generado debe pasar sin errores ni advertencias.

### Longitud de línea (E501) — MÁX. 79 caracteres

- Llamadas largas → paréntesis implícitos (NO usar `\`):

  ```python
  resultado = funcion_larga(
      arg1, arg2, arg3,
  )
  ```

- Docstrings y comentarios → cortar en la palabra antes de la col 79.
- f-strings y literales largas → concatenación implícita en paréntesis:

  ```python
  mensaje = (
      f"Primera parte {var}"
      " segunda parte fija"
  )
  ```

- SQL multilínea → triple-quote con indentación.
- `# noqa: E501` SOLO cuando el corte destruye semántica (URL, regex).
- NUNCA añadir `# noqa: E501` a comentarios o docstrings — cortarlos.

### f-strings vacíos (F541)

- NUNCA: `f"texto sin llaves"` → usar: `"texto sin llaves"`.
- Un f-string DEBE contener al menos un `{placeholder}`.

### Variables sin usar (F841)

- NUNCA asignar una variable que no se lee después.
- Resultados descartados intencionalmente → prefijo `_`:
  `_ok = funcion_con_efectos()`

### Tipado mypy — anotaciones correctas

- Dicts con valores mixtos → `resultado: dict[str, Any]`
  (importar siempre `from typing import Any`).
- `dict.get("k")` → anotar la variable destino como `T | None`.
- `sys.stdout.reconfigure(...)` → añadir `# type: ignore[union-attr]`.
- `wb.sheetnames` (openpyxl) → `list(wb.sheetnames)`.

### Imports y nombres de módulos

- Módulos Python siempre en `snake_case`: `validador_a4`, no `validador_A4`.
- Imports no usados → eliminar (no `# noqa: F401` salvo en bloques
  `try/except` que verifican disponibilidad de dependencias opcionales).
