extends Node2D

# Configurable Properties
@export var ability_range: float = 300.0 # Max range of the ability in pixels
@export var cone_angle: float = 45.0 # Angle of the cone in degrees
@export var bullets_per_second: int = 20 # Rate of fire
@export var cooldown_time: float = 5.0 # Cooldown time in seconds
@export var duration: float = 2.0 # How long the ability lasts in seconds
@export var projectile_scene: PackedScene # Reference to the projectile scene

# Internal State
var is_on_cooldown: bool = false
var is_firing: bool = false
var firing_time: float = 0.0

@export var hover_tile_path: NodePath = "/root/MapManager/HoverTile"
@onready var hover_tile = get_node_or_null(hover_tile_path)
@export var hover_tile_scene: PackedScene

# Signals
signal ability_used

var barrage_completed: bool = false

# Variables to track state
var hover_tiles_visible = false  # Whether hover tiles are currently displayed
var hover_tiles = []  # Store references to dynamically created hover tiles

var center_tile_pos

func _ready():
	pass

func _process(delta):
	# Check if the barrage is complete and the turn has not ended
	if barrage_completed:
		get_parent().current_xp += 25
		if get_parent().current_xp >= get_parent().xp_for_next_level:
			get_parent().level_up()	
				
		# Check end turn conditions after firing
		get_parent().check_end_turn_conditions()
		barrage_completed = false  # Reset the flag to prevent multiple triggers

	# Check if the barrage toggle is active
	if GlobalManager.barrage_toggle_active:
		display_hover_tiles()  # Display hover tiles if the toggle is active
	elif not GlobalManager.barrage_toggle_active:
		clear_hover_tiles()  # Clear hover tiles if the toggle is turned off
					
	is_mouse_over_gui()

func display_hover_tiles():
	# Ensure hover_tile exists and a player is selected
	if not hover_tile or not hover_tile.selected_player:
		print("No selected player or hover tile.")
		return

	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var hovertile_nodes = get_tree().get_nodes_in_group("hovertile")  # Get all nodes in the "hovertile" group

	# Define relative positions for the 8 surrounding tiles + the center tile
	var relative_positions = [
		Vector2i(0, 0),   # Center
		Vector2i(-1, 0),  # Left
		Vector2i(1, 0),   # Right
		Vector2i(0, -1),  # Up
		Vector2i(0, 1),   # Down
		Vector2i(-1, -1), # Top-left
		Vector2i(1, -1),  # Top-right
		Vector2i(-1, 1),  # Bottom-left
		Vector2i(1, 1)    # Bottom-right
	]

	# Clear any existing hover tiles before placing new ones
	clear_hover_tiles()

	# Generate hover tiles at the relevant positions
	for hovertile in hovertile_nodes:
		if hovertile:
			# Get the hovertile's tile position only once
			var hovertile_tile_pos = hovertile.tile_pos
			print("Processing hovertile at position: ", hovertile_tile_pos)

			for offset in relative_positions:
				var target_tile_pos = hovertile_tile_pos + offset
				var target_world_pos = tilemap.map_to_local(target_tile_pos)

				print("Creating hover tile at: ", target_world_pos)

				# Ensure hover_tile_scene is assigned
				if hover_tile_scene == null:
					print("Error: hover_tile_scene is not assigned!")
					return

				var hover_tile_instance = hover_tile_scene.instantiate() as Node2D
				hover_tile_instance.position = target_world_pos
				tilemap.add_child(hover_tile_instance)
				hover_tiles.append(hover_tile_instance)  # Keep track of the hover tile

	print("Hover tiles displayed: ", hover_tiles.size())

func clear_hover_tiles():
	# Remove all hover tiles
	for hover_tile_instance in hover_tiles:
		if hover_tile_instance:
			hover_tile_instance.queue_free()
	hover_tiles.clear()
	
