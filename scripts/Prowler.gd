extends Node2D

# Configuration variables
var max_targets = 8 # Maximum number of zombies to attack
var attack_damage = 50 # Damage dealt per attack
var dash_distance = 2 # Distance to dash in tiles
var fade_duration = 0.2 # Duration for fade out and in
var cooldown = 3.0 # Cooldown for the ability

var targeted_zombies = [] # List of zombies to attack
var attack_index = 0 # Tracks which zombie is currently being attacked
var is_prowler_active = false
var attacked_zombies = []  # List to track already attacked zombies

@export var hover_tile_path: NodePath = "/root/MapManager/HoverTile"
@onready var hover_tile = get_node_or_null(hover_tile_path)

var WATER_TILE_ID = 0
@onready var map_manager = get_parent().get_node("/root/MapManager")

signal turn_completed
var shadow_step_complete

func _ready() -> void:
	var err = get_parent().connect("turn_completed", Callable(self, "_on_turn_completed"))
	if err != OK:
		push_error("Failed to connect to 'turn_completed' signal: Error code %d" % err)
	
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
		WATER_TILE_ID = 0

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
					
		if position_matches_tile and is_unit_present(mouse_local):									
			# Ensure hover_tile exists and "Sarah Reese" is selected
			if hover_tile and hover_tile.selected_player and hover_tile.selected_player.player_name == "Aleks. Ducat" and GlobalManager.prowler_toggle_active == true:
				var target_zombie = get_zombie_at_tile(mouse_local)
				if target_zombie:
					var hud_manager = get_parent().get_parent().get_parent().get_node("HUDManager")  # Adjust the path if necessary
					hud_manager.hide_special_buttons()	
					get_parent().clear_special_tiles()
					if get_parent().is_in_group("unitAI"):
						pass
					else:						
						activate_prowler(target_zombie)

func activate_prowler(target_zombie):
	# Reset variables for this ability use
	targeted_zombies.clear()
	attack_index = 0
	is_prowler_active = true

	if get_parent().is_in_group("unitAI"):
		# Find nearby zombies (excluding the clicked zombie)
		var nearby_zombies = find_nearest_zombies(max_targets - 1)
		targeted_zombies.append_array(nearby_zombies)
	else:
		# Find nearby zombies (excluding the clicked zombie)
		var nearby_zombies = find_nearest_zombies_ai(max_targets - 1)
		targeted_zombies.append_array(nearby_zombies)			

	if targeted_zombies.is_empty():
		print("No zombies found for Prowler Step.")
		is_prowler_active = false
		return

	await get_tree().create_timer(0.1).timeout
	# Start the attack sequence
	attack_next_zombie()

func find_nearest_zombies(max_count: int) -> Array:
	var zombies_in_range = []
	var zombies = get_tree().get_nodes_in_group("zombies")
	var player_units = get_tree().get_nodes_in_group("player_units")
	for unit in player_units:
		if not unit.is_in_group("unitAI"):
			zombies.append(unit)
	var current_position = get_parent().tile_pos

	# Manual bubble sort based on distance to `current_position`
	for i in range(zombies.size()):
		for j in range(0, zombies.size() - i - 1):
			var dist_a = current_position.distance_to(zombies[j].tile_pos)
			var dist_b = current_position.distance_to(zombies[j + 1].tile_pos)
			if dist_a > dist_b:
				# Swap the zombies
				var temp = zombies[j]
				zombies[j] = zombies[j + 1]
				zombies[j + 1] = temp

	# Collect the nearest zombies up to max_count
	for zombie in zombies:
		zombies_in_range.append(zombie)
		if zombies_in_range.size() >= max_count:
			break

	return zombies_in_range

func find_nearest_zombies_ai(max_count: int) -> Array:
	var zombies_in_range = []
	var zombies = get_tree().get_nodes_in_group("zombies") + get_tree().get_nodes_in_group("unitAI")
	var current_position = get_parent().tile_pos

	# Manual bubble sort based on distance to `current_position`
	for i in range(zombies.size()):
		for j in range(0, zombies.size() - i - 1):
			var dist_a = current_position.distance_to(zombies[j].tile_pos)
			var dist_b = current_position.distance_to(zombies[j + 1].tile_pos)
			if dist_a > dist_b:
				# Swap the zombies
				var temp = zombies[j]
				zombies[j] = zombies[j + 1]
				zombies[j + 1] = temp

	# Collect the nearest zombies up to max_count
	for zombie in zombies:
		zombies_in_range.append(zombie)
		if zombies_in_range.size() >= max_count:
			break

	return zombies_in_range

