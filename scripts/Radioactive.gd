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

var tile_pos: Vector2i
var coord: Vector2
var layer: int

# Flag to track if particle updates are needed
var particles_need_update = true

# Function to get the zombie's movement range and spawn particles around it
func _ready():
	area2d = get_parent()
	particles_need_update = true  # Trigger an initial update
	update_particles()

# Function to update only when needed
func _process(delta):
	# Simplify to only check for interactions
	for particle_instance in active_particle_instances:
		var particle_world_pos = particle_instance.global_position
		var particle_tile_pos = get_node("/root/MapManager/TileMap").local_to_map(particle_world_pos)
		check_for_player_units_in_tile(particle_tile_pos)

# Call this function to update particles when needed (e.g., zombie moves or turns change)
func update_particles():
	if !particles_need_update:
		return  # Skip if no updates are needed
	
	# Reset the flag
	particles_need_update = false	
	
	var zombie = get_parent()
	if zombie.zombie_type == "Radioactive":
		# Ensure particles are updated in the correct order
		await spawn_particles_based_on_manhattan_distance()
		#await get_tree().create_timer(1).timeout	
		await remove_out_of_range_radiation(zombie.tile_pos, zombie.movement_range)
		await remove_overlapping_particles_for_all_zombies()	
	
	show_all_radiation()	
	
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
			if !get_parent().is_zombie_present(tile_pos) and !is_radiation_present_on_tile(tile_pos):
				
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
				if tile_is_valid(target_tile_pos) and get_parent().is_tile_movable(target_tile_pos):
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

	# Check if the particle is within the map bounds
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var particle_tile_pos = tilemap.local_to_map(spawn_position)
	if !tilemap.get_used_rect().has_point(particle_tile_pos):
		particle_instance.visible = false  # Hide the particle if outside map bounds
		print("Particle off-map, setting visibility to false at position: ", particle_tile_pos)
	else:
		particle_instance.visible = true  # Ensure visible if within bounds
	
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
					unit.apply_damage(5)  # Assuming units have an `apply_damage` method					
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
			# Apply damage to the zombie if they're on the same tile as the particle
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
	
	# Loop through the active particles to adjust visibility or remove them
	for i in range(active_particle_instances.size() - 1, -1, -1):
		var particle_instance = active_particle_instances[i]
		var particle_tile_pos = tilemap.local_to_map(particle_instance.global_position)
		
		# Check if the particle is outside the map bounds
		if !tilemap.get_used_rect().has_point(particle_tile_pos):
			print("Particle off-map, setting visibility to false at position: ", particle_tile_pos)
			particle_instance.visible = false
		elif !valid_tiles.has(particle_tile_pos):
			print("Removing radiation at tile: ", particle_tile_pos)
			particle_instance.queue_free()  # Remove the particle from the scene
			active_particle_instances.remove_at(i)  # Remove from the tracking list
		else:
			particle_instance.visible = true  # Ensure visibility for in-range particles

func remove_overlapping_particles_for_all_zombies():
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var tile_to_particle_map: Dictionary = {}

	var all_zombies = get_tree().get_nodes_in_group("zombies")
	for zombie in all_zombies:
		if zombie.zombie_type == "Radioactive":
			var zombie_particles = zombie.get_child(4).active_particle_instances
			for i in range(zombie_particles.size() - 1, -1, -1):
				var particle_instance = zombie_particles[i]
				var particle_tile_pos = tilemap.local_to_map(particle_instance.global_position)

				if tile_to_particle_map.has(particle_tile_pos):
					# Remove only if a duplicate exists
					print("Removing duplicate particle at tile: ", particle_tile_pos)
					particle_instance.queue_free()
					zombie_particles.erase(particle_instance)
				else:
					# Register particle to avoid duplicates
					tile_to_particle_map[particle_tile_pos] = particle_instance

# Function to hide all radiation particles
func hide_all_radiation():
	for particle_instance in active_particle_instances:
		particle_instance.get_child(1).visible = false  # Hide the particle
		# Optionally, you can remove the particles from the scene entirely:
		# particle_instance.queue_free()  # This will remove the particle from the scene
		# active_particle_instances.erase(particle_instance)  # Remove from active list
	print("All radiation particles are hidden.")

func show_all_radiation():
	# Loop through all active particle instances
	for particle_instance in active_particle_instances:
		var particle_child = particle_instance.get_child(1)  # Get the child responsible for fade
		particle_child.visible = true  # Ensure the child is visible
		particle_instance.get_child(0).emitting = true  # Start emitting particles
		
		particle_child.modulate.a = 0.0
		
		# Start the alpha modulation asynchronously
		fade_in_particle(particle_child, 2)  # Adjust fade duration here
	
	print("All radiation particles are visible with alpha modulation.")

# Function to handle the fade-in effect for a single particle's child
@onready var fade_timer = Timer.new()

func fade_in_particle(particle_child, fade_duration: float):
	# Add a timer to the scene if not already added
	if fade_timer.get_parent() == null:
		add_child(fade_timer)
	
	# Set up the fade parameters
	var modulate_alpha = 0.0
	var step_count = 10  # Number of steps in the fade
	var alpha_step = 1.0 / step_count  # Alpha increment per step
	fade_timer.wait_time = fade_duration / step_count  # Time per step
	fade_timer.one_shot = true
	
	while modulate_alpha < 1.0:
		modulate_alpha += alpha_step
		if modulate_alpha > 1.0:
			modulate_alpha = 1.0
		particle_child.modulate = Color(1, 1, 1, modulate_alpha)  # Adjust the alpha of child 1

		# Wait for the timer to finish before the next increment
		fade_timer.start()
		await fade_timer.timeout