func _input(event):
	# Check for mouse click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Block gameplay input if the mouse is over GUI
		if is_mouse_over_gui():
			print("Input blocked by GUI.")
			return  # Prevent further input handling

		# Reference the TileMap node
		var tilemap: TileMap = get_node("/root/MapManager/TileMap")

		# Get the boundaries of the map's used rectangle
		var map_size = tilemap.get_used_rect()  # Rect2: position and size of the used tiles
		var map_origin_x = map_size.position.x  # Starting x-coordinate of the used rectangle
		var map_origin_y = map_size.position.y  # Starting y-coordinate of the used rectangle
		var map_width = map_size.size.x         # Width of the map in tiles
		var map_height = map_size.size.y        # Height of the map in tiles

		var global_mouse_position = get_global_mouse_position() 
		global_mouse_position.y += 8
			
		# Convert the global mouse position to tile coordinates
		var mouse_local = tilemap.local_to_map(global_mouse_position)

		# Check if the mouse is outside the bounds of the used rectangle
		if mouse_local.x < map_origin_x or mouse_local.x >= map_origin_x + map_width or \
		   mouse_local.y < map_origin_y or mouse_local.y >= map_origin_y + map_height:
			return  # Exit the function if the mouse is outside the map

		# Check if mouse_local matches the local_to_map position of any special tile
		var position_matches_tile = false

		for special_tile in get_parent().special_tiles:
			# Assuming each special_tile has a position in world coordinates
			if special_tile is Node2D:
				var tile_map_position = tilemap.local_to_map(special_tile.position)  # Convert to map coordinates
				if mouse_local == tile_map_position:
					position_matches_tile = true
					break
					
		if position_matches_tile:													
			# Ensure hover_tile exists and "Sarah Reese" is selected
			if hover_tile and hover_tile.selected_player and hover_tile.selected_player.player_name == "Angel. Charlie" and GlobalManager.barrage_toggle_active == true:
				#var tilemap: TileMap = get_node("/root/MapManager/TileMap")
				var mouse_position = get_global_mouse_position() 
				mouse_position.y += 8
				var mouse_pos = tilemap.local_to_map(mouse_position)
				var mouse_on_tile = tilemap.map_to_local(mouse_pos)
				get_parent().clear_special_tiles()				
				activate_ability(mouse_on_tile)

# Check if there is a unit on the tile
func is_unit_present(tile_pos: Vector2i) -> bool:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var all_units = get_tree().get_nodes_in_group("zombies") + get_tree().get_nodes_in_group("unitAI")
	for unit in all_units:
		var unit_tile_pos = tilemap.local_to_map(unit.global_position)
		if tile_pos == unit_tile_pos:
			return true
	return false
	
func activate_ability(mouse_on_tile: Vector2):
	if is_on_cooldown or is_firing:
		return # Exit if already firing or on cooldown

	is_firing = true
	firing_time = duration
	barrage_completed = false  # Reset the flag
	
	emit_signal("ability_used")
	start_firing(mouse_on_tile)

	# Start cooldown after firing completes
	await get_tree().create_timer(duration).timeout
	is_firing = false
	is_on_cooldown = true

	await get_tree().create_timer(duration).timeout
	is_on_cooldown = false

	# Mark the barrage as completed
	barrage_completed = true

	print("Barrage completed.")
	
func start_firing(mouse_on_tile: Vector2):
	# Fire the barrage once
	fire_bullets_at_tile_and_surroundings(mouse_on_tile)
	
	# Start cooldown after firing
	is_firing = false
	is_on_cooldown = true
	await get_tree().create_timer(cooldown_time).timeout
	is_on_cooldown = false

	var hud_manager = get_parent().get_parent().get_parent().get_node("HUDManager")  # Adjust the path if necessary
	hud_manager.hide_special_buttons()	
	
	# Access the 'special' button within HUDManager
	GlobalManager.barrage_toggle_active = false  # Deactivate the special toggle
	hud_manager.barrage.button_pressed = false
	self.get_parent().has_attacked = true
	self.get_parent().has_moved = true	
	
