extends Node2D

var units: Array = []  # Array to hold all units
var current_unit_index: int = 0  # Index of the current unit

func _ready() -> void:
	# Get all units in the group
	units = get_tree().get_nodes_in_group("units")
	current_unit_index = 0  # Start with the first unit
	start_current_unit_turn()  # Start the first unit's turn

# Start the current unit's turn
func start_current_unit_turn() -> void:
	if units.size() == 0:
		print("No units available.")
		return
	
	var current_unit = units[current_unit_index]
	current_unit.start_turn()  # Call start_turn on the current unit

# End the current unit's turn and move to the next one
func end_current_unit_turn() -> void:
	var current_unit = units[current_unit_index]
	current_unit.end_turn()  # Call end_turn on the current unit

	current_unit_index = (current_unit_index + 1) % units.size()  # Cycle through units
	start_current_unit_turn()  # Start the next unit's turn
