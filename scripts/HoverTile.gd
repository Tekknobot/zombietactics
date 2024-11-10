extends Node2D

# Reference to the TileMap
var tilemap: TileMap = null

# Reference to the currently selected player
var selected_player: Area2D = null

# Track if we are waiting for a second click within the movement or attack range
var awaiting_movement_click: bool = false
var awaiting_attack_click: bool = false  # Flag to track attack mode

# Store the movement range and attack range tiles
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
	# Check if the Space key is pressed
	if Input.is_action_just_pressed("space"):
		check_and_reset_turn()
			
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

		# Check if a player unit is clicked and display its movement or attack tiles
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

func check_for_click(tile_pos: Vector2i) -> void:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	# Convert tile position to world position (tilemap coordinates -> world coordinates)
	var world_pos = tilemap.map_to_local(tile_pos)  # tile_pos is Vector2i, world_pos will be Vector2

	# Check if the mouse button is clicked
	if Input.is_action_just_pressed("mouse_left"):  # Left-click for selecting a unit and toggling range
		# If we're awaiting a movement click, check if it's within movement range
		if awaiting_movement_click and tile_pos in movement_range_tiles:
			if selected_player:
				# Move the selected player to the target tile
				selected_player.move_player_to_target(tile_pos)

				# Clear old movement tiles and display new ones based on the player's updated position
				clear_movement_tiles()
				movement_range_tiles = selected_player.get_movement_tiles()  # Assuming the player has this method
				selected_player.display_movement_tiles()  # Show the updated movement tiles

				clear_movement_tiles()
				clear_attack_tiles_for_all_players()
			else:
				print("No player selected.")
			
		# If we're in attack mode and clicked on a valid attack range tile
		if awaiting_attack_click and tile_pos in attack_range_tiles:
			if selected_player:
				# Call attack logic here (e.g., perform attack)
				selected_player.attack_target(tile_pos)  # Assuming you have an attack method

				clear_movement_tiles()
				clear_attack_tiles_for_all_players()
			
		# Select a unit if clicked on one
		var players = get_tree().get_nodes_in_group("player_units")  # Ensure all player units are in the "player_units" group
		for player in players:
			# Check if the player's global position matches the clicked world position
			if player.global_position == world_pos:
				# If the player is already selected, toggle between movement and attack
				if selected_player == player:
					# Toggle mode between movement and attack
					if awaiting_attack_click:
						select_player(player, "movement")  # Toggle to movement
					else:
						select_player(player, "attack")  # Toggle to attack
				else:
					# Select the new player and show movement range by default
					select_player(player, "movement")
				return

	elif Input.is_action_just_pressed("mouse_right") and selected_player:  # Right-click for selecting a unit and showing attack range
		# Select a unit if clicked on one
		var players = get_tree().get_nodes_in_group("player_units")  # Ensure all player units are in the "player_units" group
		for player in players:
			# Check if the player's global position matches the clicked world position
			if player.global_position == world_pos:
				# If a player is clicked, show attack range
				select_player(player, "attack")
				return
		
# Function to select a player unit and show the appropriate range (movement or attack)
func select_player(player: Area2D, mode: String) -> void:
	# Set the new selected player
	selected_player = player
	selected_player.selected = true  # Set the selected flag
	
	# Display movement or attack range tiles
	if mode == "movement":
		movement_range_tiles = selected_player.get_movement_tiles()  # Assuming the player has this method
		selected_player.display_movement_tiles()  # Show movement tiles
		awaiting_movement_click = true  # Enable waiting for second click

		# Clear the attack tiles for all player units before selecting the new one
		clear_attack_tiles_for_all_players()
	elif mode == "attack":
		selected_player.display_attack_range_tiles()  # Show attack tiles
		awaiting_attack_click = true  # Enable waiting for second click

		# Clear the movement tiles for all player units before selecting the new one
		clear_movement_tiles()

# Function to clear movement tiles after a move or deselection
func clear_movement_tiles() -> void:
	# Get all player units in the "player_units" group
	var players = get_tree().get_nodes_in_group("player_units")
	for player in players:
		# Call the clear_movement_tiles function for each player
		if player is Area2D:
			player.clear_movement_tiles()  # Assuming all player units have the `clear_movement_tiles` method

# Function to clear the attack range tiles for all player units
func clear_attack_tiles_for_all_players() -> void:
	# Get all player units in the "player_units" group
	var players = get_tree().get_nodes_in_group("player_units")
	for player in players:
		# Call the clear_attack_range_tiles function for each player
		if player is Area2D:
			player.clear_attack_range_tiles()  # Assuming all player units have the `clear_attack_range_tiles` method

# Function to check if all player units have moved and attacked
func check_and_reset_turn() -> void:
	var all_units_moved_and_attacked = true
	var players = get_tree().get_nodes_in_group("player_units")  # Get all player units

	# Check if all units have moved and attacked
	for player in players:
		# Check if any unit has not moved or attacked
		if not player.has_moved or not player.has_attacked:
			all_units_moved_and_attacked = false
			break

	# If all units have completed their actions, reset their flags and make them selectable again
	if all_units_moved_and_attacked:
		for player in players:
			player.has_moved = false  # Reset move flag
			player.has_attacked = false  # Reset attack flag
			player.selected = false  # Deselect the player to make it selectable again

		# Deselect the previously selected player (if any)
		if selected_player:
			selected_player.selected = false  # Deselect the selected player

		# Optionally, you can display a message or perform additional actions here
		print("All units have completed their turn. Flags reset, units are selectable again.")
	else:
		# If not all units have moved and attacked, print an informative message
		print("Not all units have completed their turn yet.")

	# Ensure that the players are now selectable again after turn reset
	enable_all_players_for_selection()

# Function to re-enable all players for selection
func enable_all_players_for_selection() -> void:
	var players = get_tree().get_nodes_in_group("player_units")  # Get all player units
	for player in players:
		player.selected = false  # Ensure all players are deselected and ready for re-selection
