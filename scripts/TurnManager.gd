extends Node2D

# Arrays to store non-zombie (player) and zombie units
var non_zombie_units: Array = []  # Player-controlled units
var zombie_units: Array = []      # Enemy-controlled units

# Current unit and turn management variables
var current_unit: Node = null
var is_zombie_turn: bool = false

# States for the turn phases
enum TurnPhase { PLAYER_TURN, ENEMY_TURN }
var phase: TurnPhase = TurnPhase.PLAYER_TURN

# Called when the TurnManager is ready
func _ready():
	print("TurnManager is ready.")
	reset_turn_order()  # Populate the unit arrays
	
	if non_zombie_units.size() == 0 and zombie_units.size() == 0:
		print("No units found. Cannot start turns.")
		return

	start_turns()  # Start the turn process

# Initialize turn order and start the turn cycle
func start_turns() -> void:
	print("Start Turns Called")  # Debugging
	is_zombie_turn = false  # Start with player turn (non-zombie units)
	phase = TurnPhase.PLAYER_TURN
	reset_player_turns()  # Reset the `has_moved` flag for all player units
	start_next_turn()

# Reset all player units to indicate they haven't moved yet
func reset_player_turns() -> void:
	for unit in non_zombie_units:
		unit.has_moved = false  # Each player unit should have a 'has_moved' variable

# Handles the start of the next unit's turn
func start_next_turn() -> void:
	match phase:
		TurnPhase.PLAYER_TURN:
			# Look for the next player unit that hasn't moved
			var next_unit = null
			for unit in non_zombie_units:
				if !unit.has_moved:
					next_unit = unit
					break  # Found a unit that hasn't moved yet
			
			if next_unit != null:
				current_unit = next_unit
				print("Player's unit turn: ", current_unit.name)
				current_unit.call_deferred("start_turn")  # Start player unit's turn
			else:
				# If all player units have moved, switch to the enemy phase
				print("All player units have moved, switching to enemy phase.")
				start_enemy_turns()

		TurnPhase.ENEMY_TURN:
			# Check if there are enemy units to act
			if zombie_units.size() > 0:
				current_unit = zombie_units.pop_front()  # Get the next enemy unit
				if current_unit != null:
					print("Enemy's unit turn: ", current_unit.name)
					current_unit.call_deferred("start_turn")  # Start enemy unit's turn
			else:
				# If no enemy units are left, restart the turn cycle
				print("All enemy units have acted or none exist, resetting turn cycle.")
				end_turns()  # End the enemy phase and restart the turn cycle

# Starts the player turns
func start_player_turns() -> void:
	if non_zombie_units.size() > 0:
		start_next_turn()  # Start the next player unit's turn

# Start enemy turns after all player units have moved
func start_enemy_turns() -> void:
	print("Switching to enemy phase.")
	phase = TurnPhase.ENEMY_TURN

	# Immediately check if there are no enemy units
	if zombie_units.size() == 0:
		print("No enemies to take turns, ending enemy phase early.")
		end_turns()  # No enemies, restart the turn cycle
	else:
		start_next_turn()  # Start the first enemy unit's turn

# End the current turn and reset the turn cycle
func end_turns() -> void:
	print("Ending turn cycle, resetting turns.")
	reset_turn_order()  # Reset the turn order
	start_turns()  # Restart the turns after resetting the order

# Reset the turn order, refilling the unit arrays with current units
func reset_turn_order() -> void:
	print("Resetting turn order...")
	non_zombie_units.clear()
	zombie_units.clear()

	# Populate the unit arrays from the scene tree (using groups)
	for unit in get_tree().get_nodes_in_group("units"):
		if unit.is_zombie:
			zombie_units.append(unit)
			print("Added zombie unit: ", unit.name)
		else:
			non_zombie_units.append(unit)
			print("Added non-zombie unit: ", unit.name)

	# Debugging
	print("Non-zombie units: ", non_zombie_units.size())
	print("Zombie units: ", zombie_units.size())

# Method called by a unit to signal the end of its turn
func end_current_unit_turn() -> void:
	if current_unit == null:
		print("Error: No current unit to end turn for.")
		return

	print("Ending turn for unit: ", current_unit.name)

	# Mark the unit as having moved
	if phase == TurnPhase.PLAYER_TURN:
		current_unit.has_moved = true
	else:
		# For enemy units, just put them back into the array after they move
		zombie_units.append(current_unit)

	current_unit = null  # Clear current unit
	start_next_turn()  # Move to the next unit's turn
