extends Node2D

@export var max_range: float = 100  # Maximum distance the dash can travel
@export var slash_damage: int = 50  # Damage dealt to each enemy

# Reference to the parent unit
@onready var parent_unit: Area2D = self.get_parent() as Area2D

@export var hover_tile_path: NodePath = "/root/MapManager/HoverTile"
@onready var hover_tile = get_node_or_null(hover_tile_path)
@onready var map_manager = get_parent().get_node("/root/MapManager")

@export var attack_tile_scene: PackedScene

# Store references to instantiated attack range tiles for easy cleanup
var attack_range_tiles: Array[Node2D] = []

var WATER_TILE_ID = 0
var is_slashing: bool = false

func _ready() -> void:
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

		if not is_tile_movable(mouse_local) or not is_in_attack_range(mouse_local):
			return

		# Check if the mouse is outside the bounds of the used rectangle
		if mouse_local.x < map_origin_x or mouse_local.x >= map_origin_x + map_width or \
		   mouse_local.y < map_origin_y or mouse_local.y >= map_origin_y + map_height:
			return  # Exit the function if the mouse is outside the map
		
		# Ensure hover_tile exists and "Dutch. Major" is selected
		if hover_tile and hover_tile.selected_player and hover_tile.selected_player.player_name == "Dutch. Major" and GlobalManager.slash_toggle_active == true:
			# Calculate direction
			var mouse_position = get_global_mouse_position()
			mouse_position.y += 8  # Adjust for any map-specific offsets
			var direction = mouse_position - parent_unit.global_position
			direction = direction.normalized()  # Normalize the direction vector

			# Optionally update facing direction
			if direction.x > 0:
				get_parent().scale.x = -1  # Facing right
			elif direction.x < 0:
				get_parent().scale.x = 1  # Facing left
			
			get_parent().get_child(0).play("move")
			
			# Update the HUD to reflect new stats
			var hud_manager = get_node("/root/MapManager/HUDManager")
			hud_manager.hide_special_buttons()	
						
			# Trigger Shadow Slash with the calculated direction
			shadow_slash(direction)

func is_in_attack_range(tile_pos: Vector2i) -> bool:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	for attack_tile in attack_range_tiles:
		var attack_tile_pos: Vector2i = tilemap.local_to_map(attack_tile.position)
		if attack_tile_pos == tile_pos:
			return true
	return false

func shadow_slash(direction: Vector2):
	if not parent_unit:
		print("Parent unit not found!")
		return

	# Reference the TileMap node
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")

	# Get the global mouse position converted to the TileMap's local position
	var mouse_position = get_global_mouse_position()
	mouse_position.y += 8
	var mouse_local = tilemap.local_to_map(mouse_position)
	var end_position = tilemap.map_to_local(mouse_local)  # Convert tile coordinates back to local space

	# Calculate the trajectory
	var trajectory = calculate_line_positions(parent_unit.global_position, end_position)
	
	# Dash along the trajectory
	is_slashing = true
	await dash_along_trajectory(trajectory)

	#disable_bullet_time()
	await get_tree().create_timer(0.1).timeout
	is_slashing = false
	
	get_parent().current_xp += 25
	if get_parent().current_xp >= get_parent().xp_for_next_level:
		get_parent().level_up()	
	
	get_parent().get_child(0).play("default")
	get_parent().has_moved = true
	get_parent().has_attacked = true
	get_parent().check_end_turn_conditions()
	GlobalManager.slash_toggle_active = false
		
func calculate_line_positions(start: Vector2, end: Vector2) -> Array:
	var points = []
	var step = 8  # Adjust step size based on tile/grid resolution
	var direction = (end - start).normalized()
	var current = start
	while current.distance_to(end) > step:
		points.append(current)
		current += direction * step
	points.append(end)  # Include the final point
	return points

