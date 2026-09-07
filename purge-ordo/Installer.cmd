@echo off
REM Installe la purge automatique des dossiers Ordo sur ce poste.
REM Double-cliquer ce fichier depuis la session Windows de l utilisateur concerne.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer.ps1"
echo.
pause
