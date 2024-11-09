extends Node2D

# Reference to the TileMap
var tilemap: TileMap = null

# Reference to the currently selected player
var selected_player: Area2D = null

# Track if we are waiting for a second click within the movement range
var awaiting_movement_click: bool = false
var awaiting_attack_click: bool = false  # Flag to track attack mode

# Store the movement range of the selected player
var movement_range_tiles: Array[Vector2i] = []
var attack_range_tiles: Array[Vector2i] = []  # Store the attack range tiles

# Called when the node enters the scene
func _ready() -> void:
	# Get a reference to the TileMap (adjust the path as needed)
	tilemap = get_node("/root/MapManager/TileMap")  # Adjust this path to match your scene structure

	# Ensure the hover tile is visible initially
	visible = true

# Called every frame
func _process(delta: float) -> void:
	# Get the current global mouse position
	var mouse_pos: Vector2 = get_global_mouse_position()

	# Offset to align the hover tile if necessary
	mouse_pos.y += 8  # Adjust based on tile size

	# Convert the mouse position to the closest tile position in the tilemap
	var tile_pos: Vector2i = tilemap.local_to_map(tilemap.to_local(mouse_pos))

	# Check if the tile position is within the valid bounds of the tilemap
	if is_within_bounds(tile_pos):
		# Convert the tile position back to world coordinates to position the hover tile
		var world_pos: Vector2 = tilemap.map_to_local(tile_pos)
		position = world_pos
		# Make the hover tile visible when within the bounds
		visible = true

		# Check if a player unit is clicked and display its movement tiles
		check_for_click(tile_pos)
	else:
		# Hide the hover tile when outside the map bounds
		visible = false

# Function to check if the tile position is within the tilemap bounds
func is_within_bounds(tile_pos: Vector2i) -> bool:
	# Get the size of the tilemap's used area (this is the relevant area)
	var map_rect: Rect2i = tilemap.get_used_rect()

	# Check if the tile position is within the bounds of the tilemap's used area
	return tile_pos.x >= map_rect.position.x and tile_pos.y >= map_rect.position.y and tile_pos.x < map_rect.position.x + map_rect.size.x and tile_pos.y < map_rect.position.y + map_rect.size.y

# Function to check for player unit clicks
func check_for_click(tile_pos: Vector2i) -> void:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	# Convert tile position to world position (tilemap coordinates -> world coordinates)
	var world_pos = tilemap.map_to_local(tile_pos)  # tile_pos is Vector2i, world_pos will be Vector2

	# Check if the mouse button is clicked
	if Input.is_action_just_pressed("mouse_left"):  # Use your preferred click action
		# If awaiting a movement click and the clicked tile is in the movement range, move the player
		if awaiting_movement_click and tile_pos in movement_range_tiles:
			# Clear the movement tiles
			clear_movement_tiles()
						
			# Move the selected player to the target tile
			selected_player.move_player_to_target(tile_pos)

			awaiting_movement_click = false  # Disable movement click
			awaiting_attack_click = true  # Enable attack click
			return

		# If awaiting an attack click and the clicked tile is in the attack range, perform the attack
		if awaiting_attack_click and tile_pos in attack_range_tiles:
			# Perform the attack action (you'll need to implement the attack logic here)
			selected_player.attack(tile_pos)

			# After attacking, allow the player to move again or perform further attacks
			awaiting_attack_click = false
			attack_range_tiles.clear()
			selected_player.clear_attack_tiles()  # Assuming this function exists

			# Optionally, allow for another movement or attack cycle
			# Allow multiple attacks or movement in cycles
			select_player(selected_player)  # Re-select to show available movement/attack options again
			return

		# Otherwise, check if a player unit is clicked to select it
		var players = get_tree().get_nodes_in_group("player_units")  # Ensure all player units are in the "player_units" group
		for player in players:
			# Check if the player's global position matches the clicked world position
			if player.global_position == world_pos:
				# If a player is clicked, select it and clear the current selection
				select_player(player)
				return

		# If clicked on an empty tile and not awaiting movement, clear the selection
		if selected_player and not awaiting_movement_click and not awaiting_attack_click:
			clear_selection()

# Function to select a player unit
func select_player(player: Area2D) -> void:
	# If there's an already selected player, clear its attack and movement tiles
	if selected_player and selected_player != player:
		clear_selection()

	# Set the new selected player
	selected_player = player
	selected_player.selected = true
	# Display its movement tiles and store the tiles within range
	movement_range_tiles = selected_player.get_movement_tiles()  # Assuming the player has this method
	selected_player.display_movement_tiles()  # Show movement tiles
	awaiting_movement_click = true  # Enable waiting for second click

	# Clear the attack tiles for all player units before selecting the new one
	clear_attack_tiles_for_all_players()

# Function to clear the previously selected player and their movement tiles
func clear_selection() -> void:
	# Clear movement tiles and deselect the current player
	clear_movement_tiles()
	movement_range_tiles.clear()
	awaiting_movement_click = false
	selected_player.selected = false
	selected_player = null

# Function to clear movement tiles after a move or deselection
func clear_movement_tiles() -> void:
	if selected_player.selected == true:
		selected_player.clear_movement_tiles()  # Hide movement tiles after move

# Function to clear the attack range tiles for all player units
func clear_attack_tiles_for_all_players() -> void:
	# Get all player units in the "player_units" group
	var players = get_tree().get_nodes_in_group("player_units")
	for player in players:
		# Call the clear_attack_range_tiles function for each player
		if player is Area2D:
			player.clear_attack_range_tiles()  # Assuming all player units have the `clear_attack_range_tiles` method
