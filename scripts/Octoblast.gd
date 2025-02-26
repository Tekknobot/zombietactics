extends Node2D

@export var hover_tile_path: NodePath = "/root/MapManager/HoverTile"
@onready var hover_tile = get_node_or_null(hover_tile_path)

# Exported variables for customization in the editor
@export var attack_damage: int = 25 # Damage per explosion
@export var explosion_radius: float = 1.5 # Radius of each explosion effect
@export var explosion_delay: float = 0.2 # Delay between explosions
@export var explosion_effect_scene: PackedScene # Path to explosion effect scene
@onready var missile_manager = get_node("/root/MapManager/MissileManager")  # Reference to the SpecialToggleNode

func _process(delta):
	is_mouse_over_gui()
	
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
			if hover_tile and hover_tile.selected_player and hover_tile.selected_player.player_name == "Annie. Switch" and GlobalManager.octoblast_toggle_active == true:
				get_parent().clear_special_tiles()	
				activate_ability(global_mouse_position)

# Check if there is a unit on the tile
func is_unit_present(tile_pos: Vector2i) -> bool:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var all_units = get_tree().get_nodes_in_group("zombies") + get_tree().get_nodes_in_group("unitAI")
	for unit in all_units:
		var unit_tile_pos = tilemap.local_to_map(unit.global_position)
		if tile_pos == unit_tile_pos:
			return true
	return false
				
func trigger_octoblast(target: Vector2):
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	
	var mouse_position = get_global_mouse_position() 
	mouse_position.y += 8
	var mouse_pos = tilemap.local_to_map(mouse_position)
		
	# Get the current position in tile coordinates
	var current_position = mouse_pos

	# Get the current facing direction of the parent (1 for right, -1 for left)
	var current_facing = 1 if get_parent().scale.x > 0 else -1

	# Determine sprite flip based on target_position relative to the parent
	if get_global_mouse_position().x > global_position.x and current_facing == 1:
		get_parent().scale.x = -abs(get_parent().scale.x)  # Flip to face left
	elif get_global_mouse_position().x < global_position.x and current_facing == -1:
		get_parent().scale.x = abs(get_parent().scale.x)  # Flip to face right
		
	# Trigger trajectory to the initial position
	missile_manager.start_trajectory(mouse_position, get_parent().position)
	
	if get_parent().is_in_group("unitAI"):
		var zombies = get_zombies_on_map_ai()
		var zombie_positions = []
		for zombie in zombies:
			zombie_positions.append(zombie.global_position)

		# Sort zombies by distance from the trigger location
		zombie_positions.sort_custom(func(a, b):
			return mouse_position.distance_to(a) < mouse_position.distance_to(b))

		# Select the 7 closest zombies
		var closest_zombies = zombie_positions.slice(0, min(7, zombie_positions.size()))

		# Trigger trajectories towards the closest zombies sequentially
		for zombie_pos in closest_zombies:
			get_parent().get_child(0).play("attack")		
			await get_tree().create_timer(0.3).timeout
			missile_manager.start_trajectory(zombie_pos, get_parent().position)
	else:
		# Get all zombie positions
		var zombies = get_zombies_on_map()  # Custom function to fetch all zombies on the map
		var zombie_positions = []
		for zombie in zombies:
			zombie_positions.append(zombie.global_position)

		# Sort zombies by distance from the trigger location
		zombie_positions.sort_custom(func(a, b):
			return mouse_position.distance_to(a) < mouse_position.distance_to(b))

		# Select the 7 closest zombies
		var closest_zombies = zombie_positions.slice(0, min(7, zombie_positions.size()))

		# Trigger trajectories towards the closest zombies sequentially
		for zombie_pos in closest_zombies:
			get_parent().get_child(0).play("attack")		
			await get_tree().create_timer(0.3).timeout
			missile_manager.start_trajectory(zombie_pos, get_parent().position)

	var hud_manager = get_parent().get_parent().get_parent().get_node("HUDManager")  # Adjust the path if necessary
	hud_manager.hide_special_buttons()	
	
	get_parent().current_xp += 25
	if get_parent().current_xp >= get_parent().xp_for_next_level:
		get_parent().level_up()	
		
	get_parent().has_attacked = true
	get_parent().has_moved = true
	GlobalManager.octoblast_toggle_active = false
	#await get_tree().create_timer(4).timeout
	
	get_parent().get_child(0).play("default")
	get_parent().check_end_turn_conditions()
	
# Helper function to get all zombies on the map
func get_zombies_on_map() -> Array:
	var zombies = []
	var all_entities = get_node("/root/MapManager/UnitSpawn").get_children()  # Adjust the path to your EntityManager
	for entity in all_entities:
		if entity.is_in_group("zombies") or entity.is_in_group("unitAI"):  # Check if the entity is a zombie
			zombies.append(entity)
	return zombies	

