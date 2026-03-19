# Instructivo — Clonación en Servidor

> **Proyecto:** BD_POSE_B52  
> **Repositorio:** `Richard-IA86/BD_POSE_B52`  
> **Instancia SQL:** `DEV-DIRECTORIO\SQLEXPRESS` — Windows Auth  
> **Actualizado:** 2026-03-19

Ejecutar **una sola vez** al configurar el servidor por primera vez.

---

## Paso 1 — Verificar Git

**App:** PowerShell (como Administrador)

```powershell
git --version
```

**Resultado esperado:** `git version 2.x.x`  
**Si no está instalado:** descargar e instalar desde `https://git-scm.com/download/win`, reiniciar PowerShell y repetir.

---

## Paso 2 — Verificar Python 3.9+

**App:** PowerShell

```powershell
python --version
```

**Resultado esperado:** `Python 3.9.x` o superior  
**Si no está instalado:** descargar desde `https://www.python.org/downloads/`, marcar **"Add Python to PATH"** durante la instalación, reiniciar PowerShell y repetir.

---

## Paso 3 — Clonar el repositorio

**App:** PowerShell

```powershell
cd C:\Dev
git clone https://github.com/Richard-IA86/BD_POSE_B52.git
cd BD_POSE_B52
```

**Resultado esperado:** carpeta `C:\Dev\BD_POSE_B52` creada con todos los archivos del proyecto.

---

## Paso 4 — Ejecutar el setup (una sola vez)

**App:** PowerShell (desde `C:\Dev\BD_POSE_B52`)

```powershell
.\setup_servidor.bat
```

El script realiza automáticamente:
- Verifica Python
- Crea el entorno virtual `.venv`
- Instala dependencias (`pandas`, `pyodbc`, `openpyxl`, `psutil`)
- Crea carpetas de trabajo (`00_logs\`, `01_input_raw\`, `03_output\`)
- Genera `config\conexion.json` desde el template
- Ejecuta el validador de prerequisitos

**Resultado esperado al finalizar:**
```text
============================================================
  SETUP COMPLETADO
============================================================
```

---

## Paso 5 — Verificar config\conexion.json

**App:** Bloc de notas / VS Code

```powershell
notepad config\conexion.json
```

Confirmar que el archivo contiene:

```json
{
  "server": "DEV-DIRECTORIO\\SQLEXPRESS"
}
```

> El setup crea este archivo automáticamente desde el template con el valor correcto. Solo verificar — normalmente no requiere edición.

---

## Paso 6 — Verificar conexión SQL Server

**App:** PowerShell (con `.venv` activado)

```powershell
.venv\Scripts\activate
python 02_scripts\python\validaciones\00_validar_prerequisitos.py
```

**Resultado esperado:**
```text
[OK] Python OK
[OK] Driver ODBC detectado: ODBC Driver XX for SQL Server
[OK] Conexion SQL Server exitosa: DEV-DIRECTORIO\SQLEXPRESS
[OK] Espacio en disco suficiente
```

**Si falla la conexión SQL:** verificar que el servicio `SQLEXPRESS` esté corriendo en el servidor:
```powershell
Get-Service -Name 'MSSQL$SQLEXPRESS'
```

---

## Verificación final — estado del entorno

**App:** PowerShell

```powershell
git status
git log --oneline -3
```

**Resultado esperado:**
```text
On branch main
Your branch is up to date with 'origin/main'.
nothing to commit, working tree clean
```

---

## Flujo de actualización diaria (post-clonación)

Una vez configurado el servidor, las actualizaciones son un solo comando:

```powershell
cd C:\Dev\BD_POSE_B52
git pull origin main
```

> Todo el desarrollo se hace en la **PC local**. El servidor solo ejecuta `git pull`.

---

## Resumen de apps utilizadas

| Paso | App | Acción |
|------|-----|--------|
| 1 | PowerShell (Admin) | Verificar Git |
| 2 | PowerShell | Verificar Python |
| 3 | PowerShell | Clonar repo |
| 4 | PowerShell | Ejecutar `setup_servidor.bat` |
| 5 | Bloc de notas / VS Code | Verificar `conexion.json` |
| 6 | PowerShell | Validar conexión SQL Server |
| Diario | PowerShell | `git pull origin main` |
