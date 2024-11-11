extends Node2D

# Reference to the TileMap
var tilemap: TileMap = null

# Currently selected player
var selected_player: Area2D = null

# Movement and attack range tiles
var movement_range_tiles: Array[Vector2i] = []
var attack_range_tiles: Array[Vector2i] = []

# Called when the node enters the scene
func _ready() -> void:
	tilemap = get_node("/root/MapManager/TileMap")
	visible = true

# Called every frame
func _process(delta: float) -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	mouse_pos.y += 8  # Optional offset to align tiles if necessary
	var tile_pos: Vector2i = tilemap.local_to_map(tilemap.to_local(mouse_pos))

	if is_within_bounds(tile_pos):
		position = tilemap.map_to_local(tile_pos)
		visible = true
		check_for_click(tile_pos)
	else:
		visible = false

# Checks if the tile position is within the tilemap bounds
func is_within_bounds(tile_pos: Vector2i) -> bool:
	var map_rect: Rect2i = tilemap.get_used_rect()
	return tile_pos.x >= map_rect.position.x and tile_pos.y >= map_rect.position.y \
		and tile_pos.x < map_rect.position.x + map_rect.size.x \
		and tile_pos.y < map_rect.position.y + map_rect.size.y

# Checks for clicks and executes actions based on selected mode
func check_for_click(tile_pos: Vector2i) -> void:
	if Input.is_action_just_pressed("mouse_left"):
		# If there's already a selected player, check if the player clicked on a valid tile
		if selected_player:
			# If the player is awaiting movement click and clicked a valid movement tile
			if tile_pos in movement_range_tiles:
				move_selected_player(tile_pos)
			# If the player is awaiting attack click and clicked a valid attack tile
			elif tile_pos in attack_range_tiles:
				attack_selected_player(tile_pos)
			else:
				# Reselect unit or perform an action if no other specific mode is active
				select_unit_at_tile(tile_pos)
		else:
			# If no unit is selected, allow selection of a unit
			select_unit_at_tile(tile_pos)
			
	elif Input.is_action_just_pressed("mouse_right") and selected_player:
		# Right-click to toggle between attack and movement modes for selected unit
		toggle_attack_mode()	

# Moves the selected player to the specified tile
func move_selected_player(tile_pos: Vector2i) -> void:
	selected_player.move_player_to_target(tile_pos)
	clear_action_tiles()

# Attacks the target at the specified tile
func attack_selected_player(tile_pos: Vector2i) -> void:
	selected_player.attack(tile_pos)
	clear_action_tiles()

# Selects a unit at the given tile position
func select_unit_at_tile(tile_pos: Vector2i) -> void:
	var players = get_tree().get_nodes_in_group("player_units")

	# Iterate over all players to check if the tile position matches any player's position
	for player in players:
		# Convert the player's global position to a tile position
		var player_tile_pos: Vector2i = tilemap.local_to_map(player.global_position)

		# Debugging: Check for the clicked tile and player tile position
		print("Tile position: ", tile_pos)
		print("Player tile position: ", player_tile_pos)

		# Allow for small tolerance or exact match
		if player_tile_pos == tile_pos:
			# Deselect the currently selected player, if any
			if selected_player:
				selected_player.selected = false
				# Ensure any previous selected player stops processing
				selected_player.set_process_input(false)
				selected_player.set_process(false)

			# Select the new player
			selected_player = player
			selected_player.selected = true
			
			# Show movement tiles and enable input processing
			show_movement_tiles(player)
			selected_player.set_process_input(true)  # Ensure it processes input
			selected_player.set_process(true)  # Ensure it's updated each frame

			print("Unit selected at position: ", player.global_position)
			return
	
	# If no unit is found, print debugging info
	print("No player unit found at tile position: ", tile_pos)

# Toggles between attack and movement mode for the currently selected player
func toggle_attack_mode() -> void:
	if selected_player:
		# If the unit is in movement mode, switch to attack mode
		if selected_player:
			clear_action_tiles()
			selected_player.display_attack_range_tiles()
			attack_range_tiles = selected_player.get_attack_tiles()
		# If the unit is in attack mode, switch back to movement mode
		else:
			clear_action_tiles()
			show_movement_tiles(selected_player)

# Displays movement tiles for the selected player
func show_movement_tiles(player: Area2D) -> void:
	clear_action_tiles()
	movement_range_tiles = player.get_movement_tiles()
	player.display_movement_tiles()

# Clears all action tiles (movement and attack)
func clear_action_tiles() -> void:
	clear_movement_tiles()
	clear_attack_tiles_for_all_players()

# Clears movement tiles for all players
func clear_movement_tiles() -> void:
	var players = get_tree().get_nodes_in_group("player_units")
	for player in players:
		player.clear_movement_tiles()

# Clears attack tiles for all players
func clear_attack_tiles_for_all_players() -> void:
	var players = get_tree().get_nodes_in_group("player_units")
	for player in players:
		player.clear_attack_range_tiles()
