extends Node2D

signal player_action_completed

var explosion_scene = preload("res://assets/scenes/vfx/explosion.tscn")
var landmine_scene = preload("res://assets/scenes/prefab/mine.tscn")

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
var WATER_TILE_ID = 0  # Replace with the actual tile ID for water

@onready var global_manager = get_node("/root/MapManager/GlobalManager")  # Reference to the SpecialToggleNode
@onready var map_manager = get_node("/root/MapManager")

var right_click_position: Vector2
var target_position: Vector2

var player_to_move

@onready var turn_manager = get_node("/root/MapManager/TurnManager")  # Reference to the SpecialToggleNode

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if tilemap == null:
		print("Error: Tilemap is not set.")
		return
		
	setup_astar()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if map_manager.map_1:
		WATER_TILE_ID = 0
	elif map_manager.map_2:
		WATER_TILE_ID = 9
	elif map_manager.map_3:
		WATER_TILE_ID = 15
	elif map_manager.map_4:
		WATER_TILE_ID = 21
	else:
		print("Error: No map selected, defaulting WATER to 0.")
		WATER_TILE_ID = 0  # Fallback value if no map is selected
		
	move_along_path(delta)

func _input(event: InputEvent) -> void:
	if not global_manager.landmine_toggle_active:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var global_mouse_pos = get_global_mouse_position()
				global_mouse_pos.y += 8				
				# Get the tile the mouse is pointing to
				var target_tile_pos = tilemap.local_to_map(global_mouse_pos)
				print("Clicked at tile position: ", target_tile_pos)  # Log clicked tile
				# Only move if the target tile is walkable
				if is_tile_movable(target_tile_pos):
					move_player_to_target(target_tile_pos)
				else:
					print("Tile is not walkable!")

# Update the AStar grid based on the current tilemap state
func update_astar_grid() -> void:
	# Get the tilemap and determine its grid size
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var grid_width = tilemap.get_used_rect().size.x
	var grid_height = tilemap.get_used_rect().size.y
	
	# Set the size and properties of the AStar grid
	astar.size = Vector2i(grid_width, grid_height)
	astar.cell_size = Vector2(1, 1)  # Each cell corresponds to a single tile
	astar.default_compute_heuristic = 1  # Use Manhattan heuristic
	astar.diagonal_mode = 1              # Enable diagonal movement if desired
	
	# Clear any previous configuration to avoid conflicts
	astar.update()
	
	# Iterate over each tile in the tilemap to set walkable and non-walkable cells
	for x in range(grid_width):
		for y in range(grid_height):
			var tile_position = Vector2i(x, y)
			var tile_id = tilemap.get_cell_source_id(0, tile_position)
			
			# Determine if the tile should be walkable
			var is_solid = (tile_id == -1 or tile_id == WATER_TILE_ID 
							or is_structure(tile_position) 
							or is_unit_present(tile_position))
			
			# Mark the tile in the AStar grid
			astar.set_point_solid(tile_position, is_solid)
			
			# Debug log for walkability
			if is_solid:
				print("Tile ", tile_position, " is blocked (solid).")
			else:
				print("Tile ", tile_position, " is walkable.")
	
	print("AStar grid updated with size:", grid_width, "x", grid_height)

# Setup the AStarGrid2D with walkable tiles
func setup_astar() -> void:
	update_astar_grid()  # Update AStar grid to reflect current map state
	print("AStar grid setup completed.")

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
	var WATER_TILE_ID: int

	if map_manager.map_1:
		WATER_TILE_ID = 0
	elif map_manager.map_2:
		WATER_TILE_ID = 9
	elif map_manager.map_3:
		WATER_TILE_ID = 15
	elif map_manager.map_4:
		WATER_TILE_ID = 21
	else:
		print("Error: No map selected, defaulting WATER to 0.")
		WATER_TILE_ID = 0  # Fallback value if no map is selected

	# Return whether the tile_id matches the WATER_TILE_ID
	return tile_id == WATER_TILE_ID

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
	# Get all nodes in the 'hovertile' group
	var hover_tiles = get_tree().get_nodes_in_group("hovertile")

	# Iterate through the list and find the HoverTile node
	for hover_tile in hover_tiles:
		if hover_tile.name == "HoverTile":
			# Check if 'selected_player' exists on the hover_tile
			if hover_tile.selected_player:
				# Access the selected player's position and assign it to 'tile_pos'
				var selected_player = hover_tile.selected_player
				var selected_player_position = selected_player.position  # Assuming position is a Vector2
				
				player_to_move = selected_player
				
				# Convert the world position of the player to the tile's position
				var tilemap: TileMap = get_node("/root/MapManager/TileMap")
				tile_pos = tilemap.local_to_map(selected_player_position)  # Convert to map coordinates (tile position)
				
				print("Selected player's tile position:", tile_pos)  # Optional: Debug log to confirm the position

	# Make sure the start tile (soldier's current position) is valid
	var start_tile = tile_pos
	
	# Check if the start tile is walkable and temporarily mark it as walkable if the player is on it
	var original_tile_id = get_tile_id_at_position(start_tile)
	if not is_tile_movable(start_tile):
		# If the tile is not walkable due to the player's presence, mark it as walkable temporarily
		print("Marking start tile as walkable temporarily.")
		set_tile_walkable(start_tile, true)

	# Check if target tile is walkable
	if not is_tile_movable(target_tile):
		print("Target tile ", target_tile, " is not walkable.")  # Debug log
		return

	# Calculate the path using AStar (this returns a PackedVector2Array)
	var astar_path: PackedVector2Array = astar.get_point_path(start_tile, target_tile)
	
	# If no path is found
	if astar_path.is_empty():
		print("No path found from ", start_tile, " to ", target_tile)  # Debug log
		return
	
	# Convert PackedVector2Array to Array[Vector2i]
	current_path.clear()  # Clear any existing path
	for pos in astar_path:
		current_path.append(Vector2i(pos.x, pos.y))  # Convert Vector2 to Vector2i
	
	path_index = 0  # Reset path index to start at the beginning
	print("Path calculated:", current_path)

	# Reset the start tile back to its original state after pathfinding
	if not is_tile_movable(start_tile):
		print("Restoring start tile to its original state.")
		set_tile_walkable(start_tile, false)  # Set back to non-walkable if needed

