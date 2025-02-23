extends Node2D

# Tile IDs (variables instead of constants)
var WATER: int
var SANDSTONE: int
var DIRT: int
var GRASS: int
var SNOW: int
var ICE: int

# Constants for road tile IDs
const INTERSECTION = 6
const DOWN_LEFT_ROAD = 7
const DOWN_RIGHT_ROAD = 8

# Preload PackedScenes for structures
@onready var BUILDING_SCENE = preload("res://assets/scenes/prefab/building_c.tscn")
@onready var BUILDING_SCENE_D = preload("res://assets/scenes/prefab/building_d.tscn")
@onready var BUILDING_SCENE_E = preload("res://assets/scenes/prefab/building_e.tscn")
@onready var DISTRICT_SCENE = preload("res://assets/scenes/prefab/district.tscn")
@onready var STADIUM_SCENE = preload("res://assets/scenes/prefab/stadium.tscn")
@onready var TOWER_SCENE = preload("res://assets/scenes/prefab/tower.tscn")

# Preload the hover tile scene
@onready var hover_tile = preload("res://assets/scenes/UI/hover_tile.tscn").instantiate()
@onready var mission_manager = get_node("/root/MapManager/MissionManager")
@onready var hud_manager = get_node("/root/MapManager/HUDManager")

# Grid dimensions
var grid_width = 32
var grid_height = 32

# Noise generation
var noise = FastNoiseLite.new()
var rng = RandomNumberGenerator.new()

# Track if specific structures have been spawned
var district_spawned = false
var stadium_spawned = false
var tower_spawned = false

var map_ready = false

# Array to store structure coordinates
var structure_coordinates = []
# Array to store water coordinates
var water_coordinates = []

# Maximum number of each structure type to spawn
@export var max_districts: int = 1  # Maximum number of districts
@export var max_stadiums: int = 1   # Maximum number of stadiums
@export var max_towers: int = 1     # Maximum number of towers
@export var max_buildings: int = 10  # Maximum number of buildings
# Add properties for maximum and minimum spacing between structures
@export var min_distance_between_structures: int = 3  # Minimum distance between structures

# Counters for spawned structures
var district_count: int = 0
var stadium_count: int = 0
var tower_count: int = 0
var building_count: int = 0

var map_1: bool = false
var map_2: bool = false
var map_3: bool = false
var map_4: bool = false

# Called when the node enters the scene tree for the first time
func _ready():
	add_child(hover_tile)  # Add hover tile to the scene
	hover_tile.visible = false  # Initially hide the hover tile
	
	# Set map spawn paramaters
	grid_width = get_even_random(16, 32)
	grid_height = get_even_random(16, 32)

	# Randomly choose a set of values for the tiles
	match randi() % 4:
		0:
			# Set values from the first set (0-5)
			WATER = 0
			SANDSTONE = 1
			DIRT = 2
			GRASS = 3
			SNOW = 4
			ICE = 5
			
			map_1 = true
		1:
			# Set values from the second set (9-14)
			WATER = 9
			SANDSTONE = 10
			DIRT = 11
			GRASS = 12
			SNOW = 13
			ICE = 14
			
			map_2 = true
		2:
			# Set values from the third set (15-20)
			WATER = 15
			SANDSTONE = 16
			DIRT = 17
			GRASS = 18
			SNOW = 19
			ICE = 20
			
			map_3 = true
		3:
			# Set values from the third set (15-20)
			WATER = 21
			SANDSTONE = 22
			DIRT = 23
			GRASS = 24
			SNOW = 25
			ICE = 26	
			
			map_4 = true
				
	generate_map()

# Function to generate even random numbers within a range
func get_even_random(min_val: int, max_val: int) -> int:
	var number = randi_range(min_val, max_val)
	if number % 2 != 0:
		number += 1  # Adjust to the next even number
	if number > max_val:  # Ensure it doesn't exceed max_val
		number -= 2
	return number
	
func _process(delta):
	# Check if the Space key is pressed
	if Input.is_action_just_pressed("space"):
		GlobalManager.reset_global_manager()		
		reset_level()

