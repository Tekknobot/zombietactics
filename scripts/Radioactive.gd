extends Node2D

# Particle scene
var particle_scene = preload("res://assets/scenes/prefab/radioactivity.tscn")  # Path to the particle scene
var active_particle_instances = []  # To track active particles
var damaged_units_this_turn = []  # Array to keep track of units damaged this turn

# Reference to the Area2D node (parent node)
var area2d = null
var cell_size = Vector2(32, 32)  # Correct the cell size to match the tile size of the TileMap

# This flag ensures particles are only spawned once
var particles_spawned = false

# Function to get the zombie's movement range and spawn particles around it
func _ready():
	area2d = get_parent()  # Get the Area2D node as the parent node

# Function to update the particle positions and check if a player is on the same tile as any particle
func _process(delta):
	var zombie = get_parent()  # The zombie node
	if zombie.zombie_type == "Radioactive":
		# Only spawn particles once, when the zombie is ready
		remove_out_of_range_radiation(get_parent().tile_pos, get_parent().movement_range)
		spawn_particles_based_on_manhattan_distance()
		remove_overlapping_particles_for_all_zombies()

	# Check all active particles and see if any player unit is on the same tile
	for particle_instance in active_particle_instances:
		# Get the world position of the particle instance
		var particle_world_pos = particle_instance.global_position
		
		# Convert the world position to tile position
		var tilemap: TileMap = get_node("/root/MapManager/TileMap")
		var particle_tile_pos = tilemap.local_to_map(particle_world_pos)
		
		# Check if a player unit is on the same tile
		check_for_player_units_in_tile(particle_tile_pos)
		
func spawn_particles_based_on_manhattan_distance():
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")  # Reference to your TileMap
	var zombie = get_parent()  # The zombie node
	if zombie.zombie_type == "Radioactive":  # Check if the zombie is radioactive
		var zombie_tile_pos = tilemap.local_to_map(zombie.global_position)  # Convert zombie global position to tilemap coordinates
		await get_tree().create_timer(1).timeout
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
			
			# Check if the tile is valid for spawning (movable, no zombie, and no radiation)
			if get_parent().is_tile_movable(tile_pos) and !get_parent().is_zombie_present(tile_pos) and !is_radiation_present_on_tile(tile_pos):
				
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

# Function to check for player units in the same tile as the particle
func check_for_player_units_in_tile(tile_pos: Vector2i):
	var units_in_tile = get_tree().get_nodes_in_group("player_units") + get_tree().get_nodes_in_group("zombies")
	for unit in units_in_tile:
		# Get the unit's position in world coordinates
		var unit_tile_pos = get_node("/root/MapManager/TileMap").local_to_map(unit.global_position)
		
		# Check if the player unit's tile position matches the tile position of the particle
		if unit_tile_pos == tile_pos and unit.is_in_group("player_units"):
			# Apply damage to the player if they're on the same tile as the particle
			if not damaged_units_this_turn.has(unit):
				if unit.player_name == "Yoshida. Boi":
					unit.audio_player.stream = unit.dog_hurt_audio
					unit.audio_player.play()
					
					unit.flash_damage()  # Assuming there's a flash_damage method for visual effect
					unit.apply_damage(get_parent().attack_damage)  # Assuming units have an `apply_damage` method
					unit.health_ui.value -= 5 
				else:
					unit.audio_player.stream = unit.hurt_audio
					unit.audio_player.play()
					
					unit.flash_damage()  # Assuming there's a flash_damage method for visual effect
					unit.apply_damage(get_parent().attack_damage)  # Assuming units have an `apply_damage` method					
					unit.health_ui.value -= 5 
					
				# Update the HUD to reflect new stats
				var hud_manager = get_node("/root/MapManager/HUDManager")
				hud_manager.update_hud(unit)	

				# Mark the player as damaged this turn
				damaged_units_this_turn.append(unit)
				
		# Check if the player unit's tile position matches the tile position of the particle
		if unit_tile_pos == tile_pos and unit.is_in_group("zombies"):
			if unit.zombie_type == "Radioactive":
				return
			# Apply damage to the player if they're on the same tile as the particle
			if not damaged_units_this_turn.has(unit):
				unit.audio_player.stream = unit.hurt_audio
				unit.audio_player.play()
					
				unit.flash_damage()  # Assuming there's a flash_damage method for visual effect
				unit.apply_damage(5)  # Assuming units have an `apply_damage` method					
				unit.health_ui.value -= 5 
				
				# Update the HUD to reflect new stats
				var hud_manager = get_node("/root/MapManager/HUDManager")
				hud_manager.update_hud_zombie(unit)	

				# Mark the player as damaged this turn
				damaged_units_this_turn.append(unit)				

# Helper function to check if a radiation particle is already present on a tile
func is_radiation_present_on_tile(tile_pos: Vector2i) -> bool:
	for particle_instance in active_particle_instances:
		var tilemap: TileMap = get_node("/root/MapManager/TileMap")
		var particle_tile_pos = tilemap.local_to_map(particle_instance.global_position)
		if particle_tile_pos == tile_pos:
			return true  # Radiation is already present on this tile
	return false  # No radiation present on this tile

# Helper function to remove radiation particles outside the zombie's movement range
func remove_out_of_range_radiation(zombie_tile_pos: Vector2i, movement_range: int):
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	
	# Create a list of tiles that are within the valid range
	var valid_tiles = get_radiation_tiles(zombie_tile_pos, movement_range)
	
	# Loop through the active particles in reverse to safely remove items
	for i in range(active_particle_instances.size() - 1, -1, -1):
		var particle_instance = active_particle_instances[i]
		var particle_tile_pos = tilemap.local_to_map(particle_instance.global_position)
		
		# If the particle is not within the valid range, remove it
		if !valid_tiles.has(particle_tile_pos):
			print("Removing radiation at tile: ", particle_tile_pos)
			particle_instance.queue_free()  # Remove the particle from the scene
			active_particle_instances.remove_at(i)  # Remove from the tracking list

# Helper function to remove overlapping radiation particles across all zombies
func remove_overlapping_particles_for_all_zombies():
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")  # Reference to the TileMap
	var tile_to_particle_map: Dictionary = {}  # Dictionary to track particles by tile position
	
	# Iterate through all zombies in the group
	var all_zombies = get_tree().get_nodes_in_group("zombies")
	for zombie in all_zombies:
		if zombie.zombie_type == "Radioactive":  # Only process radioactive zombies
			var zombie_particles = zombie.get_child(4).active_particle_instances
			
			# Check each particle instance for overlaps
			for i in range(zombie_particles.size() - 1, -1, -1):
				var particle_instance = zombie_particles[i]
				var particle_tile_pos = tilemap.local_to_map(particle_instance.global_position)
				
				# If a particle already exists on this tile, remove the duplicate
				if tile_to_particle_map.has(particle_tile_pos):
					print("Removing duplicate particle at tile: ", particle_tile_pos)  # Debugging
					particle_instance.queue_free()  # Remove the particle from the scene
					zombie_particles.erase(particle_instance)  # Remove from tracking list
				else:
					# Add the particle to the map if no duplicate exists
					tile_to_particle_map[particle_tile_pos] = particle_instance
