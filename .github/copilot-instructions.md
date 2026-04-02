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
