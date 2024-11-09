extends Area2D

# Movement range for the soldier
@export var movement_range: int = 3  # Adjustable movement range

# Packed scene for the movement tile (ensure you assign the movement tile scene in the editor)
@export var movement_tile_scene: PackedScene
@export var attack_tile_scene: PackedScene

# Store references to instantiated movement tiles for easy cleanup
var movement_tiles: Array[Node2D] = []

# Store references to instantiated attack range tiles for easy cleanup
var attack_range_tiles: Array[Node2D] = []

# Soldier's current tile position
var tile_pos: Vector2i
var coord: Vector2
var layer: int

# Pathfinding system
var astar: AStarGrid2D = AStarGrid2D.new()

# Tilemap reference
@export var tilemap: TileMap = null

# Pathfinding variables
var current_path: Array[Vector2i] = []  # Stores the path tiles
var path_index: int = 0  # Index for the current step in the path
var move_speed: float = 75.0  # Movement speed for the soldier

# Constants
const WATER_TILE_ID = 1  # Replace with the actual tile ID for water

var awaiting_movement_click: bool = false

@export var selected: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if tilemap == null:
		print("Error: Tilemap is not set.")
		return
	
	update_tile_position()
	setup_astar()
	visualize_walkable_tiles()

# Called every frame
func _process(delta: float) -> void:
	update_tile_position()
	move_along_path(delta)

# Function to update the tile position based on the current Area2D position
func update_tile_position() -> void:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	tile_pos = tilemap.local_to_map(position)
	coord = tile_pos
	layer = (tile_pos.x + tile_pos.y) + 1
	self.z_index = layer

# Function to update the AStar grid based on the current tilemap state
func update_astar_grid() -> void:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	
	var grid_width = tilemap.get_used_rect().size.x
	var grid_height = tilemap.get_used_rect().size.y
	
	astar.size = Vector2i(grid_width, grid_height)
	astar.cell_size = Vector2(1, 1)  # Assuming each cell is 1x1
	astar.default_compute_heuristic = 1
	astar.diagonal_mode = 1
	astar.update()
	
	# Update walkable and unwalkable cells
	for x in range(grid_width):
		for y in range(grid_height):
			var tile_id = tilemap.get_cell_source_id(0, Vector2i(x, y))
			if tile_id == -1 or tile_id == 0 or is_structure(Vector2i(x, y)) or is_unit_present(Vector2i(x, y)):
				astar.set_point_solid(Vector2i(x, y), true)  # Mark as non-walkable (solid)
			else:
				astar.set_point_solid(Vector2i(x, y), false)  # Mark as walkable

# Setup the AStarGrid2D with walkable tiles
func setup_astar() -> void:
	update_astar_grid()  # Update AStar grid to reflect current map state
	print("AStar grid setup completed.")

# Get all tiles within movement range based on Manhattan distance
func get_movement_tiles() -> Array[Vector2i]:
	var tiles_in_range: Array[Vector2i] = []
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	for x in range(-movement_range, movement_range + 1):
		for y in range(-movement_range, movement_range + 1):
			if abs(x) + abs(y) <= movement_range:
				var target_tile_pos: Vector2i = tile_pos + Vector2i(x, y)
				if tilemap.get_used_rect().has_point(target_tile_pos):
					tiles_in_range.append(target_tile_pos)

	return tiles_in_range

# Display movement tiles within range
func display_movement_tiles() -> void:
	clear_movement_tiles()  # Clear existing movement tiles
	clear_attack_range_tiles()  # Clear existing attack range tiles before displaying new movement tiles

	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	for tile in get_movement_tiles():
		if is_tile_movable(tile):
			var world_pos: Vector2 = tilemap.map_to_local(tile)
			var movement_tile_instance: Node2D = movement_tile_scene.instantiate() as Node2D
			movement_tile_instance.position = world_pos
			tilemap.add_child(movement_tile_instance)
			movement_tiles.append(movement_tile_instance)

# Clear displayed movement tiles
func clear_movement_tiles() -> void:
	for tile in movement_tiles:
		tile.queue_free()
	movement_tiles.clear()

# Check if a tile is movable
func is_tile_movable(tile_pos: Vector2i) -> bool:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var tile_id = tilemap.get_cell_source_id(0, tile_pos)
	if is_water_tile(tile_id):
		return false
	if is_structure(tile_pos) or is_unit_present(tile_pos):
		return false
	return true

# Check if a tile is a water tile
func is_water_tile(tile_id: int) -> bool:
	# Replace with the actual condition to check if the tile is water
	# For example, if water has a specific tile ID, you can check it here
	return tile_id == 0  # Replace WATER_TILE_ID with the actual water tile ID

# Check if there is a structure on the tile
func is_structure(tile_pos: Vector2i) -> bool:
	var structures = get_tree().get_nodes_in_group("structures")
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	for structure in structures:
		var structure_tile_pos = tilemap.local_to_map(tilemap.to_local(structure.global_position))
		if tile_pos == structure_tile_pos:
			return true
	return false

# Check if there is a unit on the tile
func is_unit_present(tile_pos: Vector2i) -> bool:
	var all_units = get_tree().get_nodes_in_group("player_units") + get_tree().get_nodes_in_group("zombies")
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	for unit in all_units:
		var unit_tile_pos = tilemap.local_to_map(tilemap.to_local(unit.global_position))
		if tile_pos == unit_tile_pos:
			return true
	return false

