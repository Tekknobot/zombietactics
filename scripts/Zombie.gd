extends Area2D

# Define the zombie_id property here
@export var zombie_id: int  # Default to -1, will be set later
var next_zombie_id: int = 1

# Movement range for zombies, they can move only up to this range
@export var movement_range = 3
var is_moving = false  # Flag to track if zombies are moving

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

var attacks: int = 0
var attack_damage = 25

func _ready() -> void:
	update_tile_position()
	update_astar_grid()

	# Get the MapManager node first, then access its child UnitSpawn and its children units
	var map_manager = get_node("/root/MapManager")    
	var unitspawn = map_manager.get_node("UnitSpawn")
	
	# Access the MissileManager and connect the signal if it exists
	var missile_manager = map_manager.get_node("MissileManager")

	if missile_manager and missile_manager.has_signal("player_action_completed"):
		print("MissileManager signal found!")
		missile_manager.connect("player_action_completed", Callable(self, "_on_player_action_completed"))
	else:
		print("MissileManager or signal 'player_action_completed' not found!")

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
				#print("Death animation finished, destroying zombie.")
				self.remove_from_group("zombies")				
				self.visible = false
				#queue_free()  # Destroy the zombie once the death animation ends
			
	update_tile_position()
	move_along_path(delta)

# Triggered when the player action is completed
func _on_player_action_completed() -> void:
	#print("Player action completed!")
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

	#print("AStar grid updated with size:", grid_width, "x", grid_height)
	
	# Clear any previous configuration to avoid conflicts
	astar.update()

# Function to update the tile position based on the current Area2D position
func update_tile_position() -> void:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	tile_pos = tilemap.local_to_map(position)
	coord = tile_pos
	layer = (tile_pos.x + tile_pos.y) + 1
	self.z_index = layer
	astar.set_point_solid(position, true)

var active_zombie_id = 0  # Start with the first zombie's ID (0-indexed)
var target_reach_threshold = 1  # Set a tolerance threshold to determine if the zombie reached the target tile
var zombies: Array  # This will store the zombies sorted by zombie_id

func find_and_chase_player_and_move(delta_time: float) -> void:
	# Update the AStar grid before moving zombies
	update_astar_grid()
	
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")

	# Find all zombies in the group and sort by `zombie_id`
	var zombies = get_tree().get_nodes_in_group("zombies")
	zombies.sort_custom(func(a, b):
		return a.zombie_id < b.zombie_id
	)

	# Ensure that zombies exist before proceeding
	if zombies.size() == 0:
		print("No zombies available.")
		return

	# Set is_moving to true when zombies start moving
	is_moving = true

	# Loop through zombies and move them one by one based on their ID
	for zombie in zombies:
		# Skip the zombie if it has been removed from the group
		if not zombie.is_in_group("zombies"):
			print("Zombie ID %d removed, skipping..." % zombie.zombie_id)
			continue  # Skip this zombie and move to the next one

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
		
		update_astar_grid()
		
		# Calculate path to the best adjacent tile if a valid target is found
		if closest_player and best_adjacent_tile != Vector2i():
			var current_path = astar.get_point_path(zombie.tile_pos, best_adjacent_tile)
			if current_path.size() > 0:
				zombie.current_path = current_path
				zombie.path_index = 0  # Reset path index to start from the first point
			else:
				print("No path found for Zombie ID:", zombie.zombie_id)

		update_astar_grid()
		
		# Move the zombie step by step along its path
		if zombie.path_index < zombie.current_path.size():
			var target_pos = zombie.current_path[zombie.path_index]
			var movement_vector = (target_pos - zombie.position).normalized()

			# Move the zombie toward the next path point
			zombie.position += movement_vector * move_speed * delta_time
			
			# Check if the zombie has reached the target point
			if zombie.position.distance_to(target_pos) <= target_reach_threshold:
				# Zombie reached the current target point, so increment the path index
				zombie.path_index += 1
				
				update_astar_grid()
				
				# If the zombie has completed its path, ensure to re-evaluate or update paths if necessary
				if zombie.path_index >= zombie.current_path.size():
					print("Zombie ID:", zombie.zombie_id, " has reached its final destination.")
					
		else:
			update_astar_grid()
			print("Zombie ID %d has no valid path to move." % zombie.zombie_id)
		
		if attacks >= 1:
			pass
		else:
			# Call the attack check once per zombie after its movement
			check_for_attack()  # This will check for attacks after the zombie has moved
			
		# Wait before processing the next zombie
		await get_tree().create_timer(1).timeout  # This introduces a delay, giving each zombie time to move

	# After all zombies are done moving, set is_moving to false
	is_moving = false
	attacks = 0

	
