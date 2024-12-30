extends Node2D

@export var hover_tile_path: NodePath = "/root/MapManager/HoverTile"
@onready var hover_tile = get_node_or_null(hover_tile_path)

@export var max_targets = 7 # Max number of zombies to attack
@export var attack_damage = 50
@export var fade_duration = 0.5
@export var cooldown = 3.0

@onready var map_manager = get_parent().get_node("/root/MapManager")
@onready var mission_manager = get_parent().get_node("/root/MissionManager")

var targeted_zombies = [] # Zombies to attack
var is_shadow_step_active = false
var attacked_zombies = [] # List to track already attacked zombies
var pathfinder = null # Placeholder for pathfinding utility

var original_pos: Vector2i
var unit_on_board: bool = false
var boarded_unit
var moved_back: bool = false
var assigned = false

@export var hover_tile_scene: PackedScene
var hover_tiles = []  # Store references to instantiated hover tiles
var last_hovered_tile = null  # Track the last hovered tile to avoid redundant updates
	
func _ready() -> void:
	pathfinder = get_node_or_null("/root/MapManager/Pathfinder") # Ensure you have a pathfinder node in your scene

func _process(delta: float) -> void:
	if GlobalManager.transport_toggle_active:
		update_hover_tiles()
	else:
		clear_hover_tiles()		
		
	is_mouse_over_gui()		

func _input(event):
	# Check for mouse motion or click
	if event is InputEventMouseMotion:
		if GlobalManager.transport_toggle_active:
			update_hover_tiles()	
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_mouse_over_gui():
			print("Input blocked by GUI.")
			return

		var tilemap: TileMap = get_node("/root/MapManager/TileMap")
		var global_mouse_position = get_global_mouse_position() 
		global_mouse_position.y += 8

		var mouse_local = tilemap.local_to_map(global_mouse_position)

		if hover_tile and hover_tile.selected_player and hover_tile.selected_player.player_name == "John. Doom" and GlobalManager.transport_toggle_active == true:
			if is_tile_movable(mouse_local) == false:
				return
			
			var hud_manager = get_parent().get_parent().get_parent().get_node("HUDManager")  # Adjust the path if necessary
			hud_manager.hide_special_buttons()	
			clear_hover_tiles()	
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
		print("No valid path to the target. Exiting ability.")
		finalize_ability()  # Exit the ability and finalize the turn
		return
	
	assigned = false	
	
	# Save the original position for returning later
	if assigned == false:
		original_pos = get_parent().tile_pos
		assigned = true

	# Dash to the target position along the path
	move_to_transport(get_process_delta_time())
	get_parent().get_child(0).play("move")
	
	get_parent().audio_player.stream = get_parent().helicopter_audio
	get_parent().audio_player.play()
	
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
			if not is_inside_tree() or !get_parent().is_in_group("player_units"):
				print("Node is no longer in the scene tree. Exiting ability.")
				finalize_ability()
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

	# Check if no unit was found
	if not transported_unit:
		print("No adjacent player unit found. Exiting ability.")	
		finalize_ability()  # Exit the ability and finalize the turn
		return

	# If a unit is found, move back to the original position
	await get_tree().create_timer(1).timeout
	calcualte_transport_path(original_pos)

func finalize_ability() -> void:
	get_parent().current_path.clear()
	get_parent().get_child(0).play("default")  # Reset animation only for the active unit		
	get_parent().has_moved = true
	get_parent().has_attacked = true
	get_parent().check_end_turn_conditions()
	
	get_parent().audio_player.stop()
	
	assigned = false	
	GlobalManager.transport_toggle_active = false
	print("Ability finalized.")
		
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
		
