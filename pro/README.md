# Hotkeys officine — version PRO (poste de travail en pharmacie)

**Un seul fichier** : `hotkeys-pro.ahk` (AutoHotkey **v2**), 8 raccourcis en **double appui rapide** (deux Ctrl+X en < 0,5 s). Un seul appui garde le comportement natif de la touche. Sous-ensemble strictement professionnel des scripts de la racine — sans TTS, sans IA, sans clavier arabe.

| Double appui | Action |
|---|---|
| **Ctrl+C** | Recherche Google du texte copié |
| **Ctrl+G** | Boîte de saisie → Google (Entrée à vide = google.com) |
| **Ctrl+U** | Boîte de saisie → YouTube |
| **Ctrl+T** | Ouvre Theriaque (page recherche simple) |
| **Ctrl+M** | Ouvre Meddispar |
| **Ctrl+O** | Capture d'écran → PNG horodaté + nom patient dans `Documents\CaptOrdo` |
| **Ctrl+D** | Rapatrie le dernier fichier téléchargé vers `CaptOrdo` |
| **Ctrl+I** | Injecte le dernier fichier `CaptOrdo` dans la boîte « Ouvrir » active (sinon copie + Explorateur) |

## Installation sur le poste

1. Installer **AutoHotkey v2** — https://www.autohotkey.com
2. Copier `hotkeys-pro.ahk` où tu veux (ex. `Documents`).
3. Double-clic dessus → icône verte « H » dans la zone de notification = ça tourne.
4. Démarrage automatique : `Win+R` → `shell:startup` → y déposer un **raccourci** vers le `.ahk`.

Aucun chemin en dur : `Documents\CaptOrdo` est créé au premier lancement, les téléchargements sont cherchés dans `Downloads` (et `OneDrive\Desktop\Google Downloads` s'il existe). Ouvertures web dans le **navigateur par défaut** du poste.

## Données patients (RGPD)

`CaptOrdo` contient des captures d'ordonnances et de cartes mutuelle : dossier **local**, jamais synchronisé ni versionné. Purge automatique au lancement des fichiers de plus de **30 jours** (`PURGE_JOURS := 0` pour désactiver, dans le script).

## Dépendances

- Ctrl+O/D/I : PowerShell + outil Capture d'écran (`Win+Shift+S`), natifs Windows 10/11.
- Ctrl+T : compte Theriaque (le site est sous authentification ; le terme se tape dans la page).