func get_zombies_on_map_ai() -> Array:
	var zombies = []
	var all_entities = get_node("/root/MapManager/UnitSpawn").get_children()  # Adjust path as needed.
	for entity in all_entities:
		# If entity is in "zombies", add it.
		if entity.is_in_group("zombies"):
			zombies.append(entity)
		# If entity is in "player_units" but not in "unitAI", add it.
		elif entity.is_in_group("player_units") and not entity.is_in_group("unitAI"):
			zombies.append(entity)
	return zombies


# Deal damage to units within the area of effect
func damage_units_in_area(center_position):
	# Find units in the area (adapt to your collision system)
	var units = get_tree().get_nodes_in_group("zombies") + get_tree().get_nodes_in_group("player_units") + get_tree().get_nodes_in_group("structures") + get_tree().get_nodes_in_group("unitAI")
	for unit in units:
		if unit.global_position.distance_to(center_position) <= explosion_radius:
			if unit.has_method("apply_damage"):
				unit.flash_damage()
				unit.apply_damage(get_parent().attack_damage)
			elif unit.structure_type == "Building" or unit.structure_type == "Tower" or unit.structure_type == "District" or unit.structure_type == "Stadium":
				unit.is_demolished = true
				unit.get_child(0).play("demolished")
				
# Optional: Call this method to activate Hellfire from external scripts
func activate_ability(target: Vector2):
	trigger_octoblast(target)

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
				return true
	#print("Mouse is NOT over any button.")
	return false

func execute_annie_switch_ai_turn() -> void:
	# Randomly decide which branch to execute: 0 = standard AI turn, 1 = special missile attack.
	var choice = 1 #randi() % 2
	if choice == 0:
		print("Random choice: Executing standard AI turn for Logan Raines.")
		await get_parent().execute_ai_turn()
	else:
		# Only perform the special attack if the unit hasn't attacked yet.
		if not get_parent().has_attacked:
			print("Executing Annie Switch Octoblast special attack.")
			
			# Focus the camera on the unit's current position.
			var tilemap: TileMap = get_node("/root/MapManager/TileMap")
			var camera: Camera2D = get_node("/root/MapManager/Camera2D")
			if camera:
				camera.focus_on_position(tilemap.map_to_local(get_parent().tile_pos))
			
			# Optionally display special attack range tiles for visual feedback.
			get_parent().display_special_attack_tiles()
			
			# Clear the special attack tiles (if needed) before triggering octoblast.
			get_parent().clear_special_tiles()
			
			var target = find_closest_target()
			
			# Execute the octoblast ability.
			trigger_octoblast(target.position)
			
			# Optionally wait a moment for effects to finish.
			await get_tree().create_timer(explosion_delay).timeout
			
			# Mark the turn as complete.
			get_parent().has_attacked = true
			get_parent().has_moved = true
			get_parent().check_end_turn_conditions()

# Helper function to find the closest target (zombie or player unit) that isn't in the "unitAI" group.
func find_closest_target() -> Node:
	# Find Dutch. Major among the player_units that are AI-controlled.
	var ai_player = null
	for player in get_tree().get_nodes_in_group("player_units"):
		if player.is_in_group("unitAI") and player.player_name == "Annie. Switch":
			ai_player = player
			# Optionally display the special attack tiles for feedback.
			ai_player.display_special_attack_tiles()
			break
			
	if ai_player == null:
		print("Angel. Charlie not found.")
		return null

	# Optionally, use the valid_range parameter. Here we'll override it with the attack range
	# defined by Dutch. Major's method.
	var attack_tiles: Array[Vector2i] = ai_player.get_special_tiles()

	# Gather enemies from both groups.
	var enemies = get_tree().get_nodes_in_group("zombies") + get_tree().get_nodes_in_group("player_units")
	
	# Filter out any nodes that are AI-controlled.
	var valid_enemies = []
	for enemy in enemies:
		if not enemy.is_in_group("unitAI"):
			valid_enemies.append(enemy)
	
	# From valid enemies, pick only those whose tile positions are in the attack range.
	var candidates = []
	for enemy in valid_enemies:
		# Assume each enemy has a 'tile_pos' property.
		if enemy.tile_pos in attack_tiles:
			candidates.append(enemy)
	
	if candidates.size() == 0:
		print("No enemy within special attack range.")
		return null
	
	# Find the candidate with the minimum Manhattan distance.
	var target_enemy = null
	var min_distance = INF
	for enemy in candidates:
		var dx = abs(ai_player.tile_pos.x - enemy.tile_pos.x)
		var dy = abs(ai_player.tile_pos.y - enemy.tile_pos.y)
		var d = dx + dy  # Manhattan distance calculation.
		if d < min_distance:
			min_distance = d
			target_enemy = enemy

	if target_enemy == null:
		print("No target enemy found within special attack tiles.")
		return null

	return target_enemy