func transport_unit_to_adjacent_tile(unit) -> void:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var adjacent_positions = [
		Vector2i(-1, 0), Vector2i(1, 0),  # Left, Right
		Vector2i(0, -1), Vector2i(0, 1)  # Up, Down
	]
	
	for offset in adjacent_positions:
		var adjacent_tile = original_pos + offset
		
		# Check if the tile is movable before placing the unit
		if is_tile_movable(adjacent_tile) and is_not_blank_tile(adjacent_tile):
			print("Placing unit at:", adjacent_tile)

			# Ensure no duplicate placement occurs
			if unit.visible:
				print("Unit is already visible and placed. Exiting.")
				return

			# Place the unit at the valid tile
			unit.position = tilemap.map_to_local(adjacent_tile)
			unit.visible = true  # Make the unit visible again
			print("Transported unit to:", adjacent_tile)

			# Reset state and finalize the turn
			finalize_ability()
			return  # Exit after placing the unit

	# If no movable tile was found, print a failure message
	print("No movable adjacent tile found. Transport failed.")

func update_hover_tiles():
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var start_tile = get_parent().tile_pos  # Unit's current tile position
	var end_tile = hover_tile.tile_pos  # Hover tile position

	# Avoid redundant updates if the end tile hasn't changed
	if end_tile == last_hovered_tile:
		return
	
	last_hovered_tile = end_tile

	# Clear existing hover tiles
	clear_hover_tiles()

	# Ensure AStar is updated and calculate the path
	get_parent().update_astar_grid()
	var path = get_parent().astar.get_point_path(start_tile, end_tile)

	if path.size() == 0:
		print("No path found between start and end tile.")
		return

	# Iterate through the path and place hover tiles
	for pos in path:
		var tile_pos = Vector2i(pos)  # Ensure tile position is a Vector2i
		var world_pos = tilemap.map_to_local(tile_pos)

		# Create a hover tile
		if hover_tile_scene:
			var hover_tile_instance = hover_tile_scene.instantiate()
			hover_tile_instance.position = world_pos
			tilemap.add_child(hover_tile_instance)
			hover_tiles.append(hover_tile_instance)

func clear_hover_tiles():
	for tile in hover_tiles:
		tile.queue_free()
	hover_tiles.clear()

func move_along_path() -> void:
	if get_parent().current_path.is_empty():
		return  # No path, so don't move

	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
		
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
	elif unit_on_board and get_parent().tile_pos == original_pos:
		transport_unit_to_adjacent_tile(boarded_unit)	

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
	var WATER_TILE_ID: int

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

	# Return whether the tile_id matches the WATER_TILE_ID
	return tile_id == WATER_TILE_ID

# Check if there is a structure on the tile
func is_structure(tile_pos: Vector2i) -> bool:
	var structures = get_tree().get_nodes_in_group("structures")
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	for structure in structures:
		var structure_tile_pos = tilemap.local_to_map(tilemap.to_local(structure.global_position))
		if tile_pos == structure_tile_pos:
			return true
	return false

# Check if there is a unit on the tile
func is_unit_present(tile_pos: Vector2i) -> bool:
	var all_units = get_tree().get_nodes_in_group("player_units") + get_tree().get_nodes_in_group("zombies")
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	for unit in all_units:
		var unit_tile_pos = tilemap.local_to_map(tilemap.to_local(unit.global_position))
		if tile_pos == unit_tile_pos:
			return true
	return false

# Checks if a tile is spawnable (not water)
func is_not_blank_tile(tile_pos: Vector2i) -> bool:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var tile_id = tilemap.get_cell_source_id(0, tile_pos)
	return tile_id != -1	
		
func is_mouse_over_gui() -> bool:
	var mouse_pos = get_viewport().get_mouse_position()
	var hud_controls = get_tree().get_nodes_in_group("portrait_controls") + get_tree().get_nodes_in_group("hud_controls")
	for control in hud_controls:
		if control is TextureRect or Button and control.is_visible_in_tree():
			var rect = control.get_global_rect()
			if rect.has_point(mouse_pos):
				clear_hover_tiles()
				return true
	return false

func reset_player_units():
	# Get all player units in the game
	var players = get_tree().get_nodes_in_group("player_units")
	for player in players:	
		player.has_moved = false
		player.has_attacked = false
		player.has_used_turn = false
		player.can_start_turn = true
		player.modulate = Color(1, 1, 1)