func attack_next_zombie():
	if attack_index >= targeted_zombies.size():
		is_prowler_active = false	
		GlobalManager.prowler_toggle_active = false
		
		get_parent().current_xp += 25
		# Optional: Check for level up, if applicable
		if get_parent().current_xp >= get_parent().xp_for_next_level:
			get_parent().level_up()	
			
		get_parent().has_attacked = true
		get_parent().has_moved = true	
		get_parent().check_end_turn_conditions()	
		
		_on_turn_completed()	
						
		return
	
	var target = targeted_zombies[attack_index]
	if not target or not target.is_inside_tree() or target in attacked_zombies:
		attack_index += 1
		attack_next_zombie()
		return
	
	targeted_zombies[attack_index] = target
	await get_tree().create_timer(0.2).timeout
	
	#Play SFX
	get_parent().get_child(9).stream = get_parent().claw_audio
	get_parent().get_child(9).play()	
	
	perform_prowler_step(target)

func perform_prowler_step(target):
	await fade_out(get_parent())
	teleport_to_adjacent_tile(target)
	await fade_in(get_parent())
	
	await get_tree().create_timer(0.1).timeout
	dash_forward(target)
	await get_tree().create_timer(0.2).timeout	
	attack_target(target)
	attack_index += 1
	attack_next_zombie()

func attack_target(target):
	update_facing_direction(target.position)
	
	# Play attack animation
	get_parent().get_child(0).play("attack")
	
	if target and target.is_inside_tree():
		# Wait for the attack animation to finish before applying damage
		await get_tree().create_timer(0.5).timeout

		# Play SFX
		#target.audio_player.stream = target.zombie_audio
		#target.audio_player.play()
				
		#target.apply_damage(get_parent().attack_damage)
		#target.flash_damage()
		
		attacked_zombies.append(target)
		print("Attacked zombie at tile:", target.tile_pos)

func update_facing_direction(target_pos: Vector2):
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")

	# Convert the target position to map coordinates, then back to world coordinates
	var target_world_pos = target_pos

	# Calculate the direction to the target position
	var direction = (target_world_pos - get_parent().position).normalized()

	# Determine the direction of movement based on target and current position
	if direction.x > 0:
		get_parent().scale.x = -1  # Facing right (East)
	elif direction.x < 0:
		get_parent().scale.x = 1  # Facing left (West)
  
func teleport_to_adjacent_tile(target):
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var target_position = target.tile_pos

	# Directions to check: 4 orthogonal + 4 diagonal directions
	var directions = [
		Vector2i(0, -1),   # Up
		Vector2i(0, 1),    # Down
		Vector2i(-1, 0),   # Left
		Vector2i(1, 0),    # Right
	]

	# Loop through the directions and check for a valid tile
	for direction in directions:
		var adjacent_tile = target_position + direction
		if is_tile_movable(adjacent_tile):
			var world_pos = tilemap.map_to_local(adjacent_tile)
			print("Teleporting to:", adjacent_tile)  # Debugging info
			get_parent().position = world_pos
			return  # Exit after teleporting

	print("No valid adjacent tile found for teleportation.")

func dash_forward(target):
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	
	update_facing_direction(target.position)
	await get_tree().create_timer(0.2).timeout
	
	# Get player and target positions in tile coordinates
	var player_tile = tilemap.local_to_map(get_parent().position)
	var target_tile = tilemap.local_to_map(target.global_position)
	
	# Calculate direction to target
	var direction = (target_tile - player_tile).sign()  # Normalize to -1, 0, or 1 (Vector2i)
	
	# Calculate the intended dash position 3 tiles ahead in the direction of the target
	var dash_target_tile = player_tile + direction * dash_distance
			
	target.apply_damage(get_parent().attack_damage)
	target.flash_damage()
		
	# Check if the target tile is movable
	if is_tile_movable(dash_target_tile):
		var world_pos = tilemap.map_to_local(dash_target_tile)
		get_parent().position = world_pos
		print("Dashed to tile:", dash_target_tile)
	else:
		print("Cannot dash: Target tile is not movable.")
		return

func fade_out(sprite: Node, duration: float = fade_duration) -> void:
	"""
	Fades the sprite out over the specified duration.
	:param sprite: The sprite to fade out.
	:param duration: The time it takes to fade out.
	"""
	if not sprite:
		print("Error: Sprite is null!")
		return

	# If the sprite is already faded out, do nothing
	if sprite.modulate.a <= 0.0:
		return

	# Create a new tween for the fade-out animation
	var tween = create_tween()

	#Play SFX
	get_parent().get_child(2).stream = get_parent().invisibility_audio
	get_parent().get_child(2).play()

	# Tween the alpha value of the sprite's modulate property to 0
	tween.tween_property(sprite, "modulate:a", 1, duration)

	# Wait for the tween to finish
	await tween.finished

