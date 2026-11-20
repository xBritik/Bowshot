# Installer Bowshot, pas à pas (guide pour débutants)

Ce guide est écrit pour quelqu'un qui n'est pas à l'aise avec l'informatique. Suivez les étapes **dans l'ordre**, sans en sauter. Quand vous voyez un cadre gris avec du texte, c'est une commande : on la **copie**, on la **colle** dans l'application **Terminal**, puis on appuie sur **Entrée**.

> Bowshot permet de fabriquer, sur votre Mac, une version de *Zelda : Ocarina of Time* (Switch 2) à partir de **votre propre copie du jeu**. Aucun fichier du jeu n'est fourni avec Bowshot.

**Prévoyez une demi-journée.** Les téléchargements sont gros et la fabrication du jeu prend **1 h 30 ou plus**. Ce n'est pas bloqué si l'écran avance lentement.

---

## Avant de commencer : ce qu'il vous faut

- Un **Mac avec une puce Apple** (M1, M2, M3, M4…), avec **16 Go de mémoire ou plus**.
- **macOS 26.6 ou plus récent.**
- **Environ 100 Go d'espace libre** sur le disque.
- **Votre copie du jeu** *Ocarina of Time* (Switch 2), avec sa **mise à jour v131072** : un fichier qui se termine par `.nup`, ou des fichiers `.nsp` (le jeu + la mise à jour). Bowshot ne fournit pas ce fichier et ne dit pas où le trouver.
- Une connexion Internet, et le Mac **branché sur le secteur**.

### Vérifier votre Mac

1. Cliquez sur la pomme  en haut à gauche, puis **À propos de ce Mac**.
2. Regardez la ligne **Puce** : elle doit commencer par « Apple M… » (pas « Intel »).
3. Regardez **Mémoire** : 16 Go ou plus.
4. Regardez la **version de macOS** : 26.6 ou plus. Sinon : pomme  → **Réglages Système** → **Général** → **Mise à jour de logiciels**, puis installez la mise à jour.

Si l'une de ces conditions n'est pas remplie, Bowshot ne fonctionnera pas sur ce Mac.

---

## Étape 1 : télécharger Bowshot

1. Ouvrez cette page : <https://github.com/LeoGeneret/Bowshot/releases/latest>
2. Cliquez sur le fichier **`Bowshot-0.1.0-macOS-arm64.zip`** pour le télécharger.
3. Ouvrez le dossier **Téléchargements** et double-cliquez sur le fichier `.zip` : une application **Bowshot** apparaît.
4. **Glissez Bowshot dans le dossier Applications** (dans la colonne de gauche du Finder).

Ne l'ouvrez pas encore.

## Étape 2 : installer les outils (une seule fois)

### 2.a Xcode

1. Ouvrez l'**App Store** et cherchez **Xcode**.
2. Cliquez sur **Obtenir**, puis **Installer**. C'est **très volumineux** : comptez de longues minutes.
3. Une fois installé, **ouvrez Xcode une fois**, acceptez la licence si on vous la demande, et laissez-le finir sa mise en place (il peut télécharger des composants). Puis fermez-le.

Bowshot demande **Xcode 27.2**. Si l'App Store en propose une autre version, voir « En cas de problème » plus bas.

### 2.b Ouvrir le Terminal

Appuyez sur **⌘ + Espace**, tapez **Terminal**, puis appuyez sur **Entrée**. Une fenêtre avec du texte s'ouvre. Laissez-la ouverte.

### 2.c Installer Homebrew

Homebrew est un installateur d'outils très répandu. Copiez cette commande, collez-la dans le Terminal (**⌘ + V**), puis **Entrée** :

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

- Le Mac demande votre **mot de passe** : tapez-le (**rien ne s'affiche pendant la saisie, c'est normal**) puis **Entrée**.
- Appuyez sur **Entrée** quand on vous le demande, puis patientez.
- **À la fin**, Homebrew écrit un paragraphe **« Next steps »** avec **deux commandes** à copier-coller. **Faites-le**, sans quoi les étapes suivantes ne marcheront pas.

(Si vous avez déjà Homebrew, passez à la suite.)

### 2.d Installer les autres outils

Collez ces deux commandes, **l'une après l'autre**, en attendant que la première soit finie :

```sh
brew install uv xcodegen zstd glslang
```

```sh
xcodebuild -downloadComponent MetalToolchain
```

### 2.e Vérifier que tout est en place

```sh
bash /Applications/Bowshot.app/Contents/Resources/engine/scripts/bowshot_build.sh --doctor
```

La dernière ligne doit être : **`Prerequisite executables found.`** Sinon, le message dit ce qui manque : recommencez l'étape correspondante.

## Étape 3 : préparer le dossier du jeu

1. Ouvrez le **Finder**, menu **Aller** → **Dossier personnel** (la maison, avec votre prénom).
2. Créez-y un **nouveau dossier** (**⇧ + ⌘ + N**) et appelez-le **`Ocarina`**.
3. **Copiez votre fichier du jeu** (le `.nup`, ou les `.nsp`) **dans ce dossier**.

