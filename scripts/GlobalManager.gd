extends Node2D

var non_zombie_units: Array = []  # Array to hold non-zombie units
var zombie_units: Array = []  # Array to hold zombie units

var current_unit_index: int = 0  # Index of the current non-zombie unit
var current_zombie_index: int = 0  # Index of the current zombie unit

var units_moved: int = 0  # Counter for units that have moved
var zombies_moved: int = 0  # Counter for zombies that have moved

var movement_status_non_zombies: Array = []  # Track movement status for non-zombies
var movement_status_zombies: Array = []  # Track movement status for zombies

# Timer for checking units
var unit_check_timer: Timer
var zombie_turn: bool = false  # Track if it's zombie turn or not

func _ready() -> void:
	setup_timer()  # Call the function to set up the timer
	_check_units()  # Initial check for units when the scene is ready

func setup_timer() -> void:
	# Initialize the timer if it doesn't already exist
	if unit_check_timer == null:
		unit_check_timer = Timer.new()
		unit_check_timer.wait_time = 0.5  # Short delay before checking for units
		unit_check_timer.connect("timeout", Callable(self, "_check_units"))
		add_child(unit_check_timer)  # Add the timer as a child to the scene

	unit_check_timer.start()  # Start the timer

func _check_units() -> void:
	# Get all nodes in the 'units' group
	var all_units = get_tree().get_nodes_in_group("units")
	print("Checking units... Found: ", all_units.size())  # Debugging output

	# Clear previous unit lists
	non_zombie_units.clear()
	zombie_units.clear()

	# Split units into zombie and non-zombie arrays
	for unit in all_units:
		if unit.is_zombie:
			zombie_units.append(unit)
		else:
			non_zombie_units.append(unit)

	print("Non-zombie units found: ", non_zombie_units.size())
	print("Zombie units found: ", zombie_units.size())

	if non_zombie_units.size() > 0 or zombie_units.size() > 0:
		unit_check_timer.stop()  # Stop checking if units are found
		reset_units_movement()  # Initialize movement tracking
		current_unit_index = 0  # Start with the first non-zombie unit
		zombie_turn = false  # Start with non-zombie units
		start_current_unit_turn()  # Start first non-zombie unit turn
	else:
		print("No units available. Checking again...")  # Debugging output for no units

func reset_units_movement() -> void:
	units_moved = 0  # Reset non-zombie movement counter
	zombies_moved = 0  # Reset zombie movement counter
	movement_status_non_zombies.clear()  # Clear non-zombie movement status array
	movement_status_zombies.clear()  # Clear zombie movement status array

	# Initialize movement status for non-zombies
	for unit in non_zombie_units:
		movement_status_non_zombies.append(false)

	# Initialize movement status for zombies
	for unit in zombie_units:
		movement_status_zombies.append(false)

func start_current_unit_turn() -> void:
	if zombie_turn:
		if zombie_units.size() == 0:
			print("No zombies available.")
			return

		var current_zombie = zombie_units[current_zombie_index]
		current_zombie.start_turn()  # Call start_turn on the current zombie
	else:
		if non_zombie_units.size() == 0:
			print("No non-zombies available.")
			return

		var current_unit = non_zombie_units[current_unit_index]
		current_unit.start_turn()  # Call start_turn on the current non-zombie unit

func end_current_unit_turn() -> void:
	if zombie_turn:
		if zombie_units.size() == 0:
			print("No zombies available for ending turn.")
			return

		var current_zombie = zombie_units[current_zombie_index]
		current_zombie.end_turn()  # Call end_turn on the current zombie

		# Mark the current zombie as having moved
		movement_status_zombies[current_zombie_index] = true
		zombies_moved += 1

		print("Zombies moved: ", zombies_moved, "/", zombie_units.size())

		# Check if all zombies have moved before switching to non-zombies
		if zombies_moved >= zombie_units.size():
			print("All zombies have moved. Switching to non-zombies.")
			reset_units_movement()  # Reset movement status for both sets of units
			zombie_turn = false  # Switch to non-zombie turn

		# Move to the next zombie
		current_zombie_index = (current_zombie_index + 1) % zombie_units.size()  # Cycle through zombies
	else:
		if non_zombie_units.size() == 0:
			print("No non-zombies available for ending turn.")
			return

		var current_unit = non_zombie_units[current_unit_index]
		current_unit.end_turn()  # Call end_turn on the current non-zombie unit

		# Mark the current non-zombie as having moved
		movement_status_non_zombies[current_unit_index] = true
		units_moved += 1

		print("Non-zombies moved: ", units_moved, "/", non_zombie_units.size())

		# Check if all non-zombies have moved before switching to zombies
		if units_moved >= non_zombie_units.size():
			print("All non-zombies have moved. Switching to zombies.")
			reset_units_movement()  # Reset movement status for both sets of units
			zombie_turn = true  # Switch to zombie turn

		# Move to the next non-zombie
		current_unit_index = (current_unit_index + 1) % non_zombie_units.size()  # Cycle through non-zombies

	# Start the next unit's turn (whether zombie or non-zombie)
	start_current_unit_turn()