func fire_bullets_at_tile_and_surroundings(mouse_on_tile: Vector2):
	# Get the TileMap node
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")

	var global_mouse_position = get_global_mouse_position()
	global_mouse_position.y += 8

	if get_parent().is_in_group("unitAI"):
		center_tile_pos = tilemap.local_to_map(mouse_on_tile)
	else:
		# Get the center tile position in tilemap coordinates
		center_tile_pos = tilemap.local_to_map(global_mouse_position)

	# Define relative positions for the 8 surrounding tiles + the center tile
	var relative_positions = [
		Vector2i(0, 0),   # Center
		Vector2i(-1, 0),  # Left
		Vector2i(1, 0),   # Right
		Vector2i(0, -1),  # Up
		Vector2i(0, 1),   # Down
		Vector2i(-1, -1), # Top-left
		Vector2i(1, -1),  # Top-right
		Vector2i(-1, 1),  # Bottom-left
		Vector2i(1, 1)    # Bottom-right
	]

	# Fire at each surrounding tile
	for offset in relative_positions:
		var target_tile_pos = center_tile_pos + offset
		var target_world_pos = tilemap.map_to_local(target_tile_pos)

		# Calculate direction to the target tile
		var direction_to_tile = (target_world_pos - global_position).normalized()

		# Get the current facing direction of the parent (1 for right, -1 for left)
		var current_facing = 1 if get_parent().scale.x > 0 else -1

		# Determine sprite flip based on target_position relative to the parent
		if mouse_on_tile.x > global_position.x and current_facing == 1:
			get_parent().scale.x = -abs(get_parent().scale.x)  # Flip to face left
		elif mouse_on_tile.x < global_position.x and current_facing == -1:
			get_parent().scale.x = abs(get_parent().scale.x)  # Flip to face right
			
		play_attack_animation()	
		
		# Spawn a projectile aimed at the tile
		spawn_projectile(global_position, direction_to_tile, target_world_pos)
		
		# Optional delay between shots for visual effect
		await get_tree().create_timer(0.1).timeout

func play_attack_animation():
	for i in 9:
		get_parent().get_child(0).play("attack")
		await get_tree().create_timer(0.5)
		
func spawn_projectile(start_position: Vector2, direction: Vector2, target: Vector2):
	if projectile_scene == null:
		print("Error: Projectile scene is not assigned!")
		return

	# Get the TileMap node
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")

	# Snap mouse position to tile center
	var mouse_tile_pos = tilemap.local_to_map(target)
	var snapped_target_position = tilemap.map_to_local(mouse_tile_pos)

	# Calculate the ability range dynamically
	var ability_range = start_position.distance_to(snapped_target_position)

	# Instantiate and configure the projectile
	var projectile_instance = projectile_scene.instantiate() as Node2D
	projectile_instance.position = start_position
	projectile_instance.direction = direction.normalized()  # Set the direction vector
	projectile_instance.range = ability_range  # Pass the calculated range
	projectile_instance.speed = 200.0  # Adjust if needed
	projectile_instance.attacker = self.get_parent()  # Set the firing unit as the attacker
	
	# Add projectile to the scene
	tilemap.add_child(projectile_instance)

func is_mouse_over_gui() -> bool:
	# Get global mouse position
	var mouse_pos = get_viewport().get_mouse_position()

	# Get all nodes in the "hud_controls" group
	var hud_controls = get_tree().get_nodes_in_group("portrait_controls") + get_tree().get_nodes_in_group("hud_controls")
	for control in hud_controls:
		if control is TextureRect or Button and control.is_visible_in_tree():
			# Use global rect to check if mouse is over the button
			var rect = control.get_global_rect()
			#print("Checking button:", control.name, "Rect:", rect, "Mouse Pos:", mouse_pos)
			if rect.has_point(mouse_pos):
				#print("Mouse is over button:", control.name, "Rect:", rect, "Mouse Pos:", mouse_pos)
				clear_hover_tiles()
				return true
	#print("Mouse is NOT over any button.")
	return false

