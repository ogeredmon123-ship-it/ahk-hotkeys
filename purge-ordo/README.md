# Purge automatique des dossiers Ordo

Vide **tout** le contenu de `Documents\CaptOrdo` et de `Bureau\Ordo du jour`
**vers la Corbeille**, **toutes les 2 heures**, par une tâche planifiée Windows.

> Suppression **sans filtre d'âge** : un scan déposé il y a 5 minutes part au passage suivant.
> Tout va à la Corbeille, donc tout est récupérable — mais **ne jamais laisser de document à
> conserver** dans ces deux dossiers.

## Installer sur un nouveau poste

1. Ouvrir la **session Windows de la personne** qui utilise les scripts AHK (la purge
   s'installe pour ce compte-là, pas pour la machine).
2. Copier le dossier `purge-ordo/` sur le poste (clé USB, ou `git pull` de ce dépôt).
3. Double-cliquer **`Installer.cmd`**, lire les lignes vertes, fermer.

Aucun droit administrateur : la tâche tourne sous le compte courant.

L'installeur :

- copie `vider-ordo.ps1` dans `%USERPROFILE%\Scripts\` ;
- crée `Documents\CaptOrdo` et `Bureau\Ordo du jour` s'ils manquent ;
- enregistre la tâche planifiée **« Vider dossiers Ordo »** (départ 00h06, puis toutes les 2 h) ;
- lance un premier passage et affiche la ligne écrite au journal — c'est la preuve que ça marche.

Relancer `Installer.cmd` plus tard remplace proprement la version en place (mise à jour).

## Désinstaller

Double-cliquer **`Desinstaller.cmd`** : la tâche est retirée. Le script et le journal restent
en place, sans effet.

## Vérifier / dépanner

| Question | Où regarder |
|---|---|
| Est-ce que ça tourne ? | `%USERPROFILE%\Scripts\vider-ordo.log` — une ligne par passage |
| Un fichier a disparu | La **Corbeille** d'abord, puis le journal — avant de soupçonner les scripts AHK |
| Rien depuis hier soir | Normal : jeton interactif, **pas de purge session fermée** (la Corbeille est propre à chaque utilisateur) ; le passage manqué est rattrapé à l'ouverture de session |
| Voir la tâche | Planificateur de tâches → racine → « Vider dossiers Ordo » |

## Portabilité

Aucun chemin en dur, comme les `.ahk` du dépôt : les dossiers sont déduits de
`%USERPROFILE%` et, si le poste redirige Bureau / Documents (OneDrive), la variante
redirigée est purgée **en plus** — mêmes emplacements que ceux où `ordo-mutuelle.ahk`
va chercher ses fichiers. Le nom de compte, le domaine et le SID sont ceux du poste :
rien à modifier fichier par fichier.
