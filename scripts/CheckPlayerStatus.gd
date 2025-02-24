extends TextureButton

@export var player_name: String  # Name of the player this TextureRect represents
@onready var unit_spawn = get_node("/root/MapManager/UnitSpawn")

# Called when the node enters the scene tree for the first time
func _ready():
	# Wait for a signal to start status checking
	unit_spawn.connect("units_spawned", Callable(self, "_on_units_spawned"))
	set_mouse_filter(Control.MOUSE_FILTER_PASS)

# Called when all units have spawned
func _on_units_spawned():
	# Initial check after units are ready
	check_player_status()

# Continuously check the player's status in the group
func _process(delta: float) -> void:
	check_player_status()

func check_player_status():
	var players = get_tree().get_nodes_in_group("player_units")
	var player_in_group = false
	
	for player in players:
		# Only consider non-AI player units.
		if player.is_in_group("unitAI"):
			continue
		if player_name == player.player_name:  # Match player_name
			player_in_group = true
			
			# Update the sibling ProgressBar.
			var progress_bar = get_node_or_null("../ProgressBar")
			if progress_bar and player.player_name == progress_bar.player_name:
				progress_bar.value = player.current_health
				progress_bar.max_value = player.max_health
			else:
				print("Error: ProgressBar not found for player:", player_name)
			
			# Update the sibling XPBar.
			var xp_bar = get_node_or_null("../XPBar")
			if xp_bar and player.player_name == xp_bar.player_name:
				xp_bar.value = player.current_xp
				xp_bar.max_value = player.max_xp
			else:
				print("Error: XPBar not found for player:", player_name)
			
			# Update modulate based on the player's state.
			if player.has_moved and player.has_attacked:
				self.modulate = Color(0.35, 0.35, 0.35, 1)  # Dimmed for completed actions.
			else:
				self.modulate = Color(1, 1, 1, 1)  # Normal for active players.

	# If no matching non-AI player was found, set the modulate to red.
	if not player_in_group:
		self.modulate = Color(1, 0, 0, 1)

# Detect when this TextureRect is clicked
func _gui_input(event: InputEvent) -> void:
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
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		focus_camera_on_player()

func focus_camera_on_player():
	var players = get_tree().get_nodes_in_group("player_units")

	for player in players:
		# Find the matching player by name
		if player_name == player.player_name:
			var camera: Camera2D = get_node("/root/MapManager/Camera2D")
			var tilemap: TileMap = get_node("/root/MapManager/TileMap")
			
			if camera and tilemap and player.tile_pos:
				# Move the camera to the player's `tile_pos`
				camera.focus_on_tile(tilemap, player.tile_pos)
				
				# Update hover tiles
				var hovertiles = get_tree().get_nodes_in_group("hovertile")
				for hovertile in hovertiles:
					if hovertile and hovertile.has_method("select_unit_at_tile") and hovertile.has_method("show_movement_tiles"):
						hovertile.clear_action_tiles_for_all_players()
						hovertile.select_unit_at_tile(player.tile_pos)
						hovertile.show_movement_tiles(player)
				
				print("Camera focused on player:", player_name)
			else:
				print("Error: Camera, TileMap, or Player tile_pos is invalid.")
			break
