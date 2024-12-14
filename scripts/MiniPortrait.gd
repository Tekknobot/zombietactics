extends TextureButton

@export var player_name: String  # Name of the player this TextureButton represents

# Called when the node enters the scene tree for the first time
func _ready():
	# Initial status check after a short delay
	await get_tree().create_timer(1).timeout
	check_player_status()

# Continuously check the player's status in the group
func _process(delta: float) -> void:
	check_player_status()

func check_player_status():
	var players = get_tree().get_nodes_in_group("player_units")
	var player_in_group = false
	
	for player in players:
		# Match this TextureButton's player_name with the player's name
		if player_name == player.player_name:
			player_in_group = true
			# Find the sibling ProgressBar
			var progress_bar = get_node_or_null("../ProgressBar")
			if progress_bar:
				# Update the ProgressBar values
				progress_bar.value = player.current_health
				progress_bar.max_value = player.max_health
			else:
				print("Error: ProgressBar not found for player:", player_name)

			# Update the appearance of the TextureButton based on the player's state
			if player.has_moved and player.has_attacked:
				self.modulate = Color(0.35, 0.35, 0.35, 1)  # Dim for completed actions
			else:
				self.modulate = Color(1, 1, 1, 1)  # Normal for active players

			return  # Player found and processed; exit the function

	# If no matching player is found, mark this TextureButton as invalid
	self.modulate = Color(1, 0, 0, 1)  # Red for invalid player_name

# Detect when this TextureButton is clicked
func _gui_input(event: InputEvent) -> void:
	if GlobalManager.is_any_toggle_active():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		focus_camera_on_player()

func focus_camera_on_player():
	var players = get_tree().get_nodes_in_group("player_units")

	for player in players:
		if player_name == player.player_name:
			var camera: Camera2D = get_node_or_null("/root/MapManager/Camera2D")
			var tilemap: TileMap = get_node_or_null("/root/MapManager/TileMap")

			if camera and tilemap and player.tile_pos:
				# Focus the camera on the player's `tile_pos`
				camera.focus_on_tile(tilemap, player.tile_pos)

				# Update hover tiles
				var hovertiles = get_tree().get_nodes_in_group("hovertile")
				for hovertile in hovertiles:
					if hovertile.has_method("select_unit_at_tile") and hovertile.has_method("show_movement_tiles"):
						hovertile.clear_action_tiles_for_all_players()
						hovertile.select_unit_at_tile(player.tile_pos)
						hovertile.show_movement_tiles(player)

				print("Camera focused on player:", player_name)
			else:
				print("Error: Camera, TileMap, or Player tile_pos is invalid.")
			return
