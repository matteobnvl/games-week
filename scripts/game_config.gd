class_name GameConfig
## Central configuration file containing all game constants.

# --- Map & Scale ---
const SCALE := 0.12
const WALL_HEIGHT := 5.0
const THRESHOLD := 128
const MAP_PATH := "res://maps/map_100.png"
const MAP_PATH_F2 := "res://maps/map_200.png"

# --- Player Movement ---
const WALK_SPEED := 5.0
const SPRINT_SPEED := 9.0
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.002

# --- Stamina ---
const STAMINA_MAX := 100.0
const STAMINA_DRAIN := 25.0
const STAMINA_REGEN := 15.0
const STAMINA_MIN_TO_SPRINT := 10.0

# --- Flashlight ---
const BATTERY_MAX := 100.0
const BATTERY_DRAIN := 1.5
const BATTERY_RECHARGE_SPEED := 10.0
const FLASH_ENERGY_MAX := 4.0
const FLASH_ENERGY_MIN := 0.15
const FLASH_RANGE_MAX := 35.0
const FLASH_RANGE_MIN := 6.0
const FLASH_ANGLE_MAX := 50.0
const FLASH_ANGLE_MIN := 15.0

# --- Doors ---
const DOOR_INTERACT_DISTANCE := 3.5
const DOOR_OPEN_SPEED := 0.5
const DOOR_SOUND_PATH := "res://songs/door_open.ogg"

# --- Footsteps ---
const FOOTSTEP_SOUND_PATH := "res://songs/11-Sente-des-Carrelets-2.ogg"

# --- Player Sounds ---
const RATCHET_SOUND_PATH := "res://songs/ratchet.wav"
const HEAVY_BREATHING_SOUND_PATH := "res://songs/heavy-breathing.wav"

# --- Ambient Music (random on game start) ---
const AMBIENT_MUSIC_PATHS := [
	"res://songs/hitslab-scary-creepy-dark-music-460378.mp3",
	"res://songs/lnplusmusic-scary-horror-dark-music-372674.mp3",
	"res://songs/nikitakondrashev-horror-music-box-375927.mp3",
	"res://songs/nikitakondrashev-horror-spooky-piano-254402.mp3",
]

# --- Floor 2 ---
const FLOOR_2_HEIGHT := 6.0

# --- Puzzle ---
const UV_PARTS_NEEDED := 4
const INTERACT_DISTANCE := 2.5
const EXIT_CODE := [7, 3, 5, 0]

# --- Enemy ---
const ENEMY_MODEL_PATH := "res://characters/goose.glb"
const ENEMY_PATROL_SPEED := 2.5
const ENEMY_CHASE_SPEED := 5.5
const ENEMY_DETECTION_RADIUS := 30.0       # Max distance to detect sound/light
const ENEMY_CATCH_DISTANCE := 1.8          # Distance to catch player
const ENEMY_LOSE_INTEREST_TIME := 5.0      # Seconds without stimuli before returning to patrol
const ENEMY_LIGHT_DETECTION_MULT := 1.5    # Flashlight attracts more than footsteps
const ENEMY_SOUND_SPRINT_RADIUS := 20.0    # Radius of sprinting noise
const ENEMY_SOUND_WALK_RADIUS := 8.0       # Radius of walking noise
const ENEMY_SPAWN_MIN_DIST := 40.0         # Minimum spawn distance from player
const ENEMY_GROWL_SOUND_PATH := "res://songs/monster-growl_with-reverb.wav"
const ENEMY_FIND_GROWL_SOUND_PATH := "res://songs/monster-growl-find-me.wav"
const ENEMY_GROWL_INTERVAL_MIN := 8.0      # Min seconds between random growls
const ENEMY_GROWL_INTERVAL_MAX := 20.0     # Max seconds between random growls

# --- Whiteboard ---
const WHITEBOARD_HEIGHT_RATIO := 1.5       # Height = width × this ratio
const WHITEBOARD_MAX_HEIGHT := 4.0        # Cap height so it never fills the wall
const WHITEBOARD_THICKNESS := 0.06
const WHITEBOARD_INTERACT_DISTANCE := 3.0

# --- Enemy 2 (Funny Fear) ---
const ENEMY2_MODEL_PATH := "res://characters/funny_fear_p2_rig.glb"
const ENEMY2_MODEL_SCALE := Vector3(1, 1, 1)  # Adjust if needed
const ENEMY2_MODEL_Y_OFFSET := 0.0                     # Adjust if needed
const ENEMY2_MODEL_WALK_ANIMATION := "funny_fear_p2_ref_skeleton|walk"
const ENEMY2_MODEL_RUN_ANIMATION := "funny_fear_p2_ref_skeleton|run"
const ENEMY2_MODEL_ATTACK_ANIMATION := "funny_fear_p2_ref_skeleton|attack"
const ENEMY2_MODEL_IDLE_ANIMATION := "funny_fear_p2_ref_skeleton|idle"
const ENEMY2_MODEL_SCREAM_ANIMATION := "funny_fear_p2_ref_skeleton|scream"

