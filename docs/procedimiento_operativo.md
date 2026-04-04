# Procedimiento Operativo — BD_POSE_B52

> **Proyecto:** BD_POSE_B52
> **Repositorio:** `Richard-IA86/BD_POSE_B52`
> **Actualizado:** 2026-03-19

---

## Roles

| Rol | Entorno | Responsabilidad |
|-----|---------|-----------------|
| **Copilot Local** | PC desarrollo (`C:\Dev\BD_POSE_B52`) | Diseño, desarrollo, análisis y **toma de decisiones** |
| **Copilot Servidor** | Servidor (`C:\Dev\BD_POSE_B52`) | Ejecución, documentación de resultados y reporte |

> **Regla fundamental:** El Copilot Servidor **nunca decide** por cuenta propia.
> Solo ejecuta lo que está documentado como instrucción en `estado_implementacion.json`.
> Ante cualquier duda o error inesperado, documenta y espera instrucción del Copilot Local.

---

## Canal de comunicación

Git (`main`) es el único canal entre ambos entornos. Toda instrucción, resultado
y decisión se comunica a través de archivos en el repositorio.

```text
COPILOT LOCAL                   GIT (main)             COPILOT SERVIDOR
─────────────────               ──────────             ────────────────────
1. Diseña / modifica   →push→                  →pull→  2. Lee instrucciones
4. Analiza resultados  ←pull←                  ←push→  3. Ejecuta y documenta
5. Decide próximo paso          │
```text
---

## Ciclo de trabajo

### Paso 1 — Copilot Local prepara instrucción

Antes de cada tarea, el Copilot Local actualiza `estado_implementacion.json` con:

- `fase_actual`: fase en curso
- `siguiente_accion`: descripción exacta de qué ejecutar
- `comandos_a_ejecutar`: lista ordenada de comandos
- `fecha_ultima_actualizacion`: fecha del día

Luego hace commit y push:

```powershell

git add .
git commit -m "instruccion: <descripción breve>"
git push origin main

```text

### Paso 2 — Copilot Servidor recibe y ejecuta

```powershell

cd C:\Dev\BD_POSE_B52
git pull origin main

```text
Lee `estado_implementacion.json`, ejecuta los comandos en el orden indicado
y documenta el resultado en el mismo archivo bajo `ultimo_resultado`.

### Paso 3 — Copilot Servidor reporta

Actualiza `estado_implementacion.json` con:

- `ultimo_resultado.estado`: `OK` | `ERROR` | `ADVERTENCIA`
- `ultimo_resultado.detalle`: descripción de lo ocurrido
- `ultimo_resultado.fecha`: timestamp de ejecución
- `ultimo_resultado.errores`: lista de errores si los hay

Luego hace commit y push:

```powershell

git add estado_implementacion.json
git commit -m "resultado: <descripción breve>"
git push origin main

```text

### Paso 4 — Copilot Local analiza y decide

```powershell

git pull origin main

```text
Lee `estado_implementacion.json`, analiza el resultado y define el próximo paso.
Vuelve al Paso 1.

---

## Protocolo ante errores

Si el Copilot Servidor encuentra un error **no previsto**:

1. **Detener** — no continuar con pasos siguientes
2. **Documentar** en `estado_implementacion.json`:
   - Comando exacto que falló
   - Mensaje de error completo
   - Estado de la base de datos al momento del fallo
3. **Push** del reporte
4. **Esperar** instrucción del Copilot Local

> El Copilot Servidor **no intenta corregir errores** por su cuenta.

---

## Archivos de referencia

| Archivo | Propósito |
|---------|-----------|
| `estado_implementacion.json` | Estado actual + instrucción activa + último resultado |
| `docs/plan_maestro_b52.md` | Diseño completo del DW — fuente de verdad técnica |
| `docs/analisis_implementacion.md` | Brechas identificadas y decisiones tomadas |
| `docs/git_instructivo_basico.md` | Comandos git de inicio/cierre de jornada |
| `docs/instructivo_clonacion_server.md` | Setup inicial del servidor (ejecutar una sola vez) |

---

## Convenciones de commit

| Prefijo | Quién | Cuándo |
|---------|-------|--------|
| `instruccion:` | Copilot Local | Al preparar una tarea para el servidor |
| `resultado:` | Copilot Servidor | Al reportar ejecución completada |
| `fix:` | Cualquiera | Corrección de bug |
| `feat:` | Copilot Local | Nuevo script o funcionalidad |
| `docs:` | Cualquiera | Cambios en documentación |
| `config:` | Cualquiera | Cambios en configuración |
