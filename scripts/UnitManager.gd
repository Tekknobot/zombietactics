extends Node2D

# Unit properties
var tile_pos: Vector2i  # Unit's current position in the tile grid
var is_moving: bool = false  # Flag to check if the unit is currently moving
var is_selected: bool = false  # Flag to check if the unit is selected

# Public variables (can be adjusted per unit)
@export var movement_range: int = 3  # Default movement range

# Reference to the TileMap
var tilemap: TileMap = null

# Walkable tile prefab for visualization (set up as an instance in your scene)
var walkable_tile_prefab: PackedScene = preload("res://assets/scenes/UI/move_tile.tscn")
var walkable_tiles: Array = []  # Stores references to walkable tile indicators

# Reference to the unit's sprite
var sprite: AnimatedSprite2D = null

var last_position: Vector2  # Variable to store the last position of the unit

# Called when the node enters the scene
func _ready() -> void:
	# Find the TileMap node in the scene
	tilemap = get_tree().get_root().get_node("MapManager/TileMap")  # Adjust path based on your scene structure

	# Initialize the unit's position in the tile grid based on its current world position
	tile_pos = tilemap.local_to_map(position)

	# Reference the sprite (assuming it's a direct child of the unit)
	sprite = $AnimatedSprite2D  # Adjust based on your node structure

	# Set the initial z_index based on the tile position
	update_z_index()

	# Debugging: Print initial position
	print("Unit initialized at tile: ", tile_pos)
	
	# Initialize the last position when the unit is ready
	last_position = position	

func move_to_tile(target_tile_pos: Vector2i) -> void:
	if is_moving:
		return  # Ignore input if the unit is currently moving

	# Calculate the distance to the target tile
	var distance = abs(tile_pos.x - target_tile_pos.x) + abs(tile_pos.y - target_tile_pos.y)

	# Check if the target tile is within the unit's movement range (using Manhattan distance)
	if distance <= movement_range:
		is_moving = true  # Lock the unit while it's moving

		# Store the last position before moving
		last_position = position

		# Get the world position of the target tile
		var target_world_pos = tilemap.map_to_local(target_tile_pos)

		# Move the unit to the target tile's world position
		position = target_world_pos

		# Determine the direction of movement based on current and last position
		if position.x > last_position.x:
			scale.x = -1  # Facing right (East)
		elif position.x < last_position.x:
			scale.x = 1  # Facing left (West)
		
		# Update the unit's tile position
		tile_pos = target_tile_pos

		# Update the z_index based on the new tile position
		update_z_index()

		# Simulate movement time (0.5 seconds in this case)
		await get_tree().create_timer(0.5).timeout

		is_moving = false  # Unlock the unit after movement

		print("Unit moved to tile: ", tile_pos)  # Debugging
	else:
		print("Target tile is out of range.")
		
# Update the z_index based on the unit's tile position
func update_z_index() -> void:
	# Typically, z-index is based on the y-coordinate so units further down are drawn on top
	z_index = (tile_pos.x + tile_pos.y) + 1
	

func show_walkable_tiles() -> void:
	clear_walkable_tiles()  # Clear any existing indicators

	# Loop over all possible tiles within movement range using Manhattan distance
	for x_offset in range(-movement_range, movement_range + 1):
		for y_offset in range(-movement_range, movement_range + 1):
			if abs(x_offset) + abs(y_offset) <= movement_range:
				var walkable_tile_pos = tile_pos + Vector2i(x_offset, y_offset)

				# Only instantiate if the position is valid on the map
				if tilemap.get_used_rect().has_point(walkable_tile_pos):
					var walkable_tile = walkable_tile_prefab.instantiate()
					var walkable_world_pos = tilemap.map_to_local(walkable_tile_pos)
					walkable_tile.position = walkable_world_pos

					# Add the walkable tile to the TileMap
					tilemap.add_child(walkable_tile)
					walkable_tiles.append(walkable_tile)

					print("Placing walkable tile at: ", walkable_tile_pos)  # Debugging line


# Clear all walkable tile markers
func clear_walkable_tiles() -> void:
	for tile in walkable_tiles:
		tile.queue_free()
	walkable_tiles.clear()

# Handle input events (clicks)
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_left"):
		# Get the tile position of the mouse click
		var mouse_pos = get_global_mouse_position()
		mouse_pos.y += 8  # Adjust offset if necessary

		# Convert the mouse position to tile coordinates
		var target_tile_pos = tilemap.local_to_map(tilemap.to_local(mouse_pos))

		# If the unit is clicked, toggle selection and show walkable tiles
		if !is_moving and tile_pos == target_tile_pos:
			is_selected = !is_selected  # Toggle selection
			if is_selected:
				show_walkable_tiles()  # Show movement options when selected
			else:
				clear_walkable_tiles()  # Clear if deselected

		# If the unit is selected and the clicked tile is valid, move to that tile
		elif is_selected:
			move_to_tile(target_tile_pos)
			clear_walkable_tiles()  # Clear markers after movement
			is_selected = false  # Deselect after moving
