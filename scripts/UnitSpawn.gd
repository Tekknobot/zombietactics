extends Node2D

@export var highlight_tile: PackedScene  # Highlight tile packed scene for hover effect

# Preload the unit scenes
@export var unit_soldier: PackedScene  # Set the unit scene in the Inspector
@export var unit_merc: PackedScene  # Set the unit scene in the Inspector
@export var unit_dog: PackedScene  # Set the unit scene in the Inspector

@export var unit_zombie: PackedScene  # Set the unit scene for the zombie in the Inspector
@export var unit_radioactive_zombie: PackedScene  # Set the unit scene for the zombie in the Inspector
@export var unit_crusher_zombie: PackedScene  # Set the unit scene for the zombie in the Inspector

@export var M1: PackedScene  
@export var M2: PackedScene  
@export var R1: PackedScene  
@export var R3: PackedScene 
@export var S2: PackedScene  
@export var S3: PackedScene  

@onready var tilemap = get_parent().get_node("TileMap")  # Reference to the TileMap
@onready var map_manager = get_node("/root/MapManager")

# Tile IDs for non-spawnable tiles
var WATER # Replace with the actual tile ID for water

# Track the number of player units spawned
var player_units_spawned = 0
var can_spawn = true  # Flag to control if further spawning is allowed

# Track unique zombie IDs
var zombie_id_counter = 0  # Counter to assign unique IDs to zombies

var zombie_names = [
	"Walker", "Crawler", "Stalker", "Biter",
	"Lurker", "Rotter", "Shambler", "Moaner",
	"Sniffer", "Stumbler", "Gnawer", "Howler",
	"Groaner", "Clawer", "Grunter", "Chomper",
	"Slasher", "Growler", "Drooler", "Scratcher",
	"Bleeder", "Rumbler", "Sludger", "Mangler",
	"Spitter", "Hunter", "Dragger", "Slimer",
	"Ripper", "Rager", "Slasher", "Tumbler"
]

func _ready():
	# Wait for a few frames to ensure the TileMap has generated fully
	await get_tree().process_frame  # Waits for one frame
	await get_tree().process_frame  # Additional frames if needed

	# Shuffle the zombie names to randomize the order
	zombie_names.shuffle()
	
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
	var units = [unit_soldier, unit_merc, unit_dog, M1, M2, R1, R3, S2, S3]
	
	# Units that need color modulation
	var mek_units = [M1, M2, R1, R3, S2, S3]

	# Spawn each unit at a random, valid position on one half of the map
	for unit_type in units:
		var spawn_position = get_random_spawn_position(true)  # Pass true to restrict to player side
		if spawn_position != Vector2i(-1, -1):
			var unit_instance = spawn_unit_at(unit_type, spawn_position)

			# If the unit is a mek unit, modulate its color
			if unit_type in mek_units:
				#unit_instance.modulate = Color8(255, 110, 255)  # Random color modulation
				pass
				
			player_units_spawned += 1

	# Once all player units are spawned, trigger zombie spawning
	spawn_zombies()


func spawn_unit_at(unit_type: PackedScene, tile_pos: Vector2i) -> Node2D:
	if unit_type == null:
		print("Unit scene not assigned.")
		return null

	# Instantiate and position the unit
	var unit_instance = unit_type.instantiate() as Node2D
	unit_instance.position = tilemap.map_to_local(tile_pos)
	unit_instance.z_index = int(unit_instance.position.y)

	# Randomly determine the direction (left or right)
	var random_direction = randi() % 2 == 0  # True for right, False for left
	unit_instance.scale = Vector2(
		abs(unit_instance.scale.x) if random_direction else -abs(unit_instance.scale.x),
		unit_instance.scale.y
	)

	# Add to scene tree and player units group
	add_child(unit_instance)
	unit_instance.add_to_group("player_units")
	print("Player unit spawned at:", tile_pos, "Facing:", "Right" if random_direction else "Left")

	return unit_instance

# Spawn zombies randomly on the opposite half of the map
func spawn_zombies():
	var zombie_count = 32
	var spawn_attempts = 0
	
	# Shuffle zombie names to ensure uniqueness
	zombie_names.shuffle()
	
	# Loop until we spawn the desired number of zombies
	while spawn_attempts < zombie_count:
		var spawn_position = get_random_spawn_position(false)  # Pass false to restrict to zombie side
		
		# Spawn zombie at the chosen position if valid
		if spawn_position != Vector2i(-1, -1):
			var zombie_instance
			
			# Determine the type of zombie to spawn based on the current map index
			if GlobalManager.current_map_index == 2:
				# 50% chance to spawn radioactive zombies on map index 2
				if randi() % 2 == 0:
					zombie_instance = unit_radioactive_zombie.instantiate()
				else:
					zombie_instance = unit_zombie.instantiate()
			elif GlobalManager.current_map_index == 3:
				# Mixed spawning: crusher zombies, radioactive zombies, and normal zombies
				var roll = randi() % 10  # Random roll (0 to 9)
				if roll < 2:  # 30% chance for radioactive zombie
					zombie_instance = unit_radioactive_zombie.instantiate()
				elif roll < 6:  # 70% chance for crusher zombie
					zombie_instance = unit_crusher_zombie.instantiate()
				else:  # 20% chance for normal zombie
					zombie_instance = unit_zombie.instantiate()
			else:
				# Only spawn normal zombies on other maps
				zombie_instance = unit_zombie.instantiate()
			
			# Set zombie properties
			zombie_instance.position = tilemap.map_to_local(spawn_position)
			zombie_instance.z_index = int(zombie_instance.position.y)
			
			# Assign a unique ID to the zombie
			zombie_instance.set("zombie_id", zombie_id_counter)  # Set a custom property for the unique ID
			zombie_id_counter += 1  # Increment the zombie ID for the next one
			
			# Assign a unique name to the zombie
			if zombie_names.size() > 0:
				zombie_instance.zombie_name = zombie_instance.zombie_type + " " + zombie_names.pop_back()  # Remove the last name from the list

			# Randomly determine the direction (left or right)
			var random_direction = randi() % 2 == 0  # True for right, False for left
			zombie_instance.scale = Vector2(
				abs(zombie_instance.scale.x) if random_direction else -abs(zombie_instance.scale.x),
				zombie_instance.scale.y
			)
			
			# Add to scene tree and zombie units group
			add_child(zombie_instance)
			zombie_instance.add_to_group("zombies")
			spawn_attempts += 1
			print("Zombie spawned at:", spawn_position, "with ID:", zombie_instance.zombie_id, "and name:", zombie_instance.zombie_name)
	
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
	for zombie in get_tree().get_nodes_in_group("zombies"):
		if tilemap.local_to_map(zombie.position) == tile_pos:
			return true			
	for structure in get_tree().get_nodes_in_group("structures"):
		if tilemap.local_to_map(structure.position) == tile_pos:
			return true
	return false