# Function to calculate the path
func calculate_path(target_tile: Vector2i) -> void:
	# Make sure the start tile (soldier's current position) is valid
	var start_tile = tile_pos
	
	# Check if target tile is walkable
	if is_tile_movable(target_tile):
		# Calculate the path using AStar (this returns a PackedVector2Array)
		var astar_path: PackedVector2Array = astar.get_point_path(start_tile, target_tile)
		
		# Convert PackedVector2Array to Array[Vector2i]
		current_path.clear()  # Clear any existing path
		for pos in astar_path:
			current_path.append(Vector2i(pos.x, pos.y))  # Convert Vector2 to Vector2i
		
		path_index = 0  # Reset path index to start at the beginning
		print("Path calculated:", current_path)
	else:
		print("Target tile is not walkable.")

# Update the AStar grid and calculate the path
func move_player_to_target(target_tile: Vector2i) -> void:
	get_child(0).play("move")
	
	update_astar_grid()  # Ensure AStar grid is up to date
	calculate_path(target_tile)  # Now calculate the path

	# Once the path is calculated, move the player to the target (will also update selected_player state)
	move_along_path(get_process_delta_time())  # This ensures movement happens immediately
	# Do not clear selection here. We keep selected_player intact.

# Function to move the soldier along the path
func move_along_path(delta: float) -> void:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	
	if current_path.is_empty():
		return  # No path, so don't move

	if path_index < current_path.size():
		var target_pos = current_path[path_index]  # This is a Vector2i (tile position)
		
		# Convert the target position to world position (center of the tile)
		var target_world_pos = tilemap.map_to_local(target_pos) + Vector2(0, 0) / 2  # Ensure it's the center of the tile
		
		# Calculate the direction to the target position
		# Calculate direction to move in (normalized vector)
		var direction = (target_world_pos - position).normalized()

		# Determine the direction of movement based on target and current position
		if direction.x > 0:
			scale.x = -1  # Facing right (East)
		elif direction.x < 0:
			scale.x = 1  # Facing left (West)	
			
		# Move the soldier in the direction of the target position, adjusted by delta
		position += direction * move_speed * delta
		
		# If the soldier has reached the target tile (within a small threshold)
		if position.distance_to(target_world_pos) <= 1:  # Threshold to determine if we reached the target
			path_index += 1  # Move to the next tile in the path
			
			# After moving, update the AStar grid for any changes (e.g., new walkable tiles, etc.)
			update_astar_grid()

	# If we've reached the last tile, stop moving
	if path_index >= current_path.size():
		#print("Path completed!")
		# Retain the selection after completing the path
		# Don't clear the selection, ensure that selected_player is still set
		awaiting_movement_click = false  # Finish the movement click state
		get_child(0).play("default")
		
# Visualize all walkable (non-solid) tiles in the A* grid
func visualize_walkable_tiles() -> void:
	var map_size: Vector2i = tilemap.get_used_rect().size
	
	# Iterate over all tiles in the A* grid and check for walkable (non-solid) tiles
	for x in range(map_size.x):
		for y in range(map_size.y):
			var tile = Vector2i(x, y)

			# Check if the tile is walkable (non-solid)
			if not astar.is_point_solid(tile):  # This tile is walkable
				var world_pos: Vector2 = tilemap.map_to_local(tile)
				var movement_tile_instance: Node2D = movement_tile_scene.instantiate() as Node2D
				movement_tile_instance.position = world_pos
				movement_tile_instance.modulate = Color(0.0, 1.0, 0.0, 0.5)  # Example: Green with some transparency for walkable tiles
				tilemap.add_child(movement_tile_instance)
				movement_tiles.append(movement_tile_instance)

	# Debug print to confirm visualization
	print("Visualized walkable tiles.")

# Handle right-click to display attack range tiles
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if selected:  # Only show attack range if the unit is selected
			display_attack_range_tiles()

# Display attack range tiles around the soldier using the attack_tile_scene
func display_attack_range_tiles() -> void:
	clear_movement_tiles()  # Clear existing movement tiles
	clear_attack_range_tiles()  # First, clear previous attack range tiles
	
	# Directions to check: right, left, down, up
	var directions: Array[Vector2i] = [
		Vector2i(1, 0),  # Right
		Vector2i(-1, 0), # Left
		Vector2i(0, 1),  # Down
		Vector2i(0, -1)  # Up
	]

	# For each direction, check and display tiles until we hit a structure, unit, or map boundary
	for direction in directions:
		var current_pos = tile_pos
		while true:
			# Move one step in the current direction
			current_pos += direction
			# Check if the current tile is within bounds
			var tilemap: TileMap = get_node("/root/MapManager/TileMap")
			if !tilemap.get_used_rect().has_point(current_pos):
				break  # If we reach out of bounds, stop

			# Retrieve the tile ID at the current position
			var tile_id = tilemap.get_cell_source_id(0, current_pos)

			# Check if the tile is walkable, or if we have hit a structure/unit
			# Water tiles will NOT stop the attack range now
			if is_structure(current_pos) or is_unit_present(current_pos) or is_tile_movable(current_pos) or is_water_tile(tile_id):
				var world_pos: Vector2 = tilemap.map_to_local(current_pos)
				var attack_tile_instance: Node2D = attack_tile_scene.instantiate() as Node2D  # Use attack_tile_scene here
				attack_tile_instance.position = world_pos
				tilemap.add_child(attack_tile_instance)
				attack_range_tiles.append(attack_tile_instance)
				
				# If we hit a structure or unit, stop here (we include them in the range)
				if is_structure(current_pos) or is_unit_present(current_pos):
					break
			else:
				# If the tile is not walkable and not a structure/unit, stop here
				break

# Clear displayed attack range tiles
func clear_attack_range_tiles() -> void:
	for tile in attack_range_tiles:
		tile.queue_free()
	attack_range_tiles.clear()
