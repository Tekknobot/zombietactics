extends Node2D

@onready var ZOMBIE_SCENE = preload("res://assets/scenes/prefab/Zombie.scn")  # Preload Zombie scene
@onready var SOLDIER_SCENE = preload("res://assets/scenes/prefab/Soldier.scn")  # Preload Soldier scene
@onready var MERCENARY_SCENE = preload("res://assets/scenes/prefab/Mercenary.scn")  # Preload Mercenary scene
@onready var DOG_SCENE = preload("res://assets/scenes/prefab/Dog.scn")  # Preload Dog scene
@onready var tile_map = get_node("/root/MapManager/TileMap")  # Adjust path based on your scene structure
@onready var map_manager = get_node("/root/MapManager")  # Reference to MapManager to access structure coordinates

const WATER = 0  # Ensure this matches the correct ID for water tiles

var rng = RandomNumberGenerator.new()
var map_ready: bool = false  # Flag to check if map is ready

# Maximum spawn counts for each unit type
var max_soldiers: int = 1
var max_mercenaries: int = 1
var max_dogs: int = 6  # Maximum number of dogs to spawn
var max_zombies: int = 16  # Updated for clarity

# Number of zombie clusters to spawn
var number_of_zombie_clusters: int = 3  # Adjust this to the desired number of zombie clusters

# Define cluster parameters
const CLUSTER_SIZE: int = 2  # Radius of the cluster (1 will create a 3x3 area)
const ZOMBIE_PROXIMITY_LIMIT: int = 2  # Distance from zombies to avoid for soldiers and mercenaries

var zombie_positions: Array = []  # Store positions of spawned zombies

func _ready():
	# Initialize map_ready from the MapManager
	map_ready = map_manager.map_ready  # Get the initial state of map_ready

func _process(delta: float):
	# Poll for the map_ready state
	if not map_ready:
		map_ready = map_manager.map_ready  # Update our local state
		
		if map_ready:  # If the map is now ready, proceed to spawn units
			_on_map_generated()

# Function called when the map generation is complete
func _on_map_generated():
	spawn_zombie_clusters(number_of_zombie_clusters, max_zombies, ZOMBIE_SCENE)  # Spawn multiple clusters
	spawn_soldier_cluster(max_soldiers, SOLDIER_SCENE)
	spawn_mercenary_cluster(max_mercenaries, MERCENARY_SCENE)

# Spawn multiple clusters of zombies on one side of the map
func spawn_zombie_clusters(num_clusters: int, max_count: int, zombie_scene: PackedScene):
	for cluster_index in range(num_clusters):
		spawn_zombie_cluster(max_count, zombie_scene)  # Call existing function to spawn each cluster

# Spawn a single cluster of zombies
func spawn_zombie_cluster(count: int, zombie_scene: PackedScene):
	# Randomly select a central tile for the cluster on the left side (x = 0 to 7)
	var central_x = rng.randi_range(0, 7)  # Adjusted to limit x to left side
	var central_y = rng.randi_range(0, 16 - 1)
	var central_tile_pos = Vector2i(central_x, central_y)

	# Debug print the central tile position
	print("Central tile for zombie cluster: ", central_tile_pos)

	# Define cluster boundaries
	for dx in range(-CLUSTER_SIZE, CLUSTER_SIZE + 1):
		for dy in range(-CLUSTER_SIZE, CLUSTER_SIZE + 1):
			if count <= 0:
				return  # Stop if we've spawned enough zombies

			var spawn_x = central_x + dx
			var spawn_y = central_y + dy
			var spawn_tile_pos = Vector2i(spawn_x, spawn_y)

			# Ensure we are within bounds of the map
			if spawn_x >= 0 and spawn_x < 8 and spawn_y >= 0 and spawn_y < 16:  # Limit x to 0-7
				var tile_id = tile_map.get_cell_source_id(0, spawn_tile_pos)

				# Check if the tile is valid for spawning
				if is_valid_spawn_tile(spawn_tile_pos, tile_id):
					spawn_unit(spawn_x, spawn_y, zombie_scene)
					zombie_positions.append(spawn_tile_pos)  # Store zombie position
					count -= 1  # Decrement the count of zombies left to spawn

# Spawn a cluster of soldiers on the opposite side of the map
func spawn_soldier_cluster(count: int, soldier_scene: PackedScene):
	# Randomly select a central tile for the cluster on the right side (x = 8 to 15)
	var central_x = rng.randi_range(8, 16 - 1)  # Adjusted to limit x to right side
	var central_y = rng.randi_range(0, 16 - 1)
	var central_tile_pos = Vector2i(central_x, central_y)

	# Debug print the central tile position
	print("Central tile for soldier cluster: ", central_tile_pos)

	# Define cluster boundaries
	for dx in range(-CLUSTER_SIZE, CLUSTER_SIZE + 1):
		for dy in range(-CLUSTER_SIZE, CLUSTER_SIZE + 1):
			if count <= 0:
				return  # Stop if we've spawned enough soldiers

			var spawn_x = central_x + dx
			var spawn_y = central_y + dy
			var spawn_tile_pos = Vector2i(spawn_x, spawn_y)

			# Ensure we are within bounds of the map
			if spawn_x >= 8 and spawn_x < 16 and spawn_y >= 0 and spawn_y < 16:  # Limit x to 8-15
				var tile_id = tile_map.get_cell_source_id(0, spawn_tile_pos)

				# Check if the tile is valid for spawning and not near zombies
				if is_valid_spawn_tile(spawn_tile_pos, tile_id) and not is_near_zombie(spawn_tile_pos):
					spawn_unit(spawn_x, spawn_y, soldier_scene)
					count -= 1  # Decrement the count of soldiers left to spawn
					
					# After spawning a soldier, attempt to spawn dogs around it
					spawn_dogs_around_unit(spawn_x, spawn_y, DOG_SCENE)

