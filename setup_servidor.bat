@echo off
:: ============================================================
:: setup_servidor.bat — Zero-Setup para BD_POSE_B52
:: Ejecutar UNA VEZ después de clonar el repositorio.
:: Compatible con Windows Server 2019/2022 y Windows 10/11.
:: ============================================================
setlocal EnableDelayedExpansion

:: Directorio raíz = ubicación de este .bat (sin importar dónde se clonó)
set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"

echo.
echo ============================================================
echo   SETUP BD_POSE_B52
echo   Raiz detectada: %ROOT%
echo ============================================================
echo.

:: ── 1. Verificar Python 3.9+ ─────────────────────────────────
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python no encontrado en PATH.
    echo         Instalar Python 3.9+ desde https://www.python.org y reintentar.
    pause & exit /b 1
)
for /f "tokens=2" %%v in ('python --version 2^>^&1') do set PY_VER=%%v
echo [OK] Python %PY_VER% detectado.

:: ── 2. Crear entorno virtual ──────────────────────────────────
if exist "%ROOT%\.venv\Scripts\activate.bat" (
    echo [OK] Entorno virtual ya existe. Omitiendo creacion.
) else (
    echo [..] Creando entorno virtual .venv ...
    python -m venv "%ROOT%\.venv"
    if errorlevel 1 ( echo [ERROR] Fallo al crear .venv. & pause & exit /b 1 )
    echo [OK] Entorno virtual creado.
)

:: ── 3. Instalar dependencias ──────────────────────────────────
echo [..] Instalando dependencias desde requirements_B52.txt ...
call "%ROOT%\.venv\Scripts\activate.bat"
pip install --quiet --upgrade pip
pip install --quiet -r "%ROOT%\requirements_B52.txt"
if errorlevel 1 ( echo [ERROR] Fallo al instalar dependencias. & pause & exit /b 1 )
echo [OK] Dependencias instaladas.

:: ── 4. Crear carpetas de trabajo (ignoradas en Git) ───────────
if not exist "%ROOT%\00_logs"      mkdir "%ROOT%\00_logs"
if not exist "%ROOT%\01_input_raw" mkdir "%ROOT%\01_input_raw"
if not exist "%ROOT%\03_output"    mkdir "%ROOT%\03_output"
echo [OK] Carpetas de trabajo listas.

:: ── 4b. Generar config/conexion.json si no existe ──────────────
if not exist "%ROOT%\config\conexion.json" (
    copy "%ROOT%\config\conexion.template.json" "%ROOT%\config\conexion.json" >nul
    echo [OK] config\conexion.json creado desde template.
    echo.
    echo [AVISO] Verifica el valor de "server" en:
    echo         %ROOT%\config\conexion.json
    echo         Instancia detectada por defecto: DEV-DIRECTORIO\SQLEXPRESS
    echo.
) else (
    echo [OK] config\conexion.json ya existe.
)

:: ── 5. Validar prerequisitos (SQL Server, drivers, espacio) ───
echo.
echo [..] Ejecutando validador de prerequisitos ...
python "%ROOT%\02_scripts\python\validaciones\00_validar_prerequisitos.py"
if errorlevel 1 (
    echo.
    echo [AVISO] Algunos prerequisitos fallaron. Revisar mensajes arriba.
    echo         El entorno Python quedo instalado correctamente.
    pause & exit /b 1
)

echo.
echo ============================================================
echo   SETUP COMPLETADO
echo   Proximos pasos:
echo     1. Copiar Excels de datos en:  %ROOT%\01_input_raw\
echo     2. Ejecutar SQL DDL:           %ROOT%\02_scripts\sql\01_crear_estructura_B52.sql
echo     3. Cargar catalogos:           python 02_scripts\python\cargas\01_cargar_catalogos_B52_v2.py
echo     4. Cargar costos:              python 02_scripts\python\cargas\03_cargar_costos_B52.py
echo ============================================================
echo.
pause
