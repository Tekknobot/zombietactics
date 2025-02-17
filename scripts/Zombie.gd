extends Area2D

# Declare the class
class_name ZombieUnit

# Define the zombie_id property here
@export var zombie_id: int  # Default to -1, will be set later
var next_zombie_id: int = 1

var is_moving = false  # Flag to track if zombies are moving

var tile_size = 32  # Or whatever your tile size is in pixels
@export var movement_tile_scene: PackedScene
@export var tilemap: TileMap = null

@onready var map_manager = get_parent().get_node("/root/MapManager")

var is_zombie: bool = true

var movement_tiles: Array[Node2D] = []
var tile_pos: Vector2i
var coord: Vector2
var layer: int

var astar: AStarGrid2D = AStarGrid2D.new()
var current_path: PackedVector2Array
var path_index: int = 0
@onready var move_speed: float = 75.0

var WATER_TILE_ID = 0

var attacks: int = 0

@export var movement_range = 2
@export var attack_damage: int = 25

var hud: Control

@export var selected: bool = false
@export var portrait_texture: Texture

# Player's name (optional)
@export var zombie_name: String

# Player's health properties
var max_health: int = 100
var current_health: int = 50

# Player's health properties
var max_xp: int = 100
var current_xp: int = 25
var xp_for_next_level: int = 100  # Example threshold for level-up, if relevant
var current_level: int = 1

@export var zombie_type: String

# Optional: Scene to instantiate for explosion effect
@export var explosion_scene: PackedScene
@export var explosion_radius: float = 1.0  # Radius to check for units at the target position

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D  # Adjust this path as necessary

var player_unit_is_selected = false

@onready var audio_player = $AudioStreamPlayer2D  # Adjust the path as needed
@onready var second_audio_player = $SecondAudioPlayer  # Adjust the path as needed

@export var zombie_audio: AudioStream
@export var hurt_audio: AudioStream
@export var levelup_audio: AudioStream
@export var dog_hurt_audio: AudioStream

@onready var turn_manager = get_parent().get_node("/root/MapManager/TurnManager")  
@onready var mission_manager = get_parent().get_node("/root/MapManager/MissionManager")  
@onready var zombie_spawn_manager = get_parent().get_node("/root/MapManager/SpawnZombies")  

var active_zombie_id = 0  # Start with the first zombie's ID (0-indexed)
var zombies: Array  # This will store the zombies sorted by zombie_id

var is_attacking = false  # Flag to check if the zombie is already attacking in this cycle
var is_being_attacked = false

@onready var health_ui = $HealthUI
@onready var xp_ui = $XPUI

signal astar_setup_complete
signal movement_completed

var active_zombie: Area2D = null
#var zombie_queue: Array = []  # Queue of zombies to move
var closest_player: Area2D = null
var best_adjacent_tile: Vector2i = Vector2i()

var has_moved: bool = false
var been_attacked: bool = false
var has_processed: bool = false
var is_death_processed: bool = false

func _ready() -> void:
	# Possible values for health and XP
	var possible_values = [25, 50, 75, 100]
	var possible_xp_values = [0]
	
	# Randomize current_health
	current_health = possible_values[randi() % possible_values.size()]
	print("Current Health set to:", current_health)

	# Randomize current_xp
	current_xp = possible_xp_values[randi() % possible_xp_values.size()]
	print("Current XP set to:", current_xp)
				
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
			
	update_tile_position()

	turn_manager.connect("player_action_completed", Callable(self, "_on_player_action_completed"))
	turn_manager.connect("movement_completed", Callable(self, "_movement_completed"))

	update_unit_ui()
	setup_astar()

