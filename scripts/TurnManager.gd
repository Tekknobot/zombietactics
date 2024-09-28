extends Node2D

# Lists to store non-zombie and zombie units
var non_zombie_units: Array = []  # Non-zombie units (e.g., player units, AI allies)
var zombie_units: Array = []      # Zombie units

# Turn counter for zombies (determines how many zombie turns to take)
var zombie_turns_left: int = 0
var is_zombie_turn: bool = false

# Pointer to the current unit taking a turn
var current_unit: Node = null

# States for the turn phases
enum TurnPhase { NON_ZOMBIE_TURN, ZOMBIE_TURN }
var phase: TurnPhase = TurnPhase.NON_ZOMBIE_TURN

# Called when the TurnManager is ready
func _ready():
	print("TurnManager is ready.")
	reset_turn_order()  # Populate the unit arrays
	
	if non_zombie_units.size() == 0 and zombie_units.size() == 0:
		print("No units found. Cannot start turns.")
		return  # Prevent calling start_turns if there are no units.

	start_turns()  # Start the turn process

# Initialize turn order
func start_turns() -> void:
	print("Start Turns Called")  # Debugging line
	zombie_turns_left = non_zombie_units.size()  # Set to the number of non-zombie units
	is_zombie_turn = true  # Start with zombie turns
	phase = TurnPhase.ZOMBIE_TURN
	start_next_turn()

# Handles the start of the next unit's turn
func start_next_turn() -> void:
	print("Current phase: ", phase)

	match phase:
		TurnPhase.ZOMBIE_TURN:
			if zombie_turns_left > 0:
				if zombie_units.size() > 0:
					current_unit = zombie_units.pop_front()  # Get the next zombie unit
					if current_unit != null:
						print("Starting turn for zombie unit: ", current_unit.name)
						current_unit.call_deferred("start_turn")  # Call the unit's turn method
					else:
						print("Error: Zombie unit is null.")

					zombie_turns_left -= 1

				# When all zombies have acted, move to non-zombie turn
				if zombie_turns_left == 0:
					phase = TurnPhase.NON_ZOMBIE_TURN
					print("Switching to non-zombie turn")
					start_non_zombie_turns()  # Start non-zombie turns
			else:
				print("No zombie units available for this turn.")

		TurnPhase.NON_ZOMBIE_TURN:
			if non_zombie_units.size() > 0:
				current_unit = non_zombie_units.pop_front()  # Get the next non-zombie unit
				if current_unit != null:
					print("Starting turn for non-zombie unit: ", current_unit.name)
					current_unit.call_deferred("start_turn")  # Call the unit's turn method
				else:
					print("Error: Non-zombie unit is null.")

			# If no non-zombie units are left, restart the turn cycle
			if non_zombie_units.size() == 0:
				print("Ending non-zombie turns")
				end_turns()  # End turns and restart

# Start non-zombie turns
func start_non_zombie_turns() -> void:
	if non_zombie_units.size() > 0:
		start_next_turn()  # Start the next turn for non-zombie units

# End all turns and reset the cycle
func end_turns() -> void:
	print("Ending all turns, resetting turn order...")
	is_zombie_turn = false
	reset_turn_order()  # Reset the turn order
	start_turns()  # Restart the turns after resetting the order

# Reset the turn order, refilling the arrays with the current units on the board
func reset_turn_order() -> void:
	print("Resetting turn order...")
	non_zombie_units.clear()  # Clear existing units
	zombie_units.clear()

	# Populate the unit arrays from the group
	for unit in get_tree().get_nodes_in_group("units"):
		if unit.is_zombie:
			zombie_units.append(unit)
			print("Added zombie unit: ", unit.name)
		else:
			non_zombie_units.append(unit)
			print("Added non-zombie unit: ", unit.name)

	# Debugging output
	print("Non-zombie units count: ", non_zombie_units.size())
	print("Zombie units count: ", zombie_units.size())

# This method is called by a unit to signal the end of its turn
func end_current_unit_turn() -> void:
	if current_unit == null:
		print("Error: No current unit to end turn for.")
		return

	print("Ending turn for unit: ", current_unit.name)

	# Append the current unit to the respective array based on turn type
	if is_zombie_turn:
		zombie_units.append(current_unit)
	else:
		non_zombie_units.append(current_unit)

	current_unit = null  # Clear current unit
	start_next_turn()  # Move to the next turn
