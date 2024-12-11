extends Node2D

# Configurable Properties
@export var ability_range: float = 300.0 # Max range of the ability in pixels
@export var cone_angle: float = 45.0 # Angle of the cone in degrees
@export var bullets_per_second: int = 20 # Rate of fire
@export var cooldown_time: float = 5.0 # Cooldown time in seconds
@export var duration: float = 2.0 # How long the ability lasts in seconds
@export var projectile_scene: PackedScene # Reference to the projectile scene

# Internal State
var is_on_cooldown: bool = false
var is_firing: bool = false
var firing_time: float = 0.0

@export var hover_tile_path: NodePath = "/root/MapManager/HoverTile"
@onready var hover_tile = get_node_or_null(hover_tile_path)

# Signals
signal ability_used

func _ready():
	pass

func _process(delta):
	is_mouse_over_gui()

func _input(event):
	# Check for mouse click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Block gameplay input if the mouse is over GUI
		if is_mouse_over_gui():
			print("Input blocked by GUI.")
			return  # Prevent further input handling

		# Reference the TileMap node
		var tilemap: TileMap = get_node("/root/MapManager/TileMap")

		# Get the boundaries of the map's used rectangle
		var map_size = tilemap.get_used_rect()  # Rect2: position and size of the used tiles
		var map_origin_x = map_size.position.x  # Starting x-coordinate of the used rectangle
		var map_origin_y = map_size.position.y  # Starting y-coordinate of the used rectangle
		var map_width = map_size.size.x         # Width of the map in tiles
		var map_height = map_size.size.y        # Height of the map in tiles

		var global_mouse_position = get_global_mouse_position() 
		global_mouse_position.y += 8
			
		# Convert the global mouse position to tile coordinates
		var mouse_local = tilemap.local_to_map(global_mouse_position)

		# Check if the mouse is outside the bounds of the used rectangle
		if mouse_local.x < map_origin_x or mouse_local.x >= map_origin_x + map_width or \
		   mouse_local.y < map_origin_y or mouse_local.y >= map_origin_y + map_height:
			return  # Exit the function if the mouse is outside the map
						
		# Ensure hover_tile exists and "Sarah Reese" is selected
		if hover_tile and hover_tile.selected_player and hover_tile.selected_player.player_name == "Angel. Charlie" and GlobalManager.barrage_toggle_active == true:
			#var tilemap: TileMap = get_node("/root/MapManager/TileMap")
			var mouse_position = get_global_mouse_position() 
			mouse_position.y += 8
			var mouse_pos = tilemap.local_to_map(mouse_position)
			var mouse_on_tile = tilemap.map_to_local(mouse_pos)
						
			activate_ability(mouse_on_tile)

func activate_ability(mouse_on_tile: Vector2):
	if is_on_cooldown or is_firing:
		return # Exit if already firing or on cooldown

	is_firing = true
	firing_time = duration
	emit_signal("ability_used")
	start_firing(mouse_on_tile)

	# Start cooldown after firing completes
	await get_tree().create_timer(duration).timeout
	is_firing = false
	is_on_cooldown = true

	await get_tree().create_timer(duration).timeout
	is_on_cooldown = false

func start_firing(mouse_on_tile: Vector2):
	# Fire the barrage once
	fire_bullets_at_tile_and_surroundings(mouse_on_tile)
	
	# Start cooldown after firing
	is_firing = false
	is_on_cooldown = true
	await get_tree().create_timer(cooldown_time).timeout
	is_on_cooldown = false

	var hud_manager = get_parent().get_parent().get_parent().get_node("HUDManager")  # Adjust the path if necessary
	hud_manager.hide_special_buttons()	
	
	# Access the 'special' button within HUDManager
	GlobalManager.barrage_toggle_active = false  # Deactivate the special toggle
	hud_manager.barrage.button_pressed = false
	self.get_parent().has_attacked = true
	self.get_parent().has_moved = true	
	
func fire_bullets_at_tile_and_surroundings(mouse_on_tile: Vector2):
	# Get the TileMap node
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")

	var global_mouse_position = get_global_mouse_position()
	global_mouse_position.y += 8

	# Get the center tile position in tilemap coordinates
	var center_tile_pos = tilemap.local_to_map(global_mouse_position)

	# Define relative positions for the 8 surrounding tiles + the center tile
	var relative_positions = [
		Vector2i(0, 0),   # Center
		Vector2i(-1, 0),  # Left
		Vector2i(1, 0),   # Right
		Vector2i(0, -1),  # Up
		Vector2i(0, 1),   # Down
		Vector2i(-1, -1), # Top-left
		Vector2i(1, -1),  # Top-right
		Vector2i(-1, 1),  # Bottom-left
		Vector2i(1, 1)    # Bottom-right
	]

	# Fire at each surrounding tile
	for offset in relative_positions:
		var target_tile_pos = center_tile_pos + offset
		var target_world_pos = tilemap.map_to_local(target_tile_pos)

		# Calculate direction to the target tile
		var direction_to_tile = (target_world_pos - global_position).normalized()

		# Get the current facing direction of the parent (1 for right, -1 for left)
		var current_facing = 1 if get_parent().scale.x > 0 else -1

		# Determine sprite flip based on target_position relative to the parent
		if mouse_on_tile.x > global_position.x and current_facing == 1:
			get_parent().scale.x = -abs(get_parent().scale.x)  # Flip to face left
		elif mouse_on_tile.x < global_position.x and current_facing == -1:
			get_parent().scale.x = abs(get_parent().scale.x)  # Flip to face right
			
		# Spawn a projectile aimed at the tile
		spawn_projectile(global_position, direction_to_tile, target_world_pos)

		# Optional delay between shots for visual effect
		await get_tree().create_timer(0.1).timeout

	# Check end turn conditions after firing
	get_parent().check_end_turn_conditions()

func spawn_projectile(start_position: Vector2, direction: Vector2, target: Vector2):
	if projectile_scene == null:
		print("Error: Projectile scene is not assigned!")
		return

	# Get the TileMap node
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")

	# Snap mouse position to tile center
	var mouse_tile_pos = tilemap.local_to_map(target)
	var snapped_target_position = tilemap.map_to_local(mouse_tile_pos)

	# Calculate the ability range dynamically
	var ability_range = start_position.distance_to(snapped_target_position)

	# Instantiate and configure the projectile
	var projectile_instance = projectile_scene.instantiate() as Node2D
	projectile_instance.position = start_position
	projectile_instance.direction = direction.normalized()  # Set the direction vector
	projectile_instance.range = ability_range  # Pass the calculated range
	projectile_instance.speed = 200.0  # Adjust if needed
	projectile_instance.attacker = self.get_parent()  # Set the firing unit as the attacker
	
	# Add projectile to the scene
	tilemap.add_child(projectile_instance)

func is_mouse_over_gui() -> bool:
	# Get global mouse position
	var mouse_pos = get_viewport().get_mouse_position()

	# Get all nodes in the "hud_controls" group
	var hud_controls = get_tree().get_nodes_in_group("portrait_controls") + get_tree().get_nodes_in_group("hud_controls")
	for control in hud_controls:
		if control is TextureRect or Button and control.is_visible_in_tree():
			# Use global rect to check if mouse is over the button
			var rect = control.get_global_rect()
			print("Checking button:", control.name, "Rect:", rect, "Mouse Pos:", mouse_pos)
			if rect.has_point(mouse_pos):
				print("Mouse is over button:", control.name, "Rect:", rect, "Mouse Pos:", mouse_pos)
				return true
	print("Mouse is NOT over any button.")
	return false
