extends Node2D

@onready var ZOMBIE_SCENE = preload("res://assets/scenes/prefab/Zombie.scn")
@onready var tile_map = get_node("/root/MapManager/TileMap")  # Adjust path based on your scene structure

const WATER = 0
const DISTRICT_ID = 1
const BUILDING_ID = 2
const STADIUM_ID = 3
const TOWER_ID = 4

var grid_width = 16
var grid_height = 16
var rng = RandomNumberGenerator.new()

func _ready():
	spawn_zombies()

func spawn_zombies():
	for x in range(grid_width):
		for y in range(grid_height):
			var tile_id = tile_map.get_cell_source_id(0, Vector2i(x, y))

			# Check if the tile is valid for spawning (not water or a structure)
			if is_valid_spawn_tile(tile_id):
				if rng.randi_range(0, 100) < 5:  # 30% chance to spawn a zombie
					spawn_zombie(x, y)

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

func spawn_zombie(x: int, y: int):
	var zombie_instance = ZOMBIE_SCENE.instantiate()
	var local_position = tile_map.map_to_local(Vector2i(x, y))
	zombie_instance.position = local_position
	add_child(zombie_instance)