func execute_angel_charlie_ai_turn() -> void:
	# Randomly decide which branch to execute:
	# 0 = standard AI turn, 1 = special missile attack.
	var choice = randi() % 2

	if get_parent().has_moved:
		choice = 1
			
	if choice == 0:
		print("Random choice: Executing standard AI turn for Angel Charlie.")
		await get_parent().execute_ai_turn()
		return
	else:
		# Only perform the special attack if this unit hasn't attacked yet.
		if not get_parent().has_attacked:
			print("Random choice: Executing Angel Charlie special missile attack.")
			
			# Focus the camera on the current position.
			var tilemap: TileMap = get_node("/root/MapManager/TileMap")
			var camera: Camera2D = get_node("/root/MapManager/Camera2D")
			if camera:
				camera.focus_on_position(tilemap.map_to_local(get_parent().tile_pos))
			
			await get_parent().display_special_attack_tiles()
			
			# Get the set of valid attack range tiles from the parent.
			var attack_tiles: Array[Vector2i] = get_parent().get_special_tiles()
			
			# Find the closest valid target whose tile (as derived from world position) is in the special attack range.
			var target = find_closest_target_in_range(attack_tiles)
			if target:
				# Convert the enemy's tile coordinate back to world space if needed.
				var target_world_pos = tilemap.map_to_local(target.tile_pos)
				await activate_ability(target_world_pos)
			else:
				print("No valid target found for Angel Charlie special attack.")
				get_parent().execute_ai_turn()

func find_closest_target_in_range(valid_range: Array[Vector2i]) -> Node:
	# Get the TileMap for converting positions.
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	
	# Find the AI-controlled player (attacker) for reference.
	var ai_player = null
	for player in get_tree().get_nodes_in_group("player_units"):
		if player.is_in_group("unitAI") and player.player_name == "Angel. Charlie":
			ai_player = player
			# (Optional) Show special attack tiles for debugging.
			ai_player.display_special_attack_tiles()			
			break
			
	if ai_player == null:
		print("Angel. Charlie not found.")
		return null

	# Build a unique list of potential enemy targets from both groups.
	var enemies = []
	for group in ["zombies", "player_units"]:
		for enemy in get_tree().get_nodes_in_group(group):
			# Exclude the attacker itself.
			if enemy == ai_player:
				continue
			# Exclude any enemy that is a unitAI and dead.
			if enemy.is_in_group("unitAI"):
				continue
			# Add the enemy if not already in the list.
			if enemy not in enemies:
				enemies.append(enemy)
				
	# Filter enemies to only those whose tile (converted from world position) is in the provided valid_range.
	var candidates = []
	for enemy in enemies:
		# Convert enemy's world position to tile coordinates.
		var enemy_tile: Vector2i = tilemap.local_to_map(enemy.position)
		if enemy_tile in valid_range:
			candidates.append(enemy)
	
	if candidates.size() == 0:
		print("No enemy within valid range.")
		return null
	
	# Find the candidate with the minimum Manhattan distance.
	var target_enemy = null
	var min_distance = INF
	# Convert AI player's position to tile coordinates.
	var ai_tile: Vector2i = tilemap.local_to_map(ai_player.position)
	for enemy in candidates:
		var enemy_tile: Vector2i = tilemap.local_to_map(enemy.position)
		var dx = abs(ai_tile.x - enemy_tile.x)
		var dy = abs(ai_tile.y - enemy_tile.y)
		var d = dx + dy  # Manhattan distance.
		if d < min_distance:
			min_distance = d
			target_enemy = enemy

	if target_enemy == null:
		print("No target enemy found within valid range.")
		return null

	get_parent().clear_special_tiles()
	
	return target_enemy
