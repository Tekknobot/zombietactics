extends Area2D

# Define the zombie_id property here
@export var zombie_id: int  # Default to -1, will be set later
var next_zombie_id: int = 1

# Movement range for zombies, they can move only up to this range
@export var movement_range = 3
var zombies_moving = []  # List to track the zombies that are currently moving
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

	# Get the MapManager node first, then access its child UnitSpawn and its children units
	var map_manager = get_node("/root/MapManager")    
	var unitspawn = map_manager.get_node("UnitSpawn")
	
	# List of unit names
	var units = ["Soldier", "Mercenary", "Dog"]

	# Iterate over the unit names and connect the signal
	for unit_name in units:
		var unit = unitspawn.get_node(unit_name)
		unit.connect("player_action_completed", Callable(self, "_on_player_action_completed"))

# Called every frame
func _process(delta: float) -> void:
	# Check if the zombie has an AnimatedSprite2D node
	var animated_sprite = get_node("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite:
		# Check if the current animation is "death"
		if animated_sprite.animation == "death":
			# Get the SpriteFrames resource for the current animation
			var sprite_frames = animated_sprite.sprite_frames
			
			# Check if the current frame is the last frame of the "death" animation
			if animated_sprite.frame == sprite_frames.get_frame_count("death") - 1:
				print("Death animation finished, destroying zombie.")
				self.remove_from_group("zombies")				
				self.visible = false
				#queue_free()  # Destroy the zombie once the death animation ends
			
	update_tile_position()
	move_along_path(delta)

# Triggered when the player action is completed
func _on_player_action_completed() -> void:
	print("Player action completed!")
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
	astar.set_point_solid(position, true)

var active_zombie_id = 1  # Start with the first zombie's ID
var target_reach_threshold = 1  # Set a tolerance threshold to determine if the zombie reached the target tile

func find_and_chase_player_and_move(delta_time: float) -> void:
	update_astar_grid()
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")

	# Find all zombies in the group and sort by `zombie_id`
	var zombies = get_tree().get_nodes_in_group("zombies")
	zombies.sort_custom(func(a, b):
		return a.zombie_id < b.zombie_id
	)

	# Ensure that active_zombie_id does not exceed the number of zombies in the group
	if zombies.size() == 0:
		print("No zombies available.")
		return

	# Loop through zombies and allow them to move one after another
	var current_zombie_index = 0

	while current_zombie_index < zombies.size():
		var zombie = zombies[current_zombie_index]

		if zombie.zombie_id == active_zombie_id:
			# If the zombie has been removed from the group, skip it
			if not zombie.is_in_group("zombies"):
				print("Zombie ID %d removed, skipping..." % active_zombie_id)
				current_zombie_index += 1
				continue  # Skip this iteration and move to the next zombie

			# Find the closest player for the active zombie
			var closest_player: Area2D = null
			var min_distance = INF
			var best_adjacent_tile: Vector2i = Vector2i()

			var players = get_tree().get_nodes_in_group("player_units")
			for player in players:
				var player_tile_pos = tilemap.local_to_map(player.global_position)
				var adjacent_tiles = get_adjacent_walkable_tiles(player_tile_pos)

				# Identify the closest adjacent tile to the active zombie
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
					# Set the path for the zombie if a valid path is found
					zombie.current_path = current_path

					print("Moving Zombie ID:", zombie.zombie_id)
					
					# Move this zombie along its path
					zombie.move_along_path(delta_time)

					# Compare the zombie's tile position to the target tile position within a threshold
					var current_zombie_tile_pos = tilemap.local_to_map(zombie.position)
					var target_tile_pos = current_path[zombie.path_index]

					# Debugging output for tracking movement
					print("Zombie Tile Position:", current_zombie_tile_pos)
					print("Target Tile Position:", target_tile_pos)

					# Now compare both positions as tile positions (Vector2i)
					if current_zombie_tile_pos.distance_to(target_tile_pos) <= target_reach_threshold:
						print("Zombie ID:", zombie.zombie_id, " reached target tile:", target_tile_pos)

						# Check if the zombie is still in the group after completing the action
						if zombie.is_in_group("zombies"):
							active_zombie_id += 1
							update_astar_grid()

							# If we've gone past the last zombie, reset to the first one
							if active_zombie_id > zombies.size():
								active_zombie_id = 1
								update_astar_grid()

			await get_tree().create_timer(1).timeout  # Wait for the specified delay in seconds

		# Move to the next zombie in the list
		current_zombie_index += 1

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
		if path_index >= movement_range:
			return		
			
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
