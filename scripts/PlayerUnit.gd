# PlayerUnit.gd
extends Area2D

# Declare the class
class_name PlayerUnit

# Movement range for the soldier
@export var movement_range: int = 3  # Adjustable movement range

# Packed scene for the movement tile (ensure you assign the movement tile scene in the editor)
@export var movement_tile_scene: PackedScene
@export var attack_tile_scene: PackedScene

# Store references to instantiated movement tiles for easy cleanup
var movement_tiles: Array[Node2D] = []

# Declare necessary variables for attack
@export var projectile_scene: PackedScene  # Packed scene for the projectile

# Store references to instantiated attack range tiles for easy cleanup
var attack_range_tiles: Array[Node2D] = []

# Soldier's current tile position
var tile_pos: Vector2i
var coord: Vector2
var layer: int

# Pathfinding system
var astar: AStarGrid2D = AStarGrid2D.new()

# Tilemap reference
@export var tilemap: TileMap = null
@onready var map_manager = get_parent().get_node("/root/MapManager")

# Pathfinding variables
var current_path: Array[Vector2i] = []  # Stores the path tiles
var path_index: int = 0  # Index for the current step in the path
var move_speed: float = 75.0  # Movement speed for the soldier

var is_zombie: bool = false

# Constants
var WATER_TILE_ID = 0  # Replace with the actual tile ID for water

@export var selected: bool = false

var speed = 200.0  # Speed of the projectile in pixels per second
var target_pos: Vector2  # Target position where the projectile is moving
var direction: Vector2  # Direction the projectile should move in

signal player_action_completed

# Player's health properties
var max_health: int = 100
var current_health: int = 100

# Player's portrait texture
@export var portrait_texture: Texture

# Player's name (optional)
@export var player_name: String

var hud: Control

# Player's health properties
var max_xp: int = 100
var current_xp: int = 25
var xp_for_next_level: int = 100  # Example threshold for level-up, if relevant
var current_level: int = 1

var attack_damage: int = 25

var can_display_tiles = true  # Global flag to track if tiles can be displayed

# Optional: Scene to instantiate for explosion effect
@export var explosion_scene: PackedScene
@export var explosion_radius: float = 1.0  # Radius to check for units at the target position

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D  # Adjust this path as necessary

@onready var audio_player = $AudioStreamPlayer2D  # Adjust the path as needed
@export var death_audio: AudioStream
@export var levelup_audio: AudioStream
@export var hurt_audio: AudioStream
@export var dog_hurt_audio: AudioStream
@export var mek_attack_audio = preload("res://audio/SFX/mek_attack.wav")

@onready var turn_manager = get_node("/root/MapManager/TurnManager")  # Reference to the SpecialToggleNode
@onready var item_manager = get_node("/root/MapManager/ItemManager")  # Reference to the SpecialToggleNode
@onready var mission_manager = get_node("/root/MapManager/MissionManager")  # Reference to the SpecialToggleNode

@onready var missile_manager = get_node("/root/MapManager/MissileManager")  # Reference to the SpecialToggleNode
@onready var dynamite_manager = get_node("/root/MapManager/DynamiteManager")  # Reference to the SpecialToggleNode

@onready var mek_manager = get_node("/root/MapManager/MekManager")  # Reference to the SpecialToggleNode

var has_moved: bool = false  # Tracks if the unit has moved this turn
var has_attacked: bool = false  # Tracks if the unit has attacked this turn
var has_used_turn: bool = false  # Tracks if it's currently this unit's turn

var can_start_turn: bool = false

var attack_range_visible: bool = false  # Variable to track if attack range is visible

@onready var health_ui = $HealthUI
@onready var xp_ui = $XPUI

@export var is_mek: bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if tilemap == null:
		print("Error: Tilemap is not set.")
		return
	
	update_tile_position()
	setup_astar()
	visualize_walkable_tiles()
	
