# GIT — Instructivo de Administración Básica

> **Proyecto:** BD_POSE_B52  
> **Repositorio:** `Richard-IA86/BD_POSE_B52`  
> **Rama principal:** `main`  
> **Actualizado:** 2026-03-19

---

## ¿Por qué seguir este instructivo?

Ejecutar estos pasos al inicio y al cierre de cada jornada garantiza que:

- El repositorio local y el remoto (GitHub) estén siempre sincronizados.
- No se pierdan cambios por olvido de commit o push.
- El historial sea limpio y trazable.

---

## ✅ Checklist — INICIO de jornada

Ejecutar **antes** de comenzar a trabajar.

```powershell
# 1. Moverse a la carpeta del proyecto
cd C:\Dev\BD_POSE_B52

# 2. Verificar el estado actual del repositorio
git status

# 3. Obtener los últimos cambios del repositorio remoto
git pull origin main

# 4. Confirmar en qué rama estás trabajando
git branch
```

### ¿Qué esperar en cada paso?

| Paso | Resultado esperado |
|------|--------------------|
| `git status` | `nothing to commit, working tree clean` (si no quedaron cambios pendientes de la jornada anterior) |
| `git pull` | `Already up to date.` (si no hay cambios nuevos en remoto) o una lista de archivos actualizados |
| `git branch` | El asterisco `*` debe estar sobre `main` |

---

## ✅ Checklist — CIERRE de jornada

Ejecutar **antes** de cerrar VS Code o terminar el trabajo del día.

```powershell
# 1. Revisar todos los archivos modificados o nuevos
git status

# 2. Agregar todos los cambios al área de preparación (staging)
git add .

#    — O bien, agregar solo archivos específicos —
git add ruta/al/archivo.py

# 3. Confirmar los cambios con un mensaje descriptivo
git commit -m "descripción breve y clara de lo hecho"

# 4. Subir los cambios al repositorio remoto
git push origin main

# 5. Verificar que quedó todo limpio
git status
```

### Buenas prácticas para el mensaje de commit

```
# ✔ Mensajes claros y en tiempo presente
git commit -m "Agrega script de carga de catálogos B52"
git commit -m "Corrige cálculo de costos en cargar_costos_b52"
git commit -m "Actualiza README con instrucciones de configuración"

# ✖ Evitar mensajes vagos
git commit -m "cambios"
git commit -m "arreglos varios"
git commit -m "wip"
```

---

## 📋 Referencia rápida de comandos

| Comando | ¿Para qué sirve? |
|---------|-----------------|
| `git status` | Ver archivos modificados, nuevos o eliminados |
| `git log --oneline -10` | Ver los últimos 10 commits del historial |
| `git diff` | Ver las diferencias en los archivos modificados antes de hacer commit |
| `git add .` | Agregar todos los cambios al staging |
| `git add <archivo>` | Agregar un archivo específico al staging |
| `git commit -m "msg"` | Guardar los cambios con un mensaje |
| `git push origin main` | Subir commits al repositorio remoto |
| `git pull origin main` | Bajar cambios del repositorio remoto |
| `git restore <archivo>` | Descartar cambios locales en un archivo (irreversible) |
| `git restore --staged <archivo>` | Sacar un archivo del staging sin perder los cambios |

---

## ⚠️ Situaciones comunes y cómo resolverlas

### "Me pide credenciales al hacer push"
```powershell
# Verificar que el remoto esté configurado con HTTPS o SSH
git remote -v
```
Si es HTTPS, usar un **Personal Access Token (PAT)** de GitHub como contraseña.

---

### "Hice commit pero me olvidé de agregar un archivo"
```powershell
# Agrega el archivo olvidado y corrije el último commit sin crear uno nuevo
git add archivo_olvidado.py
git commit --amend --no-edit
```
> Solo usar `--amend` si aún **no hiciste push**. Si ya subiste el commit, crear uno nuevo.

---

### "Quiero ver qué cambié antes de hacer commit"
```powershell
git diff
# Para ver los archivos en staging
git diff --staged
```

---

### "Quiero deshacer el último commit (sin perder los cambios)"
```powershell
git reset --soft HEAD~1
```

---

## 📌 Próximos pasos sugeridos

Cuando el proyecto crezca o trabajes en múltiples funcionalidades en paralelo, considerar adoptar una estrategia de ramas:

```
main          ← versión estable
└── feature/nombre-tarea   ← desarrollo de cada tarea nueva
```

Se documentará en este instructivo cuando se defina la estrategia.

---

*Instructivo generado para uso interno del proyecto.*
