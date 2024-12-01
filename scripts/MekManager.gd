extends Node2D

@export var M1: PackedScene  
@export var M2: PackedScene  
@export var R1: PackedScene  
@export var R3: PackedScene 
@export var S2: PackedScene  
@export var S3: PackedScene  

@onready var tilemap = get_parent().get_node("TileMap")  # Reference to the TileMap
@onready var map_manager = get_node("/root/MapManager")
@onready var turn_manager = get_node("/root/MapManager/TurnManager")  
@onready var hovertile = get_node("/root/MapManager/HoverTile") 

@onready var audio_player = $AudioStreamPlayer2D  # Adjust the path as needed
@export var mek_call_audio = preload("res://audio/SFX/call_mek.wav")

# Constants
var WATER_TILE_ID = 0  # Replace with the actual tile ID for water

var fade_duration = 1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
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

func _input(event: InputEvent) -> void:
	if not GlobalManager.mek_toggle_active:
		return
	
	# Get the TileMap node
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")

	# Convert the global mouse position to local position relative to the TileMap
	var global_mouse_pos = get_global_mouse_position()
	global_mouse_pos.y += 8
	var local_mouse_pos = tilemap.to_local(global_mouse_pos)

	# Convert the local mouse position to the corresponding tile position
	var tile_pos = tilemap.local_to_map(local_mouse_pos)

	# Check if the tile is within the valid bounds
	if not is_within_bounds(tile_pos):
		# If the tile is out of bounds, return early
		return
	
	# Proceed only if left mouse button is pressed
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Check if the tile is movable
		if is_tile_movable(tile_pos):				
			# Pick a random exported scene
			var random_scene = get_random_scene()
			if random_scene:
				# Spawn the scene at the tile
				var instance = random_scene.instantiate()
				var tile_world_position = tilemap.map_to_local(tile_pos)
				instance.position = tile_world_position
				instance.z_index = int(tile_world_position.y)
				add_child(instance)
				
				# Start the instance with full transparency
				instance.modulate = Color8(255, 110, 255, 0)  # RGBA: fully transparent
				
				# Animate fade-in and fade-out
				animate_fade_in_out(instance)

				var camera: Camera2D = get_node("/root/MapManager/Camera2D")				
				camera.focus_on_tile(tilemap, tile_pos)	
				camera.zoom_focus = Vector2i(3, 3)	
				
				# Get the selected attacker from the "player_units" group
				var selected_unit = get_selected_unit()
				if selected_unit:
					instance.mek_melee(selected_unit)  # Pass the selected unit to mek_melee()
					selected_unit.current_xp += 25
					# Optional: Check for level up, if applicable
					if selected_unit.current_xp >= selected_unit.xp_for_next_level:
						selected_unit.level_up()					
				else:
					print("No selected unit found to act as attacker.")
				
				await get_tree().create_timer(0.1).timeout
				GlobalManager.mek_toggle_active = false

				var hover_tiles = get_tree().get_nodes_in_group("hovertile")
				for hovertile in hover_tiles:
					hovertile.clear_action_tiles_zombie()

				var hud_manager = get_parent().get_node("HUDManager")  # Adjust the path if necessary
				
				# Access the 'special' button within HUDManager
				var mek_button = hud_manager.get_node("HUD/Mek")
				mek_button.button_pressed = false
				
				print("Spawned unit on tile:", tile_pos)
			else:
				print("No scene available to spawn.")
		else:
			print("Tile is not movable:", tile_pos)

# Checks if the tile position is within the tilemap bounds
func is_within_bounds(tile_pos: Vector2i) -> bool:
	var map_rect: Rect2i = tilemap.get_used_rect()
	return tile_pos.x >= map_rect.position.x and tile_pos.y >= map_rect.position.y \
		and tile_pos.x < map_rect.position.x + map_rect.size.x \
		and tile_pos.y < map_rect.position.y + map_rect.size.y


# Function to animate fade-in and fade-out
func animate_fade_in_out(instance: Node2D) -> void:
	var tween = create_tween()

	# Callback to play audio when fade-in begins
	tween.tween_callback(Callable(self, "_play_mek_call_audio"))

	# Fade-in animation
	tween.tween_property(instance, "modulate:a", 1, fade_duration)  # Fade to fully opaque over 2 seconds
	tween.set_trans(tween.TRANS_LINEAR).set_ease(tween.EASE_IN_OUT)

	# Add a delay before fade-out begins
	tween.tween_interval(1.0)  # Wait 1 second after fade-in completes

	# Callback to play audio when fade-out begins
	tween.tween_callback(Callable(self, "_play_mek_call_audio"))

	# Fade-out animation
	tween.tween_property(instance, "modulate:a", 0, fade_duration)  # Fade to fully transparent over 3 seconds				
	
	await get_tree().create_timer(4).timeout
	var camera: Camera2D = get_node("/root/MapManager/Camera2D")
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	camera.focus_on_tile(tilemap, instance.tile_pos)
	camera.zoom_focus = Vector2i(2, 2)		
	
# Function to play mek_call audio
func _play_mek_call_audio() -> void:
	audio_player.stream = mek_call_audio
	audio_player.play()

# Helper function to get the currently selected unit from the "player_units" group
func get_selected_unit() -> Node:
	hovertile = get_node("/root/MapManager/HoverTile") 
	return hovertile.last_selected_player
	
# Function to pick a random scene from the exported ones
func get_random_scene() -> PackedScene:
	var scenes = [M1, M2, R1, R3, S2, S3]
	return scenes[randi() % scenes.size()] if scenes.size() > 0 else null

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
	
# Check if there is a unit on the tile
func clear_tiles():
	var all_units = get_tree().get_nodes_in_group("player_units") + get_tree().get_nodes_in_group("zombies")
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	for unit in all_units:
		unit.clear_movement_tiles()
