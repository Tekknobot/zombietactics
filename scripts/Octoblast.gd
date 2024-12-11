extends Node2D

@export var hover_tile_path: NodePath = "/root/MapManager/HoverTile"
@onready var hover_tile = get_node_or_null(hover_tile_path)

# Exported variables for customization in the editor
@export var attack_damage: int = 50 # Damage per explosion
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
					
		# Ensure hover_tile exists and "Sarah Reese" is selected
		if hover_tile and hover_tile.selected_player and hover_tile.selected_player.player_name == "Annie. Switch" and GlobalManager.octoblast_toggle_active == true:
			activate_ability()
			
func trigger_octoblast():
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	
	var mouse_position = get_global_mouse_position() 
	mouse_position.y += 8
	var mouse_pos = tilemap.local_to_map(mouse_position)
		
	# Get the current position in tile coordinates
	var current_position = mouse_pos

	# Trigger trajectory to the initial position
	missile_manager.start_trajectory(mouse_position, get_parent().position)

	# Trigger explosion on the center tile immediately
	spawn_explosion(tilemap.map_to_local(current_position))

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
		await get_tree().create_timer(0.2).timeout
		missile_manager.start_trajectory(zombie_pos, get_parent().position)

	GlobalManager.octoblast_toggle_active = false
	var hud_manager = get_parent().get_parent().get_parent().get_node("HUDManager")  # Adjust the path if necessary
	hud_manager.hide_special_buttons()	
	
	get_parent().has_attacked = true
	get_parent().has_moved = true
	get_parent().check_end_turn_conditions()
	
# Helper function to get all zombies on the map
func get_zombies_on_map() -> Array:
	var zombies = []
	var all_entities = get_node("/root/MapManager/UnitSpawn").get_children()  # Adjust the path to your EntityManager
	for entity in all_entities:
		if entity.is_in_group("zombies"):  # Check if the entity is a zombie
			zombies.append(entity)
	return zombies

# Spawn an explosion at the specified position
func spawn_explosion(position):
	if explosion_effect_scene:
		var explosion_instance = explosion_effect_scene.instantiate()
		explosion_instance.global_position = get_parent().to_local(position)
		get_parent().add_child(explosion_instance)
		# Damage any units in the area
		damage_units_in_area(position)
		
		# Camera focuses on the active zombie
		var camera: Camera2D = get_node("/root/MapManager/Camera2D")
		camera.focus_on_position(position) 		

# Deal damage to units within the area of effect
func damage_units_in_area(center_position):
	# Find units in the area (adapt to your collision system)
	var units = get_tree().get_nodes_in_group("zombies") + get_tree().get_nodes_in_group("player_units") + get_tree().get_nodes_in_group("structures")
	for unit in units:
		if unit.global_position.distance_to(center_position) <= explosion_radius:
			if unit.has_method("apply_damage"):
				unit.flash_damage()
				unit.apply_damage(get_parent().attack_damage)
			elif unit.structure_type == "Building" or unit.structure_type == "Tower" or unit.structure_type == "District" or unit.structure_type == "Stadium":
				unit.is_demolished = true
				unit.get_child(0).play("demolished")
				
# Optional: Call this method to activate Hellfire from external scripts
func activate_ability():
	trigger_octoblast()

func is_mouse_over_gui() -> bool:
	# Get global mouse position
	var mouse_pos = get_viewport().get_mouse_position()

	# Get all nodes in the "hud_controls" group
	var hud_controls = get_tree().get_nodes_in_group("portrait_controls") + get_tree().get_nodes_in_group("hud_controls")
	for control in hud_controls:
		if control is TextureRect or Button and control.is_visible_in_tree():
			# Use global rect to check if mouse is over the button
			var rect = control.get_global_rect()
			print("Checking button:", control.name, "Rect:", rect, "Mouse Pos:", mouse_pos)
			if rect.has_point(mouse_pos):
				print("Mouse is over button:", control.name, "Rect:", rect, "Mouse Pos:", mouse_pos)
				return true
	print("Mouse is NOT over any button.")
	return false
