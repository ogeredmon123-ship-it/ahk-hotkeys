<#
    Amorceur : va chercher la purge des dossiers Ordo sur GitHub et l'installe.
    Rien a copier a la main sur le poste, aucun droit administrateur.

    Installer (PowerShell, session de l'utilisateur concerne) :
        irm https://raw.githubusercontent.com/ogeredmon123-ship-it/ahk-hotkeys/main/purge-ordo/installer-github.ps1 | iex

    Desinstaller :
        & ([scriptblock]::Create((irm https://raw.githubusercontent.com/ogeredmon123-ship-it/ahk-hotkeys/main/purge-ordo/installer-github.ps1))) -Desinstaller

    Ecrit pour tourner tel quel dans un " | iex " : pas de bloc param, pas de $PSScriptRoot.
#>

$ErrorActionPreference = 'Stop'
$Base = 'https://raw.githubusercontent.com/ogeredmon123-ship-it/ahk-hotkeys/main/purge-ordo'
$Desinstaller = ($args -contains '-Desinstaller')

# TLS 1.2 : Windows 10 + PowerShell 5.1 ne le choisit pas toujours seul, et GitHub
# refuse tout le reste - sans cette ligne le telechargement echoue sur certains postes.
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

$Temp = Join-Path $env:TEMP ('purge-ordo-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $Temp -Force | Out-Null

# Chaque fichier attendu, avec un morceau de texte qui doit s'y trouver : un portail
# captif ou un proxy d'entreprise repond une page HTML avec le code 200, et l'installer
# sans regarder lancerait n'importe quoi.
$Fichiers = @(
    @{ Nom = 'vider-ordo.ps1'; Temoin = 'Microsoft.VisualBasic' },
    @{ Nom = 'installer.ps1';  Temoin = 'Vider dossiers Ordo' }
)

try {
    Write-Host ''
    Write-Host '=== Purge auto des dossiers Ordo - telechargement depuis GitHub ===' -ForegroundColor Cyan

    foreach ($f in $Fichiers) {
        # raw.githubusercontent sert une version poussee avec quelques minutes de retard,
        # et ignore aussi bien un ?cb= que l'en-tete no-cache (mesure faite le 07/09/2026) :
        # apres avoir modifie le depot, laisser passer ~5 min avant d'installer un poste.
        $url = '{0}/{1}' -f $Base, $f.Nom
        $dest = Join-Path $Temp $f.Nom
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -TimeoutSec 60

        $contenu = Get-Content -LiteralPath $dest -Raw
        if ($contenu.Length -lt 500 -or $contenu -notlike ('*' + $f.Temoin + '*')) {
            throw "Le fichier telecharge n'est pas $($f.Nom) (proxy ou portail captif ?). Rien n'a ete installe."
        }
        try { Unblock-File -LiteralPath $dest } catch { }
        Write-Host ("  recu : {0} ({1:N0} octets)" -f $f.Nom, $contenu.Length) -ForegroundColor Green
    }

    $installeur = Join-Path $Temp 'installer.ps1'
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $installeur)
    if ($Desinstaller) { $arguments += '-Desinstaller' }
    & powershell.exe @arguments
    if ($LASTEXITCODE -ne 0) { throw "L'installeur s'est termine avec le code $LASTEXITCODE." }
}
catch {
    Write-Host ''
    Write-Host "  ECHEC : $($_.Exception.Message)" -ForegroundColor Red
    Write-Host '  Reessayer, ou copier le dossier purge-ordo a la main puis lancer Installer.cmd.' -ForegroundColor Yellow
    Write-Host ''
}
finally {
    Remove-Item -LiteralPath $Temp -Recurse -Force -ErrorAction SilentlyContinue
}