# Called every frame
func _process(delta: float) -> void:		
	if map_manager.map_1:
		WATER_TILE_ID = 0
	elif map_manager.map_2:
		WATER_TILE_ID = 9
	elif map_manager.map_3:
		WATER_TILE_ID = 15
	elif map_manager.map_4:
		WATER_TILE_ID = 21
	else:
		print("Error: No map selected, defaulting WATER to 0.")
		WATER_TILE_ID = 0  # Fallback value if no map is selected
	
	if target_pos != position:  # Check if the projectile hasn't reached the target yet
		# Move the projectile in the direction at a constant speed
		position += direction * speed * delta  # Adjust position by speed and time per frame (delta)
		
		# Optionally, you can check if the projectile has reached or passed the target position
		if position.distance_to(target_pos) <= speed * delta:
			position = target_pos  # Ensure the projectile stops exactly at the target
			print("Projectile has reached the target!")
			queue_free()  # Destroy the projectile once it reaches the target (optional)	

	# Check if any zombie in the "zombies" group is moving
	var zombies = get_tree().get_nodes_in_group("zombies")
	var zombies_moving = false
	for zombie in zombies:
		if zombie.is_moving:  # If any zombie is moving, skip player input and prevent showing tiles
			zombies_moving = true
			#print("Zombie is moving, skipping player input.")
			break  # Exit early once we know a zombie is moving
	
	if zombies_moving:
		# Prevent tile display or any other player action
		return

	update_unit_ui()
		
	update_tile_position()
	move_along_path(delta)
	
	is_mouse_over_gui()
	
# Function to update the tile position based on the current Area2D position
func update_tile_position() -> void:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	tile_pos = tilemap.local_to_map(position)
	coord = tile_pos
	layer = (tile_pos.x + tile_pos.y) + 1
	self.z_index = layer

func update_unit_ui():
	health_ui.value = current_health
	health_ui.max_value = max_health
	
	xp_ui.value = current_xp
	xp_ui.max_value = max_xp

# Function to update the AStar grid based on the current tilemap state
func update_astar_grid() -> void:
	# Get the tilemap and determine its grid size
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var grid_width = tilemap.get_used_rect().size.x
	var grid_height = tilemap.get_used_rect().size.y
	
	# Set the size and properties of the AStar grid
	astar.size = Vector2i(grid_width, grid_height)
	astar.cell_size = Vector2(1, 1)  # Each cell corresponds to a single tile
	astar.default_compute_heuristic = 1  # Use Manhattan heuristic
	astar.diagonal_mode = 1              # Enable diagonal movement if desired
	
	# Clear any previous configuration to avoid conflicts
	astar.update()
	
	# Iterate over each tile in the tilemap to set walkable and non-walkable cells
	for x in range(grid_width):
		for y in range(grid_height):
			var tile_position = Vector2i(x, y)
			var tile_id = tilemap.get_cell_source_id(0, tile_position)
			
			# Determine if the tile should be walkable
			var is_solid = (tile_id == -1 or tile_id == WATER_TILE_ID 
							or is_structure(tile_position) 
							or is_unit_present(tile_position))
			
			# Mark the tile in the AStar grid
			astar.set_point_solid(tile_position, is_solid)

	print("AStar grid updated with size:", grid_width, "x", grid_height)

# Setup the AStarGrid2D with walkable tiles
func setup_astar() -> void:
	update_astar_grid()  # Update AStar grid to reflect current map state
	print("AStar grid setup completed.")

# Get all tiles within movement range based on Manhattan distance
func get_movement_tiles() -> Array[Vector2i]:
	var tiles_in_range: Array[Vector2i] = []
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	for x in range(-movement_range, movement_range + 1):
		for y in range(-movement_range, movement_range + 1):
			if abs(x) + abs(y) <= movement_range:
				var target_tile_pos: Vector2i = tile_pos + Vector2i(x, y)
				if tilemap.get_used_rect().has_point(target_tile_pos):
					tiles_in_range.append(target_tile_pos)

	return tiles_in_range

