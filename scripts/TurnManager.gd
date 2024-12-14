extends Node2D

var player_units: Array = []  # Array for player units
var zombie_units: Array = []  # Array for zombie units
var current_unit: Node = null  # The unit currently taking its turn
var current_group: String = "player_units"  # Which group's turn it is ("player_units" or "zombie_units")
var current_unit_index: int = 0  # Index of the current unit in the current group

var trigger_zombies: bool = false
var used_turns_count: int = 0
var max_turn_count: int = 3

signal player_action_completed

@onready var zombie_spawn_manager = get_node("/root/MapManager/SpawnZombies")

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

func start_current_unit_turn() -> void:
	# Ensure there are valid player units
	if player_units.size() == 0:
		print("No player units left.")
		return

	# Iterate through a copy of the array to allow safe removal of invalid units
	for current_unit in player_units.duplicate():  # Use `.duplicate()` to avoid modifying the array while iterating
		if current_unit and !current_unit.is_queued_for_deletion():  # Check if the unit is valid and not queued for deletion
			if current_unit.has_method("start_turn"):
				current_unit.start_turn()  # Call start_turn on the current unit
			else:
				print("Current unit does not have a 'start_turn' method!")
		else:
			print("Invalid or removed unit found. Cleaning up.")
			player_units.erase(current_unit)  # Remove invalid or freed units from the array


func end_current_turn() -> void:
	trigger_zombies = false
	
	# Get all player units
	var all_player_units = get_tree().get_nodes_in_group("player_units")
	
	# Count the number of players who have used their turn
	used_turns_count = 0
	for player in all_player_units:
		if player.has_used_turn:
			used_turns_count += 1
	
	# If 3 or more units have used their turns and zombies are not triggered, fire event
	if used_turns_count >= max_turn_count and trigger_zombies == false:
		print("Three player units have used their turns. Ending player turn.")
		await zombie_spawn_manager.spawn_zombies()
		GlobalManager.zombies_processed = 0
		GlobalManager.zombie_queue.clear()
		await get_tree().create_timer(0.1).timeout
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
	