# Reload the current scene to reset the level
func reset_level():	
	get_tree().reload_current_scene()
	print("Resetting level...")

func generate_map():
	clear_existing_structures()  # Clear previous structures
	structure_coordinates.clear()  # Clear the structure coordinates array
	water_coordinates.clear()  # Clear the water coordinates array

	# Reset structure spawn flags
	district_spawned = false
	stadium_spawned = false
	tower_spawned = false

	# Configure the noise
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.1  # Adjust frequency for different features

	# Iterate through each cell of the grid
	for x in range(grid_width):
		for y in range(grid_height):
			var noise_value = noise.get_noise_2d(x, y)
			var tile_id = get_tile_id(noise_value)
			set_tile(x, y, tile_id)

			# If the tile is water, store its position in the water_coordinates array
			if tile_id == WATER:
				water_coordinates.append(Vector2i(x, y))

	# Track the odd numbers already picked for roads
	var picked_horizontal_odd_y = []
	var picked_vertical_odd_x = []

	# Generate roads with odd number starting positions (ensuring unique numbers)
	var horizontal_y1 = get_unique_random_odd(grid_height, picked_horizontal_odd_y)
	var vertical_x1 = get_unique_random_odd(grid_width, picked_vertical_odd_x)
	var horizontal_y2 = get_unique_random_odd(grid_height, picked_horizontal_odd_y)
	var vertical_x2 = get_unique_random_odd(grid_width, picked_vertical_odd_x)

	var horizontal_y3 = get_unique_random_odd(grid_height, picked_horizontal_odd_y)
	var vertical_x3 = get_unique_random_odd(grid_width, picked_vertical_odd_x)
	var horizontal_y4 = get_unique_random_odd(grid_height, picked_horizontal_odd_y)
	var vertical_x4 = get_unique_random_odd(grid_width, picked_vertical_odd_x)


	generate_roads(Vector2i(0, horizontal_y1), Vector2i(1, 0))  # Horizontal road 1
	generate_roads(Vector2i(vertical_x1, 0), Vector2i(0, 1))    # Vertical road 1
	generate_roads(Vector2i(0, horizontal_y2), Vector2i(1, 0))  # Horizontal road 2
	generate_roads(Vector2i(vertical_x2, 0), Vector2i(0, 1))    # Vertical road 2

	generate_roads(Vector2i(0, horizontal_y3), Vector2i(1, 0))  # Horizontal road 1
	generate_roads(Vector2i(vertical_x3, 0), Vector2i(0, 1))    # Vertical road 1
	generate_roads(Vector2i(0, horizontal_y4), Vector2i(1, 0))  # Horizontal road 2
	generate_roads(Vector2i(vertical_x4, 0), Vector2i(0, 1))    # Vertical road 2

	spawn_structures()  # Spawn structures after generating the map

# Helper function to generate a unique random odd number within a range
func get_unique_random_odd(max_value: int, picked_list: Array) -> int:
	var rand_value = 0
	while true:
		rand_value = get_random_odd(max_value)
		# Check if the random value is already picked
		if rand_value not in picked_list:
			picked_list.append(rand_value)
			break
	return rand_value

# Helper function to generate a random odd number within a range
func get_random_odd(max_value: int) -> int:
	var rand_value: int
	var attempts: int = 16
	const MAX_ATTEMPTS: int = 1024  # Limit attempts to prevent infinite loop

	# Loop until a valid odd number is found or attempts are exhausted
	while attempts < MAX_ATTEMPTS:
		rand_value = rng.randi_range(1, max_value - 1)
		if rand_value % 2 == 0:
			rand_value += 1  # Convert to odd if even

		# Ensure the number is not 0 or 16
		if rand_value != 0 and rand_value != grid_width - 1 and rand_value != grid_height - 1:
			return rand_value  # Valid odd number found

		attempts += 1
	
	# If no valid odd number found, return a default value or handle the failure case appropriately
	return -1  # Indicates failure if no valid number found

