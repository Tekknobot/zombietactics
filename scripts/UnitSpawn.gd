extends Node2D

# Preload the unit scenes
@export var unit_soldier: PackedScene  # Set the unit scene in the Inspector
@export var unit_merc: PackedScene  # Set the unit scene in the Inspector
@export var unit_dog: PackedScene  # Set the unit scene in the Inspector

@export var unit_zombie: PackedScene  # Set the unit scene for the zombie in the Inspector
@export var highlight_tile: PackedScene  # Highlight tile packed scene for hover effect

@onready var tilemap = get_parent().get_node("TileMap")  # Reference to the TileMap

# Tile IDs for non-spawnable tiles
const WATER = 0  # Replace with the actual tile ID for water

# Tile size for 16x16 grid (use the actual tile size if different)
const TILE_SIZE = 16  # Assuming each tile is 16x16 pixels

# To track the number of clicks and when zombies should spawn
var click_count = 0
var player_units_spawned = 0  # Track the number of player units spawned
var can_spawn = true  # Flag to control if further spawning is allowed

# Spawn a unit at a specified tile position
func spawn_unit(x: int, y: int):
	if unit_soldier == null and unit_merc == null and unit_dog == null:
		print("Unit scenes not assigned.")
		return

	if not can_spawn:
		print("Spawning is disabled after zombies have spawned.")
		return  # Exit early if spawning is disabled
	
	# Instantiate the appropriate unit based on the click count
	var unit_instance = null
	if click_count == 1:
		unit_instance = unit_soldier.instantiate()  # First click spawns a soldier
	elif click_count == 2:
		unit_instance = unit_merc.instantiate()  # Second click spawns a mercenary
	elif click_count == 3:
		unit_instance = unit_dog.instantiate()  # Third click spawns a dog
	
	# Convert tile coordinates to local position
	var local_position = tilemap.map_to_local(Vector2i(x, y))
	unit_instance.position = local_position  # Set the unit position
	
	# Ensure the unit's z_index is higher than the tiles
	unit_instance.z_index = int(unit_instance.position.y)  # Update z_index based on y-position

	# Add the unit to the scene tree
	add_child(unit_instance)
	
	# Add the unit to the "player_units" group (for easier management)
	unit_instance.add_to_group("player_units")
	
	# Increment the player units spawned counter
	player_units_spawned += 1
	
	# Only reset the click count after the third unit is spawned (dog)
	if click_count == 3:
		click_count = 0
	
	# If 3 units are spawned, trigger zombie spawning
	if player_units_spawned == 3:
		spawn_zombies()
	
	print("Unit spawned at position:", x, y)

# Check if a tile is spawnable (not water)
func is_spawnable_tile(tile_pos: Vector2i) -> bool:
	var tile_id = tilemap.get_cell_source_id(0, tile_pos)
	return tile_id != WATER

# Check if a tile is occupied by another unit or structure
func is_occupied(tile_pos: Vector2i) -> bool:
	# Check if the tile is already occupied by a unit
	for unit in get_tree().get_nodes_in_group("player_units"):
		if tilemap.local_to_map(unit.position) == tile_pos:
			return true  # Position is occupied by a unit
	
	# Check if the tile is occupied by a structure
	for structure in get_tree().get_nodes_in_group("structures"):
		if tilemap.local_to_map(structure.position) == tile_pos:
			return true  # Position is occupied by a structure
	
	return false

# Handle input events for mouse clicks
func _input(event):
	if event is InputEventMouseButton and event.pressed:
		# Convert mouse position to local space (taking into account map's position)
		var mouse_position = get_global_mouse_position()
		mouse_position.y += 8  # Adjust for the tile size
		
		# Print debug info to ensure the correct conversion
		print("Mouse position:", mouse_position)
		
		# Convert mouse position to local coordinates within the TileMap
		var local_pos = tilemap.to_local(mouse_position)
		
		# Print debug info to verify the local position
		print("Local position:", local_pos)
		
		# Convert local position to tile coordinates (using 16x16 grid size)
		var tile_pos = tilemap.local_to_map(local_pos)
		
		# Clamp tile coordinates to stay within bounds of a 16x16 grid (0 to 15 for both x and y)
		tile_pos.x = clamp(tile_pos.x, 0, 15)
		tile_pos.y = clamp(tile_pos.y, 0, 15)
		
		# Print tile position for debug
		print("Tile position (clamped):", tile_pos)  # Debug output to check tile position
		
		# Ensure the tile is within bounds
		if is_within_bounds(tile_pos):
			# Check if it's a valid, spawnable, and unoccupied tile
			if is_spawnable_tile(tile_pos) and not is_occupied(tile_pos):
				click_count += 1  # Increment the click count
				spawn_unit(tile_pos.x, tile_pos.y)
			else:
				print("Tile is either not spawnable or already occupied.")
		else:
			print("Tile position is out of bounds.")

# Function to check if the tile position is within the tilemap bounds
func is_within_bounds(tile_pos: Vector2i) -> bool:
	# Get the size of the tilemap (assuming rectangular bounds)
	var map_size: Vector2i = tilemap.get_used_rect().size

	# Check if the tile position is within the bounds of the tilemap
	return tile_pos.x >= 0 and tile_pos.y >= 0 and tile_pos.x < map_size.x and tile_pos.y < map_size.y

# Spawn zombies randomly after player units are spawned
func spawn_zombies():
	# Define how many zombies to spawn (for example, 5 zombies)
	var zombie_count = 32
	var spawn_attempts = 0
	
	# Get the size of the tilemap
	var map_size = tilemap.get_used_rect().size

	# Restrict zombie spawning to the top half of the map (y < map_size.y / 2)
	var max_y = map_size.y / 2
	
	while spawn_attempts < zombie_count:
		# Generate a random tile position, limiting y to the top half
		var random_x = randi() % map_size.x
		var random_y = randi() % max_y  # Limit y to the top half of the map
		var tile_pos = Vector2i(random_x, random_y)
		
		# Check if the tile is spawnable and not occupied by a player unit or structure
		if is_spawnable_tile(tile_pos) and not is_occupied(tile_pos):
			# Spawn a zombie at this position
			var zombie_instance = unit_zombie.instantiate()
			var local_position = tilemap.map_to_local(tile_pos)
			zombie_instance.position = local_position
			zombie_instance.z_index = int(zombie_instance.position.y)
			add_child(zombie_instance)
			zombie_instance.add_to_group("zombies")
			spawn_attempts += 1  # Increment the number of successful zombie spawns
			print("Zombie spawned at:", tile_pos)
		else:
			print("Tile is not spawnable or occupied. Retrying...")
	
	# After zombies are spawned, disable further spawning
	can_spawn = false
	print("All units and zombies have been spawned. Further spawning is disabled.")
