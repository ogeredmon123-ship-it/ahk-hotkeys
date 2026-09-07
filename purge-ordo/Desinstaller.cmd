@echo off
REM Retire la tache planifiee "Vider dossiers Ordo" de ce poste.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer.ps1" -Desinstaller
echo.
pause
