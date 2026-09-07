<#
    Installe (ou desinstalle) la purge automatique des dossiers Ordo sur le poste courant.

    Installation :
      - copie vider-ordo.ps1 dans %USERPROFILE%\Scripts
      - y depose de quoi desinstaller plus tard sans le depot
      - cree les dossiers Documents\CaptOrdo et Bureau\Ordo du jour s'ils manquent
      - cree la tache planifiee "Vider dossiers Ordo" (toutes les 2 h, jeton interactif)
      - lance un premier passage pour verifier

    Desinstallation : .\installer.ps1 -Desinstaller

    Aucun droit administrateur : la tache passe par schtasks.exe, qui accepte un compte
    standard tant que la tache tourne sous ce compte. Les applets Register-ScheduledTask
    et consorts, elles, repondent "Acces refuse" sans elevation (mesure faite le 07/09/2026
    avec un jeton utilisateur de base) : ne pas les reintroduire ici.
#>

[CmdletBinding()]
param(
    [switch]$Desinstaller
)

$ErrorActionPreference = 'Stop'
$NomTache = 'Vider dossiers Ordo'

function Info([string]$m) { Write-Host "  $m" }
function Bien([string]$m) { Write-Host "  $m" -ForegroundColor Green }
function Souci([string]$m) { Write-Host "  $m" -ForegroundColor Yellow }

function Tache-Existe {
    $null = & schtasks.exe /query /tn $NomTache 2>&1
    return ($LASTEXITCODE -eq 0)
}

Write-Host ''
Write-Host "=== Purge auto des dossiers Ordo - poste $env:COMPUTERNAME / compte $env:USERNAME ===" -ForegroundColor Cyan
Write-Host ''

