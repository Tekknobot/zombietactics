extends Node2D

@export var laser_color_1: Color = Color(1, 0, 0, 1)  # First color
@export var laser_color_2: Color = Color(0, 1, 0, 1)  # Second color
@export var laser_color_3: Color = Color(0, 0, 1, 1)  # Third color

@export var laser_width: float = 5.0  # Default width of the laser
@export var laser_length: float = 300.0  # Max length of the laser
@export var hover_tile_path: NodePath = "/root/MapManager/HoverTile"
@export var pulse_duration: float = 0.1  # Time between pulses

@onready var line = $Line2D  # Line2D node for the laser
@onready var hover_tile = get_node_or_null(hover_tile_path)

# Animation state variables
var color_timer: Timer
var width_pulse_up: bool = true
var pulse_speed: float = 5.0  # Speed of pulsing
var color_cycle: Array  # Array to store the three colors
var current_color_index: int = 0  # Index for cycling through colors
var laser_segments: Array = []  # Store references to all laser segments
var current_segment_index: int = 0  # Tracks the segment being animated

var laser_deployed: bool = false
var pulsing_segments: Array = []  # Array to track which segments are pulsing

func _ready():
	# Initialize color cycle
	color_cycle = [laser_color_1, laser_color_2, laser_color_3]
	
	# Set up the laser
	line.width = laser_width
	line.default_color = laser_color_1  # Start with the first color
	line.visible = false  # Hide laser initially

	# Create the timer for the pulse effect
	var pulse_timer = Timer.new()
	pulse_timer.wait_time = pulse_duration
	pulse_timer.one_shot = false
	pulse_timer.connect("timeout", Callable(self, "_on_pulse_timer_timeout"))
	add_child(pulse_timer)
	pulse_timer.start()

func _process(delta):
	for segment in pulsing_segments:
		# Check if width is expanding or contracting
		if segment.width < laser_width * 3 and width_pulse_up:
			segment.width += pulse_speed * delta
			if segment.width >= laser_width * 3:
				width_pulse_up = false  # Switch to contracting
		elif segment.width > laser_width and not width_pulse_up:
			segment.width -= pulse_speed * delta
			if segment.width <= laser_width:
				segment.width = laser_width
				width_pulse_up = true  # Reset for next pulse

				# Remove the segment from pulsing_segments once pulsing is complete
				pulsing_segments.erase(segment)

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
	laser_segments.clear()  # Clear the list of segments
	for child in get_children():
		if child is Line2D:
			child.queue_free()

	# Create a Line2D for each tile, layered correctly
	for i in range(tiles.size() - 1):
		var tile_pos = tiles[i]
		var segment_start = tilemap.map_to_local(tile_pos) + cell_size / 2
		var segment_end = tilemap.map_to_local(tiles[i + 1]) + cell_size / 2

		var height_offset = 0
		var segment_color = color_cycle[current_color_index]  # Default color from cycle

		# Create a Line2D node for this segment
		var segment = Line2D.new()
		add_child(segment)
		laser_segments.append(segment)  # Store the segment reference

		var segment_rect = Rect2(segment.global_position, Vector2(32, 32))  # Create the rect with the correct position and size

		# Check overlap with structures
		var structures = get_tree().get_nodes_in_group("structures")
		for structure in structures:
			if Rect2(structure.global_position, Vector2(32, 32)).intersects(segment_rect):
				segment_color = laser_color_3
				height_offset = structure.layer

		# Check overlap with units
		var all_units = get_tree().get_nodes_in_group("player_units") + get_tree().get_nodes_in_group("zombies")
		for unit in all_units:
			if Rect2(unit.global_position, Vector2(32, 32)).intersects(segment_rect):
				segment_color = laser_color_3
				height_offset = unit.layer

		# Update z_index for layering based on tile position and height offset
		segment.z_index = (tile_pos.x + tile_pos.y) - height_offset

		segment.width = laser_width
		segment.default_color = segment_color  # Apply the determined color

		# Add points to the Line2D
		segment.add_point(to_local(segment_start))
		segment.add_point(to_local(segment_end))

	laser_deployed = true

func _on_pulse_timer_timeout():
	if laser_segments.is_empty():
		return  # Skip if there are no laser segments

	if current_segment_index >= laser_segments.size():
		current_segment_index = 0  # Reset to the first segment

	# Reset all segments to their default state
	for segment in laser_segments:
		segment.width = laser_width
		segment.default_color = color_cycle[current_color_index]

	# Apply the pulse effect to the current segment
	var current_segment = laser_segments[current_segment_index]
	current_segment.width = laser_width * 2  # Start with increased width
	current_segment.default_color = laser_color_3  # Use the third color for the pulse

	# Add the current segment to the pulsing_segments array
	pulsing_segments.append(current_segment)

	# Move to the next segment
	current_segment_index += 1


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