Ne le mettez ni dans Bureau, ni dans Documents, ni dans iCloud Drive : ces dossiers peuvent être synchronisés avec iCloud, et la fabrication écrit des dizaines de Go.

## Étape 4 : fabriquer le jeu

1. Ouvrez **Bowshot** (dans Applications). **La première fois : clic droit sur l'icône → Ouvrir → Ouvrir.** Le Mac refuse l'ouverture par double-clic car l'application n'est pas signée par Apple. Si le Mac refuse encore : pomme  → **Réglages Système** → **Confidentialité et sécurité** → **Ouvrir quand même**.
2. Cliquez sur **Choose Game Folder…** et sélectionnez le dossier **Ocarina** (le dossier, pas le fichier dedans).
3. Le bouton **Build My Local Game** devient **bleu** : cliquez dessus. S'il reste grisé, la ligne sous le bouton explique pourquoi (jeu manquant, mauvais dossier…).
4. **Attendez.** Une barre de progression indique l'étape et le temps restant. **Comptez 1 h 30 ou plus.** Pendant ce temps :
   - gardez le Mac **branché** et **réveillé** (ne fermez pas l'écran) ;
   - ne faites rien de lourd avec l'ordinateur.
5. C'est fini quand l'état affiche **Local build ready** et que le journal se termine par `READY:`.

## Étape 5 : jouer

1. Dans Bowshot, cliquez sur **Open game folder** : un dossier **Bowshot-local** s'ouvre.
2. Ouvrez **Ocarina of Time** (l'application dedans). **La première fois : clic droit → Ouvrir → Ouvrir.** Si le Mac demande l'accès à un dossier, cliquez sur **Autoriser** : c'est nécessaire pour les sauvegardes.
3. Une fenêtre de réglages s'ouvre : vous pouvez la laisser telle quelle et lancer le jeu.
4. Jouez au **clavier** ou avec une **manette** (Xbox, PlayStation et la plupart des manettes Bluetooth).
5. **Pour quitter :** **⌘ + Q**. Pensez à **sauvegarder dans le jeu** avant, sinon la progression est perdue.

### Les raccourcis utiles pendant la partie

| Touches | Effet |
|---|---|
| **⌘ + =** | Image plus détaillée (plus beau, plus lourd) |
| **⌘ + −** | Image moins détaillée (plus fluide) |
| **⌥ + ⌘ + P** | Afficher ou cacher les chiffres de performance |

### Conseils pour que ça tourne bien

- Jouez **dans une fenêtre** et gardez-la **visible** (ne la cachez pas, ne l'enfilez pas sous une autre).
- De petits à-coups la **première fois** que vous voyez une zone sont normaux.
- Fermez les autres applications et laissez le Mac **branché**.
- Si c'est saccadé : ouvrez les réglages et choisissez une taille d'image plus petite (**Render scale**), ou utilisez **⌘ + −** en jeu.

---

## En cas de problème

| Ce que vous voyez | Que faire |
|---|---|
| « Impossible d'ouvrir l'application » | Clic droit sur l'icône → **Ouvrir** → **Ouvrir**, ou **Réglages Système → Confidentialité et sécurité → Ouvrir quand même**. |
| Le bouton **Build My Local Game** reste gris | Lisez la ligne sous le bouton : mauvais dossier, fichier du jeu absent, dossier dans iCloud ou dans un projet Git. Refaites l'étape 3. |
| Une ligne rouge dans le journal avec `Missing prerequisite` ou `uv is missing` | Refaites l'étape 2, puis la vérification 2.e. |
| Une erreur sur **Xcode 27.2** ou **Metal Toolchain** | Il faut exactement cette version de Xcode : ouvrez-la une fois, puis relancez `xcodebuild -downloadComponent MetalToolchain` dans le Terminal. Si l'erreur persiste, demandez de l'aide (voir plus bas). |
| `The supported Ocarina of Time v131072 RomFS image was not found` | Le dossier ne contient pas la **mise à jour v131072**. Cette version de Bowshot ne fonctionne qu'avec celle-là. |
| La fabrication s'arrête | Le message en rouge dit pourquoi. Le journal complet est dans `Ocarina/Bowshot-local/build.log`. Relancer **Build My Local Game** reprend là où il s'était arrêté. |
| Fenêtre noire pendant le jeu | Gardez la fenêtre visible et au premier plan. Si elle reste noire, quittez (⌘ + Q) et rouvrez. |

**Si vous êtes bloqué**, demandez à la personne qui vous a donné ce guide, ou ouvrez un signalement sur <https://github.com/LeoGeneret/Bowshot/issues> en indiquant votre modèle de Mac, votre version de macOS et le message d'erreur. **Ne joignez jamais** de fichier du jeu, de sauvegarde ou de clé.

## À ne jamais faire

**Ne partagez, ne téléversez et ne publiez jamais** l'application *Ocarina of Time*, le dossier *Bowshot-local*, votre fichier du jeu ou vos sauvegardes : ils contiennent du matériel du jeu. Ils doivent rester sur votre Mac.

---

*Bowshot est un projet indépendant, non affilié à Nintendo. Version préliminaire : testée uniquement pour la mise à jour v131072. La documentation technique complète est dans le [README](README.md).*
