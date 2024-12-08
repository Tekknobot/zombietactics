extends Node2D

# Configuration variables
var dash_speed = 75
var damage = 50
var aoe_radius = 32
var cooldown = 3.0
var is_active = false

@export var hover_tile_path: NodePath = "/root/MapManager/HoverTile"
@onready var hover_tile = get_node_or_null(hover_tile_path)

func _physics_process(delta: float) -> void:
	if is_active:  # Assuming you toggle `is_active` during the dash
		dash_to_target(delta)

func _input(event):
	# Check for mouse click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Block gameplay input if the mouse is over GUI
		if is_mouse_over_gui():
			print("Input blocked by GUI.")
			return  # Prevent further input handling
			
		# Ensure hover_tile exists and "Sarah Reese" is selected
		if hover_tile and hover_tile.selected_player and hover_tile.selected_player.player_name == "Chuck. Genius" and GlobalManager.dash_toggle_active == true:
			var tilemap: TileMap = get_node("/root/MapManager/TileMap")
			var mouse_position = get_global_mouse_position() 
			mouse_position.y += 8
			var mouse_pos = tilemap.local_to_map(mouse_position)
			blade_dash_strike(mouse_pos)

# Blade Dash Strike ability
func blade_dash_strike(target_tile: Vector2i) -> void:
	if not can_use_ability():  # Check if the unit is eligible to use the ability
		print("Ability cannot be used right now!")
		return
	
	get_parent().move_speed = dash_speed
	
	# Update the AStar grid to ensure accurate pathfinding
	get_parent().update_astar_grid()

	# Calculate the path to the target's adjacent tile
	get_parent().calculate_path(target_tile)

	if get_parent().current_path.is_empty():
		print("No valid path to the target.")
		return

	# Dash to the target position along the path
	dash_to_target(get_process_delta_time())

# Checks if the unit can use the ability
func can_use_ability() -> bool:
	return not get_parent().has_moved and not get_parent().has_attacked and get_parent().can_start_turn

func dash_to_target(delta: float) -> void:
	# Get the TileMap
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")

	# Iterate over each tile in the current path
	for tile in get_parent().current_path:
		var world_pos = tilemap.map_to_local(tile)

		print("Dashing to:", world_pos)

		# Move incrementally to each position
		while position.distance_to(world_pos) > 1:
			# Call the movement function
			move_along_path(delta)
			
			# Wait for the next frame to allow other processing
			await get_tree().process_frame

			# Check if close enough to the target
			if position.distance_to(world_pos) <= 1:
				position = world_pos  # Snap to the target position
				break  # Exit the loop for this tile

	# Ensure the sprite is back to default state and the path is cleared
	print("Dash completed to target path.")
	get_parent().current_path.clear()
	get_parent().move_speed = 75.0  # Reset movement speed

	get_parent().has_moved = true
	get_parent().has_attacked = true
	
func move_along_path(delta: float) -> void:
	if get_parent().current_path.is_empty():
		return  # No path, so don't move

	var tilemap: TileMap = get_node("/root/MapManager/TileMap")

	while get_parent().path_index < get_parent().current_path.size():
		var target_tile_pos = get_parent().current_path[get_parent().path_index]  # Get the current tile position in the path
		var target_world_pos = tilemap.map_to_local(target_tile_pos) + Vector2(0, 0)  # Adjust if needed for tile center

		# Move incrementally towards the target tile
		var direction = (target_world_pos - get_parent().position).normalized()
		get_parent().position += get_parent().direction * get_parent().move_speed * delta

		# Camera focuses on the active zombie
		var camera: Camera2D = get_node("/root/MapManager/Camera2D")
		camera.focus_on_position(get_parent().position) 
		
		# Check if the player has reached the target position (small threshold)
		if get_parent().position.distance_to(target_world_pos) <= 1:
			get_parent().position = target_world_pos  # Snap to the exact tile position
			get_parent().path_index += 1  # Move to the next tile in the path
			print("Reached tile:", target_tile_pos)

			# Optionally update facing direction
			if direction.x > 0:
				scale.x = -1  # Facing right
			elif direction.x < 0:
				scale.x = 1  # Facing left

		# Wait for the next frame before continuing
		await get_tree().process_frame

	# Clear the path once the unit reaches the final tile
	print("Path traversal completed.")
	get_parent().current_path.clear()

	get_parent().get_child(0).play("default")
	# Perform attack once the dash is complete
	check_and_attack_adjacent_zombies()

# Updates the facing direction based on movement direction
func update_facing_direction(target_pos: Vector2) -> void:
	if target_pos.x > get_parent().position.x:
		scale.x = -1  # Facing right
	elif target_pos.x < get_parent().position.x:
		scale.x = 1  # Facing left

func check_and_attack_adjacent_zombies() -> void:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var current_tile = tilemap.local_to_map(global_position)

	# Define adjacent tiles (up, down, left, right)
	var directions = [
		Vector2i(0, -1),  # Up
		Vector2i(0, 1),   # Down
		Vector2i(-1, 0),  # Left
		Vector2i(1, 0)    # Right
	]

	for direction in directions:
		var adjacent_tile = current_tile + direction
		var target = get_unit_at_tile(adjacent_tile)

		if target and target.is_in_group("zombies"):  # Check if a zombie is present
			print("Zombie found at tile:", adjacent_tile)
			
			# Attack the zombie
			var target_world_pos = tilemap.map_to_local(adjacent_tile)

			# Flip to face the target
			update_facing_direction(target_world_pos)

			# Play attack animation
			get_parent().get_child(0).play("attack")

			# Play audio effect (blade attack)
			get_parent().audio_player.stream = get_parent().mek_attack_audio
			get_parent().audio_player.play()

			# Apply damage to the zombie
			target.flash_damage()
			target.apply_damage(get_parent().attack_damage)

			await get_tree().create_timer(0.5).timeout

	# Mark this unit's action as complete
	get_parent().has_attacked = true
	get_parent().has_moved = true

	# Check if the turn should end
	get_parent().check_end_turn_conditions()
	
	print("No adjacent zombies to attack.")

# Returns the unit present at a given tile (if any)
func get_unit_at_tile(tile_pos: Vector2i) -> Node:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var world_pos = tilemap.map_to_local(tile_pos)
	var units = get_tree().get_nodes_in_group("zombies")

	for unit in units:
		if unit.position.distance_to(world_pos) < 16:  # Adjust distance threshold as needed
			return unit
	return null

func is_mouse_over_gui() -> bool:
	# Get global mouse position
	var mouse_pos = get_viewport().get_mouse_position()

	# Get all nodes in the "hud_controls" group
	var hud_controls = get_tree().get_nodes_in_group("hud_controls")
	for control in hud_controls:
		if control is Button:
			# Use global rect to check if mouse is over the button
			var rect = control.get_global_rect()
			print("Checking button:", control.name, "Rect:", rect, "Mouse Pos:", mouse_pos)
			if rect.has_point(mouse_pos):
				print("Mouse is over button:", control.name, "Rect:", rect, "Mouse Pos:", mouse_pos)
				return true
	print("Mouse is NOT over any button.")
	return false
