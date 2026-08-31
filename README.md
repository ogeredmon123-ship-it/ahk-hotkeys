# Hotkeys AutoHotkey — officine

Deux scripts AutoHotkey **v2** résidents, portables (aucun chemin en dur : `EnvGet("USERPROFILE")` / `A_MyDocuments`).
Tous les raccourcis sont en **double appui rapide** (deux Ctrl+X en < ~0,5 s) ; un seul appui garde le comportement natif de la touche.

## Version PRO (poste en pharmacie) → dossier [`pro/`](pro/)

`pro/hotkeys-pro.ahk` (+ `pro/Lib/UIA.ahk`) : **un seul script** avec les 8 raccourcis strictement professionnels — **Ctrl+C, G, U, T, M** (recherche) + **Ctrl+O, D, I** (flux ordonnances). Sans TTS, IA, PowerShell ni clavier arabe. Voir [`pro/README.md`](pro/README.md).

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
| **Ctrl+M** | Ouvre Meddispar (médicaments à dispensation particulière) |
| **Ctrl+P** | Ramène au premier plan la fenêtre PowerShell déjà ouverte (en crée une dédiée s'il n'y en a aucune) |
| **Ctrl+K** | Ouvre Claude Code dans Windows Terminal |
| **Ctrl+Calculatrice** | Bascule clavier arabe (disposition ar-SA + clavier visuel Windows) ; 2ᵉ double appui → retour AZERTY |

## `ordo-mutuelle.ahk` — flux ordonnances → logiciel officine

| Double appui | Action |
|---|---|
| **Ctrl+O** | Capture d'écran → PNG horodaté + nom patient dans `Documents\CaptOrdo` |
| **Ctrl+D** | Télécharge le document affiché (aperçu Gmail, WhatsApp Web, Doctolib, image/PDF dans un onglet) dans `CaptOrdo`, nommé — clique lui-même « Télécharger » (UI Automation) ou passe par Ctrl+S ; échec → message → Ctrl+O |
| **Ctrl+I** | Dans une boîte « Ouvrir » : insère le dernier fichier de `CaptOrdo` + Entrée ; sinon le copie (fichier + image si capture) et le colle dans la fenêtre active |

### Garde-fous « bon fichier, bon patient »
- **Contenu vérifié** : Ctrl+D lit les premiers octets du fichier obtenu et n'accepte que les images et les PDF. Une page web enregistrée par erreur — même nommée `.pdf` — est refusée ; si elle est déjà arrivée dans `CaptOrdo`, elle part à la corbeille.
- **Fraîcheur vérifiée** : si le dernier fichier de `CaptOrdo` a plus de `FRAICHEUR_MIN` minutes (10 par défaut ; `0` pour désactiver), Ctrl+I demande confirmation en affichant son nom et sa date, **« Non » présélectionné**. Sans ce contrôle, un Ctrl+D passé inaperçu ferait insérer le document du patient **précédent**.
- **Liste blanche** : seuls `png jpg jpeg gif bmp webp heic pdf` sont proposés par Ctrl+I (`EXT_IMPORT`), ce qui écarte au passage les téléchargements en cours et les fichiers système.
- **Journal** : chaque Ctrl+D / Ctrl+I écrit une ligne horodatée dans `ordo-mutuelle.log`, à côté du script — fenêtre active, fichier retenu et son âge, erreurs — pour retrouver après coup ce qui a été pris. `JOURNAL := ""` pour désactiver. Il peut contenir des noms de patients : il reste **local** (`*.log` est dans `.gitignore`).

Purge RGPD automatique : les fichiers de `CaptOrdo` de plus de 30 jours partent à la corbeille au lancement (`PURGE_JOURS := 0` pour désactiver). Le dossier `CaptOrdo` contient des **données patients** : il est exclu par `.gitignore` et ne doit jamais être versionné.

## Installation sur un nouveau PC

1. **Installer AutoHotkey v2** — https://www.autohotkey.com (les scripts sont en v2, pas v1).
2. **Cloner ce dépôt** (ou copier les deux `.ahk`).
3. **Tester** : double-clic sur chaque `.ahk` → une icône verte « H » apparaît dans la zone de notification = le script tourne.
4. **Démarrage automatique** : `Win+R` → `shell:startup` → y déposer un **raccourci** vers chaque `.ahk`.

### Dépendances par hotkey
- **Ctrl+R (TTS)** : voix fr-FR (ex. Hortense/SAPI) installée, sinon voix par défaut.
- **Ctrl+K** : Windows Terminal (`wt.exe`) + Claude Code installés.
- **Ctrl+P** : Windows Terminal (`wt.exe`).
- **Ctrl+Calculatrice** : clavier ar-SA ajouté dans Paramètres → Langue (sinon la bascule échoue) ; `osk.exe` natif Windows. Un clavier avec touche Calculatrice.
- **Ctrl+O/D/I** : PowerShell + `Win+Shift+S` (natifs Windows 10/11) + `Lib\UIA.ahk` ([UIA-v2](https://github.com/Descolada/UIA-v2), MIT, copie incluse — à placer dans un dossier `Lib` à côté de `ordo-mutuelle.ahk`). Ctrl+D clique lui-même « Télécharger » dans la page affichée et attrape le fichier dans le dossier de téléchargement du navigateur (détecté au lancement : « Téléchargements » Windows, `Downloads`, dossiers configurés dans Chrome / Edge / Firefox, Bureau) — rien à adapter.

### Recharger après une modification
Clic droit sur l'icône « H » dans le systray → **Reload Script**.
