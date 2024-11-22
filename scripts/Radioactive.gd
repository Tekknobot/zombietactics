extends Node2D

# Variables for the radiation effect
var radiation_radius = 100  # Radius of the radiation burst
var radiation_damage = 5    # Damage per tick of radiation
var radiation_duration = 5  # Duration of the radiation effect (in seconds)
var radiation_cooldown = 3  # Cooldown before the zombie can attack again
var radiation_timer = 0     # Cooldown timer
var affected_units = []     # List of affected units

var can_use_radiation_attack : bool = true

# Reference to the Area2D node (parent node)
var area2d = null

func _ready():
	area2d = get_parent()  # Get the Area2D node as the parent node
	set_process(true)

# Called each frame to update the cooldown timer
func _process(delta):
	radiation_timer -= delta  # Decrease the cooldown timer

	# Check the radiation cooldown timer
	if radiation_timer <= 0 and can_use_radiation_attack == true:
		use_radiation_burst()

	# Check if any affected units are out of range
	for unit in affected_units:
		if not is_unit_in_range(unit):
			remove_radiation_effect(unit)

# Perform the radiation burst
func use_radiation_burst():
	# Find all units within the radiation radius using Manhattan movement
	var units_in_range = get_units_in_range()

	# Apply effect to units that are in range
	for unit in units_in_range:
		if unit.is_in_group("player_units"):  # Check if it's a player unit
			if unit not in affected_units:
				affected_units.append(unit)
				apply_radiation_effect(unit)

				var tilemap: TileMap = get_node("/root/MapManager/TileMap")
				
				# Get world position of the target tile
				var target_world_pos = unit.position
				print("Target world position: ", target_world_pos)
				
				# Determine the direction to the target
				var target_direction = target_world_pos.x - get_parent().position.x

				# Flip the sprite based on the target's relative position and current scale.x value
				if target_direction > 0 and get_parent().scale.x != -1:
					get_parent().scale.x = -1  # Flip sprite to face right
				elif target_direction < 0 and get_parent().scale.x != 1:
					get_parent().scale.x = 1  # Flip sprite to face left		

				# Play attack animation
				get_parent().get_child(0).play("attack")

	# Reset the cooldown timer
	radiation_timer = radiation_cooldown

# Get all units in range of the radiation burst, using Manhattan movement based on the TileMap grid
func get_units_in_range() -> Array:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")  # Reference to your TileMap
	var units_in_range = []
	
	# Get the movement range from the parent zombie (assuming it's stored in a variable)
	var movement_range = get_parent().movement_range  # Parent zombie has a "movement_range" variable
	
	# Convert the global position of the zombie to tilemap coordinates
	var zombie_tile_pos = tilemap.local_to_map(get_parent().global_position)
	
	# Get a list of all player units in the game world
	var player_units = get_tree().get_nodes_in_group("player_units")  # Assuming player units are in a group called "player_units"
	
	# Loop through all player units
	for unit in player_units:
		if unit is Area2D:  # Ensure the body is a valid player unit
			# Convert the global position of the player unit to tilemap coordinates
			var unit_tile_pos = tilemap.local_to_map(unit.global_position)
			
			# Calculate the Manhattan distance between the zombie and the unit in tilemap space
			var manhattan_distance = abs(zombie_tile_pos.x - unit_tile_pos.x) + abs(zombie_tile_pos.y - unit_tile_pos.y)
			
			# Check if the Manhattan distance is within the movement range
			if manhattan_distance <= movement_range:
				units_in_range.append(unit)
					
	return units_in_range

# Check if the unit is within range of the radiation burst
func is_unit_in_range(unit: Node) -> bool:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")  # Reference to your TileMap
	var zombie_tile_pos = tilemap.local_to_map(get_parent().global_position)
	var unit_tile_pos = tilemap.local_to_map(unit.global_position)

	# Calculate the Manhattan distance between the zombie and the unit
	var manhattan_distance = abs(zombie_tile_pos.x - unit_tile_pos.x) + abs(zombie_tile_pos.y - unit_tile_pos.y)

	# Check if the unit is still within the movement range
	return manhattan_distance <= get_parent().movement_range

# Remove the radiation effect from a unit
func remove_radiation_effect(unit: Node):
	affected_units.erase(unit)  # Remove from affected list

	# Optionally, do something else to reset the unit's state

# Apply radiation effect (damage over time)
func apply_radiation_effect(unit: Node):
	unit.flash_damage()
	unit.audio_player.stream = unit.hurt_audio
	unit.audio_player.play()

	# Create a timer to apply damage over time
	var damage_timer = Timer.new()
	damage_timer.wait_time = 1  # Damage every second
	damage_timer.one_shot = false  # Ensure it repeats until we stop it manually
	add_child(damage_timer)

	# Connect the timer signal using a new Callable structure
	damage_timer.timeout.connect(Callable(self, "_on_damage_timeout").bind(unit))  # Pass the unit using bind

	# Start the timer
	damage_timer.start()

	# Wait for 5 seconds (this will block the function for 5 seconds)
	await get_tree().create_timer(5).timeout

	# Stop the timer after 5 seconds
	if damage_timer.time_left <= 5:  # Check if 5 seconds have passed
		damage_timer.stop()
		get_parent().get_child(0).play("default")
		_on_damage_timeout(unit)


# Called when the damage timer times out
func _on_damage_timeout(unit: Node):
	if unit.is_in_group("player_units"):
		unit.apply_damage(radiation_damage)  # Assuming the player has a `apply_damage()` method
		
		can_use_radiation_attack = false
		
		# Update the HUD to reflect new stats
		var hud_manager = get_parent().get_parent().get_parent().get_node("HUDManager")
		hud_manager.update_hud(unit)