# Spawn a cluster of mercenaries on the opposite side of the map
func spawn_mercenary_cluster(count: int, mercenary_scene: PackedScene):
	# Randomly select a central tile for the cluster on the right side (x = 8 to 15)
	var central_x = rng.randi_range(8, 16 - 1)  # Adjusted to limit x to right side
	var central_y = rng.randi_range(0, 16 - 1)
	var central_tile_pos = Vector2i(central_x, central_y)

	# Debug print the central tile position
	print("Central tile for mercenary cluster: ", central_tile_pos)

	# Define cluster boundaries
	for dx in range(-CLUSTER_SIZE, CLUSTER_SIZE + 1):
		for dy in range(-CLUSTER_SIZE, CLUSTER_SIZE + 1):
			if count <= 0:
				return  # Stop if we've spawned enough mercenaries

			var spawn_x = central_x + dx
			var spawn_y = central_y + dy
			var spawn_tile_pos = Vector2i(spawn_x, spawn_y)

			# Ensure we are within bounds of the map
			if spawn_x >= 8 and spawn_x < 16 and spawn_y >= 0 and spawn_y < 16:  # Limit x to 8-15
				var tile_id = tile_map.get_cell_source_id(0, spawn_tile_pos)

				# Check if the tile is valid for spawning and not near zombies
				if is_valid_spawn_tile(spawn_tile_pos, tile_id) and not is_near_zombie(spawn_tile_pos):
					spawn_unit(spawn_x, spawn_y, mercenary_scene)
					count -= 1  # Decrement the count of mercenaries left to spawn
					
					# After spawning a mercenary, attempt to spawn dogs around it
					spawn_dogs_around_unit(spawn_x, spawn_y, DOG_SCENE)

# Function to check if a position is too close to any zombies
func is_near_zombie(tile_pos: Vector2i) -> bool:
	for zombie_pos in zombie_positions:
		if tile_pos.distance_to(zombie_pos) <= ZOMBIE_PROXIMITY_LIMIT:
			print("Position is too close to a zombie at: ", tile_pos)
			return true  # The position is too close to a zombie
	return false  # The position is not too close to any zombies

# Function to spawn dogs around a unit
func spawn_dogs_around_unit(unit_x: int, unit_y: int, dog_scene: PackedScene):
	# Define the relative positions for spawning dogs (N, S, E, W)
	var relative_positions = [
		Vector2i(0, 1),  # North
		Vector2i(0, -1),  # South
		Vector2i(1, 0),  # East
		Vector2i(-1, 0)  # West
	]

	for position_offset in relative_positions:
		var dog_x = unit_x + position_offset.x
		var dog_y = unit_y + position_offset.y

		# Ensure we are within bounds of the map
		if dog_x >= 0 and dog_x < 16 and dog_y >= 0 and dog_y < 16:
			var dog_tile_pos = Vector2i(dog_x, dog_y)
			var tile_id = tile_map.get_cell_source_id(0, dog_tile_pos)

			# Check if the tile is valid for spawning
			if is_valid_spawn_tile(dog_tile_pos, tile_id):
				spawn_unit(dog_x, dog_y, dog_scene)

# Check if a tile is valid for spawning (not water or structure)
func is_valid_spawn_tile(tile_pos: Vector2i, tile_id: int) -> bool:
	# Check if the tile is water
	if is_water(tile_pos):
		print("Tile is water. Skipping spawn at: ", tile_pos)
		return false
	
	# Check if the tile is a structure
	if is_structure(tile_pos):
		print("Tile is a structure. Skipping spawn at: ", tile_pos)
		return false

	# If tile is not water and not a structure, it's valid for spawning
	return true

# Check if a tile is water based on MapManager's water coordinates
func is_water(tile_pos: Vector2i) -> bool:
	# Access the water coordinates array from MapManager
	var water_coords = map_manager.water_coordinates

	# Check if the given tile_pos is within the array of water coordinates
	for water_tile in water_coords:
		if water_tile == tile_pos:
			return true  # Tile is water

	return false  # Tile is not water

# Check if a tile is a structure based on MapManager's structure coordinates
func is_structure(tile_pos: Vector2i) -> bool:
	# Access the structure coordinates array from MapManager
	var structure_coords = map_manager.structure_coordinates

	# Check if the given tile_pos is within the array of structure coordinates
	for structure in structure_coords:
		if structure == tile_pos:
			return true  # Tile is occupied by a structure

	return false  # Tile is not a structure

# Generalized function to spawn a unit (zombie, soldier, mercenary, dog)
func spawn_unit(x: int, y: int, unit_scene: PackedScene):
	var unit_instance = unit_scene.instantiate()
	var local_position = tile_map.map_to_local(Vector2i(x, y))
	unit_instance.position = local_position
	add_child(unit_instance)

# Check if a tile at (x, y) is already occupied by another unit
func is_occupied(x: int, y: int) -> bool:
	var local_position = tile_map.map_to_local(Vector2i(x, y))

	# Check if any children are already on this position
	for child in get_children():
		if child.position == local_position:
			return true  # A unit is occupying this position
	return false  # No unit occupies this position
