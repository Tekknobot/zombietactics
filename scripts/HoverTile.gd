extends Node2D

# Reference to the TileMap
var tilemap: TileMap = null

# Reference to the currently hovered player
var hovered_player: Area2D = null

# Reference to the currently selected player
var selected_player: Area2D = null

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
	# Get the size of the tilemap (assuming rectangular bounds)
	var map_size: Vector2i = tilemap.get_used_rect().size

	# Check if the tile position is within the bounds of the tilemap
	return tile_pos.x >= 0 and tile_pos.y >= 0 and tile_pos.x < map_size.x and tile_pos.y < map_size.y

# Function to check for player unit clicks
func check_for_click(tile_pos: Vector2i) -> void:
	# Convert tile position to world position
	var world_pos = tilemap.map_to_local(tile_pos)

	# Check if the mouse button is clicked
	if Input.is_action_just_pressed("mouse_left"):  # Use your preferred click action
		# Check if any player unit is clicked
		var players = get_tree().get_nodes_in_group("player_units")  # Ensure all player units are in the "player_units" group
		for player in players:
			if player.global_position == world_pos:
				# If a player is clicked, select it
				if selected_player != player:
					select_player(player)
				return

		# If clicked on an empty tile, clear the movement tiles
		if selected_player:
			clear_hovered_player()

# Function to select a player unit
func select_player(player: Area2D) -> void:
	# If there's an already selected player, clear its movement tiles
	if selected_player:
		clear_hovered_player()

	# Set the new selected player
	selected_player = player
	# Display its movement tiles
	selected_player.display_movement_tiles()

# Function to clear the previously selected player and their movement tiles
func clear_hovered_player() -> void:
	if selected_player:
		selected_player.clear_movement_tiles()
		selected_player = null
