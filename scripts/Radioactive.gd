extends Node2D

# Particle scene
var particle_scene = preload("res://assets/scenes/prefab/radioactivity.tscn")  # Path to the particle scene
var active_particle_instances = []  # To track active particles

# Reference to the Area2D node (parent node)
var area2d = null
var cell_size = Vector2(32, 32)  # Correct the cell size to match the tile size of the TileMap

# This flag ensures particles are only spawned once
var particles_spawned = false

# Function to get the zombie's movement range and spawn particles around it
func _ready():
	area2d = get_parent()  # Get the Area2D node as the parent node

# Function to spawn particles based on the zombie's Manhattan distance range
func spawn_particles_based_on_manhattan_distance():
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")  # Reference to your TileMap
	var zombie = get_parent()  # The zombie node
	if zombie.zombie_type == "Radioactive":  # Check if the zombie is radioactive
		var zombie_tile_pos = tilemap.local_to_map(zombie.global_position)  # Convert zombie global position to tilemap coordinates
		var movement_range = zombie.movement_range  # Get the zombie's movement range

		# Debugging: Print zombie position and movement range
		print("Zombie Tile Position: ", zombie_tile_pos)
		print("Movement Range: ", movement_range)

		# Get the tiles within the zombie's movement range based on Manhattan distance
		var tiles_in_range = get_radiation_tiles(zombie_tile_pos, movement_range)

		# Debugging: Check the tiles found in range
		print("Tiles in Range: ", tiles_in_range.size())

		# Loop through all tiles in range and spawn a particle at each valid tile
		for tile_pos in tiles_in_range:
			# Convert the tile position to world coordinates using the helper function
			var world_pos = tilemap_position_to_world(tile_pos)
			
			# Debugging: Check the world position for tiles and particle spawn locations
			print("Tile Position: ", tile_pos, " => World Position: ", world_pos)
			
			if !get_parent().is_tile_movable(world_pos) or !get_parent().is_unit_present(world_pos) or !get_parent().is_structure(world_pos):
				# Spawn particle at the world position (not at the zombie's position)
				spawn_radiation_particle(world_pos)

# Get all tiles within movement range based on Manhattan distance
func get_radiation_tiles(zombie_tile_pos: Vector2i, movement_range: int) -> Array[Vector2i]:
	var tiles_in_range: Array[Vector2i] = []
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	
	# Debugging: Print the used area of the tilemap
	print("Tilemap Used Rect: ", tilemap.get_used_rect())

	# Loop through all positions within the zombie's movement range (Manhattan distance)
	for x in range(-movement_range, movement_range + 1):
		for y in range(-movement_range, movement_range + 1):
			if abs(x) + abs(y) <= movement_range:
				var target_tile_pos: Vector2i = zombie_tile_pos + Vector2i(x, y)
				
				# Check if the tile is valid (using get_cell() to ensure tile exists)
				print("Checking Tile: ", target_tile_pos)  # Debugging
				if tile_is_valid(target_tile_pos):
					tiles_in_range.append(target_tile_pos)

	# Debugging: Print how many tiles were found in range
	print("Found Tiles in Range: ", tiles_in_range.size())
	return tiles_in_range

# Helper function to check if a tile is valid using get_cell()
func tile_is_valid(tile_pos: Vector2i) -> bool:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	# Ensure the tile position is within the tilemap's used area
	if tilemap.get_used_rect().has_point(tile_pos):
		var tile_id = tilemap.get_cell_source_id(0, Vector2i(tile_pos.x, tile_pos.y))
		# Check if the tile exists and is not empty (i.e., -1 indicates no tile)
		if tile_id != -1:
			return true
	print("Invalid Tile: ", tile_pos)  # Debugging
	return false

# Helper function to convert tile position to world position using TileMap's map_to_world
func tilemap_position_to_world(tile_pos: Vector2i) -> Vector2:
	# Convert the tilemap grid position to world position using TileMap's built-in method
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
		
	return tilemap.map_to_local(tile_pos)  # map_to_world should be used here to properly convert to world coordinates

# Helper function to spawn a particle at a specific position
func spawn_radiation_particle(spawn_position: Vector2):
	# Print out the position where the particle will spawn
	print("Spawning particle at position: ", spawn_position)
	
	var particle_instance = particle_scene.instantiate()
	add_child(particle_instance)
	particle_instance.global_position = spawn_position  # Ensure correct world placement
	particle_instance.get_child(0).emitting = true  # Start emitting particles if needed
	active_particle_instances.append(particle_instance)  # Track active particles

# Function to update the particle positions (make them follow the zombie)
func _process(delta):
	var zombie = get_parent()  # The zombie node
	if zombie.zombie_type == "Radioactive" and not particles_spawned:
		# Only spawn particles once, when the zombie is ready
		spawn_particles_based_on_manhattan_distance()
		particles_spawned = true  # Set the flag to true to avoid spawning multiple times
