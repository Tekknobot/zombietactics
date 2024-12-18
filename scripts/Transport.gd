extends Node2D

@export var hover_tile_path: NodePath = "/root/MapManager/HoverTile"
@onready var hover_tile = get_node_or_null(hover_tile_path)

@export var max_targets = 7 # Max number of zombies to attack
@export var attack_damage = 50
@export var fade_duration = 0.5
@export var cooldown = 3.0

@onready var map_manager = get_parent().get_node("/root/MapManager")

var targeted_zombies = [] # Zombies to attack
var is_shadow_step_active = false
var attacked_zombies = [] # List to track already attacked zombies
var pathfinder = null # Placeholder for pathfinding utility

var original_pos: Vector2i
var unit_on_board: bool = false
var boarded_unit
var moved_back: bool = false
var assigned = false
	
func _ready() -> void:
	pathfinder = get_node_or_null("/root/MapManager/Pathfinder") # Ensure you have a pathfinder node in your scene

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_mouse_over_gui():
			print("Input blocked by GUI.")
			return

		var tilemap: TileMap = get_node("/root/MapManager/TileMap")
		var global_mouse_position = get_global_mouse_position() 
		global_mouse_position.y += 8

		var mouse_local = tilemap.local_to_map(global_mouse_position)

		if hover_tile and hover_tile.selected_player and hover_tile.selected_player.player_name == "John. Doom" and GlobalManager.transport_toggle_active:
			var hud_manager = get_parent().get_parent().get_parent().get_node("HUDManager")  # Adjust the path if necessary
			hud_manager.hide_special_buttons()		
			calcualte_transport_path(mouse_local)	

# Transport ability
func calcualte_transport_path(target_tile: Vector2i) -> void:
	# Update the AStar grid to ensure accurate pathfinding
	get_parent().update_astar_grid()
	
	if unit_on_board == false:
		# Calculate the path to the target's adjacent tile
		get_parent().calculate_path(target_tile)
	else:
		get_parent().calculate_path(original_pos)

	if get_parent().current_path.is_empty():
		print("No valid path to the target.")
		return

	# Save the original position for returning later
	if assigned == false:
		original_pos = get_parent().tile_pos
		assigned = true

	# Dash to the target position along the path
	move_to_transport(get_process_delta_time())

func move_to_transport(delta: float) -> void:
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
			move_along_path()
			
			# Wait for the next frame to allow other processing
			await get_tree().process_frame

			# Check if close enough to the target
			if position.distance_to(world_pos) <= 1:
				position = world_pos  # Snap to the target position                
				break  # Exit the loop for this tile

	# Ensure the sprite is back to default state and the path is cleared
	print("Move completed to target path.")
	
func check_and_transport_adjacent_unit() -> void:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var adjacent_positions = [
		Vector2i(-1, 0), Vector2i(1, 0),  # Left, Right
		Vector2i(0, -1), Vector2i(0, 1)  # Up, Down
	]

	var transported_unit = null

	# Iterate over all adjacent positions
	for offset in adjacent_positions:
		var adjacent_tile = tilemap.local_to_map(get_parent().position) + offset
		var unit = get_unit_at_tile(adjacent_tile)

		if unit and unit.is_in_group("player_units"):
			print("Found adjacent player unit:", unit.name)

			# If this is the first valid unit, transport it
			if not transported_unit:
				transported_unit = unit
				unit.visible = false  # Make the unit invisible
				unit_on_board = true
				boarded_unit = unit
	
	await get_tree().create_timer(1).timeout
	
	calcualte_transport_path(original_pos)
	
	# Move back to the original position
	move_to_transport(get_process_delta_time())	

func get_unit_at_tile(tile_pos: Vector2i) -> Node:
	var all_units = get_tree().get_nodes_in_group("player_units")
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	
	for unit in all_units:
		# Convert the unit's global position to tilemap coordinates
		var unit_tile = tilemap.local_to_map(unit.position)  # Use local_to_map or global_position_to_tile
		print("Checking unit at tile:", unit_tile, "against target tile:", tile_pos)  # Debugging
		if unit_tile == tile_pos:
			print("Unit found:", unit.name)  # Debugging
			return unit
	return null

func is_tile_empty(tile_pos: Vector2i) -> bool:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")

	# Check if the tile is occupied or invalid
	if tilemap.get_cell_source_id(0, tile_pos) != -1:
		return false

	# Check if any unit is present at the tile
	var unit = get_unit_at_tile(tile_pos)
	if unit:
		return false

	return true
		
func transport_unit_to_adjacent_tile(unit) -> void:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var adjacent_positions = [
		Vector2i(-1, 0), Vector2i(1, 0),  # Left, Right
		Vector2i(0, -1), Vector2i(0, 1)  # Up, Down
	]

	for offset in adjacent_positions:
		var adjacent_tile = original_pos + offset
		unit.position = tilemap.map_to_local(adjacent_tile)
		unit.visible = true  # Make the unit visible again
		print("Transported unit to:", adjacent_tile)
		
		assigned = false
		GlobalManager.transport_toggle_active = false
		get_parent().get_child(2).play("default")
		get_parent().has_moved = true
		get_parent().has_attacked = true
		get_parent().check_end_turn_conditions()		
		break	

func move_along_path() -> void:
	if get_parent().current_path.is_empty():
		return  # No path, so don't move

	var tilemap: TileMap = get_node("/root/MapManager/TileMap")

	get_parent().get_child(0).play("move")
		
	while get_parent().path_index < get_parent().current_path.size():
		var target_tile_pos = get_parent().current_path[get_parent().path_index]  # Get the current tile position in the path
		var target_world_pos = tilemap.map_to_local(target_tile_pos) + Vector2(0, 0)  # Adjust if needed for tile center
			
		# Move incrementally towards the target tile
		var direction = (target_world_pos - get_parent().position).normalized()
		get_parent().position += get_parent().direction * get_parent().move_speed * get_process_delta_time()
				
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

	if unit_on_board == false:	
		# Check for adjacent player units
		check_and_transport_adjacent_unit()

	if unit_on_board and get_parent().tile_pos == original_pos:
		transport_unit_to_adjacent_tile(boarded_unit)	
	
func is_mouse_over_gui() -> bool:
	var mouse_pos = get_viewport().get_mouse_position()
	var hud_controls = get_tree().get_nodes_in_group("portrait_controls") + get_tree().get_nodes_in_group("hud_controls")
	for control in hud_controls:
		if control is TextureRect or Button and control.is_visible_in_tree():
			var rect = control.get_global_rect()
			if rect.has_point(mouse_pos):
				return true
	return false
