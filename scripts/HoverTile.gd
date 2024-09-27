extends Node2D

# Reference to the TileMap
var tilemap: TileMap

# Preload or export the walkable tile and attack tile prefabs
@export var walkable_tile_prefab: PackedScene
@export var attack_tile_prefab: PackedScene  # New prefab for attack highlights

# Array to hold instances of walkable tile markers
var walkable_tiles: Array = []
var attack_tiles: Array = []  # New array for attack highlights

# State variables for toggling visibility
var show_walkable: bool = false
var show_attack: bool = false
var current_unit_pos: Vector2i  # Store the currently selected unit position

func _ready() -> void:
	find_tilemap()  # Find the TileMap when the node is ready

# Function to dynamically find the tilemap
func find_tilemap() -> void:
	tilemap = get_parent().get_node("TileMap")  # Adjust this if necessary to match the actual path to your TileMap node
	if tilemap == null:
		#print("Tilemap not found.")
		pass

# Function to handle input events
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_left"):  # Check for left click
		handle_left_click()
	elif event.is_action_pressed("mouse_right"):  # Check for right click
		handle_right_click()

# Handle left click to toggle walkable tiles
func handle_left_click() -> void:
	if tilemap == null:
		#print("Tilemap is null; cannot process left click.")
		return  # Safety check

	var mouse_pos = get_global_mouse_position()
	mouse_pos.y += 8  # Adjust for any discrepancy
	var mouse_tile_pos: Vector2i = tilemap.local_to_map(tilemap.to_local(mouse_pos))

	# Clear attack tiles if they are currently shown
	if show_attack:
		clear_attack_tiles()
		show_attack = false

	# Loop through all unit positions in the global array and check if the mouse is hovering over any of them
	for unit_pos in GlobalManager.unit_positions:
		if mouse_tile_pos == unit_pos:
			print("Left click on unit at tile: " + str(unit_pos))
			# Toggle walkable tiles for this unit
			if show_walkable and current_unit_pos == unit_pos:
				clear_walkable_tiles()  # Clear if already showing
				show_walkable = false
			else:
				current_unit_pos = unit_pos  # Update current unit position
				show_walkable_tiles(unit_pos)
				show_walkable = true
			return  # Exit early if clicking on a unit

	# If no unit is clicked, clear walkable tiles
	if show_walkable:
		clear_walkable_tiles()
		show_walkable = false

# Handle right click to toggle attack tiles
func handle_right_click() -> void:
	if tilemap == null:
		#print("Tilemap is null; cannot process right click.")
		return  # Safety check

	var mouse_pos = get_global_mouse_position()
	mouse_pos.y += 8  # Adjust for any discrepancy
	var mouse_tile_pos: Vector2i = tilemap.local_to_map(tilemap.to_local(mouse_pos))

	# Clear walkable tiles if they are currently shown
	if show_walkable:
		clear_walkable_tiles()
		show_walkable = false

	# Loop through all unit positions in the global array and check if the mouse is hovering over any of them
	for unit_pos in GlobalManager.unit_positions:
		if mouse_tile_pos == unit_pos:
			print("Right click on unit at tile: " + str(unit_pos))
			# Toggle attack tiles for this unit
			if show_attack and current_unit_pos == unit_pos:
				clear_attack_tiles()  # Clear if already showing
				show_attack = false
			else:
				current_unit_pos = unit_pos  # Update current unit position
				show_attack_tiles(unit_pos)
				show_attack = true
			return  # Exit early if clicking on a unit

	# If no unit is clicked, clear attack tiles
	if show_attack:
		clear_attack_tiles()
		show_attack = false

# Function to display walkable tiles around the hovered unit
func show_walkable_tiles(unit_pos: Vector2i) -> void:
	# First, clear any previously shown walkable tiles
	clear_walkable_tiles()

	# Assuming each unit has a defined movement range, e.g., 2 adjacent tiles in any direction
	var move_range: int = 2

	# Loop through all tiles within the movement range using Manhattan Distance
	for x_offset in range(-move_range, move_range + 1):
		for y_offset in range(-move_range, move_range + 1):
			# Check if the tile is within the movement range (Manhattan Distance)
			if abs(x_offset) + abs(y_offset) <= move_range:
				# Calculate the walkable tile position
				var walkable_tile_pos: Vector2i = unit_pos + Vector2i(x_offset, y_offset)
				
				# Check if the tile is within the map bounds
				if tilemap.get_used_rect().has_point(walkable_tile_pos):
					# Instance the walkable tile prefab and place it at the corresponding position
					var walkable_tile_instance = walkable_tile_prefab.instantiate()
					tilemap.add_child(walkable_tile_instance)
					
					# Convert the walkable tile position to global coordinates and set the position of the instance
					walkable_tile_instance.position = tilemap.map_to_local(walkable_tile_pos)
					
					# Add it to the walkable_tiles array to keep track
					walkable_tiles.append(walkable_tile_instance)

# Function to display attack tiles around the hovered unit
func show_attack_tiles(unit_pos: Vector2i) -> void:
	# Clear any previously shown attack tiles
	clear_attack_tiles()

	# Assuming each unit has a defined attack range, e.g., 2 tiles in all directions
	var attack_range: int = 2

	# Loop through all tiles within the attack range using Manhattan Distance
	for x_offset in range(-attack_range, attack_range + 1):
		for y_offset in range(-attack_range, attack_range + 1):
			# Check if the tile is within the attack range (Manhattan Distance)
			if abs(x_offset) + abs(y_offset) <= attack_range:
				# Calculate the attack tile position
				var attack_tile_pos: Vector2i = unit_pos + Vector2i(x_offset, y_offset)

				# Check if the tile is within the map bounds
				if tilemap.get_used_rect().has_point(attack_tile_pos):
					# Instance the attack tile prefab and place it at the corresponding position
					var attack_tile_instance = attack_tile_prefab.instantiate()
					tilemap.add_child(attack_tile_instance)
					
					# Convert the attack tile position to global coordinates and set the position of the instance
					attack_tile_instance.position = tilemap.map_to_local(attack_tile_pos)
					
					# Add it to the attack_tiles array to keep track
					attack_tiles.append(attack_tile_instance)

# Function to clear all walkable tiles from the scene
func clear_walkable_tiles() -> void:
	# Loop through all walkable tiles and remove them
	for tile in walkable_tiles:
		tile.queue_free()

	# Clear the walkable_tiles array
	walkable_tiles.clear()

# Function to clear all attack tiles from the scene
func clear_attack_tiles() -> void:
	# Loop through all attack tiles and remove them
	for tile in attack_tiles:
		tile.queue_free()

	# Clear the attack_tiles array
	attack_tiles.clear()
