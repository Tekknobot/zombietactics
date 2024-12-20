extends Node2D

# Reference to the TileMap
var tilemap: TileMap = null

# Currently selected player
var selected_player: Area2D = null
var last_selected_player: Area2D = null

var selected_structure: Area2D = null
var selected_zombie: Area2D = null

# Movement and attack range tiles
var movement_range_tiles: Array[Vector2i] = []
var attack_range_tiles: Array[Vector2i] = []

@onready var hud_manager = $HUDManager  # Access the HUDManager instance in the scene
@onready var player_unit1 = $PlayerUnit1  # Reference to PlayerUnit1
@onready var player_unit2 = $PlayerUnit2  # Reference to PlayerUnit2
@onready var player_unit3 = $PlayerUnit3  # Reference to PlayerUnit3

@onready var audio_player = $AudioStreamPlayer2D  # Adjust the path as needed
@export var select_audio: AudioStream
@export var arm_attack_audio: AudioStream

var tile_pos

# Initialization
func _ready() -> void:
	tilemap = get_node("/root/MapManager/TileMap")
	visible = true
	
# Called every frame to process input and update hover tile position
func _process(delta: float) -> void:
	is_mouse_over_gui()
	
	var mouse_pos: Vector2 = get_global_mouse_position()
	mouse_pos.y += 8  # Optional offset to align tiles if necessary
	tile_pos = tilemap.local_to_map(tilemap.to_local(mouse_pos))
		
	# Update the hover tile to follow the mouse cursor
	if is_within_bounds(tile_pos):
		position = tilemap.map_to_local(tile_pos)
		visible = true  # Make sure the hover tile is visible		
	else:
		visible = false  # Hide hover tile if out of bounds

	# Block gameplay input if the mouse is over GUI
	if is_mouse_over_gui():
		print("Input blocked by GUI.")
		return  # Prevent further input handling

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
			# Prevent movement if clicking the same tile the selected player is on
			# OR if another player unit is on the tile
			if tile_pos == selected_player.tile_pos or is_tile_occupied_by_unit(tile_pos):
				return
			move_selected_player(tile_pos)
		else:
			# If clicked on a non-action tile, try selecting a different unit
			select_unit_at_tile(tile_pos)
	else:
		# If no player is selected, try selecting one on the clicked tile
		select_unit_at_tile(tile_pos)

# Helper function to check if a tile is occupied by another player unit
func is_tile_occupied_by_unit(tile_pos: Vector2i) -> bool:
	var all_players = get_tree().get_nodes_in_group("player_units") + get_tree().get_nodes_in_group("zombies")
	for player in all_players:
		if player.tile_pos == tile_pos:
			select_unit_at_tile(tile_pos)
			return true
	return false

# Handles right-click to toggle between attack and movement range display
func handle_right_click() -> void:
	if selected_player:
		toggle_attack_mode()
		last_selected_player = selected_player

# Attacks the target at the specified tile
func attack_selected_player(tile_pos: Vector2i) -> void:
	if selected_player.has_attacked == false:
		selected_player.attack(tile_pos)
		clear_action_tiles()  # Clear tiles after the attack
		await get_tree().create_timer(1).timeout  # Optional delay for action feedback

# Moves the selected player to the specified tile
func move_selected_player(tile_pos: Vector2i) -> void:
	if (
		GlobalManager.missile_toggle_active or 
		GlobalManager.landmine_toggle_active or 
		GlobalManager.dynamite_toggle_active or 
		GlobalManager.mek_toggle_active or 
		GlobalManager.thread_toggle_active or 
		GlobalManager.dash_toggle_active or 
		GlobalManager.claw_toggle_active or 
		GlobalManager.hellfire_toggle_active or 
		GlobalManager.barrage_toggle_active or 
		GlobalManager.octoblast_toggle_active or 
		GlobalManager.grenade_toggle_active or 
		GlobalManager.slash_toggle_active or
		GlobalManager.shadows_toggle_active or
		GlobalManager.prowler_toggle_active or
		GlobalManager.regenerate_toggle_active or
		GlobalManager.transport_toggle_active
	):
		return
	
	var zombies = get_tree().get_nodes_in_group("zombies")
	for zombie in zombies:
		if zombie.selected:
			return
		
	if selected_player.has_moved == false:
		await selected_player.move_player_to_target(tile_pos)
		await clear_action_tiles()  # Clear movement and attack tiles after moving
			
		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:						
			player.check_end_turn_conditions()

		if zombies.size() <= 0:
			reset_player_units()
			if GlobalManager.secret_items_found >= 3:
				GlobalManager.zombies_cleared = true
				var mission_manager = get_node("/root/MapManager/MissionManager")	
		else:	
			selected_player.has_moved = true	
		