func get_tile_id(noise_value: float) -> int:
	# Determine the tile ID based on the noise value
	if noise_value < -0.3:
		return WATER
	elif noise_value < 0:
		return SANDSTONE
	elif noise_value < 0.15:
		return DIRT
	elif noise_value < 0.3:
		return GRASS
	elif noise_value < 0.45:
		return SNOW
	else:
		return ICE

func set_tile(x: int, y: int, tile_id: int):
	# Set the cell in the TileMap to the appropriate tile ID
	$TileMap.set_cell(0, Vector2i(x, y), tile_id, Vector2i(0, 0), 0)

func generate_roads(start: Vector2i, direction: Vector2i):
	var x = start.x
	var y = start.y	

	# Generate roads depending on the direction
	if direction.x != 0:  # Horizontal road
		for i in range(grid_width):
			handle_road_tile(x, y, DOWN_RIGHT_ROAD)
			# Move to the next tile in the horizontal direction
			x += direction.x
	elif direction.y != 0:  # Vertical road
		for i in range(grid_height):
			handle_road_tile(x, y, DOWN_LEFT_ROAD)
			# Move to the next tile in the vertical direction
			y += direction.y

# Function to handle placing a road tile and checking for intersections
func handle_road_tile(x: int, y: int, road_tile: int):
	# Get the current tile ID at the specified position
	var current_tile_id = $TileMap.get_cell_source_id(0, Vector2i(x, y))

	# If there's already a road tile (but not an intersection), place an intersection
	if current_tile_id == DOWN_LEFT_ROAD or current_tile_id == DOWN_RIGHT_ROAD:
		set_tile(x, y, INTERSECTION)
	else:
		# Otherwise, place the road tile as normal
		set_tile(x, y, road_tile)

func spawn_structures():
	# Store positions of spawned structures for distance checks
	var spawned_positions: Array = []

	# Create a list of all possible positions on the map
	var all_positions: Array = []
	for x in range(grid_width):
		for y in range(grid_height):
			# Exclude perimeter tiles (x == 0, y == 0, x == grid_width - 1, y == grid_height - 1)
			if x > 0 and x < grid_width - 1 and y > 0 and y < grid_height - 1:
				all_positions.append(Vector2i(x, y))

	# Shuffle the positions to randomize spawning order
	all_positions.shuffle()

	# Iterate over the randomized positions
	for position in all_positions:
		var x = position.x
		var y = position.y

		# Get the tile ID based on the noise value for this position
		var tile_id = $TileMap.get_cell_source_id(0, position)

		# Only spawn on DIRT or GRASS and make sure the tile is not a road or already occupied
		if (tile_id == DIRT or tile_id == GRASS) and not is_road(tile_id) and not is_occupied(position):
			if rng.randi_range(0, 100) < 100:  # 100% chance (you may want to adjust this)
				var structure_type = rng.randi_range(0, 5)

				match structure_type:
					0:
						if building_count < max_buildings:  # Check building limit
							if can_spawn(position, spawned_positions, min_distance_between_structures, [1, 2, 3]):  # Check against districts, stadiums, and towers
								spawn_structure(BUILDING_SCENE, x, y)  # Allow multiple buildings
								building_count += 1
								spawned_positions.append(position)  # Track this position
					1:
						if district_count < max_districts:  # Only spawn up to max districts
							if can_spawn(position, spawned_positions, 3, [0, 2, 3]):  # Check against buildings, stadiums, and towers
								spawn_structure(DISTRICT_SCENE, x, y)
								district_count += 1
								spawned_positions.append(position)  # Track this position
					2:
						if stadium_count < max_stadiums:  # Only spawn up to max stadiums
							if can_spawn(position, spawned_positions, 3, [0, 1, 3]):  # Check against buildings, districts, and towers
								spawn_structure(STADIUM_SCENE, x, y)
								stadium_count += 1
								spawned_positions.append(position)  # Track this position
					3:
						if tower_count < max_towers:  # Only spawn up to max towers
							if can_spawn(position, spawned_positions, 3, [0, 1, 2]):  # Check against buildings, districts, and stadiums
								spawn_structure(TOWER_SCENE, x, y)
								tower_count += 1
								spawned_positions.append(position)  # Track this position
					4:
						if building_count < 8:  # Only spawn up to max towers
							if can_spawn(position, spawned_positions, min_distance_between_structures, [0, 1, 2]):  # Check against buildings, districts, and stadiums
								spawn_structure(BUILDING_SCENE_D, x, y)
								building_count += 1
								spawned_positions.append(position)  # Track this position
					5:
						if building_count < 8:  # Only spawn up to max towers
							if can_spawn(position, spawned_positions, min_distance_between_structures, [0, 1, 2]):  # Check against buildings, districts, and stadiums
								spawn_structure(BUILDING_SCENE_E, x, y)
								building_count += 1
								spawned_positions.append(position)  # Track this position

	GlobalManager.secret_items_found = 0
	map_ready = true

