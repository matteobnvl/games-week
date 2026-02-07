from ursina import *
from ursina.prefabs.first_person_controller import FirstPersonController

from engine.map_parser import MapParser
from settings import SCALE, WALL_HEIGHT, WINDOW_SIZE, WINDOW_TITLE


class Game:
    def __init__(self, map_image):
        self.app = Ursina()
        self._configure_window()

        self.map = MapParser(map_image)
        self.spawn_world = self._to_world(self.map.spawn_pos)

        self._build_world()
        self._setup_lighting()
        self._setup_player()
        self._setup_ui()

        self.frame_counter = 0
        mouse.locked = True

    def _configure_window(self):
        window.title = WINDOW_TITLE
        window.borderless = False
        window.fullscreen = False
        window.exit_button.visible = True
        window.fps_counter.enabled = True
        window.vsync = True
        window.size = WINDOW_SIZE
        window.position = (100, 100)

    def _to_world(self, grid_pos):
        """Convertit une position grille (col, row) en position 3D (x, z)."""
        x = grid_pos[0] * SCALE
        z = (self.map.rows - grid_pos[1]) * SCALE
        return Vec3(x, 0, z)

    def _build_world(self):
        # Sol
        Entity(
            model='cube', color=color.gray, collider='box', texture='white_cube',
            position=(self.map.cols * SCALE / 2, -0.5, self.map.rows * SCALE / 2),
            scale=(self.map.cols * SCALE, 1, self.map.rows * SCALE),
        )

        # Murs optimisés
        for col, row, w, h in self.map.wall_rectangles:
            Entity(
                model='cube', color=color.dark_gray, collider='box', texture='white_cube',
                position=((col + w / 2) * SCALE, WALL_HEIGHT / 2, (self.map.rows - row - h / 2) * SCALE),
                scale=(w * SCALE, WALL_HEIGHT, h * SCALE),
            )

        # Marqueur de spawn
        Entity(
            model='cube', color=color.green, double_sided=True,
            position=(self.spawn_world.x, 1, self.spawn_world.z),
            scale=(SCALE * 2, 2, SCALE * 2),
        )

    def _setup_lighting(self):
        camera.clip_plane_far = 100
        camera.clip_plane_near = 0.1
        Sky(color=color.rgb(135, 206, 235))
        AmbientLight(color=color.rgba(255, 255, 255, 0.8))
        DirectionalLight(y=20, z=-10, rotation=(45, -45, 0), color=color.rgba(255, 255, 255, 0.6))

    def _setup_player(self):
        self.player = FirstPersonController(
            position=Vec3(self.spawn_world.x, 2, self.spawn_world.z),
            mouse_sensitivity=Vec2(40, 40),
            speed=5, jump_height=2, jump_duration=0.5, gravity=1,
        )
        self.player.cursor.visible = False
        self.player.collider = BoxCollider(self.player, Vec3(0, 1, 0), Vec3(0.8, 1.8, 0.8))

    def _setup_ui(self):
        self.fps_text = Text(
            text='', position=window.top_left + Vec2(0.01, -0.03),
            scale=1.5, color=color.lime,
        )
        self.info_text = Text(
            text=f'Echelle: {SCALE} | Murs: {len(self.map.wall_rectangles)}',
            position=window.bottom_left + Vec2(0.01, 0.05),
            scale=1.2, background=True,
        )
        controls = Text(
            text='ZQSD: Bouger | SOURIS: Regarder | ESC: Menu | F11: Plein ecran | E: Quitter',
            position=(0, 0.45), scale=1, color=color.white, background=True,
        )
        invoke(lambda: setattr(controls, 'enabled', False), delay=8)

    def update(self):
        self.frame_counter += 1
        if self.frame_counter % 10 == 0:
            fps = int(1 / time.dt) if time.dt > 0 else 0
            self.fps_text.text = f'FPS: {fps}'
            if fps > 50:
                self.fps_text.color = color.lime
            elif fps > 30:
                self.fps_text.color = color.yellow
            else:
                self.fps_text.color = color.red

    def input(self, key):
        if key == 'escape':
            mouse.locked = not mouse.locked
        elif key == 'e':
            quit()
        elif key == 'f11':
            window.fullscreen = not window.fullscreen
        elif key == 'f':
            self.fps_text.visible = not self.fps_text.visible
            self.info_text.visible = not self.info_text.visible
        elif key == 'r':
            self.player.position = Vec3(self.spawn_world.x, 2, self.spawn_world.z)
            self.player.rotation_y = 0
        elif key == 't':
            self.player.position = Vec3(self.spawn_world.x, 5, self.spawn_world.z)

    def run(self):
        self.app.run()