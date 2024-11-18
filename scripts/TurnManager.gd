extends Node2D

var player_units: Array = []  # Array for player units
var zombie_units: Array = []  # Array for zombie units
var current_unit: Node = null  # The unit currently taking its turn
var current_group: String = "player_units"  # Which group's turn it is ("player_units" or "zombie_units")
var current_unit_index: int = 0  # Index of the current unit in the current group

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
			switch_to_next_group()
			return

		current_unit = player_units[current_unit_index]
	elif current_group == "zombie_units":
		if zombie_units.size() == 0:
			print("No zombie units left.")
			switch_to_next_group()
			return

		current_unit = zombie_units[current_unit_index]

	if current_unit and current_unit.has_method("start_turn"):
		current_unit.start_turn()  # Call start_turn on the current unit
	else:
		print("Current unit does not have a 'start_turn' method!")

# End the current unit's turn and move to the next one
func end_current_unit_turn() -> void:
	if current_unit and current_unit.has_method("end_turn"):
		current_unit.end_turn()  # Call end_turn on the current unit
	else:
		print("Current unit does not have an 'end_turn' method!")

	# Move to the next unit in the group
	if current_group == "player_units":
		current_unit_index += 1
		if current_unit_index >= player_units.size():
			switch_to_next_group()  # Switch to zombie units
	elif current_group == "zombie_units":
		current_unit_index += 1
		if current_unit_index >= zombie_units.size():
			switch_to_next_group()  # Switch to player units

	# Start the next turn
	start_current_unit_turn()

# Switch to the other group
func switch_to_next_group() -> void:
	if current_group == "player_units":
		current_group = "zombie_units"
		current_unit_index = 0  # Reset to the first zombie
	else:
		current_group = "player_units"
		current_unit_index = 0  # Reset to the first player

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
		if current_group == "player_units" and player_units.size() == 0:
			switch_to_next_group()
	elif zombie_units.has(unit):
		zombie_units.erase(unit)
		if current_group == "zombie_units" and zombie_units.size() == 0:
			switch_to_next_group()

	# If the removed unit is the current unit, adjust the index
	if unit == current_unit:
		end_current_unit_turn()

# Get the currently active unit
func get_current_unit() -> Node:
	return current_unit
