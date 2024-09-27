extends Node2D

# Constants for tile IDs
const WATER = 0
const SANDSTONE = 1
const DIRT = 2
const GRASS = 3
const SNOW = 4
const ICE = 5

# Constants for road tile IDs
const INTERSECTION = 6
const DOWN_LEFT_ROAD = 7
const DOWN_RIGHT_ROAD = 8

# Preload PackedScenes for structures
@onready var BUILDING_SCENE = preload("res://assets/scenes/prefab/building_c.scn")
@onready var DISTRICT_SCENE = preload("res://assets/scenes/prefab/district.scn")
@onready var STADIUM_SCENE = preload("res://assets/scenes/prefab/stadium.scn")
@onready var TOWER_SCENE = preload("res://assets/scenes/prefab/tower.scn")

# Preload the hover tile scene
@onready var hover_tile = preload("res://assets/scenes/UI/hover_tile.tscn").instantiate()

# Grid dimensions
var grid_width = 16
var grid_height = 16

# Noise generation
var noise = FastNoiseLite.new()
var rng = RandomNumberGenerator.new()

# Track if specific structures have been spawned
var district_spawned = false
var stadium_spawned = false
var tower_spawned = false

@onready var ui_manager = $UIManager  # Ensure the path is correct

# Called when the node enters the scene tree for the first time
func _ready():
	add_child(hover_tile)  # Add hover tile to the scene
	hover_tile.visible = false  # Initially hide the hover tile
	generate_map()

func generate_map():
	clear_existing_structures()  # Clear previous structures
	
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

	# Track the odd numbers already picked for roads
	var picked_horizontal_odd_y = []
	var picked_vertical_odd_x = []

	# Generate roads with odd number starting positions (ensuring unique numbers)
	var horizontal_y1 = get_unique_random_odd(grid_height, picked_horizontal_odd_y)
	var vertical_x1 = get_unique_random_odd(grid_width, picked_vertical_odd_x)
	var horizontal_y2 = get_unique_random_odd(grid_height, picked_horizontal_odd_y)
	var vertical_x2 = get_unique_random_odd(grid_width, picked_vertical_odd_x)

	generate_roads(Vector2i(0, horizontal_y1), Vector2i(1, 0))  # Horizontal road 1
	generate_roads(Vector2i(vertical_x1, 0), Vector2i(0, 1))    # Vertical road 1
	generate_roads(Vector2i(0, horizontal_y2), Vector2i(1, 0))  # Horizontal road 2
	generate_roads(Vector2i(vertical_x2, 0), Vector2i(0, 1))    # Vertical road 2

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
	var attempts: int = 0
	const MAX_ATTEMPTS: int = 100  # Limit attempts to prevent infinite loop

	# Loop until a valid odd number is found or attempts are exhausted
	while attempts < MAX_ATTEMPTS:
		rand_value = rng.randi_range(1, max_value - 1)
		if rand_value % 2 == 0:
			rand_value += 1  # Convert to odd if even

		# Ensure the number is not 0 or 16
		if rand_value != 0 and rand_value != 15:
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
	for x in range(grid_width):
		for y in range(grid_height):
			# Get the tile ID based on the noise value for this position
			var tile_id = $TileMap.get_cell_source_id(0, Vector2i(x, y))

			# Only spawn on DIRT or GRASS and make sure the tile is not a road
			if (tile_id == DIRT or tile_id == GRASS) and not is_road(tile_id):
				if rng.randi_range(0, 100) < 50:  # 50% chance to spawn a structure
					var structure_type = rng.randi_range(0, 4)
					match structure_type:
						0:
							spawn_structure(BUILDING_SCENE, x, y)  # Allow multiple buildings
						1:
							if not district_spawned:  # Only spawn one district
								spawn_structure(DISTRICT_SCENE, x, y)
								district_spawned = true
						2:
							if not stadium_spawned:  # Only spawn one stadium
								spawn_structure(STADIUM_SCENE, x, y)
								stadium_spawned = true
						3:
							if not tower_spawned:  # Only spawn one tower
								spawn_structure(TOWER_SCENE, x, y)
								tower_spawned = true

# Helper function to check if a tile is a road tile
func is_road(tile_id: int) -> bool:
	return tile_id == DOWN_LEFT_ROAD or tile_id == DOWN_RIGHT_ROAD or tile_id == INTERSECTION

func spawn_structure(scene: PackedScene, x: int, y: int):
	var structure_instance = scene.instantiate()
	
	# Convert tile coordinates to local position
	var local_position = $TileMap.map_to_local(Vector2i(x, y))
	structure_instance.position = local_position  # Set position based on tile coordinates

	# Add the structure to the scene tree and assign it to a group for easy management
	add_child(structure_instance)
	structure_instance.add_to_group("structures")  # Add structure to "structures" group

func clear_existing_structures():
	# Remove all children that are in the "structures" group
	for structure in get_tree().get_nodes_in_group("structures"):
		structure.queue_free()  # Remove the structure from the scene

# Handle input for regenerating the map and hover functionality
func _input(event):
	if event.is_action_pressed("ui_accept"):  # Default is Spacebar
		generate_map()
	
	# Handle hover tile positioning
	var mouse_pos = get_global_mouse_position()
	mouse_pos.y += 8
	var tile_pos = $TileMap.local_to_map(mouse_pos)
	if tile_pos.x >= 0 and tile_pos.x < grid_width and tile_pos.y >= 0 and tile_pos.y < grid_height:
		hover_tile.position = $TileMap.map_to_local(tile_pos)  # Update hover tile position
		hover_tile.visible = true  # Show hover tile
	else:
		hover_tile.visible = false  # Hide hover tile when out of bounds