func dash_along_trajectory(trajectory: Array):
	print("Dashing along trajectory...")
	
	for position in trajectory:		
		# Check for enemies and deal damage
		var enemy = find_enemy_at_position(position)
		if enemy:
			get_parent().get_child(0).play("attack")
			
			get_parent().get_child(8).stream = get_parent().slash_audio
			get_parent().get_child(8).play()
						
			await get_tree().create_timer(0.5).timeout
			enemy.flash_damage()
			
			enemy.audio_player.stream = enemy.zombie_audio
			enemy.audio_player.play()
			
			enemy.apply_damage(get_parent().attack_damage)

		# Move parent unit to the current position
		parent_unit.global_position = position
		
		await get_tree().create_timer(0.05).timeout  # Adjust for smooth movement
		get_parent().get_child(0).play("move")
			
	# Play attack animation
	clear_attack_range_tiles()
	print("Shadow Slash completed. Final position:", parent_unit.global_position)

func find_enemy_at_position(position: Vector2) -> Node:
	# Check for enemies in the specified position
	var enemies = get_tree().get_nodes_in_group("zombies")
	for enemy in enemies:
		if enemy.global_position.distance_to(position) < 8:  # Adjust hitbox tolerance
			#enable_bullet_time()
			return enemy
	return null

func apply_damage(enemy: Node, damage: int):
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage)
		print("Enemy at", enemy.global_position, "took", damage, "damage.")

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

# Check if a tile is movable
func is_tile_movable(tile_pos: Vector2i) -> bool:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var tile_id = tilemap.get_cell_source_id(0, tile_pos)
	if is_water_tile(tile_id):
		return false
	if is_structure(tile_pos) or is_unit_present(tile_pos):
		return false
	return true

# Check if a tile is water or not
func is_water_tile_at_position(tile_pos: Vector2i) -> bool:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	if tilemap == null:
		push_error("TileMap node not found at the specified path.")
		return false
	
	var tile_id = tilemap.get_cell_source_id(0, tile_pos)
	return tile_id == WATER_TILE_ID
	
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
	var all_units = get_tree().get_nodes_in_group("player_units")
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

# Display the attack range for Shadow Slash
func display_slash_attack_range():
	# Clear previous attack range tiles
	clear_attack_range_tiles()

	# Reference the TileMap node
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var start_pos: Vector2i = tilemap.local_to_map(parent_unit.global_position)

	# Directions to check: right, left, down, up
	var directions: Array[Vector2i] = [
		Vector2i(1, 0),  # Right
		Vector2i(-1, 0), # Left
		Vector2i(0, 1),  # Down
		Vector2i(0, -1)  # Up
	]

	for direction in directions:
		var current_pos = start_pos
		for step in get_parent().movement_range * 16:  # Iterate up to the max range
			current_pos += direction

			# Check if the current tile is within bounds
			if !tilemap.get_used_rect().has_point(current_pos):
				break  # Stop if out of bounds

			# Check if the tile is movable or occupied
			if is_structure(current_pos) or is_unit_present(current_pos) or is_water_tile_at_position(current_pos):
				break
			highlight_attack_tile(current_pos, tilemap)

# Helper function to highlight a specific tile
func highlight_attack_tile(tile_pos: Vector2i, tilemap: TileMap):
	var world_pos: Vector2 = tilemap.map_to_local(tile_pos)
	var attack_tile_instance: Node2D = attack_tile_scene.instantiate() as Node2D  # Use attack_tile_scene here
	attack_tile_instance.position = world_pos
	tilemap.add_child(attack_tile_instance)
	attack_range_tiles.append(attack_tile_instance)

# Clear attack range tiles
func clear_attack_range_tiles():
	for tile in attack_range_tiles:
		tile.queue_free()
	attack_range_tiles.clear()

# Enable bullet time effect
func enable_bullet_time():
	Engine.time_scale = 0.3  # Slow down time to 30%

# Disable bullet time effect
func disable_bullet_time():
	Engine.time_scale = 1.0  # Restore normal time scale