var is_attacking = false  # Flag to check if the zombie is already attacking in this cycle

# Function to check adjacency and trigger attack if necessary
func check_for_attack() -> void:
	# Prevent checking if the zombie has already attacked
	if is_attacking:
		return
	
	# Set the attack flag to true
	is_attacking = true
	
	# Get all player units in the game
	var players = get_tree().get_nodes_in_group("player_units")
	
	# Check each player for adjacency and attack
	for player in players:
		# Check if the player is adjacent to this zombie
		if is_adjacent_to_tile(tile_pos, player):
			var tilemap: TileMap = get_node("/root/MapManager/TileMap")
			
			# Get world position of the target tile
			var target_world_pos = player.position
			print("Target world position: ", target_world_pos)
			
			# Determine the direction to the target
			var target_direction = target_world_pos.x - position.x

			# Flip the sprite based on the target's relative position and current scale.x value
			if target_direction > 0 and scale.x != -1:
				scale.x = -1  # Flip sprite to face right
			elif target_direction < 0 and scale.x != 1:
				scale.x = 1  # Flip sprite to face left

			# Play attack animation on the zombie
			self.get_child(0).play("attack")
			print("Zombie just attacked.")
			
			if self.visible:
				# Call the attack player function
				attack_player(player)
			
			# After the first attack, exit the loop
			break
	
	# Reset the attack flag after a small delay to avoid multiple attacks in the same cycle/frame
	await get_tree().create_timer(0.5).timeout  # Adjust the delay as needed
	is_attacking = false

# Function to handle the attack logic
func attack_player(player: Area2D) -> void:
	# Assuming the player has an AnimatedSprite2D node or any other visual node
	var sprite = player.get_node("AnimatedSprite2D")  # Get the AnimatedSprite2D or visual representation of the player
	
	if sprite:
		# Modulate the color to a bright red (indicating the attack)
		sprite.modulate = Color(1, 0, 0)  # Red color to indicate damage or attack
		
		# Start a timer to reset the modulate back to the original color after 0.1 second
		await get_tree().create_timer(0.2).timeout  # Wait 0.1 seconds for a quick flash
		
		# Reset the modulate to the original color (full color, no effect)
		sprite.modulate = Color(1, 1, 1)  # Reset back to the original color (white/full color)
	
	# Print a debug message
	print("Zombie attacks player at position:", player.global_position)
	
	# Inflict damage on the player
	take_damage(player, attack_damage)  # Call the take_damage function with 10 damage
	
	attacks += 1

# New Function to handle player taking damage
func take_damage(player: Area2D, damage: int) -> void:
	# Check if the player has a health property, otherwise assume max health
	if not player.has_method("apply_damage"):
		print("Player object does not have an 'apply_damage' method")
		return
	
	player.apply_damage(damage)  # Call the player's apply_damage method
	print("Zombie dealt", damage, "damage to player")

# Function to check if the zombie is adjacent to a specific tile
func is_adjacent_to_tile(zombie_tile: Vector2i, player: Area2D) -> bool:
	# Get the tilemap
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	
	# Get the player's tile position
	var player_tile_pos = tilemap.local_to_map(player.global_position)
	
	# Get the surrounding tiles of the zombie's current position
	var surrounding_cells = tilemap.get_surrounding_cells(zombie_tile)
	
	# Check if any of the surrounding cells match the player's tile position
	for tile in surrounding_cells:
		if tile == player_tile_pos:
			return true  # Player is adjacent to the zombie
	
	# If no surrounding cell matches, return false
	return false

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

func move_along_path(delta: float) -> void:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	
	if current_path.is_empty():
		return  # No path, so don't move

	# Ensure we don't move past the allowed movement range (3 tiles)
	if path_index >= min(current_path.size(), movement_range):
		return  # Stop moving once we've reached the maximum movement range


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
