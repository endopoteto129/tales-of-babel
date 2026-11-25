@echo off
chcp 65001 >nul
cd /d "%~dp0"
set PYTHONUTF8=1
set PY=python
where py >nul 2>nul && set PY=py
%PY% -c "import openpyxl" 2>nul || %PY% -m pip install --user openpyxl
%PY% art_src\scenario\import_scenario.py
echo.
pause