func fade_in(sprite: Node, duration: float = fade_duration) -> void:
	"""
	Fades the sprite in over the specified duration.
	:param sprite: The sprite to fade in.
	:param duration: The time it takes to fade in.
	"""
	if not sprite:
		print("Error: Sprite is null!")
		return

	# Camera focuses on the active zombie
	var camera: Camera2D = get_node("/root/MapManager/Camera2D")
	camera.focus_on_position(get_parent().position)
	
	# If the sprite is already fully visible, do nothing
	if sprite.modulate.a >= 1:
		return

	# Create a new tween for the fade-in animation
	var tween = create_tween()

	#Play SFX
	get_parent().get_child(2).stream = get_parent().invisibility_audio
	get_parent().get_child(2).play()

	# Tween the alpha value of the sprite's modulate property to 1
	tween.tween_property(sprite, "modulate:a", 0, duration)

	# Wait for the tween to finish
	await tween.finished


func is_mouse_over_gui() -> bool:
	var mouse_pos = get_viewport().get_mouse_position()
	var hud_controls = get_tree().get_nodes_in_group("hud_controls")
	for control in hud_controls:
		if control.is_visible_in_tree() and control.get_global_rect().has_point(mouse_pos):
			return true
	return false

# Check if a tile is movable
func is_tile_movable(tile_pos: Vector2i) -> bool:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var tile_id = tilemap.get_cell_source_id(0, tile_pos)
	if is_water_tile(tile_id):
		return false
	if is_structure(tile_pos) or is_unit_present(tile_pos) or !is_blank_tile(tile_pos):
		return false
	return true

# Checks if a tile is spawnable (not water)
func is_blank_tile(tile_pos: Vector2i) -> bool:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var tile_id = tilemap.get_cell_source_id(0, tile_pos)
	return tile_id != -1

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
	var all_units = get_tree().get_nodes_in_group("zombies") + get_tree().get_nodes_in_group("unitAI") + get_tree().get_nodes_in_group("player_units") 
	for unit in all_units:
		if get_parent().dead == true:
			return false
		var unit_tile_pos = tilemap.local_to_map(unit.global_position)
		if tile_pos == unit_tile_pos:
			return true
	return false

# Check if there is a unit on the tile
func is_zombie_present(tile_pos: Vector2i) -> bool:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var all_units = get_tree().get_nodes_in_group("zombies") + get_tree().get_nodes_in_group("unitAI")
	for unit in all_units:
		if get_parent().dead == true:
			return false		
		var unit_tile_pos = tilemap.local_to_map(unit.global_position)
		if tile_pos == unit_tile_pos:
			return true
	return false

func get_zombie_at_tile(tile_pos: Vector2i):
	var zombies = get_tree().get_nodes_in_group("zombies") + get_tree().get_nodes_in_group("unitAI")
	for zombie in zombies:
		if zombie.tile_pos == tile_pos:
			return zombie
	return null
	
func execute_aleks_ducat_ai_turn() -> void:	
	# Randomly decide which branch to execute: 0 = standard AI turn, 1 = special missile attack.
	var choice = randi() % 2

	if get_parent().has_moved:
		choice = 1
			
	if choice == 0:
		print("Random choice: Executing standard AI turn for Logan Raines.")
		await get_parent().execute_ai_turn()
	else:
		# If standard AI hasn't resulted in an attack…
		if not get_parent().has_attacked:
			print("Random choice: Executing Logan Raines special missile attack.")
			# Get the missile manager by its node path.
			var missile_manager = get_node("/root/MapManager/MissileManager")
			
			# Focus the camera on the current position.
			var tilemap: TileMap = get_node("/root/MapManager/TileMap")
			var camera: Camera2D = get_node("/root/MapManager/Camera2D")
			if camera:
				camera.focus_on_position(tilemap.map_to_local(get_parent().tile_pos))
			
			# Find the closest target (zombie or player unit not in unitAI)
			var target = find_closest_target()
			if target:
				# Execute the special missile attack via the missile manager.
				await activate_prowler(target)
			else:
				print("No valid target found for Logan Raines special attack.")
				get_parent().execute_ai_turn()

func find_closest_target() -> Node:
	var candidates = get_tree().get_nodes_in_group("zombies") + get_tree().get_nodes_in_group("player_units")
	var target = null
	var min_distance = INF
	var parent_pos = get_parent().position  # Using parent's position as reference
	for candidate in candidates:
		# Skip self
		if candidate == get_parent():
			continue
		# Skip units in the "unitAI" group
		if candidate.is_in_group("unitAI"):
			continue
		var d = parent_pos.distance_to(candidate.position)
		if d < min_distance:
			min_distance = d
			target = candidate
	return target


func _on_turn_completed():
	print("Turn has completed!")
	emit_signal("turn_completed")
	