# Display movement tiles within range
func display_movement_tiles() -> void:
	# Check if any zombie in the "zombies" group is moving
	var zombies = get_tree().get_nodes_in_group("zombies")
	var zombies_moving = false
	for zombie in zombies:
		if zombie.is_moving:  # If any zombie is moving, skip player input and prevent showing tiles
			zombies_moving = true
			#print("Zombie is moving, skipping player input.")
			break  # Exit early once we know a zombie is moving
	
	if zombies_moving:
		# Prevent tile display or any other player action
		return

	# Update the HUD to reflect new stats
	var hud_manager = get_parent().get_parent().get_node("HUDManager")
	hud_manager.hide_special_buttons()	
		
			
	clear_movement_tiles()  # Clear existing movement tiles
	clear_attack_range_tiles()  # Clear existing attack range tiles before displaying new movement tiles

	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	for tile in get_movement_tiles():
		if is_tile_movable(tile):
			var world_pos: Vector2 = tilemap.map_to_local(tile)
			var movement_tile_instance: Node2D = movement_tile_scene.instantiate() as Node2D
			movement_tile_instance.position = world_pos
			tilemap.add_child(movement_tile_instance)
			movement_tiles.append(movement_tile_instance)

# Clear displayed movement tiles
func clear_movement_tiles() -> void:
	for tile in movement_tiles:
		tile.queue_free()
	movement_tiles.clear()

# Check if a tile is movable
func is_tile_movable(tile_pos: Vector2i) -> bool:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var tile_id = tilemap.get_cell_source_id(0, tile_pos)
	if is_water_tile(tile_id):
		return false
	if is_structure(tile_pos) or is_unit_present(tile_pos):
		return false
	return true

# Check if a tile is a water tile
func is_water_tile(tile_id: int) -> bool:
	var WATER_TILE_ID: int

	if map_manager.map_1:
		WATER_TILE_ID = 0
	elif map_manager.map_2:
		WATER_TILE_ID = 9
	elif map_manager.map_3:
		WATER_TILE_ID = 15
	elif map_manager.map_4:
		WATER_TILE_ID = 21
	else:
		print("Error: No map selected, defaulting WATER to 0.")
		WATER_TILE_ID = 0  # Fallback value if no map is selected

	# Return whether the tile_id matches the WATER_TILE_ID
	return tile_id == WATER_TILE_ID

# Check if there is a structure on the tile
func is_structure(tile_pos: Vector2i) -> bool:
	var structures = get_tree().get_nodes_in_group("structures")
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	for structure in structures:
		var structure_tile_pos = tilemap.local_to_map(tilemap.to_local(structure.global_position))
		if tile_pos == structure_tile_pos:
			return true
	return false

# Check if there is a unit on the tile
func is_unit_present(tile_pos: Vector2i) -> bool:
	var all_units = get_tree().get_nodes_in_group("player_units") + get_tree().get_nodes_in_group("zombies")
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	for unit in all_units:
		var unit_tile_pos = tilemap.local_to_map(tilemap.to_local(unit.global_position))
		if tile_pos == unit_tile_pos:
			return true
	return false

# Function to calculate the path
func calculate_path(target_tile: Vector2i) -> void:
	# Make sure the start tile (soldier's current position) is valid
	var start_tile = tile_pos
	
	# Check if target tile is walkable
	if is_tile_movable(target_tile):
		# Calculate the path using AStar (this returns a PackedVector2Array)
		var astar_path: PackedVector2Array = astar.get_point_path(start_tile, target_tile)
		
		# Convert PackedVector2Array to Array[Vector2i]
		current_path.clear()  # Clear any existing path
		for pos in astar_path:
			current_path.append(Vector2i(pos.x, pos.y))  # Convert Vector2 to Vector2i
		
		path_index = 0  # Reset path index to start at the beginning
		print("Path calculated:", current_path)
	else:
		print("Target tile is not walkable.")

# Update the AStar grid and calculate the path
func move_player_to_target(target_tile: Vector2i) -> void:
	update_astar_grid()  # Ensure AStar grid is up to date
	calculate_path(target_tile)  # Now calculate the path

	# Once the path is calculated, move the player to the target (will also update selected_player state)
	move_along_path(get_process_delta_time())  # This ensures movement happens immediately
	# Do not clear selection here. We keep selected_player intact.

