# Hotkeys AutoHotkey — officine

Deux scripts AutoHotkey **v2** résidents, portables (aucun chemin en dur : `A_UserProfile` / `A_MyDocuments`).
Tous les raccourcis sont en **double appui rapide** (deux Ctrl+X en < ~0,5 s) ; un seul appui garde le comportement natif de la touche.

## `recherche-selection.ahk` — recherche / TTS / IA

| Double appui | Action |
|---|---|
| **Ctrl+C** | Recherche Google du texte copié |
| **Ctrl+R** | Lecture à voix haute (TTS fr-FR) de la sélection |
| **Ctrl+G** | Boîte de saisie → Google |
| **Ctrl+U** | Boîte de saisie → YouTube |
| **Ctrl+B** | Boîte de saisie → VIDAL (vide = accueil vidal.fr) |
| **Ctrl+T** | Ouvre Theriaque (page recherche simple) |
| **Ctrl+A** | Boîte de saisie → Claude.ai (pré-remplit le prompt) |
| **Ctrl+K** | Ouvre Claude Code dans Windows Terminal |

## `ordo-mutuelle.ahk` — flux ordonnances → logiciel officine

| Double appui | Action |
|---|---|
| **Ctrl+O** | Capture d'écran → PNG horodaté + nom patient dans `Documents\CaptOrdo` |
| **Ctrl+D** | Rapatrie le dernier fichier téléchargé vers `CaptOrdo` |
| **Ctrl+I** | Injecte le dernier fichier dans la boîte « Ouvrir » active (sinon copie + Explorateur) |

Purge RGPD automatique : les fichiers de `CaptOrdo` de plus de 30 jours partent à la corbeille au lancement (`PURGE_JOURS := 0` pour désactiver). Le dossier `CaptOrdo` contient des **données patients** : il est exclu par `.gitignore` et ne doit jamais être versionné.

## Installation sur un nouveau PC

1. **Installer AutoHotkey v2** — https://www.autohotkey.com (les scripts sont en v2, pas v1).
2. **Cloner ce dépôt** (ou copier les deux `.ahk`).
3. **Tester** : double-clic sur chaque `.ahk` → une icône verte « H » apparaît dans la zone de notification = le script tourne.
4. **Démarrage automatique** : `Win+R` → `shell:startup` → y déposer un **raccourci** vers chaque `.ahk`.

### Dépendances par hotkey
- **Ctrl+R (TTS)** : voix fr-FR (ex. Hortense/SAPI) installée, sinon voix par défaut.
- **Ctrl+K** : Windows Terminal (`wt.exe`) + Claude Code installés.
- **Ctrl+O/D/I** : PowerShell + `Win+Shift+S` (natifs Windows 10/11). Le dossier « Google Downloads » n'existe que si Chrome y télécharge — sinon adapter `DOSSIERS_TELECHARGEMENT` dans `ordo-mutuelle.ahk`.

### Recharger après une modification
Clic droit sur l'icône « H » dans le systray → **Reload Script**.
