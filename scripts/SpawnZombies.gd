extends Node2D

# Reference to the player units and structures
@export var zombie_scene: PackedScene # Assign your Zombie scene in the editor

@onready var map_manager = get_parent().get_node("/root/MapManager")
@onready var unit_spawn = get_parent().get_node("/root/MapManager/UnitSpawn")
@onready var tilemap = get_node("/root/MapManager/TileMap") # Replace with your actual tilemap path
var WATER_TILE_ID = 0

# Store the used structures globally or as a class variable
var used_structures = []

var zombie_names = [
	"Gnasher", "Lunger", "Spewer", "Flailer",
	"Slosher", "Lasher", "Mumbler", "Thrasher",
	"Hacker", "Chopper", "Pouncer", "Rattler",
	"Screecher", "Sprawler", "Wailer", "Twitcher",
	"Scrambler", "Snapper", "Thriller", "Dribbler",
	"Shredder", "Cruncher", "Splatter", "Glower",
	"Piercer", "Seether", "Stabber", "Gusher",
	"Squelcher", "Shrieker", "Bubbler", "Groaner"
];

func _ready() -> void:
	if map_manager.map_1:
		WATER_TILE_ID = 0
	elif map_manager.map_2:
		WATER_TILE_ID = 9
	elif map_manager.map_3:
		WATER_TILE_ID = 15
	elif map_manager.map_4:
		WATER_TILE_ID = 21
	else:
		print("Error: No map selected, defaulting WATER to 0.")
		WATER_TILE_ID = 0  # Fallback value if no map is selected	

func spawn_zombies():
	var player_units = get_tree().get_nodes_in_group("player_units")
	var structures = get_tree().get_nodes_in_group("structures")

	# Debug: Check if units and structures are found
	print("Player units: ", player_units.size())
	print("Structures: ", structures.size())

	if player_units.size() == 0 or structures.size() == 0:
		print("No player units or structures found.")
		return

	# Find the furthest non-demolished and unused structure from any player unit
	var furthest_structure = null
	var furthest_distance = 0  # Start with 0 as we're looking for the max distance

	for structure in structures:
		if structure.is_demolished or structure in used_structures:
			continue  # Skip demolished or already used structures

		for player in player_units:
			if not structure or not player:
				continue  # Avoid null nodes
			var distance = player.global_position.distance_to(structure.global_position)
			if distance > furthest_distance:
				furthest_distance = distance
				furthest_structure = structure

	if not furthest_structure:
		print("No valid non-demolished and unused structures found.")
		return

	# Mark the structure as used
	used_structures.append(furthest_structure)

	# Debug: Furthest non-demolished and unused structure found
	print("Furthest structure: ", furthest_structure.name, " at ", furthest_structure.global_position)

	# Spawn 4 zombies adjacent to the furthest structure
	var structure_tile_pos = tilemap.local_to_map(furthest_structure.global_position)
	var spawn_positions = get_adjacent_positions(structure_tile_pos)
	var zombies_spawned = 0

	for tile_pos in spawn_positions:
		if zombies_spawned >= 4:
			break

		if is_valid_spawn_position(tile_pos):
			var zombie_instance = zombie_scene.instantiate()
			if zombie_instance:
				zombie_instance.global_position = tilemap.map_to_local(tile_pos)
				unit_spawn.add_child(zombie_instance)
				zombie_instance.add_to_group("zombies")
				
				zombie_instance.audio_player.stream = zombie_instance.zombie_audio
				zombie_instance.audio_player.play()

				# Assign a unique ID to the zombie
				zombie_instance.set("zombie_id", unit_spawn.zombie_id_counter)  # Set a custom property for the unique ID
				unit_spawn.zombie_id_counter += 1  # Increment the zombie ID for the next one
								
				# Assign a unique name to the zombie
				if zombie_names.size() > 0:
					zombie_instance.zombie_name = zombie_instance.zombie_type + " " + zombie_names.pop_back()  # Remove the last name from the list
				
				# Debug: Zombie spawned
				print("Spawned zombie at position: ", tile_pos)

				# Camera focuses on the active zombie
				var camera = get_node_or_null("/root/MapManager/Camera2D")
				if camera:
					camera.focus_on_position(zombie_instance.global_position)

				zombies_spawned += 1
				await get_tree().create_timer(0.5).timeout

	if zombies_spawned == 0:
		print("No zombies were spawned. Check spawn positions.")
		
# Helper function to get adjacent grid positions
func get_adjacent_positions(origin: Vector2i) -> Array:
	var directions = [
		Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)
	]
	var adjacent_positions = []

	for dir in directions:
		adjacent_positions.append(origin + dir)

	return adjacent_positions

# Check if the spawn position is valid
func is_valid_spawn_position(tile_pos: Vector2i) -> bool:
	# Check if tilemap exists
	if not tilemap:
		print("Tilemap not found!")
		return false

	# Get the bounds of the tilemap
	var used_rect = tilemap.get_used_rect()

	# Check if the cell position is within the used rectangle
	if not used_rect.has_point(tile_pos):
		print("Position ", tile_pos, " is out of bounds.")
		return false

	# Check if the tile is movable
	if not is_tile_movable(tile_pos):
		print("Position ", tile_pos, " is not movable.")
		return false

	return true

# Check if a tile is movable
func is_tile_movable(tile_pos: Vector2i) -> bool:
	var tile_id = tilemap.get_cell_source_id(0, tile_pos)
	if is_water_tile(tile_id):
		return false
	if is_structure(tile_pos) or is_unit_present(tile_pos):
		return false
	return true

# Check if a tile is a water tile
func is_water_tile(tile_id: int) -> bool:
	return tile_id == WATER_TILE_ID

# Check if there is a structure on the tile
func is_structure(tile_pos: Vector2i) -> bool:
	var structures = get_tree().get_nodes_in_group("structures")
	for structure in structures:
		var structure_tile_pos = tilemap.local_to_map(structure.global_position)
		if tile_pos == structure_tile_pos:
			return true
	return false

# Check if there is a unit on the tile
func is_unit_present(tile_pos: Vector2i) -> bool:
	var all_units = get_tree().get_nodes_in_group("player_units") + get_tree().get_nodes_in_group("zombies")
	for unit in all_units:
		var unit_tile_pos = tilemap.local_to_map(unit.global_position)
		if tile_pos == unit_tile_pos:
			return true
	return false