# Function to move the soldier along the path
func move_along_path(delta: float) -> void:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	
	if current_path.is_empty():
		return  # No path, so don't move

	if path_index < current_path.size():
		get_child(0).play("move")
		
		var target_pos = current_path[path_index]  # This is a Vector2i (tile position)
		
		# Convert the target position to world position (center of the tile)
		var target_world_pos = tilemap.map_to_local(target_pos) + Vector2(0, 0) / 2  # Ensure it's the center of the tile
		
		# Calculate the direction to the target position
		# Calculate direction to move in (normalized vector)
		var direction = (target_world_pos - position).normalized()

		# Determine the direction of movement based on target and current position
		if direction.x > 0:
			scale.x = -1  # Facing right (East)
		elif direction.x < 0:
			scale.x = 1  # Facing left (West)	
			
		# Move the soldier in the direction of the target position, adjusted by delta
		position += direction * move_speed * delta
		
		# If the soldier has reached the target tile (within a small threshold)
		if position.distance_to(target_world_pos) <= 1:  # Threshold to determine if we reached the target
			path_index += 1  # Move to the next tile in the path
			get_child(0).play("default")
			# After moving, update the AStar grid for any changes (e.g., new walkable tiles, etc.)
			has_moved = true
			item_manager.check_for_item_discovery(self)
			update_astar_grid()
			check_end_turn_conditions()
	
# Visualize all walkable (non-solid) tiles in the A* grid
func visualize_walkable_tiles() -> void:
	var map_size: Vector2i = tilemap.get_used_rect().size
	
	# Iterate over all tiles in the A* grid and check for walkable (non-solid) tiles
	for x in range(map_size.x):
		for y in range(map_size.y):
			var tile = Vector2i(x, y)

			# Check if the tile is walkable (non-solid)
			if not astar.is_point_solid(tile):  # This tile is walkable
				var world_pos: Vector2 = tilemap.map_to_local(tile)
				var movement_tile_instance: Node2D = movement_tile_scene.instantiate() as Node2D
				movement_tile_instance.position = world_pos
				movement_tile_instance.modulate = Color(0.0, 1.0, 0.0, 0.5)  # Example: Green with some transparency for walkable tiles
				tilemap.add_child(movement_tile_instance)
				movement_tiles.append(movement_tile_instance)

	# Debug print to confirm visualization
	print("Visualized walkable tiles.")

func _input(event: InputEvent) -> void:	
	# Check if any zombie in the "zombies" group is moving
	var zombies = get_tree().get_nodes_in_group("zombies")
	var zombies_moving = false
	for zombie in zombies:
		if zombie.is_moving:  # If any zombie is moving, skip player input and prevent showing tiles
			zombies_moving = true
			#print("Zombie is moving, skipping player input.")
			
			# Update the HUD to reflect new stats
			var hud_manager = get_parent().get_parent().get_node("HUDManager")
			hud_manager.hide_special_buttons()				
			break  # Exit early once we know a zombie is moving
	
	if zombies_moving:
		# Prevent tile display or any other player action
		return
			
	# Process player input only if zombies are not moving
	if event is InputEventMouseButton:
		var tilemap: TileMap = get_node("/root/MapManager/TileMap")

		# Right-click to show attack range (already implemented)
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if selected:  # Only show attack range if the unit is selected
				print("Right-click detected: Showing attack range.")  # Debug log
				display_attack_range_tiles()
				attack_range_visible = true  # Set the attack range visible flag to true
				selected = true
				print("Attack range is now visible.")  # Debug log

		# Left-click to trigger the attack
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			print("Left-click detected.")  # Debug log
			# Ensure that the unit is selected before triggering the attack
			if selected and attack_range_visible:  # Only proceed if attack range is visible
				# Get the global mouse position and convert it to tilemap coordinates
				var global_mouse_pos = get_global_mouse_position()
				global_mouse_pos.y += 8
				var clicked_tile_pos = tilemap.local_to_map(tilemap.to_local(global_mouse_pos))

				print("Global mouse position: ", global_mouse_pos)  # Debug log
				print("Clicked on tile (converted): ", clicked_tile_pos)  # Debug log

				# Check if the tile is occupied by a unit or structure
				if is_unit_present(clicked_tile_pos):
					print("Attack triggered at position: ", clicked_tile_pos)  # Debug log
					attack(clicked_tile_pos)
					attack_range_visible = false  # Reset the attack range visibility after attacking
					print("Attack range visibility reset.")  # Debug log
				else:
					print("Clicked tile is not occupied by a unit or structure.")  # Debug log
			else:
				if not selected:
					print("Unit is not selected. Can't attack.")  # Debug log
				if not attack_range_visible:
					print("Attack range is not visible. Can't attack.")  # Debug log

