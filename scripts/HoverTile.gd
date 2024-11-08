extends Node2D

# Reference to the TileMap
var tilemap: TileMap = null

# Reference to any detected soldier in the hovered tile
var hovered_soldier: Area2D = null

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

		# Check for a soldier at the tile position
		detect_soldier_at_tile(tile_pos)
	else:
		# Hide the hover tile when outside the map bounds
		visible = false
		clear_hovered_soldier()

# Function to check if the tile position is within the tilemap bounds
func is_within_bounds(tile_pos: Vector2i) -> bool:
	# Get the size of the tilemap (assuming rectangular bounds)
	var map_size: Vector2i = tilemap.get_used_rect().size

	# Check if the tile position is within the bounds of the tilemap
	return tile_pos.x >= 0 and tile_pos.y >= 0 and tile_pos.x < map_size.x and tile_pos.y < map_size.y

# Function to detect if a soldier unit is at a given tile position
func detect_soldier_at_tile(tile_pos: Vector2i) -> void:
	# Convert tile position to world position
	var world_pos = tilemap.map_to_local(tile_pos)

	# Check if any soldier (or other units) is at this world position
	var soldiers = get_tree().get_nodes_in_group("player_units")  # Make sure all soldiers are in the "Soldiers" group
	for soldier in soldiers:
		if soldier.global_position == world_pos:
			# If hovering over a new soldier, display its movement tiles
			if hovered_soldier != soldier:
				clear_hovered_soldier()  # Clear the previous soldier
				hovered_soldier = soldier
				hovered_soldier.display_movement_tiles()
			return

	# If no soldier is found at the position, clear any hovered soldier
	clear_hovered_soldier()

# Function to clear the previous hovered soldier
func clear_hovered_soldier() -> void:
	if hovered_soldier:
		hovered_soldier.clear_movement_tiles()
		hovered_soldier = null
