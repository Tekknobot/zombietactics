extends Node2D

# Arrays to store non-zombie (player) and zombie units
var non_zombie_units: Array = []  # Player-controlled units
var zombie_units: Array = []      # Enemy-controlled units

# Current unit and turn management variables
var current_unit: Node = null

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
	phase = TurnPhase.PLAYER_TURN  # Ensure we start with player turn
	start_next_turn()  # Start the first player's turn

func start_next_turn() -> void:
	match phase:
		TurnPhase.PLAYER_TURN:
			var next_unit = null
			for unit in non_zombie_units:
				if !unit.has_moved:
					next_unit = unit
					break

			if next_unit != null:
				current_unit = next_unit
				current_unit.call_deferred("start_turn")
			else:
				phase = TurnPhase.ENEMY_TURN
				start_enemy_turns()

		TurnPhase.ENEMY_TURN:
			var next_zombie = null
			for unit in zombie_units:
				if !unit.has_moved:
					next_zombie = unit
					break

			if next_zombie != null:
				current_unit = next_zombie
				current_unit.call_deferred("start_turn")
			else:
				if phase == TurnPhase.ENEMY_TURN:
					print("All enemy units have acted, resetting turn cycle.")
					end_turns()
				else:
					print("Turn cycle stuck, forcing reset.")
					end_turns()

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
			unit.has_moved = false  # Ensure zombie units are reset
			print("Added zombie unit: ", unit.name)
		else:
			non_zombie_units.append(unit)
			unit.has_moved = false  # Ensure player units are reset
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
		current_unit.has_moved = true  # Mark player unit as moved
	else:
		current_unit.has_moved = true  # Mark enemy unit as moved

	current_unit = null  # Clear current unit
	start_next_turn()  # Move to the next unit's turn
