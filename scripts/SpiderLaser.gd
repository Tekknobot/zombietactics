extends Node2D

@export var laser_color_1: Color = Color(1, 0, 0, 1)  # First color
@export var laser_color_2: Color = Color(0, 1, 0, 1)  # Second color
@export var laser_color_3: Color = Color(0, 0, 1, 1)  # Third color

@export var laser_width: float = 5.0  # Default width of the laser
@export var laser_length: float = 300.0  # Max length of the laser
@export var hover_tile_path: NodePath = "/root/MapManager/HoverTile"

@onready var line = $Line2D  # Line2D node for the laser
@onready var hover_tile = get_node_or_null(hover_tile_path)

# Animation state variables
var color_timer: Timer
var width_pulse_up: bool = true
var pulse_speed: float = 5.0  # Speed of pulsing
var color_cycle: Array  # Array to store the three colors
var current_color_index: int = 0  # Index for cycling through colors

var laser_deployed: bool = false

func _ready():
	# Initialize color cycle
	color_cycle = [laser_color_1, laser_color_2, laser_color_3]
	
	# Set up the laser
	line.width = laser_width
	line.default_color = laser_color_1  # Start with the first color
	line.visible = false  # Hide laser initially

func _input(event):
	# Check for mouse click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Ensure hover_tile exists and "Sarah Reese" is selected
		if hover_tile and hover_tile.selected_player and hover_tile.selected_player.player_name == "Sarah. Reese":
			var tilemap: TileMap = get_node("/root/MapManager/TileMap")
			var mouse_position = get_global_mouse_position() 
			mouse_position.y += 8
			var mouse_pos = tilemap.local_to_map(mouse_position)
			var laser_target = tilemap.map_to_local(mouse_pos)
			laser_target.y -= 8
			deploy_laser(laser_target)

func deploy_laser(target_position: Vector2):
	# Get the current facing direction of the parent (1 for right, -1 for left)
	var current_facing = 1 if get_parent().scale.x > 0 else -1

	# Determine sprite flip based on target_position relative to the parent
	if target_position.x > global_position.x and current_facing == 1:
		get_parent().scale.x = -abs(get_parent().scale.x)  # Flip to face left
	elif target_position.x < global_position.x and current_facing == -1:
		get_parent().scale.x = abs(get_parent().scale.x)  # Flip to face right

	# Calculate laser path across tiles
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")

	# Get cell size from the tilemap
	var cell_size = Vector2(32, 32)
	
	var start = tilemap.local_to_map(Vector2(global_position.x, global_position.y - 16))
	start = Vector2i(start.x - 1, start.y)
	var end = tilemap.local_to_map(Vector2(target_position.x, target_position.y - 16))

	# Use a Bresenham line algorithm to get all tiles along the laser path
	var tiles = get_line_tiles(start, end)

	# Clear previous laser segments
	for child in get_children():
		if child is Line2D:
			child.queue_free()

	# Create a Line2D for each tile, layered correctly
	for i in range(tiles.size() - 1):
		var tile_pos = tiles[i]
		var segment_start = tilemap.map_to_local(tile_pos) + cell_size / 2
		var segment_end = tilemap.map_to_local(tiles[i + 1]) + cell_size / 2

		# Check if there's a building or unit in the tile
		var height_offset = 0
		var segment_color = color_cycle[current_color_index]  # Default color from cycle
		if is_structure(tile_pos) or is_unit_present(tile_pos):
			height_offset = 1  # Add a height offset for objects
			segment_color = laser_color_3  # Example: Use the third color for obstacles

		# Create a Line2D node for this segment
		var segment = Line2D.new()
		add_child(segment)

		# Update z_index for layering based on tile position and height offset
		segment.z_index = (tile_pos.x + tile_pos.y) - height_offset

		segment.width = laser_width
		segment.default_color = segment_color  # Apply the determined color

		# Add points to the Line2D
		segment.add_point(to_local(segment_start))
		segment.add_point(to_local(segment_end))


		laser_deployed = true
	
func get_line_tiles(start: Vector2i, end: Vector2i) -> Array:
	var tiles = []
	var dx = abs(end.x - start.x)
	var dy = abs(end.y - start.y)
	var sx = 1 if start.x < end.x else -1
	var sy = 1 if start.y < end.y else -1
	var err = dx - dy

	var current = start
	while current != end:
		tiles.append(current)
		var e2 = err * 2
		if e2 > -dy:
			err -= dy
			current.x += sx
		if e2 < dx:
			err += dx
			current.y += sy

	tiles.append(end)  # Include the last tile
	return tiles

# Check if there is a structure on the tile or surrounding tiles
func is_structure(tile_pos: Vector2i) -> bool:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var structures = get_tree().get_nodes_in_group("structures")
	
	# Iterate through the tile and its surrounding 8 tiles
	for x_offset in range(-1, 2):
		for y_offset in range(-1, 2):
			var check_tile = tile_pos + Vector2i(x_offset, y_offset)
			for structure in structures:
				var structure_tile_pos = tilemap.local_to_map(structure.global_position)
				if check_tile == structure_tile_pos:
					return true
	return false

# Check if there is a unit on the tile or surrounding tiles
func is_unit_present(tile_pos: Vector2i) -> bool:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var all_units = get_tree().get_nodes_in_group("player_units") + get_tree().get_nodes_in_group("zombies")
	
	# Iterate through the tile and its surrounding 8 tiles
	for x_offset in range(-1, 2):
		for y_offset in range(-1, 2):
			var check_tile = tile_pos + Vector2i(x_offset, y_offset)
			for unit in all_units:
				var unit_tile_pos = tilemap.local_to_map(unit.global_position)
				if check_tile == unit_tile_pos:
					return true
	return false

	
func _process(delta):
	if laser_deployed == true:
		get_parent().get_child(0).play("attack")		
