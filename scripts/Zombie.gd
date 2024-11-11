extends Area2D

# Define the zombie_id property here
@export var zombie_id: int  # Default to -1, will be set later
var next_zombie_id: int = 1

# Movement range for zombies, they can move only up to this range
@export var movement_range = 3
var zombies_moving = []  # List to track the zombies that are currently moving
var zombie_path_index = 0  # To track which zombie should move next
var tile_size = 32  # Or whatever your tile size is in pixels
@export var movement_tile_scene: PackedScene
@export var tilemap: TileMap = null

var movement_tiles: Array[Node2D] = []
var tile_pos: Vector2i
var coord: Vector2
var layer: int

var astar: AStarGrid2D = AStarGrid2D.new()
var current_path: PackedVector2Array
var path_index: int = 0
var move_speed: float = 75.0

const WATER_TILE_ID = 0

func _ready() -> void:
	update_tile_position()
	update_astar_grid()
	
	# Get the MapManager node first, then access its child hovertile
	var map_manager = get_node("/root/MapManager")
	var hovertile = map_manager.get_node("HoverTile")
	
	if hovertile:
		hovertile.connect("player_action_completed", Callable(self, "_on_player_action_completed"))
	else:
		print("Hovertile not detected.")

# Called every frame
func _process(delta: float) -> void:
	update_tile_position()
	move_along_path(delta)

# Triggered when the player action is completed
func _on_player_action_completed() -> void:
	find_and_chase_player_and_move(get_process_delta_time())

# Setup the AStarGrid2D with walkable tiles
func setup_astar() -> void:
	update_astar_grid()  # Update AStar grid to reflect current map state
	print("AStar grid setup completed.")

# Function to update the AStar grid based on the current tilemap state
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

	print("AStar grid updated with size:", grid_width, "x", grid_height)

# Function to update the tile position based on the current Area2D position
func update_tile_position() -> void:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	tile_pos = tilemap.local_to_map(position)
	coord = tile_pos
	layer = (tile_pos.x + tile_pos.y) + 1
	self.z_index = layer

func find_and_chase_player_and_move(delta_time: float) -> void:
	update_astar_grid()
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")

	# Sort zombies in the `zombies` group by their `zombie_id` to ensure they move in order
	var zombies = get_tree().get_nodes_in_group("zombies")
	zombies.sort_custom(func(a, b):
		return a.zombie_id < b.zombie_id
	)  # Sort in ascending order by `zombie_id`

	# Process each zombie sequentially based on their `zombie_id`
	for zombie in zombies:
		if zombie.zombie_id == next_zombie_id:
			# Find the closest player for this zombie
			var closest_player: Area2D = null
			var min_distance = INF
			var best_adjacent_tile: Vector2i = Vector2i()
			
			var players = get_tree().get_nodes_in_group("player_units")
			for player in players:
				var player_tile_pos = tilemap.local_to_map(player.global_position)
				var adjacent_tiles = get_adjacent_walkable_tiles(player_tile_pos)

				# Identify the closest adjacent tile to the zombie
				for adj_tile in adjacent_tiles:
					var distance = zombie.tile_pos.distance_to(adj_tile)
					if distance < min_distance:
						min_distance = distance
						closest_player = player
						best_adjacent_tile = adj_tile

			# Calculate path to the best adjacent tile if a valid target is found
			if closest_player and best_adjacent_tile != Vector2i():
				var current_path = astar.get_point_path(zombie.tile_pos, best_adjacent_tile)
				if current_path.size() == 0:
					print("No path found for Zombie ID:", zombie.zombie_id)
				else:
					print("Path found for Zombie ID:", zombie.zombie_id, ":", current_path)
					# Set the path and path index directly on the zombie instance
					zombie.current_path = current_path
					zombie.path_index = 0

					# Move this zombie along its path
					print("Moving Zombie ID:", zombie.zombie_id)
					zombie.move_along_path(delta_time)

					# If the zombie has completed its path, increment `next_zombie_id`
					if zombie.path_index >= current_path.size():
						next_zombie_id += 1
					break  # Process only one zombie per function call
			break  # Exit loop after processing one zombie

func get_adjacent_walkable_tiles(center_tile: Vector2i) -> Array[Vector2i]:
	var walkable_tiles: Array[Vector2i] = []
	
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	
	# Get the surrounding cells of the center_tile
	var surrounding_cells = tilemap.get_surrounding_cells(center_tile)

	# Check if each surrounding cell is walkable
	for tile in surrounding_cells:
		if !astar.is_point_solid(tile):  # Check if the tile is walkable
			walkable_tiles.append(tile)

	return walkable_tiles

# Check if a tile is adjacent to the current position
func is_adjacent_to_tile(target_tile_pos: Vector2i) -> bool:
	return abs(tile_pos.x - target_tile_pos.x) + abs(tile_pos.y - target_tile_pos.y) == 1

func move_along_path(delta: float) -> void:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	
	if current_path.is_empty():
		return  # No path, so don't move

	if path_index < current_path.size():
		# Play the "move" animation
		get_child(0).play("move")
		
		# Get the next target position (tile position)
		var target_pos = current_path[path_index]  # This is a Vector2i (tile position)
		
		# Convert the target tile position to world position
		var target_world_pos = tilemap.map_to_local(target_pos)  # Center of the tile

		# Calculate the direction towards the target position (normalized vector)
		var direction = (target_world_pos - position).normalized()

		# Determine the direction to face based on movement
		if direction.x > 0:
			scale.x = -1  # Facing right (East)
		elif direction.x < 0:
			scale.x = 1  # Facing left (West)  
		
		# Move towards the target position
		position += direction * move_speed * delta
		
		# If the zombie has reached the target tile (within a small threshold), move to the next tile
		if position.distance_to(target_world_pos) <= 1:  # Threshold to check if we reached the target
			path_index += 1  # Move to the next tile in the path
			get_child(0).play("default")  # Play idle animation when not moving
			# After moving, update the AStar grid for any changes (optional)
			update_astar_grid()

# Attack the player unit
func attack_player(player: Area2D) -> void:
	# Trigger the player's death animation
	if player.has_method("play_death_animation"):
		player.play_death_animation()
	# Optionally add zombie-specific attack animation or effects here
	print("Zombie attacks player at position:", player.global_position)

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
	return tile_id == WATER_TILE_ID

# Check if there is a structure on the tile
func is_structure(tile_pos: Vector2i) -> bool:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var structures = get_tree().get_nodes_in_group("structures")
	for structure in structures:
		var structure_tile_pos = tilemap.local_to_map(structure.global_position)
		if tile_pos == structure_tile_pos:
			return true
	return false

# Check if there is a unit on the tile
func is_unit_present(tile_pos: Vector2i) -> bool:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var all_units = get_tree().get_nodes_in_group("player_units") + get_tree().get_nodes_in_group("zombies")
	for unit in all_units:
		var unit_tile_pos = tilemap.local_to_map(unit.global_position)
		if tile_pos == unit_tile_pos:
			return true
	return false
