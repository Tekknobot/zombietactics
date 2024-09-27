extends Node2D

@onready var ZOMBIE_SCENE = preload("res://assets/scenes/prefab/Zombie.scn")  # Preload Zombie scene
@onready var SOLDIER_SCENE = preload("res://assets/scenes/prefab/Soldier.scn")  # Preload Soldier scene
@onready var MERCENARY_SCENE = preload("res://assets/scenes/prefab/Mercenary.scn")  # Preload Mercenary scene
@onready var tile_map = get_node("/root/MapManager/TileMap")  # Adjust path based on your scene structure

const WATER = 0
const DISTRICT_ID = 1
const BUILDING_ID = 2
const STADIUM_ID = 3
const TOWER_ID = 4

var grid_width = 16
var grid_height = 16
var rng = RandomNumberGenerator.new()
var map_ready: bool = false  # Flag to check if map is ready

# Maximum spawn counts for each unit type
@export var max_zombies: int = 10
@export var max_soldiers: int = 5
@export var max_mercenaries: int = 3

# Current spawn counts for each unit type
var current_zombies: int = 0
var current_soldiers: int = 0
var current_mercenaries: int = 0

func _ready():
	# Initialize map_ready from the MapManager
	var map_manager = get_tree().get_root().get_node("MapManager")  # Get the MapManager node
	map_ready = map_manager.map_ready  # Get the initial state of map_ready

func _process(delta: float):
	# Poll for the map_ready state
	if not map_ready:
		var map_manager = get_tree().get_root().get_node("MapManager")  # Ensure we get the latest reference
		map_ready = map_manager.map_ready  # Update our local state
		
		if map_ready:  # If the map is now ready, proceed to spawn units
			_on_map_generated()

# Function called when the map generation is complete
func _on_map_generated():
	spawn_zombies()     # Spawn zombies on the left side
	spawn_soldiers()    # Spawn soldiers in the center
	spawn_mercenaries() # Spawn mercenaries on the right side

func spawn_zombies():
	# Define the area for zombies: left half of the grid
	var spawn_area = Rect2(0, 0, grid_width / 2, grid_height)

	while current_zombies < max_zombies:
		var found_spawn = false  # Flag to check if a spawn location was found
		for x in range(spawn_area.position.x, spawn_area.position.x + spawn_area.size.x):
			for y in range(spawn_area.position.y, spawn_area.position.y + spawn_area.size.y):
				var tile_id = tile_map.get_cell_source_id(0, Vector2i(x, y))

				# Check if the tile is valid for spawning (not water or a structure and not occupied)
				if is_valid_spawn_tile(tile_id) and not is_occupied(x, y):
					spawn_zombie(x, y)
					found_spawn = true
					break  # Exit the loop after spawning one zombie
			if found_spawn:
				break  # Exit the outer loop if a zombie was spawned

func spawn_soldiers():
	# Define the area for soldiers: center of the grid
	var spawn_area = Rect2(grid_width / 2, 0, grid_width / 2, grid_height)

	while current_soldiers < max_soldiers:
		var found_spawn = false  # Flag to check if a spawn location was found
		for x in range(spawn_area.position.x, spawn_area.position.x + spawn_area.size.x):
			for y in range(spawn_area.position.y, spawn_area.position.y + spawn_area.size.y):
				var tile_id = tile_map.get_cell_source_id(0, Vector2i(x, y))

				# Check if the tile is valid for spawning (not water or a structure and not occupied)
				if is_valid_spawn_tile(tile_id) and not is_occupied(x, y):
					spawn_soldier(x, y)
					found_spawn = true
					break  # Exit the loop after spawning one soldier
			if found_spawn:
				break  # Exit the outer loop if a soldier was spawned

func spawn_mercenaries():
	# Define the area for mercenaries: right half of the grid
	var spawn_area = Rect2(grid_width / 2, 0, grid_width / 2, grid_height)

	while current_mercenaries < max_mercenaries:
		var found_spawn = false  # Flag to check if a spawn location was found
		for x in range(spawn_area.position.x, spawn_area.position.x + spawn_area.size.x):
			for y in range(spawn_area.position.y, spawn_area.position.y + spawn_area.size.y):
				var tile_id = tile_map.get_cell_source_id(0, Vector2i(x, y))

				# Check if the tile is valid for spawning (not water or a structure and not occupied)
				if is_valid_spawn_tile(tile_id) and not is_occupied(x, y):
					spawn_mercenary(x, y)
					found_spawn = true
					break  # Exit the loop after spawning one mercenary
			if found_spawn:
				break  # Exit the outer loop if a mercenary was spawned

func is_valid_spawn_tile(tile_id: int) -> bool:
	return tile_id != WATER and not is_structure(tile_id)

func is_structure(tile_id: int) -> bool:
	# Define a list of tile IDs that represent structures
	var structure_ids = [
		DISTRICT_ID,
		BUILDING_ID,
		STADIUM_ID,
		TOWER_ID
	]
	
	# Check if the given tile ID is in the list of structure IDs
	return tile_id in structure_ids

# Check if a tile at (x, y) is already occupied by a Zombie, Soldier, or Mercenary
func is_occupied(x: int, y: int) -> bool:
	# Convert tile coordinates to local position
	var local_position = tile_map.map_to_local(Vector2i(x, y))

	# Check each child to see if any occupy the same position
	for child in get_children():
		if child.position == local_position:
			return true  # A unit is already occupying this position

	return false  # No existing units occupy this position

func spawn_zombie(x: int, y: int):
	var zombie_instance = ZOMBIE_SCENE.instantiate()
	var local_position = tile_map.map_to_local(Vector2i(x, y))
	zombie_instance.position = local_position
	add_child(zombie_instance)
	current_zombies += 1  # Increment the zombie count

func spawn_soldier(x: int, y: int):
	var soldier_instance = SOLDIER_SCENE.instantiate()
	var local_position = tile_map.map_to_local(Vector2i(x, y))
	soldier_instance.position = local_position
	add_child(soldier_instance)
	current_soldiers += 1  # Increment the soldier count

func spawn_mercenary(x: int, y: int):
	var mercenary_instance = MERCENARY_SCENE.instantiate()
	var local_position = tile_map.map_to_local(Vector2i(x, y))
	mercenary_instance.position = local_position
	add_child(mercenary_instance)
	current_mercenaries += 1  # Increment the mercenary count
