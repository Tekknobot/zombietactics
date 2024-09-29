extends Node2D

var units: Array = []  # Array to hold all units
var current_unit_index: int = 0  # Index of the current unit
var units_moved: int = 0  # Counter for units that have moved
var movement_status: Array = []  # Track movement status for each unit

# Timer for checking units
var unit_check_timer: Timer

func _ready() -> void:
	# Initialize the timer
	unit_check_timer = Timer.new()
	unit_check_timer.wait_time = 1.0  # Check every second
	unit_check_timer.connect("timeout", Callable(self, "_check_units"))  # Using Callable to connect
	add_child(unit_check_timer)  # Add the timer as a child to the scene
	unit_check_timer.start()  # Start the timer

func _check_units() -> void:
	units = get_tree().get_nodes_in_group("units")
	print("Checking units... Found: ", units.size())  # Debugging output

	if units.size() > 0:
		unit_check_timer.stop()  # Stop checking if units are found
		reset_units_movement()  # Initialize movement tracking
		current_unit_index = 0  # Start with the first unit
		start_current_unit_turn()

func reset_units_movement() -> void:
	units_moved = 0  # Reset the counter
	movement_status = []  # Reset movement status array
	for unit in units:
		movement_status.append(false)  # Initialize with false (not moved)

func start_current_unit_turn() -> void:
	if units.size() == 0:
		print("No units available.")
		return
	
	var current_unit = units[current_unit_index]
	current_unit.start_turn()  # Call start_turn on the current unit

func end_current_unit_turn() -> void:
	var current_unit = units[current_unit_index]
	current_unit.end_turn()  # Call end_turn on the current unit

	# Mark the current unit as having moved
	movement_status[current_unit_index] = true
	units_moved += 1

	# Check if all units have moved
	if units_moved >= units.size():
		print("All units have moved once!")
		reset_units_movement()  # Reset for the next turn

	current_unit_index = (current_unit_index + 1) % units.size()  # Cycle through units
	start_current_unit_turn()  # Start the next unit's turn
