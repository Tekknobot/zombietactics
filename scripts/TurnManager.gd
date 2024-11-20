extends Node2D

var player_units: Array = []  # Array for player units
var zombie_units: Array = []  # Array for zombie units
var current_unit: Node = null  # The unit currently taking its turn
var current_group: String = "player_units"  # Which group's turn it is ("player_units" or "zombie_units")
var current_unit_index: int = 0  # Index of the current unit in the current group

var trigger_zombies: bool = false

signal player_action_completed

func _ready() -> void:
	await get_tree().create_timer(1).timeout
	
	# Initialize player and zombie units
	player_units = get_tree().get_nodes_in_group("player_units")
	zombie_units = get_tree().get_nodes_in_group("zombies")

	if player_units.size() > 0:
		current_group = "player_units"
		current_unit_index = 0
		start_current_unit_turn()  # Start the first unit's turn
	else:
		print("No player units available to start.")

# Start the current unit's turn
func start_current_unit_turn() -> void:
	trigger_zombies = false
	
	if current_group == "player_units":
		if player_units.size() == 0:
			print("No player units left.")
			return

	for current_unit in player_units:
		if current_unit and current_unit.has_method("start_turn"):
			current_unit.start_turn()  # Call start_turn on the current unit
		else:
			print("Current unit does not have a 'start_turn' method!")

func end_current_turn() -> void:
	# Get all player units
	var all_player_units = get_tree().get_nodes_in_group("player_units")
	
	# Check if all player units have `has_used_turn = true`
	var all_turns_used = true
	for player in all_player_units:
		if not player.has_used_turn:  # If any player has not used their turn
			all_turns_used = false
			break  # No need to check further
	
	# If all turns are used, fire `on_player_action_completed`
	if all_turns_used and trigger_zombies == false:
		on_player_action_completed()
		trigger_zombies = true

# Add a player unit
func add_player_unit(unit: Node) -> void:
	if not player_units.has(unit):
		player_units.append(unit)

# Add a zombie unit
func add_zombie_unit(unit: Node) -> void:
	if not zombie_units.has(unit):
		zombie_units.append(unit)

# Call this function after every player action
func on_player_action_completed():
	emit_signal("player_action_completed")
	
