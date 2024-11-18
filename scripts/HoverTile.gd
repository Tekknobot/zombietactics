extends Node2D

# Reference to the TileMap
var tilemap: TileMap = null

# Currently selected player
var selected_player: Area2D = null
var last_selected_player: Area2D = null

# Movement and attack range tiles
var movement_range_tiles: Array[Vector2i] = []
var attack_range_tiles: Array[Vector2i] = []

@onready var hud_manager = $HUDManager  # Access the HUDManager instance in the scene
@onready var player_unit1 = $PlayerUnit1  # Reference to PlayerUnit1
@onready var player_unit2 = $PlayerUnit2  # Reference to PlayerUnit2
@onready var player_unit3 = $PlayerUnit3  # Reference to PlayerUnit3

@onready var global_manager = get_node("/root/MapManager/GlobalManager")  # Reference to the SpecialToggleNode

@onready var audio_player = $AudioStreamPlayer2D  # Adjust the path as needed
@export var select_audio: AudioStream
@export var arm_attack_audio: AudioStream

# Initialization
func _ready() -> void:
	tilemap = get_node("/root/MapManager/TileMap")
	visible = true
	
# Called every frame to process input and update hover tile position
func _process(delta: float) -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	mouse_pos.y += 8  # Optional offset to align tiles if necessary
	var tile_pos: Vector2i = tilemap.local_to_map(tilemap.to_local(mouse_pos))
		
	# Update the hover tile to follow the mouse cursor
	if is_within_bounds(tile_pos):
		position = tilemap.map_to_local(tile_pos)
		visible = true  # Make sure the hover tile is visible		
	else:
		visible = false  # Hide hover tile if out of bounds

	# Handle left-click and right-click actions
	if is_within_bounds(tile_pos) and Input.is_action_just_pressed("mouse_left"):
		handle_left_click(tile_pos)
	elif is_within_bounds(tile_pos) and Input.is_action_just_pressed("mouse_right"):
		handle_right_click()
		
# Checks if the tile position is within the tilemap bounds
func is_within_bounds(tile_pos: Vector2i) -> bool:
	var map_rect: Rect2i = tilemap.get_used_rect()
	return tile_pos.x >= map_rect.position.x and tile_pos.y >= map_rect.position.y \
		and tile_pos.x < map_rect.position.x + map_rect.size.x \
		and tile_pos.y < map_rect.position.y + map_rect.size.y

# Handles left-click input for selecting, moving, or attacking with the unit
func handle_left_click(tile_pos: Vector2i) -> void:
	if selected_player:
		# If in attack mode and clicked a valid attack tile
		if tile_pos in attack_range_tiles:
			attack_selected_player(tile_pos)
		# If in movement mode and clicked a valid movement tile
		elif tile_pos in movement_range_tiles:
			move_selected_player(tile_pos)
		else:
			# If clicked on a non-action tile, try selecting a different unit
			select_unit_at_tile(tile_pos)
	else:
		# If no player is selected, try selecting one on the clicked tile
		select_unit_at_tile(tile_pos)

# Handles right-click to toggle between attack and movement range display
func handle_right_click() -> void:
	if selected_player:
		toggle_attack_mode()

# Attacks the target at the specified tile
func attack_selected_player(tile_pos: Vector2i) -> void:
	if selected_player.has_attacked == false:
		selected_player.attack(tile_pos)
		clear_action_tiles()  # Clear tiles after the attack
		await get_tree().create_timer(1).timeout  # Optional delay for action feedback

# Moves the selected player to the specified tile
func move_selected_player(tile_pos: Vector2i) -> void:
	if selected_player.has_moved == false:
		selected_player.move_player_to_target(tile_pos)
		clear_action_tiles()  # Clear movement and attack tiles after moving

# Selects a unit at the given tile position
func select_unit_at_tile(tile_pos: Vector2i) -> void:
	# Update the HUD to reflect new stats
	var hud_manager = get_parent().get_node("HUDManager")
	hud_manager.visible = true
	
	clear_action_tiles()  # Clear any previous selection tiles
	clear_action_tiles_zombie()
	
	var players = get_tree().get_nodes_in_group("player_units")
	for player in players:
		if tilemap.local_to_map(player.global_position) == tile_pos:
			# Play sfx
			audio_player.stream = select_audio
			audio_player.play()			
			
			selected_player = player
			selected_player.selected = true
			show_movement_tiles(player)
			hud_manager.update_hud(player)
			return
	
	#selected_player = null  # Deselect if no player is found at the clicked tile
	
	clear_action_tiles() 
	clear_action_tiles_zombie()  # Clear any previous selection tiles

	var zombies = get_tree().get_nodes_in_group("zombies")
	for zombie in zombies:
		if tilemap.local_to_map(zombie.global_position) == tile_pos:
			# Play sfx
			audio_player.stream = select_audio
			audio_player.play()			
			
			zombie.selected = true
			show_movement_tiles_zombie(zombie)
			hud_manager.update_hud_zombie(zombie)
			return

# Displays movement tiles for the selected player
func show_movement_tiles(player: Area2D) -> void:
	movement_range_tiles = player.get_movement_tiles()
	player.display_movement_tiles()

# Displays movement tiles for the selected player
func show_movement_tiles_zombie(zombie: Area2D) -> void:
	movement_range_tiles = zombie.get_movement_tiles()
	zombie.display_movement_tiles()

# Toggles between attack and movement mode for the currently selected player
func toggle_attack_mode() -> void:
	# Play sfx
	audio_player.stream = arm_attack_audio
	audio_player.play()
		
	clear_action_tiles()
	if attack_range_tiles.is_empty():
		# Switch to attack mode
		attack_range_tiles = selected_player.get_attack_tiles()
		selected_player.display_attack_range_tiles()
	else:
		# Switch back to movement mode
		show_movement_tiles(selected_player)

# Clears all action tiles (movement and attack) when the selection changes
func clear_action_tiles() -> void:
	if selected_player:
		selected_player.clear_movement_tiles()
		selected_player.clear_attack_range_tiles()
		last_selected_player = selected_player
		selected_player.selected = false
	movement_range_tiles.clear()
	attack_range_tiles.clear()

# Clears all action tiles (movement and attack) when the selection changes
func clear_action_tiles_zombie() -> void:
	var zombies = get_tree().get_nodes_in_group("zombies")
	for zombie in zombies:
		zombie.selected = false
		zombie.clear_movement_tiles()
