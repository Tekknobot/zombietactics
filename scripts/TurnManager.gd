extends Node2D

var player_units: Array = []  # Array to hold all player units
var zombie_units: Array = []  # Array to hold all zombie units
var current_unit_index: int = 0  # Index of the current unit
var all_units: Array = []  # Combined list of all units (to determine turn order)

func _ready() -> void:
	# Get all player units and zombie units
	player_units = get_tree().get_nodes_in_group("player_units")
	zombie_units = get_tree().get_nodes_in_group("zombies")
	
	# Combine both groups into a single turn order list
	all_units = player_units + zombie_units

	# Sort the units by initiative (if applicable) or keep as default
	# Uncomment the following line if units have an `initiative` property
	# all_units.sort_custom(self, "_sort_by_initiative")

	current_unit_index = 0  # Start with the first unit
	start_current_unit_turn()  # Start the first unit's turn

# Sort units by initiative (optional)
func _sort_by_initiative(a, b) -> int:
	# Compare the initiative of two units; higher initiative goes first
	return b.initiative - a.initiative  # Descending order

# Start the current unit's turn
func start_current_unit_turn() -> void:
	if all_units.size() == 0:
		print("No units available.")
		return
	
	var current_unit = all_units[current_unit_index]
	if current_unit.has_method("start_turn"):
		current_unit.start_turn()  # Call start_turn on the current unit
	else:
		print("Unit", current_unit.name, "does not have a 'start_turn' method!")

# End the current unit's turn and move to the next one
func end_current_unit_turn() -> void:
	var current_unit = all_units[current_unit_index]
	if current_unit.has_method("end_turn"):
		current_unit.end_turn()  # Call end_turn on the current unit
	else:
		print("Unit", current_unit.name, "does not have an 'end_turn' method!")

	# Move to the next unit
	current_unit_index = (current_unit_index + 1) % all_units.size()
	start_current_unit_turn()  # Start the next unit's turn

# Add a new player unit to the turn manager
func add_player_unit(unit: Node) -> void:
	if not player_units.has(unit):
		player_units.append(unit)
		all_units = player_units + zombie_units  # Recombine unit list

# Add a new zombie unit to the turn manager
func add_zombie_unit(unit: Node) -> void:
	if not zombie_units.has(unit):
		zombie_units.append(unit)
		all_units = player_units + zombie_units  # Recombine unit list

# Remove a unit (e.g., if destroyed)
func remove_unit(unit: Node) -> void:
	if player_units.has(unit):
		player_units.erase(unit)
	elif zombie_units.has(unit):
		zombie_units.erase(unit)
	
	# Recombine unit list and adjust the current index
	all_units = player_units + zombie_units
	if current_unit_index >= all_units.size():
		current_unit_index = 0  # Reset index if it exceeds list size
