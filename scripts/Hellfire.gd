extends Node2D

@export var hover_tile_path: NodePath = "/root/MapManager/HoverTile"
@onready var hover_tile = get_node_or_null(hover_tile_path)

# Exported variables for customization in the editor
@export var attack_damage: int = 50 # Damage per explosion
@export var explosion_radius: float = 1.5 # Radius of each explosion effect
@export var explosion_delay: float = 0.2 # Delay between explosions
@export var explosion_effect_scene: PackedScene # Path to explosion effect scene
@onready var missile_manager = get_node("/root/MapManager/MissileManager")  # Reference to the SpecialToggleNode

@export var hover_tile_scene: PackedScene
# Variables to track state
var hover_tiles_visible = false  # Whether hover tiles are currently displayed
var hover_tiles = []  # Store references to dynamically created hover tiles

var hellfire_target

func _process(delta):
	# Check if the barrage toggle is active
	if GlobalManager.hellfire_toggle_active:
		display_hover_tiles()  # Display hover tiles if the toggle is active
	elif not GlobalManager.hellfire_toggle_active:
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
			if hover_tile and hover_tile.selected_player and hover_tile.selected_player.player_name == "John. Doom" and 	GlobalManager.hellfire_toggle_active == true:
				activate_ability(global_mouse_position)
				get_parent().clear_special_tiles()	
				await get_tree().create_timer(0.01).timeout
				GlobalManager.hellfire_toggle_active = false

# Check if there is a unit on the tile
func is_unit_present(tile_pos: Vector2i) -> bool:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var all_units = get_tree().get_nodes_in_group("zombies") + get_tree().get_nodes_in_group("unitAI")
	for unit in all_units:
		var unit_tile_pos = tilemap.local_to_map(unit.global_position)
		if tile_pos == unit_tile_pos:
			return true
	return false
			
# Trigger Hellfire ability
func trigger_hellfire(target: Vector2):
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	
	var mouse_position = get_global_mouse_position() 
	mouse_position.y += 8
	var mouse_pos = tilemap.local_to_map(mouse_position)
	
	if get_parent().is_in_group("unitAI"):
		var target_pos = tilemap.local_to_map(target)
		var current_position = target_pos
		hellfire_target = current_position
	else:	
		# Get the current position in tile coordinates
		var current_position = mouse_pos
		hellfire_target = current_position

	# Get the current facing direction of the parent (1 for right, -1 for left)
	var current_facing = 1 if get_parent().scale.x > 0 else -1

	# Determine sprite flip based on target_position relative to the parent
	if get_global_mouse_position().x > global_position.x and current_facing == 1:
		get_parent().scale.x = -abs(get_parent().scale.x)  # Flip to face left
	elif get_global_mouse_position().x < global_position.x and current_facing == -1:
		get_parent().scale.x = abs(get_parent().scale.x)  # Flip to face right

	get_parent().get_child(0).play("attack")

	if get_parent().is_in_group("unitAI"):
		await missile_manager.start_trajectory(target, get_parent().position)
	else:	
		await missile_manager.start_trajectory(mouse_position, get_parent().position)

	# Define offsets for the 8 surrounding tiles (including the center tile)
	var offsets = [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(-1,  0), Vector2i(0,  0), Vector2i(1,  0),
		Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1)
	]

	# Trigger explosions on the 8 surrounding tiles
	for offset in offsets:
		# Calculate target tile coordinates
		var target_tile_coords = hellfire_target + offset
		
		# Convert the tile coordinates to a local position
		var target_position = tilemap.map_to_local(target_tile_coords)
		# Spawn the explosion at the calculated position
		spawn_explosion(target_position)
		await get_tree().create_timer(0.2).timeout
		
	var hud_manager = get_parent().get_parent().get_parent().get_node("HUDManager")  # Adjust the path if necessary
	hud_manager.hide_special_buttons()	
	
	get_parent().has_attacked = true
	get_parent().has_moved = true
	
	get_parent().current_xp += 25
	if get_parent().current_xp >= get_parent().xp_for_next_level:
		get_parent().level_up()	
			
	get_parent().check_end_turn_conditions()		

# Spawn an explosion at the specified position
func spawn_explosion(position):
	if explosion_effect_scene:
		var explosion_instance = explosion_effect_scene.instantiate()
		explosion_instance.global_position = get_parent().to_local(position)
		get_parent().add_child(explosion_instance)
		# Damage any units in the area
		if get_parent().is_in_group("unitAI"):
			damage_units_in_area(position)
		else:
			damage_units_in_area_ai(position)
		
		# Camera focuses on the active zombie
		var camera: Camera2D = get_node("/root/MapManager/Camera2D")
		camera.focus_on_position(position) 		

# Deal damage to units within the area of effect
func damage_units_in_area(center_position):
	# Find units in the area (adapt to your collision system)
	var units = get_tree().get_nodes_in_group("zombies") + get_tree().get_nodes_in_group("structures") + get_tree().get_nodes_in_group("unitAI") + get_tree().get_nodes_in_group("player_units")
	for unit in units:
		if unit.global_position.distance_to(center_position) <= explosion_radius:
			if unit.has_method("apply_damage"):
				unit.flash_damage()
				unit.apply_damage(get_parent().attack_damage)
			elif unit.structure_type == "Building" or unit.structure_type == "Tower" or unit.structure_type == "District" or unit.structure_type == "Stadium":
				unit.is_demolished = true
				unit.get_child(0).play("demolished")

# Deal damage to units within the area of effect
func damage_units_in_area_ai(center_position):
	# Find units in the area (adapt to your collision system)
	var units = get_tree().get_nodes_in_group("zombies") + get_tree().get_nodes_in_group("structures") + get_tree().get_nodes_in_group("player_units")
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
	trigger_hellfire(target)

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

func execute_john_doom_ai_turn() -> void:
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
				await trigger_hellfire(target.position)
			else:
				print("No valid target found for John Doom special attack.")
				get_parent().execute_ai_turn()
			
# Helper function to find the closest target (zombie or player unit) that isn't in the "unitAI" group.
func find_closest_target() -> Node:
	# Find Dutch. Major among the player_units that are AI-controlled.
	var ai_player = null
	for player in get_tree().get_nodes_in_group("player_units"):
		if player.is_in_group("unitAI") and player.player_name == "John. Doom":
			ai_player = player
			# Optionally display the special attack tiles for feedback.
			ai_player.display_special_attack_tiles()
			break
			
	if ai_player == null:
		print("John. Doom not found.")
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
