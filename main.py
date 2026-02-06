from ursina import *
from ursina.prefabs.first_person_controller import FirstPersonController
from PIL import Image
import numpy as np

# --- PARAMÈTRES AJUSTABLES ---
SCALE = 0.12  # ← AJUSTEZ ICI pour changer la taille de la map
WALL_HEIGHT = 3
THRESHOLD = 128  # Pixels < threshold = murs noirs


# --- CHARGEMENT DE LA MAP ---
def load_map_from_pixels(image_path):
    """Charge l'image pixel par pixel"""
    img = Image.open(image_path).convert('L')
    pixels = np.array(img)

    height, width = pixels.shape
    print(f"📊 Image: {width}x{height} pixels")

    # Créer la grille
    grid = []
    for row in range(height):
        line = []
        for col in range(width):
            if pixels[row, col] < THRESHOLD:
                line.append(1)  # Mur
            else:
                line.append(0)  # Vide
        grid.append(line)

    # TROUVER UN BON SPAWN (au centre d'une zone blanche)
    spawn_pos = find_safe_spawn(grid, width, height)

    return grid, spawn_pos, height, width


def find_safe_spawn(grid, width, height):
    """
    Trouve un bon point de spawn au centre d'une zone blanche.
    Cherche d'abord au centre de l'image, puis en spirale.
    """
    # 1. Essayer le centre
    center_x, center_y = width // 2, height // 2

    if grid[center_y][center_x] == 0:  # Si le centre est vide
        print(f"✅ Spawn trouvé au centre: ({center_x}, {center_y})")
        return (center_x, center_y)

    # 2. Chercher en spirale depuis le centre
    max_radius = max(width, height) // 2

    for radius in range(1, max_radius, 5):  # Par pas de 5 pour aller plus vite
        for angle in range(0, 360, 15):  # Tous les 15 degrés
            rad = angle * 3.14159 / 180
            x = int(center_x + radius * np.cos(rad))
            y = int(center_y + radius * np.sin(rad))

            if 0 <= x < width and 0 <= y < height:
                if grid[y][x] == 0:  # Zone vide trouvée
                    print(f"✅ Spawn trouvé en spirale: ({x}, {y})")
                    return (x, y)

    # 3. Si rien trouvé, chercher la première zone blanche
    for row in range(height):
        for col in range(width):
            if grid[row][col] == 0:
                print(f"⚠️ Spawn par défaut (première zone blanche): ({col}, {row})")
                return (col, row)

    # 4. Dernier recours (ne devrait jamais arriver)
    print(f"❌ Aucune zone blanche trouvée! Spawn au centre absolu")
    return (width // 2, height // 2)


def merge_walls(grid, rows, cols):
    """Fusionne les murs adjacents en rectangles"""
    visited = [[False] * cols for _ in range(rows)]
    rectangles = []

    for row in range(rows):
        for col in range(cols):
            if grid[row][col] == 1 and not visited[row][col]:
                # Largeur max
                width = 0
                for c in range(col, cols):
                    if grid[row][c] == 1 and not visited[row][c]:
                        width += 1
                    else:
                        break

                # Hauteur max
                height = 0
                for r in range(row, rows):
                    if all(grid[r][c] == 1 and not visited[r][c]
                           for c in range(col, col + width) if c < cols):
                        height += 1
                    else:
                        break

                for r in range(row, row + height):
                    for c in range(col, col + width):
                        visited[r][c] = True

                rectangles.append((col, row, width, height))

    return rectangles


# --- INITIALISATION ---
# FIX MACOS: Configurer la fenêtre AVANT de créer Ursina
window_config = {
    'size': (1280, 720),  # Taille fixe au lieu de auto
    'borderless': False,  # Activer les bordures
    'fullscreen': False,
    'exit_button': True,
    'forced_aspect_ratio': None
}

# Appliquer la config
import sys

for key, value in window_config.items():
    sys.argv.append(f'--{key}')
    if value is not None and value is not True:
        sys.argv.append(str(value))

app = Ursina()

# Configuration de la fenêtre pour macOS
window.title = 'Map 3D - Labyrinthe'
window.borderless = False  # Important pour macOS
window.fullscreen = False
window.exit_button.visible = True
window.fps_counter.enabled = True
window.vsync = True

# Forcer une taille de fenêtre valide
window.size = (1280, 720)
window.position = (100, 100)

print(f"\n{'=' * 60}")
print(f"🎮 Chargement de la map avec échelle {SCALE}...")
print(f"{'=' * 60}\n")

grid, spawn_pos, rows, cols = load_map_from_pixels('map2.png')

print(f"📍 Position spawn: {spawn_pos}")
print(f"🔢 Grille: {cols}x{rows} pixels")

# Vérifier que le spawn n'est pas dans un mur
if grid[spawn_pos[1]][spawn_pos[0]] == 1:
    print("⚠️ ATTENTION: Spawn dans un mur! Recherche d'une meilleure position...")
    spawn_pos = find_safe_spawn(grid, cols, rows)

# Regrouper les murs
wall_rectangles = merge_walls(grid, rows, cols)
original_walls = sum(row.count(1) for row in grid)
reduction = ((1 - len(wall_rectangles) / max(original_walls, 1)) * 100)

print(f"⚡ Optimisation: {len(wall_rectangles)} entités au lieu de {original_walls}")
print(f"🎯 Réduction: {reduction:.1f}%")

# --- GÉNÉRATION 3D ---
# Sol unifié
floor = Entity(
    model='cube',
    color=color.gray,
    position=(cols * SCALE / 2, -0.5, rows * SCALE / 2),
    scale=(cols * SCALE, 1, rows * SCALE),
    texture='white_cube',
    collider='box'
)

# Murs regroupés
walls = []
for col, row, width, height in wall_rectangles:
    x = (col + width / 2) * SCALE
    z = (rows - row - height / 2) * SCALE

    wall = Entity(
        model='cube',
        color=color.dark_gray,
        position=(x, WALL_HEIGHT / 2, z),
        scale=(width * SCALE, WALL_HEIGHT, height * SCALE),
        texture='white_cube',
        collider='box'
    )
    walls.append(wall)

# Marqueur de spawn (gros cube vert pour le voir facilement)
spawn_x = spawn_pos[0] * SCALE
spawn_z = (rows - spawn_pos[1]) * SCALE

spawn_marker = Entity(
    model='cube',
    color=color.green,
    position=(spawn_x, 1, spawn_z),
    scale=(SCALE * 2, 2, SCALE * 2),
    double_sided=True
)

print(f"\n🟢 Marqueur de spawn placé à: ({spawn_x:.1f}, {spawn_z:.1f})")

# --- OPTIMISATIONS ---
camera.clip_plane_far = 100
camera.clip_plane_near = 0.1

# Ciel bleu pour bien voir
Sky(color=color.rgb(135, 206, 235))

# Lumières
AmbientLight(color=color.rgba(255, 255, 255, 0.8))
DirectionalLight(y=20, z=-10, rotation=(45, -45, 0), color=color.rgba(255, 255, 255, 0.6))

# --- JOUEUR ---
start_pos = Vec3(spawn_x, 2, spawn_z)

print(f"👤 Position joueur: {start_pos}")

player = FirstPersonController(
    position=start_pos,
    mouse_sensitivity=Vec2(40, 40),
    speed=5,
    jump_height=2,
    jump_duration=0.5,
    gravity=1
)
player.cursor.visible = False
player.collider = BoxCollider(player, Vec3(0, 1, 0), Vec3(0.8, 1.8, 0.8))

# --- INTERFACE ---
fps_text = Text(
    text='',
    position=window.top_left + Vec2(0.01, -0.03),
    scale=1.5,
    color=color.lime
)

info_text = Text(
    text=f'Echelle: {SCALE} | Murs: {len(wall_rectangles)}',
    position=window.bottom_left + Vec2(0.01, 0.05),
    scale=1.2,
    background=True
)

# Instructions
controls_text = Text(
    text='ZQSD: Bouger | SOURIS: Regarder | ESC: Menu | F11: Plein ecran | Q: Quitter',
    position=(0, 0.45),
    scale=1,
    color=color.white,
    background=True
)
invoke(lambda: setattr(controls_text, 'enabled', False), delay=8)

# --- UPDATE ---
frame_counter = 0


def update():
    global frame_counter
    frame_counter += 1

    if frame_counter % 10 == 0:
        fps = int(1 / time.dt) if time.dt > 0 else 0
        fps_text.text = f'FPS: {fps}'

        if fps > 50:
            fps_text.color = color.lime
        elif fps > 30:
            fps_text.color = color.yellow
        else:
            fps_text.color = color.red


# --- CONTRÔLES ---
def input(key):
    if key == 'escape':
        mouse.locked = not mouse.locked
        print(f"Souris {'verrouillée' if mouse.locked else 'déverrouillée'}")

    if key == 'e':
        quit()

    if key == 'f11':
        window.fullscreen = not window.fullscreen
        print(f"Plein écran: {window.fullscreen}")

    if key == 'f':
        fps_text.visible = not fps_text.visible
        info_text.visible = not info_text.visible

    if key == 'r':
        player.position = start_pos
        player.rotation_y = 0
        print("Position réinitialisée")

    if key == 't':
        # Téléporter au marqueur vert
        player.position = Vec3(spawn_x, 5, spawn_z)
        print(f"Téléporté au spawn: {player.position}")


# Verrouiller la souris
mouse.locked = True

print(f"\n{'=' * 60}")
print("✅ Map chargée avec succès!")
print(f"📏 Taille réelle: {cols * SCALE:.1f} x {rows * SCALE:.1f} unités")
print(f"🖥️  Fenêtre: 1280x720 (redimensionnable)")
print(f"\n🎮 CONTRÔLES:")
print("   ZQSD = Déplacer")
print("   SOURIS = Regarder")
print("   ESPACE = Sauter")
print("   R = Reset position")
print("   T = Téléporter au spawn")
print("   F11 = Plein écran")
print("   ESC = Menu / Déverrouiller souris")
print("   Q = Quitter")
print(f"\n🍎 macOS: La fenêtre devrait maintenant être redimensionnable")
print(f"         avec les boutons rouge/jaune/vert en haut à gauche!")
print(f"{'=' * 60}\n")

app.run()