# Function to check if a structure can be spawned based on minimum distance
func can_spawn(new_pos: Vector2i, existing_positions: Array, min_distance: int, excluded_types: Array) -> bool:
	# Check against the existing positions to maintain distance
	for pos in existing_positions:
		if new_pos.distance_to(pos) < min_distance:
			return false  # Too close to an existing structure

	# Now check against the excluded types if they are present in the nearby area
	for excluded_type in excluded_types:
		# Check positions around the new_pos for other structures
		for dx in range(-1, 2):  # Check the 3x3 grid around new_pos
			for dy in range(-1, 2):
				if dx == 0 and dy == 0:
					continue  # Skip the new position itself
				var check_pos = new_pos + Vector2i(dx, dy)
				if is_valid_position(check_pos) and is_structure_type(check_pos, excluded_type):  # Check if this position is valid and contains an excluded structure type
					return false  # Too close to an excluded structure type

	return true  # Valid position for spawning

# Function to check if a position is valid for checking
func is_valid_position(pos: Vector2i) -> bool:
	# Add any necessary checks to see if the position is within the map bounds
	return pos.x >= 0 and pos.x < grid_width and pos.y >= 0 and pos.y < grid_height

# Function to check if a structure type is present at a given position
func is_structure_type(pos: Vector2i, structure_type: int) -> bool:
	# Implement your logic to check if the position has the corresponding structure type
	# For example, you may have a method to get the structure type at a given position
	# Here, just a placeholder return value
	return false  # Replace with actual check

# Helper function to check if a tile is a road tile
func is_road(tile_id: int) -> bool:
	return tile_id == DOWN_LEFT_ROAD or tile_id == DOWN_RIGHT_ROAD or tile_id == INTERSECTION

# Check if a tile at (x, y) is already occupied by a structure
func is_occupied(tile_pos: Vector2i) -> bool:
	return tile_pos in structure_coordinates  # Check if the tile position is in the coordinates array

func spawn_structure(scene: PackedScene, x: int, y: int):
	var structure_instance = scene.instantiate()
	
	# Convert tile coordinates to local position
	var local_position = $TileMap.map_to_local(Vector2i(x, y))
	structure_instance.position = local_position  # Set position based on tile coordinates

	# Add the structure to the scene tree and assign it to a group for easy management
	add_child(structure_instance)
	structure_instance.add_to_group("structures")  # Add structure to "structures" group

	# Apply random color modulation to make it visually distinct
	var random_modulation = Color(
		0.8 + rng.randf_range(-0.2, 0.2),  # Red
		0.8 + rng.randf_range(-0.2, 0.2),  # Green
		0.8 + rng.randf_range(-0.2, 0.2),  # Blue
		1  # Fully opaque
	)
	structure_instance.modulate = random_modulation
	
	# Store the structure's coordinates
	structure_coordinates.append(Vector2i(x, y))

func clear_existing_structures():
	# Remove all children that are in the "structures" group
	for structure in get_tree().get_nodes_in_group("structures"):
		structure.queue_free()  # Remove the structure from the scene
