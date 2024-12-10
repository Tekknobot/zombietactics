extends Node2D

# Configuration variables
var dash_speed = 125
var damage = 50
var aoe_radius = 32
var cooldown = 3.0
var is_active = false

@export var hover_tile_path: NodePath = "/root/MapManager/HoverTile"
@onready var hover_tile = get_node_or_null(hover_tile_path)

var attacked: bool = false
var pos_before_dash: Vector2i

func _physics_process(delta: float) -> void:
	if is_active:  # Assuming you toggle `is_active` during the dash
		dash_to_target(delta)

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
		if hover_tile and hover_tile.selected_player and hover_tile.selected_player.player_name == "Aleks. Ducat" and GlobalManager.claw_toggle_active == true:
			#var tilemap: TileMap = get_node("/root/MapManager/TileMap")
			var mouse_position = get_global_mouse_position() 
			mouse_position.y += 8
			var mouse_pos = tilemap.local_to_map(mouse_position)
			# Camera focuses on the active zombie
			var camera: Camera2D = get_node("/root/MapManager/Camera2D")
			camera.focus_on_position(get_parent().position) 
						
			#await fade_out(get_parent())
			claw_dash_strike(mouse_pos)
	
func fade_out(sprite: Node, duration: float = 1.5) -> void:
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
	tween.tween_property(sprite, "modulate:a", 0.2, duration)

	# Wait for the tween to finish
	await tween.finished

func fade_in(sprite: Node, duration: float = 1.5) -> void:
	"""
	Fades the sprite in over the specified duration.
	:param sprite: The sprite to fade in.
	:param duration: The time it takes to fade in.
	"""
	if not sprite:
		print("Error: Sprite is null!")
		return

	# If the sprite is already fully visible, do nothing
	if sprite.modulate.a >= 1:
		return

	# Create a new tween for the fade-in animation
	var tween = create_tween()

	#Play SFX
	get_parent().get_child(2).stream = get_parent().invisibility_audio
	get_parent().get_child(2).play()

	# Tween the alpha value of the sprite's modulate property to 1
	tween.tween_property(sprite, "modulate:a", 1.0, duration)

	# Wait for the tween to finish
	await tween.finished

# Blade Dash Strike ability
func claw_dash_strike(target_tile: Vector2i) -> void:
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

	#Play SFX
	get_parent().get_child(2).stream = get_parent().footstep_audio
	get_parent().get_child(2).play()

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
			# Break the loop if the node is no longer in the scene tree
			if not is_inside_tree():
				print("Node is no longer in the scene tree. Exiting loop.")
				return
				
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

	get_parent().is_moving = true
	get_parent().get_child(0).play("move")
		
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
	
	get_parent().is_moving = false
	get_parent().get_child(0).play("default")
	
	# Perform attack once the dash is complete
	check_and_attack_adjacent_zombies()

# Updates the facing direction based on movement direction
func update_facing_direction(target_pos: Vector2) -> void:
	# Get the world position of the zombie (target)
	var zombie_world_pos = target_pos
	print("Zombie world position: ", zombie_world_pos)
	
	# Determine the direction to the target
	var direction_to_target = zombie_world_pos.x - get_parent().position.x
	
	# Flip the sprite based on the target's relative position (left or right)
	if direction_to_target > 0 and get_parent().scale.x != -1:
		# Zombie is to the right, flip the mek to face right
		get_parent().scale.x = -1
	elif direction_to_target < 0 and get_parent().scale.x != 1:
		# Zombie is to the left, flip the mek to face left
		get_parent().scale.x = 1

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
			var target_world_pos = tilemap.map_to_local(target.tile_pos)

			# Flip to face the target
			update_facing_direction(target_world_pos)

			# Play attack animation
			get_parent().is_moving = false
			get_parent().get_child(0).play("attack")

			# Play audio effect (blade attack)
			get_parent().audio_player.stream = get_parent().claw_audio
			get_parent().audio_player.play()

			# Apply damage to the zombie
			if not target.has_meta("been_attacked") or target.get_meta("been_attacked") == false:
				target.flash_damage()
				target.apply_damage(get_parent().attack_damage)
				target.set_meta("been_attacked", true)  # Mark this zombie as been_attacked
				print("Blade damage applied")

			await get_tree().create_timer(0.5).timeout

	# Reset the "been_attacked" state for all zombies in the group after the loop
	var zombies = get_tree().get_nodes_in_group("zombies")
	for zombie in zombies:
		if zombie.has_meta("been_attacked"):
			zombie.set_meta("been_attacked", false)  # Reset been_attacked flag
	
	print("No adjacent zombies to attack.")

	await fade_in(get_parent())
	
	# Mark this unit's action as complete
	get_parent().has_attacked = true
	get_parent().has_moved = true

	GlobalManager.claw_toggle_active = false
	var hud_manager = get_parent().get_parent().get_parent().get_node("HUDManager")  # Adjust the path if necessary
	hud_manager.hide_special_buttons()
	
	# Check if the turn should end
	get_parent().check_end_turn_conditions()
		
# Returns the unit present at a given tile (if any)
func get_unit_at_tile(tile_pos: Vector2i) -> Node:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var world_pos = tilemap.map_to_local(tile_pos)
	var units = get_tree().get_nodes_in_group("zombies")

	for unit in units:
		if unit.tile_pos == tile_pos:
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
