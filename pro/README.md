# Hotkeys officine — version PRO (poste de travail en pharmacie)

**Deux fichiers** : `hotkeys-pro.ahk` (AutoHotkey **v2**) + `Lib\UIA.ahk` (bibliothèque UI Automation, utilisée par Ctrl+D), 8 raccourcis en **double appui rapide** (deux Ctrl+X en < 0,5 s). Un seul appui garde le comportement natif de la touche. Sous-ensemble strictement professionnel des scripts de la racine — sans TTS, sans IA, sans clavier arabe.

| Double appui | Action |
|---|---|
| **Ctrl+C** | Recherche Google du texte copié |
| **Ctrl+G** | Boîte de saisie → Google (Entrée à vide = google.com) |
| **Ctrl+U** | Boîte de saisie → YouTube |
| **Ctrl+T** | Ouvre Theriaque (page recherche simple) |
| **Ctrl+M** | Ouvre Meddispar |
| **Ctrl+O** | Capture d'écran → PNG horodaté + nom patient dans `Documents\CaptOrdo` |
| **Ctrl+D** | Télécharge le document affiché (aperçu Gmail, WhatsApp Web, Doctolib, image/PDF dans un onglet) dans `CaptOrdo`, nommé — clique lui-même « Télécharger » (UI Automation) ou passe par Ctrl+S ; échec → message → Ctrl+O |
| **Ctrl+I** | Dans une boîte « Ouvrir » : insère le dernier fichier de `CaptOrdo` + Entrée ; sinon le copie (fichier + image si capture) et le colle dans la fenêtre active |

## Installation sur le poste

1. Installer **AutoHotkey v2** — https://www.autohotkey.com
2. Télécharger le dépôt en ZIP — https://github.com/ogeredmon123-ship-it/ahk-hotkeys/archive/refs/heads/main.zip — l'ouvrir, et copier le contenu du dossier `pro` où tu veux (ex. `Documents`) : `Documents\hotkeys-pro.ahk` **et** `Documents\Lib\UIA.ahk` (le sous-dossier `Lib` doit rester à côté du script). Fichiers seuls : https://raw.githubusercontent.com/ogeredmon123-ship-it/ahk-hotkeys/main/pro/hotkeys-pro.ahk et https://raw.githubusercontent.com/ogeredmon123-ship-it/ahk-hotkeys/main/pro/Lib/UIA.ahk (clic droit → « Enregistrer le lien sous »).
3. Double-clic dessus → icône verte « H » dans la zone de notification = ça tourne.
4. Démarrage automatique : `Win+R` → `shell:startup` → y déposer un **raccourci** vers le `.ahk`.

Aucun chemin en dur : `C:\Users\<compte>\Documents\CaptOrdo` est créé au premier lancement — toujours le dossier Documents **local** du compte, jamais OneDrive, même si « Documents » est redirigé vers OneDrive sur le poste (Ctrl+I l'ouvre dans l'Explorateur s'il est vide). **Ctrl+D** se lance depuis le navigateur, le document du patient à l'écran : il demande le nom, clique lui-même le bouton « Télécharger » / « Download » de la page (Gmail, WhatsApp Web, Doctolib…) — ou fait Ctrl+S pour une image / un PDF ouvert dans un onglet — puis attrape le fichier qui arrive dans le dossier de téléchargement du navigateur (détecté automatiquement : « Téléchargements » Windows, `Downloads`, dossiers configurés dans Chrome / Edge / Firefox, Bureau) et le range nommé dans `CaptOrdo`. Rien dans les 30 s → message → Ctrl+O. Ouvertures web dans le **navigateur par défaut** du poste.

## Données patients (RGPD)

`CaptOrdo` contient des captures d'ordonnances et de cartes mutuelle : dossier **local**, jamais synchronisé ni versionné. Purge automatique au lancement des fichiers de plus de **30 jours** (`PURGE_JOURS := 0` pour désactiver, dans le script).

## Dépendances

- `Lib\UIA.ahk` — [UIA-v2](https://github.com/Descolada/UIA-v2) (Descolada, licence MIT), copie incluse dans ce dossier ; indispensable au clic automatique de Ctrl+D.

- Ctrl+O/D/I : PowerShell + outil Capture d'écran (`Win+Shift+S`), natifs Windows 10/11.
- Ctrl+T : compte Theriaque (le site est sous authentification ; le terme se tape dans la page).