func is_mouse_over_gui() -> bool:
	# Get global mouse position
	var mouse_pos = get_viewport().get_mouse_position()

	# Get all nodes in the "hud_controls" group
	var hud_controls = get_tree().get_nodes_in_group("hud_controls")
	for control in hud_controls:
		if control is Button:
			# Use global rect to check if mouse is over the button
			var rect = control.get_global_rect()
			print("Checking button:", control.name, "Rect:", rect, "Mouse Pos:", mouse_pos)
			if rect.has_point(mouse_pos):
				print("Mouse is over button:", control.name, "Rect:", rect, "Mouse Pos:", mouse_pos)
				return true
	print("Mouse is NOT over any button.")
	return false
			
# Display attack range tiles around the soldier using the attack_tile_scene
func display_attack_range_tiles() -> void:
	# Check if any zombie in the "zombies" group is moving
	var zombies = get_tree().get_nodes_in_group("zombies")
	var zombies_moving = false
	for zombie in zombies:
		if zombie.is_moving:  # If any zombie is moving, skip player input and prevent showing tiles
			zombies_moving = true
			#print("Zombie is moving, skipping player input.")

			# Update the HUD to reflect new stats
			var hud_manager = get_parent().get_parent().get_node("HUDManager")
			hud_manager.hide_special_buttons()		
					
			break  # Exit early once we know a zombie is moving
	
	if zombies_moving:
		# Prevent tile display or any other player action
		return

	# Update the HUD to reflect new stats
	var hud_manager = get_parent().get_parent().get_node("HUDManager")
	hud_manager.show_special_buttons(self)	
	
	clear_movement_tiles()  # Clear existing movement tiles
	clear_attack_range_tiles()  # First, clear previous attack range tiles
	
	# Directions to check: right, left, down, up
	var directions: Array[Vector2i] = [
		Vector2i(1, 0),  # Right
		Vector2i(-1, 0), # Left
		Vector2i(0, 1),  # Down
		Vector2i(0, -1)  # Up
	]

	# For each direction, check and display tiles until we hit a structure, unit, or map boundary
	for direction in directions:
		var current_pos = tile_pos
		while true:
			# Move one step in the current direction
			current_pos += direction
			# Check if the current tile is within bounds
			var tilemap: TileMap = get_node("/root/MapManager/TileMap")
			if !tilemap.get_used_rect().has_point(current_pos):
				break  # If we reach out of bounds, stop

			# Retrieve the tile ID at the current position
			var tile_id = tilemap.get_cell_source_id(0, current_pos)

			# Check if the tile is walkable, or if we have hit a structure/unit
			# Water tiles will NOT stop the attack range now
			if is_structure(current_pos) or is_unit_present(current_pos) or is_tile_movable(current_pos) or is_water_tile(tile_id):
				var world_pos: Vector2 = tilemap.map_to_local(current_pos)
				var attack_tile_instance: Node2D = attack_tile_scene.instantiate() as Node2D  # Use attack_tile_scene here
				attack_tile_instance.position = world_pos
				tilemap.add_child(attack_tile_instance)
				attack_range_tiles.append(attack_tile_instance)
				
				# If we hit a structure or unit, stop here (we include them in the range)
				if is_structure(current_pos) or is_unit_present(current_pos):
					break
			else:
				# If the tile is not walkable and not a structure/unit, stop here
				break

