extends Node2D

# Unit properties
var tile_pos: Vector2i  # Unit's current position in the tile grid
var is_moving: bool = false  # Flag to check if the unit is currently moving
var is_selected: bool = false  # Flag to check if the unit is selected

# Public variables (can be adjusted per unit)
@export var movement_range: int = 3  # Default movement range

# Reference to the TileMap and AStarGrid
var tilemap: TileMap = null
var astar_grid: AStarGrid2D = null  # Reference to the AStarGrid2D

# Walkable tile prefab for visualization (set up as an instance in your scene)
var walkable_tile_prefab: PackedScene = preload("res://assets/scenes/UI/move_tile.tscn")
var walkable_tiles: Array = []  # Stores references to walkable tile indicators

# Reference to the unit's sprite
var sprite: AnimatedSprite2D = null

var last_position: Vector2  # Variable to store the last position of the unit

# Called when the node enters the scene
func _ready() -> void:
	# Find the TileMap and AStarGrid nodes in the scene
	tilemap = get_tree().get_root().get_node("MapManager/TileMap")  # Adjust path based on your scene structure
	astar_grid = AStarGrid2D.new()

	# Initialize the unit's position in the tile grid based on its current world position
	tile_pos = tilemap.local_to_map(position)

	# Reference the sprite (assuming it's a direct child of the unit)
	sprite = $AnimatedSprite2D  # Adjust based on your node structure

	# Set the initial z_index based on the tile position
	update_z_index()

	# Debugging: Print initial position
	print("Unit initialized at tile: ", tile_pos)

	# Initialize the last position when the unit is ready
	last_position = position  

	add_to_group("units")
	
	# Set up AStar grid (optional, depending on your game)
	update_astar_grid()

# Function to update the AStar grid
func update_astar_grid() -> void:
	var grid_width = 16
	var grid_height = 16
	astar_grid.size = Vector2i(grid_width, grid_height)
	astar_grid.cell_size = Vector2(1, 1)
	astar_grid.default_compute_heuristic = 1
	astar_grid.diagonal_mode = 1
	
	# Update walkable and unwalkable cells
	for x in range(grid_width):
		for y in range(grid_height):
			var tile_id = tilemap.get_cell_source_id(0, Vector2i(x, y))
			if tile_id == -1 or tile_id == 0:
				astar_grid.set_point_solid(Vector2i(x, y), true)
			else:
				astar_grid.set_point_solid(Vector2i(x, y), false)

func move_to_tile(target_tile_pos: Vector2i) -> void:
	if is_moving:
		return  # Ignore input if the unit is currently moving

	# Calculate the distance to the target tile
	var distance = abs(tile_pos.x - target_tile_pos.x) + abs(tile_pos.y - target_tile_pos.y)

	# Check if the target tile is within the unit's movement range (using Manhattan distance)
	if distance <= movement_range:
		is_moving = true  # Lock the unit while it's moving

		# Store the last position before moving
		last_position = position

		# Get the path from AStar
		var path = astar_grid.get_point_path(tile_pos, target_tile_pos)

		if path.size() > 0:
			# Move the unit along the calculated path
			for point in path:
				var target_world_pos = tilemap.map_to_local(point)
				await move_to_position(target_world_pos)
				
			# Update the tile position
			tile_pos = target_tile_pos
			# Update the z_index based on the new tile position
			update_z_index()

			print("Unit moved to tile: ", tile_pos)  # Debugging
		else:
			print("No valid path to target tile.")
	else:
		print("Target tile is out of range.")

# Function to move to a specific world position over time
func move_to_position(target_world_pos: Vector2) -> void:
	position = target_world_pos
	# Determine the direction of movement based on current and last position
	if position.x > last_position.x:
		scale.x = -1  # Facing right (East)
	elif position.x < last_position.x:
		scale.x = 1  # Facing left (West)

	# Simulate movement time (0.5 seconds in this case)
	await get_tree().create_timer(0.5).timeout

	is_moving = false  # Unlock the unit after movement

# Update the z_index based on the unit's tile position
func update_z_index() -> void:
	# Typically, z-index is based on the y-coordinate so units further down are drawn on top
	z_index = (tile_pos.x + tile_pos.y) + 1

func show_walkable_tiles() -> void:
	clear_walkable_tiles()  # Clear any existing indicators

	# Loop over all possible tiles within movement range using Manhattan distance
	for x_offset in range(-movement_range, movement_range + 1):
		for y_offset in range(-movement_range, movement_range + 1):
			if abs(x_offset) + abs(y_offset) <= movement_range:
				var walkable_tile_pos = tile_pos + Vector2i(x_offset, y_offset)

				# Only instantiate if the position is valid on the map
				if tilemap.get_used_rect().has_point(walkable_tile_pos):
					# Check if the tile is not water, not occupied by a structure, and not occupied by another unit
					if !is_water(walkable_tile_pos) and !is_structure(walkable_tile_pos) and !is_unit_present(walkable_tile_pos):
					   
						var walkable_tile = walkable_tile_prefab.instantiate()
						var walkable_world_pos = tilemap.map_to_local(walkable_tile_pos)
						walkable_tile.position = walkable_world_pos

						# Add the walkable tile to the TileMap
						tilemap.add_child(walkable_tile)
						walkable_tiles.append(walkable_tile)

						print("Placing walkable tile at: ", walkable_tile_pos)  # Debugging line

# Function to check if a unit is present on a specific tile
func is_unit_present(tile_pos: Vector2i) -> bool:
	for unit in get_tree().get_nodes_in_group("units"):  # Assume units are added to a group called "units"
		if unit.tile_pos == tile_pos:
			return true
	return false

# Function to check if the tile is water
func is_water(tile_pos: Vector2i) -> bool:
	# Replace WATER_TILE_INDEX with the actual index for water tiles
	const WATER_TILE_INDEX = 0 # Adjust this value according to your tilemap
	return tilemap.get_cell_source_id(0, tile_pos) == WATER_TILE_INDEX

# Function to check if the tile is a structure
func is_structure(tile_pos: Vector2i) -> bool:
	var structure_coords = get_tree().get_root().get_node("MapManager").structure_coordinates
	for coord in structure_coords:
		if tile_pos == coord:
			return true  # Return true if the tile is a structure
	return false  # Return false if no match was found

# Clear all walkable tile markers
func clear_walkable_tiles() -> void:
	for tile in walkable_tiles:
		tile.queue_free()
	walkable_tiles.clear()

# Handle input events (clicks)
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_left"):
		# Get the tile position of the mouse click
		var mouse_pos = get_global_mouse_position()
		mouse_pos.y += 8  # Adjust offset if necessary

		# Convert the mouse position to tile coordinates
		var target_tile_pos = tilemap.local_to_map(tilemap.to_local(mouse_pos))

		# If the unit is clicked, toggle selection and show walkable tiles
		if !is_moving and tile_pos == target_tile_pos:
			is_selected = !is_selected  # Toggle selection
			if is_selected:
				show_walkable_tiles()  # Show movement options when selected
			else:
				clear_walkable_tiles()  # Clear if deselected

		# If the unit is selected and the clicked tile is valid, move to that tile
		elif is_selected:
			move_to_tile(target_tile_pos)
			clear_walkable_tiles()  # Clear markers after movement
			is_selected = false  # Deselect after moving
