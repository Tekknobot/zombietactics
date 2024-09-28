extends Node2D

# Unit states
enum State {
	IDLE,
	SELECTED,
	MOVING
}

# Unit properties
var tile_pos: Vector2i  # Unit's current position in the tile grid
var is_moving: bool = false  # Flag to check if the unit is currently moving
var state: State = State.IDLE  # Current state of the unit

# Public variables (can be adjusted per unit)
@export var movement_range: int = 3  # Default movement range

# Define public variables for target positions
@export var first_target_position: Vector2i = Vector2i(-1, -1)  # Position of the first click
@export var second_target_position: Vector2i = Vector2i(-1, -1)  # Position of the second click
@export var active_target_position: Vector2i = Vector2i(-1, -1)  # Active target for movement

var target_tile_pos
var last_target_tile_pos

# Reference to the TileMap and AStarGrid
var tilemap: TileMap = null
var astar_grid: AStarGrid2D = null  # Reference to the AStarGrid2D

# Walkable tile prefab for visualization
var walkable_tile_prefab: PackedScene = preload("res://assets/scenes/UI/move_tile.tscn")
var walkable_tiles: Array = []  # Stores references to walkable tile indicators

# Reference to the unit's sprite
var sprite: AnimatedSprite2D = null

var last_position: Vector2  # Variable to store the last position of the unit

var selected_unit: Node2D = null  # Track the currently selected unit

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
	
	# Set up AStar grid
	update_astar_grid()

# Function to update the AStar grid
func update_astar_grid() -> void:
	var grid_width = 16
	var grid_height = 16
	astar_grid.size = Vector2i(grid_width, grid_height)
	astar_grid.cell_size = Vector2(1, 1)
	astar_grid.default_compute_heuristic = 1
	astar_grid.diagonal_mode = 1
	astar_grid.update()
	
	for x in 16:
		for y in 16:
			var pos = Vector2i(x, y)
			astar_grid.set_point_solid(pos, false)  # Set all points as walkable

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
	state = State.IDLE  # Return to idle state

# Update the z_index based on the unit's tile position
func update_z_index() -> void:
	z_index = (tile_pos.x + tile_pos.y) + 1  # Adjust z-index based on tile position

# Show walkable tiles based on the actual walkability of the tile
func show_walkable_tiles() -> void:
	clear_walkable_tiles()  # Clear any existing indicators

	# Loop over all possible tiles within movement range using Manhattan distance
	for x_offset in range(-movement_range, movement_range + 1):
		for y_offset in range(-movement_range, movement_range + 1):
			if abs(x_offset) + abs(y_offset) <= movement_range:
				var walkable_tile_pos = tile_pos + Vector2i(x_offset, y_offset)

				# Only instantiate if the position is valid on the map and not occupied
				if tilemap.get_used_rect().has_point(walkable_tile_pos) and is_walkable(walkable_tile_pos):
					var walkable_tile = walkable_tile_prefab.instantiate()
					var walkable_world_pos = tilemap.map_to_local(walkable_tile_pos)
					walkable_tile.position = walkable_world_pos

					# Add the walkable tile to the TileMap
					tilemap.add_child(walkable_tile)
					walkable_tiles.append(walkable_tile)

					print("Placing walkable tile at: ", walkable_tile_pos)  # Debugging line

# Clear all walkable tile markers
func clear_walkable_tiles() -> void:
	for tile in walkable_tiles:
		tile.queue_free()
	walkable_tiles.clear()

# Check if the tile is walkable
func is_walkable(tile_pos: Vector2i) -> bool:
	return not is_water(tile_pos) and not is_structure(tile_pos) and not is_unit_present(tile_pos)

# Check if the tile is water
func is_water(tile_pos: Vector2i) -> bool:
	var water_tile_index = 0  # Define the correct index for water tiles
	return tilemap.get_cell_source_id(0, tile_pos) == water_tile_index

# Check if the tile is a structure
func is_structure(tile_pos: Vector2i) -> bool:
	var structure_coordinates = get_tree().get_root().get_node("MapManager").structure_coordinates
	for coord in structure_coordinates:
		if tile_pos == coord:
			return true  # Tile is a structure if it matches any coordinate
	return false  # Tile is not a structure if no matches are found

# Check if a unit is present on a specific tile
func is_unit_present(tile_pos: Vector2i) -> bool:
	for unit in get_tree().get_nodes_in_group("units"):  # Assume units are added to a group called "units"
		if unit.tile_pos == tile_pos:
			return true  # Unit is present on this tile
	return false  # No unit present on this tile

