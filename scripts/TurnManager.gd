extends Node2D

var player_units: Array = []  # Array for player units
var zombie_units: Array = []  # Array for zombie units
var current_unit: Node = null  # The unit currently taking its turn
var current_group: String = "player_units"  # Which group's turn it is ("player_units" or "zombie_units")
var current_unit_index: int = 0  # Index of the current unit in the current group

signal player_action_completed

func _ready() -> void:
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
	if current_group == "player_units":
		if player_units.size() == 0:
			print("No player units left.")
			return

		current_unit = zombie_units[current_unit_index]

	if current_unit and current_unit.has_method("start_turn"):
		current_unit.start_turn()  # Call start_turn on the current unit
	else:
		print("Current unit does not have a 'start_turn' method!")

func end_current_unit_turn() -> void:
	# Get all player units
	var all_player_units = get_tree().get_nodes_in_group("player_units")
	
	# Check if all player units have `has_used_turn = true`
	var all_turns_used = true
	for player in all_player_units:
		if not player.has_used_turn:  # If any player has not used their turn
			all_turns_used = false
			break  # No need to check further
	
	# If all turns are used, fire `on_player_action_completed`
	if all_turns_used:
		on_player_action_completed()

# Add a player unit
func add_player_unit(unit: Node) -> void:
	if not player_units.has(unit):
		player_units.append(unit)

# Add a zombie unit
func add_zombie_unit(unit: Node) -> void:
	if not zombie_units.has(unit):
		zombie_units.append(unit)

# Remove a unit from its respective group
func remove_unit(unit: Node) -> void:
	if player_units.has(unit):
		player_units.erase(unit)

	# If the removed unit is the current unit, adjust the index
	if unit == current_unit:
		end_current_unit_turn()

# Get the currently active unit
func get_current_unit() -> Node:
	return current_unit

# Call this function after every player action
func on_player_action_completed():
	emit_signal("player_action_completed")
	
