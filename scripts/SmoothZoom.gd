extends Camera2D

@export var zoom_target: Vector2 = Vector2(2, 2)  # Default zoom (already zoomed in by 2x)
@export var zoom_focus: Vector2 = Vector2(3, 3)  # Focus zoom level (closer than default)
@export var zoom_speed: float = 5.0  # Speed of zoom transition
@export var focus_duration: float = 1.5  # Duration of the zoom focus

var is_zooming_in = false
var is_zooming_out = false
var target_tile_pos: Vector2 = Vector2.ZERO  # Tile position to focus on
var return_to_default_timer: Timer = null

var is_mouse_wheel_down = false
var is_mouse_wheel_up = false

var target_zoom = Vector2.ONE

# Variables to store the original camera settings
var original_position: Vector2 = Vector2.ZERO
var original_zoom: Vector2 = Vector2(2, 2)

# Variables for dragging mechanic
var is_dragging = false
var drag_start_mouse_position: Vector2 = Vector2.ZERO
var drag_start_camera_position: Vector2 = Vector2.ZERO

signal zoom_completed

@export var map_manager: Node2D
@export var tilemap: TileMap

func _ready():
	# Initialize the return timer
	return_to_default_timer = Timer.new()
	add_child(return_to_default_timer)
	return_to_default_timer.one_shot = true
	return_to_default_timer.connect("timeout", Callable(self, "_on_return_to_default_timeout"))

	# Ensure the nodes are ready before focusing
	call_deferred("_initialize_focus")

func _initialize_focus():
	if not map_manager or not tilemap:
		# Ensure map_manager and tilemap are present
		print("MapManager or TileMap is not set!")
		return

	# Focus on the tile after ensuring nodes are ready
	focus_on_tile(tilemap, Vector2i(map_manager.grid_width / 2, map_manager.grid_height / 2))
	
	#await get_tree().create_timer(1).timeout
	#is_mouse_wheel_down = true
	#target_zoom = Vector2(1,1)
	
func focus_on_tile(tilemap: TileMap, tile_coords: Vector2i):
	# Save the original position and zoom before focusing
	original_position = position
	original_zoom = zoom

	# Convert tile coordinates to world coordinates
	target_tile_pos = tilemap.map_to_local(tile_coords)
	is_zooming_in = true
	is_zooming_out = false

func _process(delta):
	if is_zooming_in:
		is_mouse_wheel_down = false
		is_mouse_wheel_up = false
		# Smoothly move the camera to the tile position
		position = position.lerp(target_tile_pos, zoom_speed * delta)
		# Smoothly zoom in
		zoom = zoom.lerp(zoom_focus, zoom_speed * delta)
		# Check if the zoom and position are close enough
		if position.distance_to(target_tile_pos) < 15 and zoom.distance_to(zoom_focus) < 15:
			is_zooming_in = false
			emit_signal("zoom_completed")  # Notify that zooming in is complete
			return_to_default_timer.start(focus_duration)  # Start the timer to return to default
	elif is_zooming_out:
		is_mouse_wheel_down = false
		is_mouse_wheel_up = false		
		# Smoothly return to the original position and zoom
		position = position.lerp(original_position, zoom_speed * delta)
		zoom = zoom.lerp(original_zoom, zoom_speed * delta)
		if position.distance_to(original_position) < 15 and zoom.distance_to(original_zoom) < 15:
			is_zooming_out = false
			emit_signal("zoom_completed") 
			 # Notify that zooming in is complete

	if is_mouse_wheel_up and is_zooming_in == false:
		zoom = zoom.lerp(target_zoom, zoom_speed * delta)
	elif is_mouse_wheel_down and is_zooming_in == false:
		zoom = zoom.lerp(target_zoom, zoom_speed * delta)

	# Handle dragging mechanic
	if is_dragging:
		var mouse_delta = drag_start_mouse_position - get_viewport().get_mouse_position()
		position = drag_start_camera_position + mouse_delta / zoom

func _input(event):
	# Handle mouse button press
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:  # Middle mouse button
			if event.pressed:
				# Start dragging
				is_dragging = true
				drag_start_mouse_position = get_viewport().get_mouse_position()
				drag_start_camera_position = position
			else:
				# Stop dragging
				is_dragging = false
				
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:	
			is_mouse_wheel_down = true
			target_zoom = Vector2(1,1)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			is_mouse_wheel_up = true	
			target_zoom = Vector2(2,2)
			

func _on_return_to_default_timeout():
	is_zooming_out = false

func focus_on_trajectory(point: Vector2):
	is_zooming_in = true
	target_tile_pos = point
	
func focus_on_position(target_position: Vector2):
	is_zooming_in = true
	target_tile_pos = target_position	