func _process(delta: float) -> void:
	var animated_sprite = get_node("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite:
		# Check if the current animation is "death"
		if animated_sprite.animation == "death" and not is_death_processed:
			var sprite_frames = animated_sprite.sprite_frames
			
			# Check if the current frame is the last frame of the "death" animation
			if animated_sprite.frame == sprite_frames.get_frame_count("death") - 1:
				print("Death animation finished, destroying zombie.")
				
				# Mark the death as processed
				is_death_processed = true

				self.remove_from_group("zombies")
				self.visible = false
				
				GlobalManager.zombies_processed = 0
				GlobalManager.zombie_queue.clear()
				
				if self.zombie_type == "Radioactive":
					self.get_child(4).active_particle_instances.clear()
				
				var zombies = get_tree().get_nodes_in_group("zombies")
				if zombies.size() <= 0:
					reset_player_units()	
					GlobalManager.zombies_cleared = true
					GlobalManager.zombie_queue.clear()
					mission_manager.check_mission_manager()

				#queue_free()  # Destroy the zombie once the death animation ends

	# Zombie movement
	if self and self.is_moving:		
		# Camera focuses on the active zombie
		var camera: Camera2D = get_node("/root/MapManager/Camera2D")
		camera.focus_on_position(self.position) 
		
		# Update HUD with new stats
		var hud_manager = get_node("/root/MapManager/HUDManager")
		hud_manager.update_hud_zombie(self)  # Consolidate all updates into one method
					
		if self.path_index < min(self.current_path.size(), self.movement_range + 1):
			var tilemap: TileMap = get_node("/root/MapManager/TileMap")
			var target_tile_pos = self.current_path[self.path_index]
			var target_world_pos = tilemap.map_to_local(target_tile_pos)
				
			# Calculate direction and move toward the target
			var direction = (target_world_pos - self.position).normalized()
			self.position += direction * move_speed * delta  
			
			# Update facing direction
			if direction.x > 0:
				self.scale.x = -1  # Facing right
			elif direction.x < 0:
				self.scale.x = 1  # Facing left

			# Check if the zombie has reached the target position
			if self.position.distance_to(target_world_pos) <= 1:
				self.path_index += 1  # Move to the next point in the path

				# Check if the zombie has moved the maximum range or completed the path
				if self.path_index >= min(self.current_path.size(), self.movement_range + 1):
					print("Zombie ID:", self.zombie_id, "completed movement.")
					self.is_moving = false
					self.has_moved = true
					
					self.get_child(0).play("default")
				
					# Check for adjacent attacks
					await check_for_attack(self)

					# Update AStar grid after movement
					update_astar_grid()
					
				  # Increment the processed zombies counter only here
					if not self.has_processed:
						GlobalManager.zombies_processed += 1
						self.has_processed = true  # Ensure it doesn't increment again
									
					process_zombie_queue()
					emit_signal("movement_completed")  # Notify main loop
		else:
			# If out of range or no path
			self.is_moving = false
			self.has_moved = true
			self.get_child(0).play("default")
			
			# Check for adjacent attacks
			await check_for_attack(self)
			update_astar_grid()
			process_zombie_queue()
			emit_signal("movement_completed")  # Notify main loop
											
	update_tile_position()
	update_unit_ui()
	
func process_zombie_queue() -> void:		
	been_attacked = false
	var all_players = get_tree().get_nodes_in_group("player_units")
	
	print("Debug: zombies_processed =", GlobalManager.zombies_processed, "zombie_limit =", all_players.size())
	print("Debug: zombie_queue size =", GlobalManager.zombie_queue.size())
		
	if GlobalManager.zombies_processed >= all_players.size() or GlobalManager.zombie_queue.is_empty():
		print("Processed ", GlobalManager.zombies_processed, " zombies. Turn complete.")
		
		var all_zombies = get_tree().get_nodes_in_group("zombies")
		
		# Reset zombie movement flags
		for zombie in all_zombies:
			zombie.is_moving = false
			zombie.has_moved = false
			
		# Handle radioactive zombies
		for zombie in all_zombies:
			if zombie.zombie_type == "Radioactive":
				zombie.get_child(4).particles_need_update = true
				zombie.get_child(4).update_particles()
				
		reset_player_units()
		GlobalManager.zombies_processed = 0  # Reset the counter for the next turn
		return
	
	# Process the next zombie
	if not GlobalManager.zombie_queue.is_empty():
		var active_zombie = GlobalManager.zombie_queue.pop_front()
		GlobalManager.active_zombie = active_zombie
		GlobalManager.active_zombie.has_moved = true
		print("Processing Zombie ID:", active_zombie.zombie_id)
		reset_player_units()	

	# Get the next zombie that has not moved
	while not GlobalManager.zombie_queue.is_empty():
		GlobalManager.active_zombie = GlobalManager.zombie_queue.pop_front()
		if not GlobalManager.active_zombie.has_moved:
			break
		print("Skipping Zombie ID:", GlobalManager.active_zombie.zombie_id, "as it has already moved.")
		reset_player_units()
	
	# If all zombies have moved, stop processing
	if GlobalManager.active_zombie.has_moved:
		print("All zombies have moved. Ending turn.")
		process_zombie_queue()  # Recursive call to clean up
		reset_player_units()
		return

	# Reset path and movement state for the current zombie
	GlobalManager.active_zombie.path_index = 0
	GlobalManager.active_zombie.current_path.clear()
	print("Processing Zombie ID:", GlobalManager.active_zombie.zombie_id)

	# Find the closest player and calculate the path
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var players = get_tree().get_nodes_in_group("player_units")

	var min_distance = INF
	var closest_player = null
	var best_adjacent_tile = Vector2i()

	for player in players:
		if not player.is_in_group("player_units"):
			continue

		var player_tile_pos = tilemap.local_to_map(player.global_position)
		var adjacent_tiles = get_adjacent_walkable_tiles(player_tile_pos)

		for adj_tile in adjacent_tiles:
			var distance = GlobalManager.active_zombie.tile_pos.distance_to(adj_tile)
			if distance < min_distance:
				min_distance = distance
				closest_player = player
				best_adjacent_tile = adj_tile
				
	if not closest_player or best_adjacent_tile == Vector2i():
		print("No valid adjacent tiles found. Attempting fallback.")
		# Optional fallback logic here (e.g., move toward player without attack)
		process_zombie_queue()
		return				

	if closest_player and best_adjacent_tile != Vector2i():
		GlobalManager.active_zombie.current_path = astar.get_point_path(GlobalManager.active_zombie.tile_pos, best_adjacent_tile)
		
		if GlobalManager.active_zombie.current_path.is_empty():
			print("No path found for Zombie ID:", GlobalManager.active_zombie.zombie_id, ". Attempting fallback movement.")
			# Optional fallback logic (e.g., move in the general direction of the player)
			process_zombie_queue()
			return	
				
		if GlobalManager.active_zombie.current_path.size() > 0:
			# Limit the path length to the zombie's movement range
			GlobalManager.active_zombie.current_path = GlobalManager.active_zombie.current_path.slice(0, GlobalManager.active_zombie.movement_range + 1)
			GlobalManager.active_zombie.is_moving = true
			GlobalManager.active_zombie.get_child(0).play("move")

			# Play SFX
			GlobalManager.active_zombie.audio_player.stream = GlobalManager.active_zombie.zombie_audio
			GlobalManager.active_zombie.audio_player.play()

			# Handle radioactive zombies
			for zombie in get_tree().get_nodes_in_group("zombies"):
				if zombie.zombie_type == "Radioactive":
					zombie.get_child(4).hide_all_radiation()

			print("Zombie ID:", GlobalManager.active_zombie.zombie_id, "assigned path:", GlobalManager.active_zombie.current_path)
		else:
			print("No valid path for Zombie ID:", GlobalManager.active_zombie.zombie_id)
			process_zombie_queue()  # Process the next zombie
			return
	else:
		print("No target for Zombie ID:", GlobalManager.active_zombie.zombie_id)
		process_zombie_queue()  # Process the next zombie
		return	
			
# Triggered when the player action is completed
func _on_player_action_completed() -> void:
	reset_player_units()
	
	update_astar_grid()
	
	var zombies = get_tree().get_nodes_in_group("zombies")
	for zombie in zombies:
		zombie.has_processed = false
	
	turn_manager.used_turns_count = 0
	
	print("Player action completed. Starting zombie movement.")
	await get_tree().create_timer(0.5).timeout 
	mission_manager.check_mission_manager()

	# Populate the zombie queue
	GlobalManager.zombie_queue.clear()
	await get_tree().create_timer(0.5).timeout 
	GlobalManager.zombie_queue = get_tree().get_nodes_in_group("zombies")
	GlobalManager.zombie_queue.sort_custom(func(a, b):
		return zombie_sort_function(a, b, get_tree().get_nodes_in_group("player_units"))
	)
	process_zombie_queue()

# Setup the AStarGrid2D with walkable tiles
func setup_astar() -> void:
	await update_astar_grid()  # Update AStar grid to reflect current map state
	print("AStar grid setup completed.")
	
	# Emit the signal when setup is complete
	emit_signal("astar_setup_complete")	

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

	# Clear any previous configuration to avoid conflicts
	astar.update()

# Function to update the tile position based on the current Area2D position
func update_tile_position() -> void:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	tile_pos = tilemap.local_to_map(position)
	coord = tile_pos
	layer = tile_pos.x + tile_pos.y
	self.z_index = layer
	#astar.set_point_solid(position, true)

func update_unit_ui():
	health_ui.value = current_health
	health_ui.max_value = max_health
	
	xp_ui.value = current_xp
	xp_ui.max_value = max_xp

# Helper function to calculate the distance to the nearest player
func nearest_player_distance(entity: Node2D, players: Array) -> float:
	var min_distance = INF  # Start with a very large value
	for player in players:
		if player is Node2D:
			var distance = entity.global_position.distance_to(player.global_position)
			if distance < min_distance:
				min_distance = distance
	return min_distance

# Custom sort function for zombies based on nearest player distance
func zombie_sort_function(a: Node2D, b: Node2D, players: Array) -> bool:
	return nearest_player_distance(a, players) < nearest_player_distance(b, players)

	
func check_for_attack(zombie: Area2D) -> void:
	# Prevent checking if the zombie has already attacked
	if is_attacking:
		print("Already attacking, skipping attack check.")
		return

	# Set the attack flag to true
	is_attacking = true

	# Get all player units in the game
	var players = get_tree().get_nodes_in_group("player_units")
	
	# Check each player for adjacency and attack
	for player in players:
		if not player.is_in_group("player_units"):
			continue  # Skip invalid or removed players

		# Check if the player is adjacent to this zombie
		if is_adjacent_to_tile(zombie.tile_pos, player):
			print("Player adjacent to Zombie ID:", zombie.zombie_id)
			
			# Determine direction for animation
			var target_direction = player.global_position.x - zombie.global_position.x
			if target_direction > 0 and zombie.scale.x != -1:
				zombie.scale.x = -1  # Facing right
			elif target_direction < 0 and zombie.scale.x != 1:
				zombie.scale.x = 1  # Facing left
			
			# Play attack animation
			var animation_node = zombie.get_child(0)
			if animation_node:
				animation_node.play("attack")
				print("Zombie ID:", zombie.zombie_id, "played attack animation.")
			else:
				print("Animation node not found for Zombie ID:", zombie.zombie_id)

			# Inflict damage
			attacks += 1
			if zombie.visible:
				attack_player(player)
				player.health_ui.value -= attack_damage
				print("Zombie dealt", attack_damage, "damage to Player:", player.name)
			
			# Wait for animation completion
			await get_tree().create_timer(0.5).timeout
			
			if animation_node:
				animation_node.play("default")
			break  # Attack only one player
	
	# Reset attack flag
	await get_tree().create_timer(0.5).timeout
	is_attacking = false

# Function to handle the attack logic
func attack_player(player: Area2D) -> void:
	# Assuming the player has an AnimatedSprite2D node or any other visual node
	var sprite = player.get_node("AnimatedSprite2D")  # Get the AnimatedSprite2D or visual representation of the player
	
	if sprite:
		for i in range(4):  # Flash 3 times
			sprite.modulate = Color(1, 0, 0)  # Set to red
			await get_tree().create_timer(0.1).timeout  # Wait 0.1 seconds
			sprite.modulate = Color(1, 1, 1)  # Set back to normal color
			await get_tree().create_timer(0.1).timeout  # Wait 0.1 seconds

	# Print a debug message
	print("Zombie attacks player at position:", player.global_position)
	
	# Inflict damage on the player
	give_damage(player, attack_damage)  # Call the take_damage function with 10 damage
	current_xp += 25
	
	# Optional: Check for level up, if applicable
	if current_xp >= xp_for_next_level:
		level_up()

	await get_tree().create_timer(1).timeout
	
# New Function to handle player taking damage
func give_damage(player: Area2D, damage: int) -> void:
	# Check if the player has a health property, otherwise assume max health
	if not player.has_method("apply_damage"):
		print("Player object does not have an 'apply_damage' method")
		return
	
	if player.player_name == "Yoshida. Boi":
		# Play sfx
		player.audio_player.stream = dog_hurt_audio
		player.audio_player.play()	
		player.apply_damage(damage) 
	else:
		# Play sfx
		player.audio_player.stream = hurt_audio
		player.audio_player.play()	
		player.apply_damage(damage)  # Call the player's apply_damage method

	print("Zombie dealt ", damage, " damage to player")

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

func move_along_path(zombie: Area2D, current_path: PackedVector2Array) -> void:
	if current_path.is_empty():
		print("Path is empty. No movement.")
		return

	zombie.current_path = current_path
	zombie.path_index = 0  # Start at the first step of the path
	zombie.is_moving = true
	
	print("Zombie ID:", zombie.zombie_id, "started moving.")
		
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

# Check if there is a unit on the tile
func is_zombie_present(tile_pos: Vector2i) -> bool:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var all_units = get_tree().get_nodes_in_group("zombies")
	for unit in all_units:
		var unit_tile_pos = tilemap.local_to_map(unit.global_position)
		if tile_pos == unit_tile_pos:
			return true
	return false

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
	# Check if any zombie in the "zombies" group is moving
	var zombies = get_tree().get_nodes_in_group("zombies")
	var zombies_moving = false
	for zombie in zombies:
		if zombie.is_moving:  # If any zombie is moving, skip player input and prevent showing tiles
			zombies_moving = true
			#print("Zombie is moving, skipping player input.")
			break  # Exit early once we know a zombie is moving
	
	if zombies_moving:
		# Prevent tile display or any other player action
		return

	# Update the HUD to reflect new stats
	var hud_manager = get_parent().get_parent().get_node("HUDManager")
	hud_manager.hide_special_buttons()	
		
	clear_movement_tiles()  # Clear existing movement tiles
	
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

# Method to apply damage
func apply_damage(damage: int) -> void:
	current_health -= damage  # Reduce health by damage
	current_health = clamp(current_health, 0, max_health)  # Ensure health stays within bounds
	
	if current_health <= 0:
		die()  # Handle player death if health is 0
	else:
		print("Player health after attack:", current_health)

# Optional death handling
func die() -> void:
	print("Zombie has died")
	get_child(0).play("death")
	audio_player.stream = zombie_audio
	audio_player.play()
	
	await get_tree().create_timer(2).timeout
	
	self.remove_from_group("zombies")
	self.visible = false
	#queue_free()  # Remove player from the scene or handle accordingly		

func level_up() -> void:	
	# Play SFX
	second_audio_player.stream = levelup_audio
	second_audio_player.play()
	print("Level up triggered!")
	
	# Add level-up bonuses
	movement_range += 1
	current_level += 1
	max_health += 25
	current_health += 25  # Fully heal player
	attack_damage += 25

	# Reset XP threshold
	current_xp -= xp_for_next_level
	xp_for_next_level += 25  # Increment XP threshold
		
	# Play visual effect
	play_level_up_effect()

	# Update HUD with new stats
	var hud_manager = get_parent().get_parent().get_node("HUDManager")
	hud_manager.update_hud_zombie(self)  # Consolidate all updates into one method
			
	print("Level up completed!")
	
# Function to play level-up flickering effect (green to normal)
func play_level_up_effect() -> void:
	var original_color = modulate  # Store the original color of the unit
	var flash_color = Color(0, 1, 0)  # Green color for the flash effect
	
	# Number of flashes and duration
	var flash_count = 12  # How many times to alternate
	var flash_duration = 0.1  # Duration for each flash (on or off)
	
	# Loop to alternate colors
	for i in range(flash_count):
		# Alternate color between green and the original color
		modulate = flash_color if i % 2 == 0 else original_color
		
		# Wait for the duration before switching again
		await get_tree().create_timer(flash_duration).timeout

	# Ensure color is reset to original after the effect
	modulate = original_color

func _create_explosion() -> void:
	# Check if explosion_scene is assigned
	if explosion_scene == null:
		print("Error: Explosion scene is not assigned!")
		return

	# Instantiate the explosion effect
	var explosion = explosion_scene.instantiate() as Node2D
	if explosion == null:
		print("Error: Failed to instantiate explosion!")
		return
	
	# Set the explosion's position to the projectile's impact location
	explosion.position = position
	explosion.z_index = int(position.y)  # Ensure explosion is layered correctly
	
	# Add explosion to the parent scene
	get_parent().add_child(explosion)
	print("Explosion created at position: ", explosion.position)

# Flashes the sprite red and white a few times
func flash_damage():
	if sprite:
		for i in range(8):  # Flash 3 times
			sprite.modulate = Color(1, 0, 0)  # Set to red
			await get_tree().create_timer(0.1).timeout  # Wait 0.1 seconds
			sprite.modulate = Color(1, 1, 1)  # Set back to normal color
			await get_tree().create_timer(0.1).timeout  # Wait 0.1 seconds

func get_attack_damage() -> int:
	return attack_damage  # Replace with your variable holding attack damage

func reset_player_units():
	# Get all player units in the game
	var players = get_tree().get_nodes_in_group("player_units")
	for player in players:	
		player.has_moved = false
		player.has_attacked = false
		player.has_used_turn = false
		player.can_start_turn = true
		player.modulate = Color(1, 1, 1)
