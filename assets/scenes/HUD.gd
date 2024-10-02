extends Control

# Variables to store references to HUD elements
var healthbar: ProgressBar
var unit_name: Label
var unit_health: Label
var unit_damage: Label
var portrait: TextureRect  # Single portrait display area
var tile_map: TileMap  # Reference to the TileMap containing the game tiles
var attackable_tile_prefab: PackedScene = preload("res://assets/scenes/UI/attack_tile.tscn")

# Preload the portrait assets
var portrait_zombie = preload("res://assets/portraits/zombie_port.png")
var portrait_merc = preload("res://assets/portraits/rambo_port.png")
var portrait_soldier = preload("res://assets/portraits/soldier_port.png")
var portrait_dog = preload("res://assets/portraits/dog_port.png")

# References
var selected_unit = null  # Store reference to the selected unit
var unit_manager = null  # Reference to the UnitManager
var global_manager = null  # Reference to the GlobalManager

var waiting_for_attack_target = false  # Flag to indicate waiting for attack target
var attack_range: int  # Attack range of the selected unit

var attackable_tiles: Array = []  # Array to store currently active attackable tiles

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Get references to HUD elements by their node paths
	healthbar = $Healthbar
	unit_name = $UnitName
	unit_health = $HBoxContainer/UnitHealth
	unit_damage = $HBoxContainer/UnitDamage
	portrait = $Background  # Reference to the portrait display area (TextureRect)

	# Get references to the UnitManager and GlobalManager
	tile_map = get_node("/root/MapManager/TileMap")  # Adjust this path as necessary
	
# Public function to update the health bar
func update_health(current_health: int, max_health: int) -> void:
	healthbar.max_value = max_health
	healthbar.value = current_health
	unit_health.text = "HP: " + str(current_health) + " - " + str(max_health)  # Update formatting

# Public function to update the unit name
func update_unit_name(name: String) -> void:
	unit_name.text = name

# Public function to update the unit damage
func update_unit_damage(damage: int) -> void:
	unit_damage.text = "POW: " + str(damage)

# Public function to update the portrait based on unit type
func update_portrait(unit_type: String) -> void:
	match unit_type:
		"Zombie":
			portrait.texture = portrait_zombie
		"Merc":
			portrait.texture = portrait_merc
		"Soldier":
			portrait.texture = portrait_soldier
		"Dog":
			portrait.texture = portrait_dog
		_:
			portrait.texture = null  # Clear portrait if no valid unit type

# Public function to update the entire HUD based on the selected unit
func update_hud_for_unit(unit_type: String, unit_health_value: int, unit_max_health_value: int, unit_damage_value: int) -> void:
	update_unit_name(unit_type)
	update_health(unit_health_value, unit_max_health_value)
	update_unit_damage(unit_damage_value)
	update_portrait(unit_type)
	selected_unit = GlobalManager.get_unit_by_type(unit_type)  # Get the selected unit from the GlobalManager

	# Dynamically get attack range from the selected unit
	if selected_unit:
		attack_range = selected_unit.attack_range  # Assuming attack_range is a property of the selected unit

# Handle the attack button press
func _on_attack_button_down() -> void:
	if selected_unit:
		if !GlobalManager.zombie_turn:  # Assuming GlobalManager has this property
			print("Attack button pressed! Waiting for target...")
			waiting_for_attack_target = true
			selected_unit.armed_attack = true
			
			highlight_attackable_tiles()  # Highlight attackable tiles
		else:
			print("This unit cannot attack right now.")
	else:
		print("No unit selected for attacking.")

# Function to clear previously shown attackable tiles
func clear_attackable_tiles() -> void:
	for attackable_tile in attackable_tiles:
		attackable_tile.queue_free()  # Remove it from the scene
		print("Removed attackable tile at: ", attackable_tile.position)  # Debugging line
	attackable_tiles.clear()  # Clear the array

# Highlight attackable tiles based on the selected unit's attack range
func highlight_attackable_tiles() -> void:
	if selected_unit:  # Check if a unit is selected
		var selected_unit_position = tile_map.local_to_map(selected_unit.position)  # Convert world position to tile position
		clear_attackable_tiles()  # Clear any existing attackable tiles
		print("Highlighting attackable tiles for unit at position: ", selected_unit_position)

		# Loop over all possible tiles within attack range using Manhattan distance
		for x_offset in range(-attack_range, attack_range + 1):
			for y_offset in range(-attack_range, attack_range + 1):
				if abs(x_offset) + abs(y_offset) <= attack_range:  # Manhattan distance check
					var target_tile_pos = selected_unit_position + Vector2i(x_offset, y_offset)

					# Ensure the target tile position is within the bounds of the TileMap
					if tile_map.get_used_rect().has_point(target_tile_pos):  # Only process valid tile positions
						# Check if the tile is walkable or if it is an enemy unit
						if selected_unit.is_attackable(target_tile_pos):  # You can customize this condition based on your game logic
							# Instance the attackable tile prefab at the target position
							var attackable_tile = attackable_tile_prefab.instantiate()
							var attackable_tile_world_pos = tile_map.map_to_local(target_tile_pos)  # Convert tile position to world position
							attackable_tile.position = attackable_tile_world_pos  # Set the position of the attackable tile
							attackable_tile.name = "AttackableTile"  # Assign a name to the tile for identification
							tile_map.add_child(attackable_tile)  # Add to the TileMap or main scene

							# Add the new tile to the active tiles array
							attackable_tiles.append(attackable_tile)

							# Debugging information
							print("Added attackable tile at position: ", target_tile_pos, " (World position: ", attackable_tile_world_pos, ")")
						else:
							# Optionally handle tiles that are not walkable or occupied
							print("Tile at ", target_tile_pos, " is not walkable or occupied.")
					else:
						# Debugging for out-of-bounds
						print("Target tile position out of bounds: ", target_tile_pos)
	else:
		print("No unit selected to highlight attackable tiles.")

# This function will be called when an enemy unit is clicked (needs to be hooked into the input system)
func on_enemy_unit_clicked(enemy_unit) -> void:
	if waiting_for_attack_target and selected_unit:
		# Check if the enemy is in range using the new function
		if selected_unit.is_in_attack_range(selected_unit, enemy_unit):
			print("Enemy in range! Attacking...")
			execute_attack_on_enemy(enemy_unit)
		else:
			print("Enemy out of range.")
	else:
		# If no target was selected, reset armed attack state
		selected_unit.armed_attack = false  # Cancel armed attack if no valid target
	waiting_for_attack_target = false  # Stop waiting after target selection

# Function to execute the attack logic
func execute_attack_on_enemy(enemy_unit) -> void:
	# Ensure the selected unit has an attack method (and that it's implemented)
	selected_unit.attack()
	
	# Assuming the enemy unit has 'health' and 'max_health' properties
	update_health(enemy_unit.health, enemy_unit.maxhealth)

	# Optionally flash the enemy red or show damage dealt (using UnitManager's feedback)
	enemy_unit.flash_target(enemy_unit)  # This is a placeholder for feedback

	# Set armed_attack to false after the attack
	selected_unit.armed_attack = false  # Reset armed attack state

	# End the turn after the attack
	GlobalManager.end_current_unit_turn()  # Call to end the current unit's turn
