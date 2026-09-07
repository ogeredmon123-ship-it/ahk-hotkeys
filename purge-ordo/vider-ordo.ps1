# Vide le contenu de CaptOrdo et "Ordo du jour" vers la Corbeille.
# Lance automatiquement toutes les 2 heures par la tache planifiee "Vider dossiers Ordo".
# Portable : aucun chemin en dur, tout est deduit du profil de l'utilisateur courant.

Add-Type -AssemblyName Microsoft.VisualBasic

# Les memes emplacements que ordo-mutuelle.ahk : le profil LOCAL d'abord (jamais OneDrive
# pour les donnees patients), plus la variante redirigee au cas ou le poste redirige
# Bureau / Documents. Les doublons sont retires juste apres.
$Candidats = @(
    (Join-Path $env:USERPROFILE 'Documents\CaptOrdo'),
    (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'CaptOrdo'),
    (Join-Path $env:USERPROFILE 'Desktop\Ordo du jour'),
    (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Ordo du jour')
)

$Dossiers = @()
foreach ($c in $Candidats) {
    if ([string]::IsNullOrWhiteSpace($c)) { continue }
    $normalise = $c.TrimEnd('\')
    if ($Dossiers -notcontains $normalise) { $Dossiers += $normalise }
}

$Journal = Join-Path $env:USERPROFILE 'Scripts\vider-ordo.log'
$dossierJournal = Split-Path -Parent $Journal
if (-not (Test-Path -LiteralPath $dossierJournal)) {
    New-Item -ItemType Directory -Path $dossierJournal -Force | Out-Null
}

function Ecrire-Journal([string]$Message) {
    $ligne = "{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $Journal -Value $ligne -Encoding UTF8
}

$total = 0
$erreurs = 0

foreach ($dossier in $Dossiers) {
    if (-not (Test-Path -LiteralPath $dossier)) {
        Ecrire-Journal "ABSENT : $dossier"
        continue
    }

    foreach ($item in (Get-ChildItem -LiteralPath $dossier -Force)) {
        try {
            if ($item.PSIsContainer) {
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
                    $item.FullName,
                    [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                    [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin,
                    [Microsoft.VisualBasic.FileIO.UICancelOption]::DoNothing)
            } else {
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
                    $item.FullName,
                    [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                    [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin,
                    [Microsoft.VisualBasic.FileIO.UICancelOption]::DoNothing)
            }
            $total++
        } catch {
            $erreurs++
            Ecrire-Journal ("ECHEC : {0} -> {1}" -f $item.FullName, $_.Exception.Message)
        }
    }
}

Ecrire-Journal ("Corbeille : {0} element(s) supprime(s), {1} echec(s)." -f $total, $erreurs)

# Garde le journal sous 500 lignes
if (Test-Path -LiteralPath $Journal) {
    $lignes = Get-Content -LiteralPath $Journal
    if ($lignes.Count -gt 500) {
        $lignes | Select-Object -Last 500 | Set-Content -LiteralPath $Journal -Encoding UTF8
    }
}
