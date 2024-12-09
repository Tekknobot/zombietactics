extends TextureRect

@export var player_name: String  # Name of the player this TextureRect represents

# Called when the node enters the scene tree for the first time
func _ready():
	check_player_status()
	# Enable mouse input for the TextureRect
	set_mouse_filter(Control.MOUSE_FILTER_PASS)

# Continuously check the player's status in the group
func _process(delta: float) -> void:
	check_player_status()

func check_player_status():
	var players = get_tree().get_nodes_in_group("player_units")
	var player_in_group = false

	for player in players:
		# Check if the current unit is in the group
		if player_name == player.player_name:
			player_in_group = true
			
			# Check if this specific player has moved and attacked
			if player.has_moved and player.has_attacked:
				self.modulate = Color(0.35, 0.35, 0.35, 1)  # Dim color for completed action
			else:
				self.modulate = Color(1, 1, 1, 1)  # Normal color for active players
			
			return  # Exit the function after processing this player

	# If the loop completes without finding the player, they are not in the group
	if not player_in_group:
		self.modulate = Color(1, 0, 0, 1)  # Red for players not in the group

			 

# Detect when this TextureRect is clicked
func _gui_input(event: InputEvent) -> void:
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
