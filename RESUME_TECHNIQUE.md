# RÉSUMÉ TECHNIQUE - Jeu Escape Room Godot 4 (GDScript)

## CONCEPT DU JEU
Escape room 3D first-person dans un bâtiment de 2 étages. Le joueur explore avec une lampe torche, résout 3 puzzles pour trouver un code à 4 chiffres, et s'échappe par une porte de sortie. Ambiance horreur avec lore sur "la bête" et des étudiants disparus.

---

## ARCHITECTURE TECHNIQUE

### Fichier unique : `main.gd` (extends Node3D)
Tout le jeu est dans un seul script (~2400 lignes cible). Pas de scènes séparées pour les objets — tout est créé par code.

### Génération procédurale depuis 2 images PNG
- **`map_100.png`** : Plan du rez-de-chaussée (N1). Chaque pixel = une cellule.
- **`map_200.png`** : Plan de l'étage 2 (N2). Même dimension.

**Code couleur des pixels :**
| Couleur | Code | Signification |
|---------|------|---------------|
| Noir | 1 | Mur |
| Blanc | 0 | Sol libre (marchable) |
| Rouge | 2 | Porte (pivot, s'ouvre à 90°) |
| Bleu | 3 | Fenêtre (verre transparent) |
| Vert | 4 | Terrasse (sol extérieur) |
| Magenta | 5 | Barrière vitrée |
| Cyan | 6 | Machine à café (lumière spot) |
| Jaune | 7 | Escalier (sur map_100 uniquement) |

**Pour map_200 spécifiquement :**
- Jaune = vide total (pas de sol N2, le plafond N1 reste)
- Blanc = sol N2 existe (le plafond N1 est supprimé, remplacé par le sol N2)

### Constantes clés
```
SCALE = 0.12          # 1 pixel = 0.12 unités Godot
WALL_HEIGHT = 5.0     # Hauteur des murs
FLOOR_2_HEIGHT = 6.0  # Altitude du sol N2
THRESHOLD = 128       # Seuil noir/blanc pour les murs
```

---

## CONSTRUCTION DU MONDE (ordre dans _ready)

### Étage 1 (N1)
1. **`_build_floor()`** : Un seul grand BoxMesh pour tout le sol + collision. Texture `res://textures/floor.jpg` en triplanar.
2. **`_build_terrace_floors()`** : Sols verts extérieurs (type 4).
3. **`_build_ceiling_with_holes()`** : Plafond N1 avec trous aux emplacements des terrasses, escaliers, ET zones où le sol N2 existe (évite double plafond). Texture `res://textures/ceiling_cut.jpg` triplanar.
4. **`_build_walls()`** : Murs fusionnés en rectangles (`_merge_type`). Texture `res://textures/wall.jpg` triplanar.
5. **`_build_windows()`** : Vitres transparentes (alpha 0.3, bleu pâle).
6. **`_build_glass_fences()`** : Barrières vitrées basses (30% hauteur mur).
7. **`_build_coffee_machines()`** : Blocs cyan 70% hauteur + SpotLight3D bleue.
8. **`_build_doors_from_blocks()`** : Portes 3D avec pivot, animation rotation 90°, son `door_open.ogg`. Orientation auto-détectée par murs adjacents (`_detect_orientation`).

### Étage 2 (N2)
9. **`_build_floor_2()`** : Parse `map_200.png`, construit :
   - Sol N2 (BoxMesh à y=FLOOR_2_HEIGHT-0.5) + fine dalle plafond-N1 en dessous (texture ceiling)
   - Plafond N2 (à y=FLOOR_2_HEIGHT+WALL_HEIGHT+0.5)
   - Murs N2 (à y=FLOOR_2_HEIGHT+WALL_HEIGHT/2)
   - Fenêtres N2
   - Portes N2 (pivot à y=FLOOR_2_HEIGHT)
   - Exclut les zones jaunes (vide = pas de sol)
   - Sauvegarde/restaure grid_data temporairement pour `_detect_orientation`

### Escaliers
10. **`_build_staircases()`** : Rampes est-ouest entre N1 et N2.
    - Détectés depuis zones jaunes sur map_100
    - 80 dalles fines avec chevauchement (slab_length = largeur/80 * 1.5)
    - Direction : monte vers le centre de la map
    - Murs latéraux (nord/sud) pleine hauteur
    - `floor_max_angle = 60°` sur le joueur pour pouvoir monter

### Algorithmes de parsing
- **`_merge_type(grid, rows, cols, type_id)`** : Fusionne pixels adjacents du même type en rectangles (greedy mesh). Retourne Array de [col, row, w, h].
- **`_merge_ceiling_areas(rows, cols, exclude_grid)`** : Même algo mais inverse (fusionne les zones NON exclues).
- **`_find_door_blocks(red_grid)`** : Flood-fill pour regrouper pixels rouges en blocs porte.
- **`_find_spawn()`** : Cherche espace libre en spirale depuis le centre de la map.

---

## JOUEUR

### CharacterBody3D créé par code
- Capsule collision (r=0.35, h=1.8)
- Camera3D à y=1.6
- SpotLight3D (lampe torche) enfant de la caméra
- Spawn après 3 frames (attente construction monde)

### Contrôles
| Touche | Action |
|--------|--------|
| Z/W, S, Q/A, D | Mouvement (AZERTY+QWERTY) |
| Souris | Regard |
| Shift | Sprint |
| Espace | Saut |
| F | Toggle lampe torche |
| R (maintenu) | Recharger batterie |
| G | Toggle mode UV |
| H | Toggle stroboscope |
| E | Interagir |
| Escape | Capturer/libérer souris |

### Systèmes
- **Stamina** : 100 max, drain 25/s sprint, regen 15/s (7.5 en mouvement). Barre jaune→orange→rouge.
- **Batterie** : 100 max, drain 3/s, recharge 35/s. Affecte énergie/portée/angle du spot. Flicker < 15%.
- **Pas** : AudioStreamPlayer avec pitch 1.0 (marche) / 1.4 (sprint). Son `footstep.ogg`.

---

## PUZZLES (système de leurres)

Le jeu a 3 puzzles, chacun donne 1 chiffre du code. **Chaque puzzle a des objets leurres** qui affichent des messages d'horreur au lieu du vrai chiffre. Le joueur doit trouver le bon objet parmi les faux.

**Code de sortie : `EXIT_CODE = [7, 3, 5, 0]`**

### Puzzle 1 : Lampe UV + Tableaux
- **4 pièces UV** à ramasser (Ampoule, Boitier, Batterie, Filtre) → craft lampe UV
- **4 tableaux blancs** (1 vrai + 3 leurres), index aléatoire `uv_real_index = randi() % 4`
- Mode UV (touche G) : la lampe devient violette, portée réduite 12m
- Approcher un tableau en mode UV → révélation progressive (alpha + émission)
- **Vrai** : affiche "Chiffre 1 trouvé : 7"
- **Leurres** : messages horreur via `fake_uv_messages` (Thomas promo 2019, la bête furieuse...)
- Métadonnées : `chiffre_mesh.set_meta("is_real", bool)` et `set_meta("fake_index", int)`

### Puzzle 2 : PC Quiz
- **3 PCs** (1 vrai + 2 leurres), index aléatoire `pc_real_index = randi() % 3`
- Interaction → ouvre panneau quiz (4 questions sciences/lumière)
- Faut tout bon pour valider
- **Vrai PC** : affiche "Le chiffre est : 3"
- **Faux PC** : messages système (Emma L. 847 jours, rapport_incident_2021 confidentiel...)
- Variable `active_pc_is_real` captée au moment d'interagir
- Quiz bloque le mouvement du joueur (`quiz_active`)

### Puzzle 3 : Stroboscope + Disque tournant
- **3 stroboscopes** à ramasser (1 vrai + 2 leurres), `strobe_real_index = randi() % 3`
- **4 disques tournants** (1 vrai + 3 leurres), `disc_real_index = randi() % 4`
- Disque tourne à 720°/s normalement
- Vrai strobo (touche H) : clignotement rapide 50ms blanc pur, énergie 8.0 → ralentit disque à 5°/s
- **Faux strobo** : grésillement sinusoïdal jaune pâle, énergie ~1.0, messages (Lucas M., "Pas celui-là...")
- S'approcher d'un disque avec vrai strobo actif :
  - **Vrai disque** : "Chiffre 3 trouvé : 5"
  - **Faux disque** : messages bête (4ème groupe, chaussures, "elle connaît le code"...)
- Variable `picked_strobe_is_real` captée au ramassage

### Porte de sortie
- Placée à la position de salle la plus éloignée du spawn
- Mesh rouge foncé + panneau vert "SORTIE" luminescent + OmniLight verte
- Première interaction → "porte verrouillée, code 4 chiffres"
- Avec ≥3 chiffres → vérification stricte (`found_digits[i] != EXIT_CODE[i]`)
- **Code correct** → victoire (fade noir + "VOUS VOUS ÊTES ÉCHAPPÉ" + retour menu)
- **Code faux** → message horreur + **reset total** : `found_digits = [-1,-1,-1,-1]`, `pc_done = false`
- Le joueur doit tout refaire avec des leurres potentiellement différents

### Placement des objets
- `_find_room_positions()` : scanne la grille tous les 40px, vérifie zone 7x7 libre, distance > 60px du spawn
- `_get_room_pos(index)` : retourne position par index dans l'array mélangé
- Index 0 = porte sortie, 1-4 = pièces UV, 5-8 = tableaux, 9-11 = PCs, 12-14 = strobos, 15-18 = disques

---

## UI
- **Barre stamina** (jaune, masquée si pleine)
- **Barre batterie** (bleue, toujours visible)
- **Label interaction** ("[E] Ramasser...", centre-bas)
- **Label quête** (haut-gauche, jaune : "Trouver la sortie" → "Explorer" → "Retourner à la porte")
- **Label code** (haut-droite : "Code : 7 _ 5 _")
- **Compteur UV** ("Pièces UV : 2/4" puis "Lampe UV : ON/OFF")
- **Message temporaire** (centre, durée adaptative : `3.0 + text.length() * 0.04`)
- **Panel quiz** (PanelContainer + VBoxContainer + boutons dynamiques)
- **Overlay victoire** (ColorRect fade + Label tween)

---

## ENVIRONNEMENT
- WorldEnvironment : fond bleu sombre, ambient 0.5, brouillard volumétrique (density 0.015)
- DirectionalLight3D : soleil orange bas (-15°), ombres
- Sphère soleil décorative à 300 unités

---

## TEXTURES (triplanar mapping)
- `res://textures/floor.jpg` — Sol (scale 0.5)
- `res://textures/wall.jpg` — Murs (scale 0.3)
- `res://textures/ceiling_cut.jpg` — Plafond (scale 0.5)
- Fallback couleur unie si texture absente

---

## LORE HORREUR (messages des leurres)

Les faux objets construisent une histoire parallèle :
- **Thomas** (promo 2019) : coincé dans les murs
- **Emma L.** : 847 jours de connexion sur un PC
- **Lucas M.** : propriétaire d'un stroboscope défectueux
- **4ème groupe** : tentative de fuite par le toit, seules chaussures retrouvées
- **"La bête"** : entité qui connaît le code, attend que tu l'entres, rendue furieuse par la lumière UV
- **Rapport incident 2021** : disparitions documentées à l'étage 2

---

## FICHIERS DU PROJET GODOT
- `main.gd` — Script principal (ce fichier)
- `map_100.png` — Plan N1
- `map_200.png` — Plan N2
- `menu.tscn` / `menu.gd` — Menu principal
- `cinematic.gd` — Cinématique d'intro
- `door_open.ogg` — Son porte
- `footstep.ogg` — Son pas
- `textures/floor.jpg`, `wall.jpg`, `ceiling_cut.jpg`

---

## ÉTAT DU CODE
Le fichier `main.gd` fourni dans la conversation contient le document complet AVEC :
- ✅ Étage 2 complet (`_build_floor_2`)
- ✅ Escaliers (`_build_staircases`) — rampes 80 dalles est-ouest
- ✅ Plafond intelligent (`_build_ceiling_with_holes`) — trous sous N2
- ✅ Textures triplanar sur sol/murs/plafond
- ✅ Système de leurres (4 tableaux, 3 PCs, 3 strobos, 4 disques)
- ✅ Messages horreur au lieu de faux chiffres
- ✅ Validation stricte du code à la porte + reset si faux
- ✅ Effet visuel strobo faux (grésillement vs clignotement)
- ✅ Durée message adaptative

**ATTENTION** : Le fichier physique uploadé (1928 lignes) est une ANCIENNE VERSION sans étage 2. La version complète avec tout le code est dans le contenu du document texte collé dans la conversation. Il faut s'assurer de travailler sur la version complète (~2400 lignes).
