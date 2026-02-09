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
const BATTERY_DRAIN := 3.0
const BATTERY_RECHARGE_SPEED := 35.0
const FLASH_ENERGY_MAX := 4.0
const FLASH_ENERGY_MIN := 0.15
const FLASH_RANGE_MAX := 35.0
const FLASH_RANGE_MIN := 6.0
const FLASH_ANGLE_MAX := 50.0
const FLASH_ANGLE_MIN := 15.0

# --- Doors ---
const DOOR_INTERACT_DISTANCE := 3.5
const DOOR_OPEN_SPEED := 1.5
const DOOR_SOUND_PATH := "res://songs/door_open.ogg"

# --- Footsteps ---
const FOOTSTEP_SOUND_PATH := "res://songs/footstep.ogg"

# --- Floor 2 ---
const FLOOR_2_HEIGHT := 6.0

# --- Puzzle ---
const UV_PARTS_NEEDED := 4
const INTERACT_DISTANCE := 2.5
const EXIT_CODE := [7, 3, 5, 0]
