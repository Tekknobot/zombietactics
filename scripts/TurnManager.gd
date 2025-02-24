extends Node2D

var player_units: Array = []  # Array for player units
var zombie_units: Array = []  # Array for zombie units
var current_unit: Node = null  # The unit currently taking its turn
var current_group: String = "player_units"  # Which group's turn it is ("player_units" or "zombie_units")
var current_unit_index: int = 0  # Index of the current unit in the current group

var trigger_zombies: bool = false
var used_turns_count: int = 0
var max_turn_count: int = 9

signal player_action_completed

@onready var zombie_spawn_manager = get_node("/root/MapManager/SpawnZombies")
@onready var mission_manager = get_node("/root/MapManager/MissionManager")
@onready var hud_mananger = get_node("/root/MapManager/HUDManager")

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

func check_if_end_map():
	var zombies = get_tree().get_nodes_in_group("zombies")
	if zombies.size() <= 0:
		GlobalManager.zombies_cleared = true
		reset_player_units()
	else:
		GlobalManager.zombies_cleared = false		

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


func _compare_candidates(a, b):
	# Custom comparator function for sorting candidate dictionaries by "dist".
	if a["dist"] < b["dist"]:
		return -1
	elif a["dist"] > b["dist"]:
		return 1
	else:
		return 0

func end_current_turn() -> void:
	var trigger_zombies = false

	# Get all non-AI player units.
	var all_non_ai_players = []
	for player in get_tree().get_nodes_in_group("player_units"):
		if not player.is_in_group("unitAI"):
			all_non_ai_players.append(player)
	
	# Count the number of non-AI players who have used their turn.
	var used_turns_count = 0
	for player in all_non_ai_players:
		if player.has_used_turn:
			used_turns_count += 1
	
	var max_turn_count = all_non_ai_players.size()
	
	# If all non-AI units have used their turns and zombies haven't been triggered, fire the zombie event.
	if used_turns_count >= max_turn_count and not trigger_zombies:
		# Optionally, spawn zombies:
		await zombie_spawn_manager.spawn_zombies()
		GlobalManager.zombies_processed = 0
		GlobalManager.zombie_queue.clear()
		await get_tree().create_timer(0.1).timeout        
		GlobalManager.reset_global_manager()
		
		# Among AI-controlled player units, build a list of candidates sorted by proximity.
		var all_ai_player_units = get_tree().get_nodes_in_group("unitAI")
		var candidates = []
		for ai in all_ai_player_units:
			var min_dist = INF
			# Check distance to all non-AI player units.
			for unit in get_tree().get_nodes_in_group("player_units"):
				if unit != ai:
					var d = abs(ai.tile_pos.x - unit.tile_pos.x) + abs(ai.tile_pos.y - unit.tile_pos.y)
					if d < min_dist:
						min_dist = d
			# Check distance to zombies.
			for zombie in get_tree().get_nodes_in_group("zombies"):
				var d = abs(ai.tile_pos.x - zombie.tile_pos.x) + abs(ai.tile_pos.y - zombie.tile_pos.y)
				if d < min_dist:
					min_dist = d
			candidates.append({ "ai": ai, "dist": min_dist })
		
		# Sort the candidates by distance (smallest first)
		candidates.sort_custom(Callable(self, "_compare_candidates"))
		
		# Iterate through each candidate and trigger its AI turn.
		for candidate in candidates:
			var chosen_ai = candidate["ai"]
			# Await each AI unit's turn to finish before moving to the next.
			await chosen_ai.start_ai_turn()

		trigger_zombies = true

		# Reset the player units for a new turn.
		reset_player_units()
		check_if_end_map()


func end_current_turn_from_button():
	# Among AI-controlled player units, build a list of candidates sorted by proximity.
	var all_ai_player_units = get_tree().get_nodes_in_group("unitAI")
	var candidates = []
	for ai in all_ai_player_units:
		var min_dist = INF
		# Check distance to all non-AI player units.
		for unit in get_tree().get_nodes_in_group("player_units"):
			if unit != ai:
				var d = abs(ai.tile_pos.x - unit.tile_pos.x) + abs(ai.tile_pos.y - unit.tile_pos.y)
				if d < min_dist:
					min_dist = d
		# Check distance to zombies.
		for zombie in get_tree().get_nodes_in_group("zombies"):
			var d = abs(ai.tile_pos.x - zombie.tile_pos.x) + abs(ai.tile_pos.y - zombie.tile_pos.y)
			if d < min_dist:
				min_dist = d
		candidates.append({ "ai": ai, "dist": min_dist })
	
	# Sort the candidates by distance (smallest first)
	candidates.sort_custom(Callable(self, "_compare_candidates"))
	
	# Iterate through each candidate and trigger its AI turn.
	for candidate in candidates:
		var chosen_ai = candidate["ai"]
		# Await each AI unit's turn to finish before moving to the next.
		await chosen_ai.start_ai_turn()	

	trigger_zombies = true

	# Reset the player units for a new turn.
	reset_player_units()
	check_if_end_map()
		
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

func reset_player_units():
	# Get all player units in the game
	var players = get_tree().get_nodes_in_group("player_units")
	for player in players:	
		player.has_moved = false
		player.has_attacked = false
		player.has_used_turn = false
		player.can_start_turn = true
		player.modulate = Color(1, 1, 1)	
		if player.is_in_group("unitAI"):		
			player.modulate = Color8(255, 110, 255)
					
	hud_mananger.hide_special_buttons()
	mission_manager.check_mission_manager()