# Get the positions of attack range tiles around the soldier
func get_attack_tiles() -> Array[Vector2i]:
	var attack_tiles: Array[Vector2i] = []  # Array to store positions in attack range

	# Define directions to check: right, left, down, up
	var directions: Array[Vector2i] = [
		Vector2i(1, 0),  # Right
		Vector2i(-1, 0), # Left
		Vector2i(0, 1),  # Down
		Vector2i(0, -1)  # Up
	]

	# Get the current tilemap and starting position
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var current_pos = tile_pos  # Assuming `tile_pos` is the soldier's current tile position

	# Loop through each direction and calculate attack tiles
	for direction in directions:
		var check_pos = current_pos
		while true:
			# Move one step in the current direction
			check_pos += direction

			# Check if the position is within the tilemap bounds
			if !tilemap.get_used_rect().has_point(check_pos):
				break  # Stop if out of bounds

			# Get the tile ID at the current position
			var tile_id = tilemap.get_cell_source_id(0, check_pos)

			# Check if this tile should be included in the attack range
			if is_structure(check_pos) or is_unit_present(check_pos) or is_tile_movable(check_pos) or is_water_tile(tile_id):
				# Add the current position to the attack range
				attack_tiles.append(check_pos)

				# Stop if we hit a structure or unit, as these block further range in that direction
				if is_structure(check_pos) or is_unit_present(check_pos):
					break
			else:
				# If the tile is not walkable and is not a structure/unit, stop here
				break

	# Return the array of attack range positions
	return attack_tiles

# Clear displayed attack range tiles
func clear_attack_range_tiles() -> void:
	for tile in attack_range_tiles:
		tile.queue_free()
	attack_range_tiles.clear()

func attack(target_tile: Vector2i, is_missile_attack: bool = false, is_landmine_attack: bool = false) -> void:
	# Block gameplay input if the mouse is over GUI
	if is_mouse_over_gui():
		print("Input blocked by GUI.")
		return  # Prevent further input handling
			
	# If this is a missile or landmine attack, check the respective toggle
	if is_missile_attack and not GlobalManager.missile_toggle_active:
		print("Missile toggle is off, ignoring missile attack.")
		return	

	if is_landmine_attack and not GlobalManager.landmine_toggle_active:
		print("Landmine toggle is off, ignoring landmine attack.")
		return	

	# Check if the target is within the attack range
	if not is_within_attack_range(target_tile):
		print("Target is out of range")
		return

	# Check if projectile_scene is set correctly
	if projectile_scene == null:
		print("Error: projectile_scene is not assigned!")
		return

	# Instantiate the projectile
	var projectile = projectile_scene.instantiate() as Node2D
	projectile.attacker = self
	
	if projectile == null:
		print("Error: Failed to instantiate projectile!")
		return

	# Check if missile or landmine toggle is active, free the projectile immediately
	if GlobalManager.missile_toggle_active:
		print("Missile toggle active, freeing projectile immediately.")
		projectile.queue_free()
		return
	elif GlobalManager.landmine_toggle_active:
		print("Landmine toggle active, freeing projectile immediately.")
		projectile.queue_free()
		return

	# Get the TileMap to get world position of the target
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	if tilemap == null:
		print("Error: TileMap not found!")
		return

	# Get world position of the target tile
	var target_world_pos = tilemap.map_to_local(target_tile)
	print("Target world position: ", target_world_pos)
	
	# Play the attack animation
	get_child(0).play("attack")
	
	# Determine the direction to the target
	var target_direction = target_world_pos.x - position.x

	# Flip the sprite based on the target's relative position and current scale.x value
	if target_direction > 0 and scale.x != -1:
		scale.x = -1  # Flip sprite to face right
	elif target_direction < 0 and scale.x != 1:
		scale.x = 1  # Flip sprite to face left
	
	# Set the initial position of the projectile (e.g., the soldier's position)
	projectile.position = self.position
	print("Projectile created at position: ", projectile.position)

	# Add the projectile to the scene
	tilemap.add_child(projectile)

	# Set the target position and speed on the projectile
	projectile.target_position = target_world_pos
	projectile.speed = 200.0  # Adjust as needed
	
	clear_attack_range_tiles()
	#on_player_action_completed()
	has_attacked = true
	has_moved = true

	# Increase experience points by 25 for each attack
	current_xp += 25
	print("Current XP increased to:", current_xp)

	# Optional: Check for level up, if applicable
	if current_xp >= xp_for_next_level:
		level_up()
	
	#item_manager.check_item_destroyed()
	await get_tree().create_timer(0.1).timeout
	#mission_manager.check_mission_manager()
			
	# Update the HUD to reflect new stats
	var hud_manager = get_parent().get_parent().get_node("HUDManager")
	hud_manager.update_hud(self)	
	hud_manager.hide_special_buttons()				
	check_end_turn_conditions()

