@echo off
REM Installe la purge des dossiers Ordo en la telechargeant depuis GitHub.
REM Ce fichier suffit : il va chercher le reste tout seul.
REM A lancer dans la session Windows de l utilisateur concerne.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/ogeredmon123-ship-it/ahk-hotkeys/main/purge-ordo/installer-github.ps1 | iex"
echo.
pause
