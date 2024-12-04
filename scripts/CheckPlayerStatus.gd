extends TextureRect

@export var player_name: String  # Name of the player this TextureRect represents

# Called when the node enters the scene tree for the first time
func _ready():
	check_player_status()

func check_player_status():
	var players = get_tree().get_nodes_in_group("player_units")
	var player_in_group = false

	for player in players:
		# Check if a player with the matching name is still in the group
		if player_name == player.player_name:
			player_in_group = true
			break

	# Update the modulation based on group membership
	modulate = Color(1, 1, 1) if player_in_group else Color(0.35, 0.35, 0.35)

# Optional: Use this if dynamic checking is needed
func _process(delta: float) -> void:
	check_player_status()