# Function to check if the target is within the attack range
func is_within_attack_range(target_tile: Vector2i) -> bool:
	# Check if the target tile is within the attack range
	# Assuming the target is a part of the attack range tiles, which we should have already populated
	for tile in attack_range_tiles:
		var tile_position = tile.position
		var tilemap: TileMap = get_node("/root/MapManager/TileMap")
		var target_pos = tilemap.local_to_map(tile_position)
		if target_pos == target_tile:
			return true
	return false

# Call this function after every player action
func on_player_action_completed():
	emit_signal("player_action_completed")
		
# Method to apply damage
func apply_damage(damage: int) -> void:
	current_health -= damage  # Reduce health by damage
	current_health = clamp(current_health, 0, max_health)  # Ensure health stays within bounds
	
	if current_health <= 0:
		die()  # Handle player death if health is 0
	else:
		print("Player health after attack:", current_health)
	
	# Access the HUDManager (move up the tree from PlayerUnit -> UnitSpawn -> parent (to HUDManager)
	var hud_manager = get_parent().get_parent().get_node("HUDManager")
	hud_manager.update_hud(self)  # Pass the selected unit to the HUDManager # Pass the current unit (self) to the HUDManager						
	
# Optional death handling
func die() -> void:	
	if self.player_name == "Dutch. Major" or self.player_name == "Logan. Raines" :
		# Play sfx
		audio_player.stream = death_audio
		audio_player.play()
		await get_tree().create_timer(1).timeout
		self.get_child(0).play("death")
	
	await get_tree().create_timer(1).timeout
	
	if self.player_name == "Yoshida. Boi":
		_create_explosion()
	
	if !self.player_name == "Dutch. Major" or !self.player_name == "Logan. Raines":
		_create_explosion()
		
	self.remove_from_group("player_units")
		
	self.visible = false
	print("Player has died")	
	#queue_free()  # Remove player from the scene or handle accordingly		

func level_up() -> void:
	# Play SFX
	audio_player.stream = levelup_audio
	audio_player.play()
	print("Level up triggered!")
	
	# Add level-up bonuses
	movement_range += 1
	current_level += 1
	max_health += 25
	current_health += 25  # Fully heal player
	attack_damage += 25

	# Reset XP threshold
	current_xp -= xp_for_next_level
	xp_for_next_level += 25  # Increment XP threshold
		
	# Play visual effect
	play_level_up_effect()
		
	print("Level up completed!")

# Function to play level-up flickering effect (green to normal)
func play_level_up_effect() -> void:
	var original_color = modulate  # Store the original color of the unit
	var flash_color = Color(0, 1, 0)  # Green color for the flash effect
	
	# Number of flashes and duration
	var flash_count = 12  # How many times to alternate
	var flash_duration = 0.1  # Duration for each flash (on or off)

	# Loop to alternate colors
	for i in range(flash_count):
		# Alternate color between green and the original color
		modulate = flash_color if i % 2 == 0 else original_color
		
		# Wait for the duration before switching again
		await get_tree().create_timer(flash_duration).timeout

	# Ensure color is reset to original after the effect
	modulate = original_color
	
	# Darken the unit to visually indicate its turn is over
	self.modulate = Color(0.5, 0.5, 0.5, 1.0)  # Reduce brightness (darken)
		

func _create_explosion() -> void:
	# Check if explosion_scene is assigned
	if explosion_scene == null:
		print("Error: Explosion scene is not assigned!")
		return

	# Instantiate the explosion effect
	var explosion = explosion_scene.instantiate() as Node2D
	if explosion == null:
		print("Error: Failed to instantiate explosion!")
		return
	
	# Set the explosion's position to the projectile's impact location
	explosion.position = position
	explosion.z_index = int(position.y)  # Ensure explosion is layered correctly
	
	# Add explosion to the parent scene
	get_parent().add_child(explosion)
	print("Explosion created at position: ", explosion.position)

