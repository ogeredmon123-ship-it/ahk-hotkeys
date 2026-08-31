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

### Garde-fous « bon fichier, bon patient »
- **Contenu vérifié** : Ctrl+D n'accepte que les images et les PDF, reconnus à leurs premiers octets. Une page web enregistrée par erreur — même nommée `.pdf` — est refusée ; si elle est déjà arrivée dans `CaptOrdo`, elle part à la corbeille.
- **Fraîcheur vérifiée** : si le dernier fichier de `CaptOrdo` a plus de 10 minutes (`FRAICHEUR_MIN`, `0` pour désactiver), Ctrl+I demande confirmation en affichant son nom et sa date, **« Non » présélectionné**. Sans ce contrôle, un Ctrl+D passé inaperçu ferait insérer le document du patient **précédent**.
- **Journal** : chaque Ctrl+D / Ctrl+I écrit une ligne horodatée dans `hotkeys-pro.log`, à côté du script. Il peut contenir des noms de patients : il reste **local**, jamais versionné ni synchronisé.

## Installation sur le poste — pas à pas, de zéro

### 1. Installer AutoHotkey v2 (une seule fois par PC)
1. Ouvrir https://www.autohotkey.com → bouton **Download** → **Download v2.0**.
2. Lancer le fichier téléchargé (`AutoHotkey_2.0.x_setup.exe`) → **Install** (réglages par défaut) → fermer.
3. Vérification : menu Démarrer → taper « AutoHotkey » → « AutoHotkey Dash » apparaît.
   - Si Windows demande un mot de passe administrateur que tu n'as pas : demander au titulaire (ou choisir l'installation « pour moi seulement » si l'installeur la propose).
   - Si un antivirus bloque AutoHotkey : c'est fréquent en entreprise, il faut l'autoriser (titulaire / informaticien).

### 2. Récupérer les deux fichiers
- **Depuis GitHub** : https://github.com/ogeredmon123-ship-it/ahk-hotkeys → bouton vert **Code** → **Download ZIP** → `ahk-hotkeys-main.zip` arrive dans Téléchargements. (Dépôt privé = il faut être connecté à GitHub ; s'il est public, le ZIP direct marche aussi : https://github.com/ogeredmon123-ship-it/ahk-hotkeys/archive/refs/heads/main.zip .)
- **Sans GitHub** : le ZIP `hotkeys-pro.zip` déposé dans OneDrive (« Claude dossiers ») contient exactement le dossier `pro`.

### 3. Décompresser et placer
1. Clic droit sur le ZIP → **Extraire tout…** → **Extraire**.
2. Dans le dossier extrait, ouvrir `ahk-hotkeys-main` → `pro`. Il contient : `hotkeys-pro.ahk`, un dossier `Lib` (avec `UIA.ahk`) et ce README.
3. Copier **`hotkeys-pro.ahk` ET le dossier `Lib`** dans `Documents` du compte du poste. Résultat attendu :
   - `Documents\hotkeys-pro.ahk`
   - `Documents\Lib\UIA.ahk`
   Le dossier `Lib` doit rester **à côté** du script, sinon Ctrl+D ne peut pas cliquer « Télécharger ».

### 4. Lancer
1. Double-clic sur `hotkeys-pro.ahk` → une icône verte **« H »** apparaît dans la zone de notification (en bas à droite, parfois cachée sous la petite flèche ^). C'est tout : les raccourcis sont actifs.
2. Si Windows demande « avec quelle application ouvrir ce fichier » : AutoHotkey n'est pas installé (retour à l'étape 1) — ou choisir `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe`.
3. Au premier lancement, le dossier `C:\Users\<compte>\Documents\CaptOrdo` est créé (Documents **local**, jamais OneDrive).

### 5. Tester (2 minutes)
- **Ctrl+O** : double appui rapide (deux Ctrl+O en moins d'une demi-seconde) → sélectionner une zone de l'écran → nom du patient → OK → « Enregistré : … ». Le PNG est dans `CaptOrdo`.
- **Ctrl+D** : dans Chrome, ouvrir un mail avec une pièce jointe, cliquer la pièce jointe (aperçu plein écran) → double Ctrl+D → nom du patient → OK → « Téléchargement… » puis « Rangé dans CaptOrdo : … ». Un bandeau **rouge** = échec, et il dit quoi faire (en général : Ctrl+O).
- **Ctrl+I** : dans le logiciel, boîte « Ouvrir » ouverte → double Ctrl+I → le chemin du dernier fichier est inséré + Entrée. Hors boîte « Ouvrir » (mail, chat) : double Ctrl+I colle le dernier fichier de `CaptOrdo`.
- Chrome : Paramètres → Téléchargements → « Demander où enregistrer chaque fichier » doit être **désactivé** (réglage par défaut) ; l'emplacement peut être n'importe lequel, le script le détecte.

### 6. Démarrage automatique (pour ne plus y penser)
1. `Win+R` → taper `shell:startup` → Entrée : le dossier « Démarrage » s'ouvre.
2. Dans `Documents`, clic droit sur `hotkeys-pro.ahk` → **Créer un raccourci** → glisser ce raccourci dans le dossier « Démarrage ».
3. À la prochaine ouverture de session, le script démarre tout seul (icône « H »).

### 7. Mettre à jour / arrêter
- Mise à jour : re-télécharger le ZIP, remplacer `hotkeys-pro.ahk` et `Lib\UIA.ahk`, double-clic sur le script (il remplace l'ancien automatiquement).
- Arrêter : clic droit sur l'icône « H » → **Exit**. Désinstaller : supprimer les fichiers et le raccourci de « Démarrage ».

## Données patients (RGPD)

`CaptOrdo` contient des captures d'ordonnances et de cartes mutuelle : dossier **local**, jamais synchronisé ni versionné. Purge automatique au lancement des fichiers de plus de **30 jours** (`PURGE_JOURS := 0` pour désactiver, dans le script).

## Dépendances

- `Lib\UIA.ahk` — [UIA-v2](https://github.com/Descolada/UIA-v2) (Descolada, licence MIT), copie incluse dans ce dossier ; indispensable au clic automatique de Ctrl+D.

- Ctrl+O/D/I : PowerShell + outil Capture d'écran (`Win+Shift+S`), natifs Windows 10/11.
- Ctrl+T : compte Theriaque (le site est sous authentification ; le terme se tape dans la page).