# Handle input events based on the current state
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_left"):
		# Get the tile position of the mouse click
		var mouse_pos = get_global_mouse_position()
		mouse_pos.y += 8  # Adjust offset if necessary

		# Convert the mouse position to tile coordinates
		var target_tile_pos = tilemap.local_to_map(tilemap.to_local(mouse_pos))

		match state:
			State.IDLE:
				# If the unit is clicked, toggle selection and show walkable tiles
				if tile_pos == target_tile_pos:
					selected_unit = self  # Track this unit as selected
					state = State.SELECTED  # Change state to SELECTED
					
					# Temporarily make the unit's current tile walkable in AStar
					astar_grid.set_point_solid(tile_pos, false)
					
					show_walkable_tiles()  # Show movement options when selected
					first_target_position = target_tile_pos  # Store the first click position
					print("Unit selected. First target position: ", first_target_position)  # Debugging

			State.SELECTED:
				# If the user clicks the same tile again, deselect the unit
				if tile_pos == target_tile_pos:
					state = State.IDLE  # Deselect the unit
					clear_walkable_tiles()  # Clear walkable tile indicators
					reset_targets()  # Reset target positions
					
					# Restore the solid state of the current tile
					astar_grid.set_point_solid(tile_pos, true)
					
					selected_unit = null  # Deselect the unit
					print("Unit deselected.")  # Debugging
					return

				# Use temporary variables to store the targets
				var temp_first_target = first_target_position
				var temp_second_target = target_tile_pos

				# Check if the clicked tile is walkable and not the same as the first target
				if is_walkable(temp_second_target) and temp_first_target != temp_second_target:
					second_target_position = temp_second_target  # Set second target position
					
					# Move to the tile, making sure the start tile is not solid
					astar_grid.set_point_solid(tile_pos, false)  # Make sure the starting tile is walkable
					move_to_tile(temp_first_target, second_target_position)  # Move to the clicked tile position
					
					clear_walkable_tiles()  # Clear markers after movement
					state = State.IDLE  # Return to IDLE after moving
					
					# Restore the solid state of the tile after moving
					astar_grid.set_point_solid(tile_pos, true)
					
					selected_unit = null  # Deselect the unit after movement
					print("Unit moved to second target position: ", second_target_position)  # Debugging

# Function to check if the target tile is within movement range
func is_within_range(target_tile_pos: Vector2i) -> bool:
	var distance = abs(tile_pos.x - target_tile_pos.x) + abs(tile_pos.y - target_tile_pos.y)
	return distance <= movement_range

# Move to tile function
func move_to_tile(first_tile_pos: Vector2i, target_tile_pos: Vector2i) -> void:
	if is_moving:
		return  # Ignore input if the unit is currently moving

	# Check if a valid path exists using the A* algorithm
	var path = astar_grid.get_point_path(first_tile_pos, target_tile_pos)
	if path.size() > 0:
		is_moving = true  # Lock the unit while it's moving

		# Store the last position before moving
		last_position = position

		# Start the movement animation
		sprite.play("move")  # Assuming the walking animation is named "walk"

		# Move the unit along the calculated path
		for point in path:
			var target_world_pos = tilemap.map_to_local(point)
			await move_to_position(target_world_pos)
			
		# Get the world position of the target tile
		var target_world_pos = tilemap.map_to_local(target_tile_pos)			
		# Move the unit to the target tile's world position
		position = target_world_pos

		# Determine the direction of movement based on current and last position
		if position.x > last_position.x:
			scale.x = -1  # Facing right (East)
		elif position.x < last_position.x:
			scale.x = 1  # Facing left (West)

		# Update the unit's tile position after reaching the final point in the path
		tile_pos = target_tile_pos
		# Update the z_index based on the new tile position
		update_z_index()

		# Stop the movement animation and switch to idle animation
		sprite.play("default")  # Assuming the idle animation is named "idle"
		
		is_moving = false  # Unlock the unit after movement

		print("Unit moved to tile: ", tile_pos)  # Debugging
	else:
		print("No valid path to target tile.")  # Debugging message

# Reset target positions
func reset_targets() -> void:
	first_target_position = Vector2i(-1, -1)  # Reset first target position
	second_target_position = Vector2i(-1, -1)  # Reset second target position
	active_target_position = Vector2i(-1, -1)  # Reset active target