if ($Desinstaller) {
    if (Tache-Existe) {
        $sortie = & schtasks.exe /delete /tn $NomTache /f 2>&1
        if ($LASTEXITCODE -eq 0) {
            Bien "Tache planifiee `"$NomTache`" supprimee."
        } else {
            Souci ("Suppression refusee : " + ($sortie -join ' '))
        }
    } else {
        Info "Aucune tache `"$NomTache`" sur ce poste."
    }
    Info "Le script %USERPROFILE%\Scripts\vider-ordo.ps1 et le journal sont laisses en place."
    Write-Host ''
    return
}

# --- 1. Copie du script dans le profil ---------------------------------------
$Source = Join-Path $PSScriptRoot 'vider-ordo.ps1'
if (-not (Test-Path -LiteralPath $Source)) {
    throw "vider-ordo.ps1 est introuvable a cote de l'installeur ($PSScriptRoot)."
}

$DossierScripts = Join-Path $env:USERPROFILE 'Scripts'
$Cible = Join-Path $DossierScripts 'vider-ordo.ps1'
if (-not (Test-Path -LiteralPath $DossierScripts)) {
    New-Item -ItemType Directory -Path $DossierScripts -Force | Out-Null
}
Copy-Item -LiteralPath $Source -Destination $Cible -Force
Bien "Script installe : $Cible"

# --- 1 bis. Rendre le poste autonome pour la suite ---------------------------
# Installe par GitHub, il n'y a pas de dossier du depot sur le poste : on depose
# l'installeur lui-meme et un Desinstaller.cmd a cote du script.
$CopieInstalleur = Join-Path $DossierScripts 'installer-purge-ordo.ps1'
if ($PSCommandPath -and ($PSCommandPath -ne $CopieInstalleur)) {
    Copy-Item -LiteralPath $PSCommandPath -Destination $CopieInstalleur -Force
}
$Desinstalleur = Join-Path $DossierScripts 'Desinstaller-purge-ordo.cmd'
Set-Content -LiteralPath $Desinstalleur -Encoding ASCII -Value @(
    '@echo off',
    'REM Retire la tache planifiee "Vider dossiers Ordo" de ce poste.',
    'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer-purge-ordo.ps1" -Desinstaller',
    'echo.',
    'pause'
)
Info "Desinstallation sur ce poste : $Desinstalleur"

# --- 2. Dossiers surveilles ---------------------------------------------------
foreach ($d in @((Join-Path $env:USERPROFILE 'Documents\CaptOrdo'),
                 (Join-Path $env:USERPROFILE 'Desktop\Ordo du jour'))) {
    if (Test-Path -LiteralPath $d) {
        Info "Dossier deja present : $d"
    } else {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
        Bien "Dossier cree : $d"
    }
}

# --- 3. Tache planifiee -------------------------------------------------------
# Depart a 00h06 puis toutes les 2 h, indefiniment. StartWhenAvailable rattrape les
# passages manques (poste eteint la nuit). Jeton interactif : la purge n'a lieu que
# session ouverte, contrainte de la Corbeille qui est propre a chaque utilisateur.
$Depart = (Get-Date -Hour 0 -Minute 6 -Second 0).ToString('yyyy-MM-ddTHH:mm:ss')
$Utilisateur = "$env:USERDOMAIN\$env:USERNAME"

$Xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Author>$Utilisateur</Author>
    <Description>Vide CaptOrdo et "Ordo du jour" vers la Corbeille toutes les 2 heures.</Description>
    <URI>\$NomTache</URI>
  </RegistrationInfo>
  <Principals>
    <Principal id="Author">
      <UserId>$Utilisateur</UserId>
      <LogonType>InteractiveToken</LogonType>
    </Principal>
  </Principals>
  <Settings>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT10M</ExecutionTimeLimit>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <StartWhenAvailable>true</StartWhenAvailable>
    <IdleSettings>
      <Duration>PT10M</Duration>
      <WaitTimeout>PT1H</WaitTimeout>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
  </Settings>
  <Triggers>
    <TimeTrigger>
      <StartBoundary>$Depart</StartBoundary>
      <Repetition>
        <Interval>PT2H</Interval>
      </Repetition>
    </TimeTrigger>
  </Triggers>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "$Cible"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

# schtasks lit le XML en UTF-16, pas autre chose.
$XmlTemp = Join-Path $env:TEMP ('vider-ordo-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.xml')
Set-Content -LiteralPath $XmlTemp -Value $Xml -Encoding Unicode
try {
    $sortie = & schtasks.exe /create /tn $NomTache /xml $XmlTemp /f 2>&1
    if ($LASTEXITCODE -ne 0 -and (Tache-Existe)) {
        # Un compte standard cree sans probleme une tache qui n'existe pas encore, mais
        # n'ecrase pas celle qu'une session administrateur a posee avant lui (mesure faite
        # le 07/09/2026) : on tente de la retirer, puis de la recreer.
        $null = & schtasks.exe /delete /tn $NomTache /f 2>&1
        $sortie = & schtasks.exe /create /tn $NomTache /xml $XmlTemp /f 2>&1
    }
    if ($LASTEXITCODE -ne 0) {
        throw ("schtasks n'a pas pu creer la tache : " + ($sortie -join ' ') + " -- si elle " +
               "existe deja et a ete posee par un administrateur, relancer cet installeur en " +
               "tant qu'administrateur (clic droit sur Installer.cmd).")
    }
} finally {
    if (Test-Path -LiteralPath $XmlTemp) {
        Remove-Item -LiteralPath $XmlTemp -Force -ErrorAction SilentlyContinue
    }
}
Bien "Tache planifiee `"$NomTache`" enregistree (toutes les 2 h, a partir de 00h06)."

# --- 4. Premier passage de verification --------------------------------------
Info 'Premier passage de verification...'
$Journal = Join-Path $env:USERPROFILE 'Scripts\vider-ordo.log'
$attendu = (Get-Date).AddSeconds(-5)
$null = & schtasks.exe /run /tn $NomTache 2>&1
$vu = $false
foreach ($essai in 1..20) {
    Start-Sleep -Milliseconds 500
    if ((Test-Path -LiteralPath $Journal) -and
        ((Get-Item -LiteralPath $Journal).LastWriteTime -gt $attendu)) { $vu = $true; break }
}

Write-Host ''
if ($vu) {
    Bien 'Installation terminee - derniere ligne du journal :'
    Get-Content -LiteralPath $Journal -Tail 1 | ForEach-Object { Write-Host "      $_" }
} else {
    Souci "La tache est enregistree mais n'a pas encore ecrit dans $Journal."
    Souci 'Ouvrir le Planificateur de taches et lancer "Vider dossiers Ordo" a la main pour voir l erreur.'
}
Write-Host ''
Write-Host '  Rappel : la suppression va dans la Corbeille, tout est recuperable.' -ForegroundColor Cyan
Write-Host '  Ne rien laisser a conserver dans CaptOrdo ni dans "Ordo du jour".' -ForegroundColor Cyan
Write-Host ''
