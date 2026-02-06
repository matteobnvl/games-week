from ursina import *
from ursina.prefabs.first_person_controller import FirstPersonController

app = Ursina()

# Génération de la map
for z in range(15):
    for x in range(15):
        Entity(
            model='cube',
            color=color.gray,
            collider='box',
            position=(x, 0, z),
            texture='white_cube'
        )

# Joueur
player = FirstPersonController()


# --- GESTION DES TOUCHES ---
def input(key):
    # Quitter le jeu avec Esc
    if key == 'escape':
        quit()

    # Optionnel : Débloquer la souris avec 'm' pour pouvoir fermer la fenêtre manuellement
    if key == 'm':
        mouse.locked = not mouse.locked


app.run()