# Selects a unit or structure at the given tile position
func select_unit_at_tile(tile_pos: Vector2i) -> void:	
	var hud_manager = get_parent().get_node("HUDManager")
	
	clear_action_tiles()  # Clear any previous selection tiles
	clear_action_tiles_zombie()  # Clear any previous zombie selection tiles
	
	# Check if a player unit is at the tile
	var players = get_tree().get_nodes_in_group("player_units")
	for player in players:
		if tilemap.local_to_map(player.global_position) == tile_pos and player.can_start_turn == true:
			if (
				GlobalManager.missile_toggle_active or 
				GlobalManager.landmine_toggle_active or 
				GlobalManager.dynamite_toggle_active or 
				GlobalManager.mek_toggle_active or 
				GlobalManager.thread_toggle_active or 
				GlobalManager.dash_toggle_active or 
				GlobalManager.claw_toggle_active or 
				GlobalManager.hellfire_toggle_active or 
				GlobalManager.barrage_toggle_active or 
				GlobalManager.octoblast_toggle_active or 
				GlobalManager.grenade_toggle_active or 
				GlobalManager.slash_toggle_active or
				GlobalManager.shadows_toggle_active or 
				GlobalManager.prowler_toggle_active or
				GlobalManager.regenerate_toggle_active or
				GlobalManager.transport_toggle_active
			):				
				return
							
			set_special_button_pressed()	
					
			# Update the HUD to reflect new stats
			hud_manager.visible = true		
				
			# Play selection sound effect
			audio_player.stream = select_audio
			audio_player.play()
			
			# Update the last selected player only when a new player is selected
			if selected_player and selected_player != player:
				last_selected_player = selected_player
			
			selected_player = player
			player.selected = true
			
			var tilemap: TileMap = get_node("/root/MapManager/TileMap")
			var camera: Camera2D = get_node("/root/MapManager/Camera2D")
			#camera.focus_on_tile(tilemap, selected_player.tile_pos)
						
			show_movement_tiles(player)
			hud_manager.update_hud(player)
			return
	
	# Check if a zombie is at the tile
	var zombies = get_tree().get_nodes_in_group("zombies")
	for zombie in zombies:
		if tilemap.local_to_map(zombie.global_position) == tile_pos:
			if (
				GlobalManager.missile_toggle_active or 
				GlobalManager.landmine_toggle_active or 
				GlobalManager.dynamite_toggle_active or 
				GlobalManager.mek_toggle_active or 
				GlobalManager.thread_toggle_active or 
				GlobalManager.dash_toggle_active or 
				GlobalManager.claw_toggle_active or 
				GlobalManager.hellfire_toggle_active or 
				GlobalManager.barrage_toggle_active or 
				GlobalManager.octoblast_toggle_active or 
				GlobalManager.grenade_toggle_active or 
				GlobalManager.slash_toggle_active or
				GlobalManager.shadows_toggle_active or 
				GlobalManager.prowler_toggle_active or
				GlobalManager.regenerate_toggle_active or
				GlobalManager.transport_toggle_active
			):				
				return
				
			set_special_button_pressed()	
			
			# Update the HUD to reflect new stats
			hud_manager.visible = true	
						
			# Play selection sound effect
			audio_player.stream = select_audio
			audio_player.play()		
				
			selected_zombie = zombie
			zombie.selected = true

			var tilemap: TileMap = get_node("/root/MapManager/TileMap")
			var camera: Camera2D = get_node("/root/MapManager/Camera2D")
			#camera.focus_on_tile(tilemap, selected_zombie.tile_pos)
			
			show_movement_tiles_zombie(zombie)
			hud_manager.update_hud_zombie(zombie)
			return
	
	# Check if a structure is at the tile (from the 'structures' group)
	var structures = get_tree().get_nodes_in_group("structures")
	for structure in structures:
		if tilemap.local_to_map(structure.global_position) == tile_pos:
			set_special_button_pressed()
			
			# Play selection sound effect
			audio_player.stream = select_audio
			audio_player.play()
			
			selected_structure = structure		
			# If the structure is selected, perform any necessary action (like highlighting it)
			structure.selected = true
			
			var tilemap: TileMap = get_node("/root/MapManager/TileMap")
			var camera: Camera2D = get_node("/root/MapManager/Camera2D")
			#camera.focus_on_tile(tilemap, selected_structure.tile_pos)
						
			return
	
	# If no unit or structure is found at the clicked tile, deselect the current player
	if selected_player:
		last_selected_player = selected_player  # Save the current player as last selected

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
	if attack_range_tiles.is_empty() and selected_player.tile_pos == tile_pos:
		# Switch to attack mode
		attack_range_tiles = selected_player.get_attack_tiles()
		selected_player.display_attack_range_tiles()
		
		if selected_player.has_used_turn == true:
			var hud_manager = get_parent().get_node("HUDManager")  # Adjust the path if necessary
			hud_manager.hide_special_buttons()	
	else:
		# Switch back to movement mode
		#show_movement_tiles(selected_player)
		pass