# Flashes the sprite red and white a few times
func flash_damage():
	if sprite:
		for i in range(8):  # Flash 3 times
			sprite.modulate = Color(1, 0, 0)  # Set to red
			await get_tree().create_timer(0.1).timeout  # Wait 0.1 seconds
			sprite.modulate = Color(1, 1, 1)  # Set back to normal color
			await get_tree().create_timer(0.1).timeout  # Wait 0.1 seconds

func get_attack_damage() -> int:
	return attack_damage  # Replace with your variable holding attack damage

func mek_melee(selected_unit: Area2D) -> void:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	#var camera: Camera2D = get_node("/root/MapManager/Camera2D")
		
	if not tilemap:
		print("TileMap not found!")
		return

	# Get the player's current tile position
	var mek_tile_pos = tilemap.local_to_map(self.position)
	#camera.focus_on_tile(tilemap, mek_tile_pos)
	
	# Define adjacent tiles (4 directions: up, down, left, right)
	var adjacent_tiles = [
		mek_tile_pos + Vector2i(1, 0),   # Right
		mek_tile_pos + Vector2i(-1, 0),  # Left
		mek_tile_pos + Vector2i(0, 1),   # Down
		mek_tile_pos + Vector2i(0, -1)   # Up
	]
	
	# Iterate over each adjacent tile to check for zombies
	for tile_pos in adjacent_tiles:
		var zombies = get_tree().get_nodes_in_group("zombies")
		for zombie in zombies:
			var zombie_tile_pos = tilemap.local_to_map(zombie.position)
			if tile_pos == zombie_tile_pos:
				print("Zombie found adjacent at tile:", tile_pos)
				
				# Get the world position of the zombie (target)
				var zombie_world_pos = tilemap.map_to_local(zombie_tile_pos)
				print("Zombie world position: ", zombie_world_pos)
				
				# Determine the direction to the target
				var direction_to_target = zombie_world_pos.x - position.x
				
				# Flip the sprite based on the target's relative position (left or right)
				if direction_to_target > 0 and scale.x != -1:
					# Zombie is to the right, flip the mek to face right
					scale.x = -1
				elif direction_to_target < 0 and scale.x != 1:
					# Zombie is to the left, flip the mek to face left
					scale.x = 1

				# Perform attack animation and damage
				await get_tree().create_timer(0.5).timeout
				get_child(0).play("attack")

				# Play sfx
				audio_player.stream = mek_attack_audio
				audio_player.play()	
							
				zombie.flash_damage()
				zombie.apply_damage(selected_unit.get_attack_damage())
				
				zombie.second_audio_player.stream = zombie.hurt_audio
				zombie.second_audio_player.play()
				
				# Update the HUD to reflect new stats
				var hud_manager = get_parent().get_parent().get_node("HUDManager")
				hud_manager.update_hud_zombie(zombie)

				await get_tree().create_timer(1).timeout
				hud_manager.update_hud(selected_unit)		
						
				hud_manager.hide_special_buttons()				
				#return  # Exit once a zombie is found

	# Update selected unit's state
	selected_unit.has_attacked = true
	selected_unit.has_moved = true
	
	# Darken the unit to visually indicate its turn is over
	selected_unit.modulate = Color(0.5, 0.5, 0.5, 1.0)  # Reduce brightness (darken)
						
	selected_unit.check_end_turn_conditions()
	
	# No adjacent zombies found
	print("No zombies adjacent.")
	
func check_end_turn_conditions() -> void:
	# Check if the unit has completed its turn
	if has_moved and has_attacked:
		print(self.name, "has completed its turn.")
		has_used_turn = true
		can_start_turn = false

		# Proceed to end the turn
		await get_tree().create_timer(0.5).timeout	
		
		# Darken the unit to visually indicate its turn is over
		self.modulate = Color(0.5, 0.5, 0.5, 1.0)  # Reduce brightness (darken)
					
		get_child(0).play("default")
		end_turn()

func end_turn() -> void:
	if turn_manager:
		turn_manager.end_current_turn()  # Notify the turn manager to move to the next unit
	else:
		print("Turn manager is not set! Unable to proceed to the next unit.")

func start_turn() -> void:
	can_start_turn = true