# Helper function to get the current tile ID at a position
func get_tile_id_at_position(tile_pos: Vector2i) -> int:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	return tilemap.get_cell_source_id(0, tile_pos)

# Helper function to set a tile as walkable or not using AStar
func set_tile_walkable(tile_pos: Vector2i, walkable: bool) -> void:
	# Mark the point as solid or not solid based on whether it's walkable
	if walkable:
		astar.set_point_solid(tile_pos, false)  # Mark the tile as walkable (not solid)
	else:
		astar.set_point_solid(tile_pos, true)   # Mark the tile as blocked (solid)

# Update the AStar grid and calculate the path
func move_player_to_target(target_tile: Vector2i) -> void:
	update_astar_grid()  # Ensure AStar grid is up to date
	calculate_path(target_tile)  # Now calculate the path
	
	# Once the path is calculated, move the player to the target (will also update selected_player state)
	move_along_path(get_process_delta_time())  # This ensures movement happens immediately

# Function to move the soldier along the path
func move_along_path(delta: float) -> void:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
		
	if current_path.is_empty():
		return  # No path, so don't move

	if path_index < current_path.size() and player_to_move.has_attacked == false:
		player_to_move.get_child(0).play("move")

		# Check if the player is still valid
		if !player_to_move.visible or not is_instance_valid(player_to_move):
			print("Player no longer exists. Stopping path traversal and mine placement.")
			current_path.clear()
			#on_player_action_completed()
			player_to_move.has_attacked = true
			player_to_move.check_end_turn_conditions()
			return  # Stop movement if the player is destroyed or invalid
					
		var target_pos = current_path[path_index]  # This is a Vector2i (tile position)
		
		# Convert the target position to world position (center of the tile)
		var target_world_pos = tilemap.map_to_local(target_pos) # Ensure it's the center of the tile
		
		# Calculate the direction to the target position
		var direction = (target_world_pos - player_to_move.position).normalized()

		# Determine the direction of movement based on target and current position
		if direction.x > 0:
			player_to_move.scale.x = -1  # Facing right (East)
		elif direction.x < 0:
			player_to_move.scale.x = 1  # Facing left (West)
			
		# Move the soldier in the direction of the target position, adjusted by delta
		var distance_to_target = player_to_move.position.distance_to(target_world_pos)
		var move_distance = min(distance_to_target, move_speed * delta)  # Move only as far as the remaining distance
		player_to_move.position += direction * move_distance
		
		# Check if we have reached the target tile
		if distance_to_target <= move_distance:  # Threshold to determine if we reached the target
			# Only instantiate the mine if we're not on the last tile
			if path_index < current_path.size() - 1:
				instantiate_mine_on_tile(target_pos)
			else:
				player_to_move.current_xp += 25	
				#on_player_action_completed()
				player_to_move.has_attacked = true
				player_to_move.check_end_turn_conditions()
				
			path_index += 1  # Move to the next tile in the path
			player_to_move.get_child(0).play("default")
			
			# After moving, update the AStar grid for any changes (e.g., new walkable tiles, etc.)
			update_astar_grid()
			
		 	# Access the HUDManager (move up the tree from PlayerUnit -> UnitSpawn -> parent to HUDManager)
			var hud_manager = get_parent().get_node("HUDManager")  # Adjust the path if necessary
			
			# Access the 'special' button within HUDManager
			var landmine_button = hud_manager.get_node("HUD/Landmine")
			global_manager.missile_toggle_active = false  # Deactivate the special toggle
			#hud_manager.update_hud(player_to_move)

# Instantiate the mine on the current tile
func instantiate_mine_on_tile(tile_pos: Vector2i) -> void:
	await get_tree().create_timer(0.2).timeout
	
	var mine = landmine_scene.instantiate() as Node2D
	if mine == null:
		print("Error: Failed to instantiate mine!")
		return
	
	# Set the mine's position to the tile's center
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var world_pos = tilemap.map_to_local(tile_pos)
	mine.position = world_pos
	
	# Add mine to the parent scene
	get_parent().add_child(mine)
	print("Mine created at position: ", mine.position)  # Log the mine position

# Call this function after every player action
func on_player_action_completed():
	emit_signal("player_action_completed")