# Clears all action tiles (movement and attack) when the selection changes
func clear_action_tiles() -> void:
	if selected_player:
		selected_player.clear_movement_tiles()
		selected_player.clear_attack_range_tiles()
		selected_player.selected = false

	if selected_zombie:
		selected_zombie.clear_movement_tiles()
		selected_zombie.selected = false
		
	movement_range_tiles.clear()
	attack_range_tiles.clear()

func clear_action_tiles_for_all_players():
	var players = get_tree().get_nodes_in_group("player_units")
	for player in players:
		player.selected = false
		player.clear_movement_tiles()

# Clears all action tiles (movement and attack) when the selection changes
func clear_action_tiles_zombie() -> void:
	var zombies = get_tree().get_nodes_in_group("zombies")
	for zombie in zombies:
		zombie.selected = false
		zombie.clear_movement_tiles()

func is_mouse_over_gui() -> bool:
	# Get global mouse position
	var mouse_pos = get_viewport().get_mouse_position()

	# Get all nodes in the "hud_controls" group
	var controls = get_tree().get_nodes_in_group("portrait_controls") + get_tree().get_nodes_in_group("hud_controls")
	for control in controls:
		if control is TextureRect or Button and control.is_visible_in_tree():
			# Use global rect to check if mouse is over the button
			var rect = control.get_global_rect()
			print("Checking TextureRect:", control.name, "Rect:", rect, "Mouse Pos:", mouse_pos)
			if rect.has_point(mouse_pos):
				print("Mouse is over TextureRect:", control.name, "Rect:", rect, "Mouse Pos:", mouse_pos)
				return true
	print("Mouse is NOT over any TextureRect.")
	return false

func set_special_button_pressed():
	var hud_manager = get_parent().get_node("HUDManager")
		
	hud_manager.dynamite.button_pressed = false	
	hud_manager.landmine.button_pressed = false	
	hud_manager.mek.button_pressed = false	
	hud_manager.missile.button_pressed = false
	hud_manager.thread.button_pressed = false
	hud_manager.dash.button_pressed = false
	hud_manager.claw.button_pressed = false
	hud_manager.hellfire.button_pressed = false
	hud_manager.barrage.button_pressed = false
	hud_manager.octoblast.button_pressed = false
	hud_manager.grenade.button_pressed = false
	hud_manager.slash.button_pressed = false
	hud_manager.shadows.button_pressed = false
	hud_manager.prowler.button_pressed = false
	hud_manager.regenerate.button_pressed = false
	hud_manager.transport.button_pressed = false
		
func reset_player_units():
	# Get all player units in the game
	var players = get_tree().get_nodes_in_group("player_units")
	for player in players:	
		player.has_moved = false
		player.has_attacked = false
		player.has_used_turn = false
		player.can_start_turn = true
		player.modulate = Color(1, 1, 1)
