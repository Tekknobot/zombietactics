extends Node2D

# Preload the unit scenes
@export var unit_soldier: PackedScene  # Set the unit scene in the Inspector
@export var unit_merc: PackedScene  # Set the unit scene in the Inspector
@export var unit_dog: PackedScene  # Set the unit scene in the Inspector
@export var unit_zombie: PackedScene  # Set the unit scene for the zombie in the Inspector
@export var M1: PackedScene  # Set the unit scene for the zombie in the Inspector

@export var highlight_tile: PackedScene  # Highlight tile packed scene for hover effect

@onready var tilemap = get_parent().get_node("TileMap")  # Reference to the TileMap
@onready var map_manager = get_node("/root/MapManager")

# Tile IDs for non-spawnable tiles
var WATER # Replace with the actual tile ID for water

# Track the number of player units spawned
var player_units_spawned = 0
var can_spawn = true  # Flag to control if further spawning is allowed

# Track unique zombie IDs
var zombie_id_counter = 0  # Counter to assign unique IDs to zombies

func _ready():
	# Wait for a few frames to ensure the TileMap has generated fully
	await get_tree().process_frame  # Waits for one frame
	await get_tree().process_frame  # Additional frames if needed

	if map_manager.map_1:
		WATER = 0
	elif map_manager.map_2:
		WATER = 9
	elif map_manager.map_3:
		WATER = 15
	elif map_manager.map_4:
		WATER = 21
	else:
		print("Error: No map selected, defaulting WATER to 0.")
		WATER = 0  # Fallback value if no map is selected
			
	# Now check if the TileMap has usable tiles before proceeding
	if tilemap.get_used_rect().size.x == 0 or tilemap.get_used_rect().size.y == 0:
		print("Error: TileMap still has no usable tiles after waiting.")
	else:		
		spawn_player_units()  # Proceed to spawn units if the map has tiles

# Function to spawn player units on one half of the map
func spawn_player_units():
	# List of unit scenes for easier access
	var units = [unit_soldier, unit_merc, unit_dog, M1]
	
	# Spawn each unit at a random, valid position on one half of the map
	for unit_type in units:
		var spawn_position = get_random_spawn_position(true)  # Pass true to restrict to player side
		if spawn_position != Vector2i(-1, -1):
			spawn_unit_at(unit_type, spawn_position)
			player_units_spawned += 1
	
	# Once all player units are spawned, trigger zombie spawning
	spawn_zombies()

# Function to spawn a unit of a given type at a specified tile position
func spawn_unit_at(unit_type: PackedScene, tile_pos: Vector2i):
	if unit_type == null:
		print("Unit scene not assigned.")
		return
	
	# Instantiate and position the unit
	var unit_instance = unit_type.instantiate()
	unit_instance.position = tilemap.map_to_local(tile_pos)
	unit_instance.z_index = int(unit_instance.position.y)
	
	# Add to scene tree and player units group
	add_child(unit_instance)
	unit_instance.add_to_group("player_units")
	print("Player unit spawned at:", tile_pos)

# Spawn zombies randomly on the opposite half of the map
func spawn_zombies():
	var zombie_count = 16
	var spawn_attempts = 0
	
	# Loop until we spawn the desired number of zombies
	while spawn_attempts < zombie_count:
		var spawn_position = get_random_spawn_position(false)  # Pass false to restrict to zombie side
		
		# Spawn zombie at the chosen position if valid
		if spawn_position != Vector2i(-1, -1):
			var zombie_instance = unit_zombie.instantiate()
			zombie_instance.position = tilemap.map_to_local(spawn_position)
			zombie_instance.z_index = int(zombie_instance.position.y)
			
			# Assign a unique ID to the zombie
			zombie_instance.set("zombie_id", zombie_id_counter)  # Set a custom property for the unique ID
			zombie_id_counter += 1  # Increment the zombie ID for the next one
			
			# Add to scene tree and zombie units group
			add_child(zombie_instance)
			zombie_instance.add_to_group("zombies")
			spawn_attempts += 1
			print("Zombie spawned at:", spawn_position, "with ID:", zombie_instance.zombie_id)
			
			zombie_instance.zombie_id = zombie_id_counter
	
	# Disable further spawning once all zombies are spawned
	can_spawn = false
	print("All units and zombies have been spawned.")

# Finds a random, unoccupied, spawnable tile on the map, restricted by side if needed
func get_random_spawn_position(is_player_side: bool) -> Vector2i:
	var map_size = tilemap.get_used_rect().size
	
	# Ensure map size is valid to avoid modulo by zero error
	if map_size.x == 0 or map_size.y == 0:
		print("Error: TileMap has no usable tiles.")
		return Vector2i(-1, -1)  # Invalid position when map is empty
	
	var attempts = 0
	while attempts < 20:  # Limit attempts to prevent infinite loops
		# Determine the x-range based on which side we're spawning on
		var x_range_start = 0
		var x_range_end = map_size.x / 2 - 1  # Left half for players
		
		# If spawning zombies, use the right half of the map
		if not is_player_side:
			x_range_start = map_size.x / 2
			x_range_end = map_size.x - 1

		# Generate a random tile position within the specified range
		var random_x = randi_range(x_range_start, x_range_end)
		var random_y = randi() % map_size.y
		var tile_pos = Vector2i(random_x, random_y)
		
		# Check if the tile is spawnable and unoccupied
		if is_spawnable_tile(tile_pos) and not is_occupied(tile_pos):
			return tile_pos  # Return a valid position
		
		attempts += 1
	
	print("Could not find a valid spawn position after multiple attempts.")
	return Vector2i(-1, -1)  # Return an invalid position if none found

# Checks if a tile is spawnable (not water)
func is_spawnable_tile(tile_pos: Vector2i) -> bool:
	var tile_id = tilemap.get_cell_source_id(0, tile_pos)
	return tile_id != WATER

# Checks if a tile is occupied by another unit or structure
func is_occupied(tile_pos: Vector2i) -> bool:
	# Check if any units or structures occupy this tile
	for unit in get_tree().get_nodes_in_group("player_units"):
		if tilemap.local_to_map(unit.position) == tile_pos:
			return true
	for structure in get_tree().get_nodes_in_group("structures"):
		if tilemap.local_to_map(structure.position) == tile_pos:
			return true
	return false
