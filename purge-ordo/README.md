# Purge automatique des dossiers Ordo

Vide **tout** le contenu de `Documents\CaptOrdo` et de `Bureau\Ordo du jour`
**vers la Corbeille**, **toutes les 2 heures**, par une tâche planifiée Windows.

> Suppression **sans filtre d'âge** : un scan déposé il y a 5 minutes part au passage suivant.
> Tout va à la Corbeille, donc tout est récupérable — mais **ne jamais laisser de document à
> conserver** dans ces deux dossiers.

## Installer sur un nouveau poste

Dans **la session Windows de la personne** qui utilise les scripts AHK (la purge s'installe
pour ce compte-là, pas pour la machine).

**Droits administrateur : non**, sur un poste où la tâche n'existe pas encore — vérifié en
lançant l'installeur avec un jeton d'utilisateur standard. Seul cas contraire : si une tâche
« Vider dossiers Ordo » y a déjà été posée **par un administrateur**, un compte standard ne
peut pas l'écraser ; l'installeur le dit alors en clair et il faut le relancer par un clic
droit → « Exécuter en tant qu'administrateur ».

### Le plus simple : depuis GitHub, rien à copier

Ouvrir PowerShell (`Win+R` → `powershell`) et coller **une ligne** :

```powershell
irm https://raw.githubusercontent.com/ogeredmon123-ship-it/ahk-hotkeys/main/purge-ordo/installer-github.ps1 | iex
```

Le dépôt est public : pas de compte GitHub ni de jeton à saisir. La ligne télécharge
`vider-ordo.ps1` et `installer.ps1` dans un dossier temporaire, **vérifie** que ce sont bien
eux (un proxy ou un portail captif renvoie une page HTML avec un code 200 — elle serait
refusée), installe, puis efface le temporaire.

Variante sans taper de commande : mettre `Installer-depuis-GitHub.cmd` sur une clé USB ou
l'envoyer par mail — ce **seul** fichier suffit, il va chercher le reste. Double-clic.

### Si le poste a déjà le dépôt

`git pull`, puis double-clic sur **`Installer.cmd`**.

### Ce que fait l'installeur

- copie `vider-ordo.ps1` dans `%USERPROFILE%\Scripts\` ;
- y dépose aussi de quoi désinstaller plus tard sans le dépôt (`Desinstaller-purge-ordo.cmd`) ;
- crée `Documents\CaptOrdo` et `Bureau\Ordo du jour` s'ils manquent ;
- enregistre la tâche planifiée **« Vider dossiers Ordo »** (départ 00h06, puis toutes les 2 h) ;
- lance un premier passage et affiche la ligne écrite au journal — c'est la preuve que ça marche.

Relancer l'installeur plus tard remplace proprement la version en place : c'est aussi la
procédure de **mise à jour**.

## Désinstaller

Double-clic sur `%USERPROFILE%\Scripts\Desinstaller-purge-ordo.cmd` (ou sur `Desinstaller.cmd`
du dépôt). La tâche est retirée ; le script et le journal restent en place, sans effet.

## Vérifier / dépanner

| Question | Où regarder |
|---|---|
| Est-ce que ça tourne ? | `%USERPROFILE%\Scripts\vider-ordo.log` — une ligne par passage |
| Un fichier a disparu | La **Corbeille** d'abord, puis le journal — avant de soupçonner les scripts AHK |
| Rien depuis hier soir | Normal : jeton interactif, **pas de purge session fermée** (la Corbeille est propre à chaque utilisateur) ; le passage manqué est rattrapé à l'ouverture de session |
| Voir la tâche | Planificateur de tâches → racine → « Vider dossiers Ordo » |
| « Accès refusé » à l'enregistrement de la tâche | Une tâche du même nom, posée par un administrateur, est déjà là : relancer l'installeur en administrateur (clic droit) |
| J'ai modifié le dépôt et l'installeur prend l'ancienne version | `raw.githubusercontent` sert le fichier avec **~5 min** de cache, et ignore les astuces anti-cache (`?cb=`, en-tête `no-cache`) : attendre, ou copier le dossier et lancer `Installer.cmd` |

## Portabilité

Aucun chemin en dur, comme les `.ahk` du dépôt : les dossiers sont déduits de
`%USERPROFILE%` et, si le poste redirige Bureau / Documents (OneDrive), la variante
redirigée est purgée **en plus** — mêmes emplacements que ceux où `ordo-mutuelle.ahk`
va chercher ses fichiers. Le nom de compte, le domaine et le SID sont ceux du poste :
rien à modifier fichier par fichier.
