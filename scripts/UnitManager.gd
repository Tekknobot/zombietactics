extends Node2D

# Unit states
enum State {
	IDLE,
	SELECTED,
	MOVING, 
	ATTACKING
}

# Unit properties
var tile_pos: Vector2i  # Unit's current position in the tile grid
var is_moving: bool = false  # Flag to check if the unit is currently moving
var state: State = State.IDLE  # Current state of the unit

# Public variables (can be adjusted per unit)
# General properties for all units
@export var attack_range: int = 1  # General attack range for all units
@export var attack_damage: int = 5  # General attack damage for all units
@export var movement_range: int = 3  # Default movement range
@export var unit_type: String
@export var health: int = 5

# Define public variables for target positions
@export var first_target_position: Vector2i = Vector2i(-1, -1)  # Position of the first click
@export var second_target_position: Vector2i = Vector2i(-1, -1)  # Position of the second click
@export var active_target_position: Vector2i = Vector2i(-1, -1)  # Active target for movement

var target_tile_pos
var last_target_tile_pos

# Reference to the TileMap and AStarGrid
var tilemap: TileMap = null
var astar_grid: AStarGrid2D = null  # Reference to the AStarGrid2D

# Walkable tile prefab for visualization
var walkable_tile_prefab: PackedScene = preload("res://assets/scenes/UI/move_tile.tscn")
var walkable_tiles: Array = []  # Stores references to walkable tile indicators

# Reference to the unit's sprite
var sprite: AnimatedSprite2D = null

var last_position: Vector2  # Variable to store the last position of the unit

var selected_unit: Node2D = null  # Track the currently selected unit

var has_moved

# This flag is used to differentiate zombies from non-zombie units
@export var is_zombie: bool
var turn_manager: Node2D = null  # Reference to the TurnManager

# Called when the node enters the scene
func _ready() -> void:
	# Try to find the TileMap
	tilemap = get_tree().get_root().get_node("MapManager/TileMap")  # Adjust path based on your scene structure
	if tilemap == null:
		print("Error: TileMap not found!")
	else:
		print("TileMap found: ", tilemap.name)

	# Try to find the TurnManager
	turn_manager = get_tree().get_root().get_node("MapManager/TurnManager")  # Adjust the path accordingly
	if turn_manager == null:
		print("Error: TurnManager not found!")
	else:
		print("TurnManager found: ", turn_manager.name)


	# Create a new AStarGrid instance
	astar_grid = AStarGrid2D.new()

	# Initialize the unit's position in the tile grid based on its current world position
	tile_pos = tilemap.local_to_map(position)

	# Reference the sprite (assuming it's a direct child of the unit)
	sprite = $AnimatedSprite2D  # Adjust based on your node structure

	# Set the initial z_index based on the tile position
	update_z_index()

	# Debugging: Print initial position
	print("Unit initialized at tile: ", tile_pos)

	# Initialize the last position when the unit is ready
	last_position = position  
	
	# Notify that this unit is ready
	emit_signal("ready")
	add_to_group("units")
	
	# Set up AStar grid
	update_astar_grid()

func _process(delta: float) -> void:
	tile_pos = tilemap.local_to_map(position)
	update_z_index() 
	update_astar_grid()
		
# Function to update the AStar grid
func update_astar_grid() -> void:
	var grid_width = 16
	var grid_height = 16
	astar_grid.size = Vector2i(grid_width, grid_height)
	astar_grid.cell_size = Vector2(1, 1)
	astar_grid.default_compute_heuristic = 1
	astar_grid.diagonal_mode = 1
	astar_grid.update()
	
	# Update walkable and unwalkable cells
	for x in 16:
		for y in 16:
			var tile_id = tilemap.get_cell_source_id(0, Vector2i(x, y))
			if tile_id == -1 or tile_id == 0 or is_structure(Vector2i(x, y)) or is_unit_present(Vector2i(x, y)):
				astar_grid.set_point_solid(Vector2i(x, y), true)
			else:
				astar_grid.set_point_solid(Vector2i(x, y), false)# Set all points as walkable

# Smooth movement function
func move_to_position(target_world_pos: Vector2) -> void:
	is_moving = true  # Lock the unit during movement
	state = State.MOVING  # Change to moving state

	# Calculate direction to move in (normalized vector)
	var direction = (target_world_pos - position).normalized()

	# Determine the direction of movement based on target and current position
	if direction.x > 0:
		scale.x = -1  # Facing right (East)
	elif direction.x < 0:
		scale.x = 1  # Facing left (West)

	# Define movement speed (units per second)
	var speed = 50  # Adjust speed as needed

	# Move in a loop until the position is close enough to the target
	while position.distance_to(target_world_pos) > 2:  # Threshold to avoid overshooting
		var delta = get_process_delta_time()

		# Calculate movement step based on speed and delta
		var move_step = direction * speed * delta

		# Move the object toward the target position
		position += move_step

		# Ensure we're not overshooting the target
		if position.distance_to(target_world_pos) < move_step.length():
			position = target_world_pos

		# Await the next frame before continuing the loop
		await get_tree().process_frame

	# Ensure the object reaches the exact target position at the end
	position = target_world_pos

	is_moving = false  # Unlock the unit after movement
	state = State.IDLE  # Return to idle state
	
	update_astar_grid()

# Update the z_index based on the unit's tile position
func update_z_index() -> void:
	z_index = (tile_pos.x + tile_pos.y) + 1  # Adjust z-index based on tile position

# Show walkable tiles based on the actual walkability of the tile
func show_walkable_tiles() -> void:
	clear_walkable_tiles()  # Clear any existing indicators

	# Loop over all possible tiles within movement range using Manhattan distance
	for x_offset in range(-movement_range, movement_range + 1):
		for y_offset in range(-movement_range, movement_range + 1):
			if abs(x_offset) + abs(y_offset) <= movement_range:
				var walkable_tile_pos = tile_pos + Vector2i(x_offset, y_offset)

				# Only instantiate if the position is valid on the map
				if tilemap.get_used_rect().has_point(walkable_tile_pos):
					# Check if the tile is walkable
					if is_walkable(walkable_tile_pos):
						var walkable_tile = walkable_tile_prefab.instantiate()
						var walkable_world_pos = tilemap.map_to_local(walkable_tile_pos)
						walkable_tile.position = walkable_world_pos

						# Add the walkable tile to the TileMap
						tilemap.add_child(walkable_tile)
						walkable_tiles.append(walkable_tile)

						# print("Placing walkable tile at: ", walkable_tile_pos)  # Debugging line
					else:
						# Set the tile as solid (assuming you have a method or property to do this)
						set_tile_solid(walkable_tile_pos)

# Function to set the tile at a given position to solid
func set_tile_solid(tile_pos: Vector2i) -> void:
	# You may need to adjust this based on your tilemap settings
	# For example, setting a specific tile index that is solid
	astar_grid.set_point_solid(tile_pos, true)  # Assuming `solid_tile_index` is the index of your solid tile

	print("Setting tile at: ", tile_pos, " to solid.")  # Debugging line

# Clear all walkable tile markers
func clear_walkable_tiles() -> void:
	for tile in walkable_tiles:
		tile.queue_free()
	walkable_tiles.clear()

# Check if the tile is walkable
func is_walkable(tile_pos: Vector2i) -> bool:
	# Calculate the Manhattan distance between the current tile and the target tile
	var distance = abs(tile_pos.x - self.tile_pos.x) + abs(tile_pos.y - self.tile_pos.y)
	
	# Ensure the tile is within movement range
	if distance > movement_range:
		return false  # If the tile is beyond movement range, it is not walkable

	# Check if the tile position is in the list of walkable tiles
	for walkable_tile in walkable_tiles:
		# Check if the current walkable tile matches the position being checked
		if walkable_tile.position == tilemap.map_to_local(tile_pos):
			return true  # If the tile is a walkable tile, return true

	# If no walkable tiles match, check other conditions: not water, not a structure, and not a unit present
	return not is_water(tile_pos) and not is_structure(tile_pos) and not is_unit_present(tile_pos)

# Check if the tile is water
func is_water(tile_pos: Vector2i) -> bool:
	var water_tile_index = 0  # Define the correct index for water tiles
	return tilemap.get_cell_source_id(0, tile_pos) == water_tile_index

# Check if the tile is a structure
func is_structure(tile_pos: Vector2i) -> bool:
	var structure_coordinates = get_tree().get_root().get_node("MapManager").structure_coordinates
	for coord in structure_coordinates:
		if tile_pos == coord:
			return true  # Tile is a structure if it matches any coordinate
	return false  # Tile is not a structure if no matches are found

# Check if a unit is present on a specific tile
func is_unit_present(tile_pos: Vector2i) -> bool:
	for unit in get_tree().get_nodes_in_group("units"):  # Assume units are added to a group called "units"
		if unit.tile_pos == tile_pos:
			return true  # Unit is present on this tile
	return false  # No unit present on this tile

# Handle input events based on the current state
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_left"):
		clear_walkable_tiles()
		
		# Get the tile position of the mouse click
		var mouse_pos = get_global_mouse_position()
		mouse_pos.y += 8  # Adjust offset if necessary

		# Convert the mouse position to tile coordinates
		var target_tile_pos = tilemap.local_to_map(tilemap.to_local(mouse_pos))

		match state:
			State.IDLE:
				# If the unit is clicked, toggle selection and show walkable tiles
				if tile_pos == target_tile_pos:
					selected_unit = self  # Track this unit as selected
					state = State.SELECTED  # Change state to SELECTED
					
					# Temporarily make the unit's current tile walkable in AStar
					astar_grid.set_point_solid(tile_pos, false)
					
					show_walkable_tiles()  # Show movement options when selected
					first_target_position = target_tile_pos  # Store the first click position
					print("Unit selected. First target position: ", first_target_position)  # Debugging

			State.SELECTED:
				# If the user clicks the same tile again, deselect the unit
				if tile_pos == target_tile_pos:
					state = State.IDLE  # Deselect the unit
					clear_walkable_tiles()  # Clear walkable tile indicators
					reset_targets()  # Reset target positions
					
					# Restore the solid state of the current tile
					astar_grid.set_point_solid(tile_pos, true)
					
					selected_unit = null  # Deselect the unit
					print("Unit deselected.")  # Debugging
					return

				# Use temporary variables to store the targets
				var temp_first_target = first_target_position
				var temp_second_target = target_tile_pos

				# Check if the clicked tile is walkable and not the same as the first target
				if is_walkable(temp_second_target) and temp_first_target != temp_second_target:
					second_target_position = temp_second_target  # Set second target position
					
					# Move to the tile, making sure the start tile is not solid
					astar_grid.set_point_solid(tile_pos, false)  # Make sure the starting tile is walkable
					move_to_tile(temp_first_target, second_target_position)  # Move to the clicked tile position
					
					clear_walkable_tiles()  # Clear markers after movement
					state = State.IDLE  # Return to IDLE after moving
					
					# Restore the solid state of the tile after moving
					astar_grid.set_point_solid(tile_pos, true)
					
					selected_unit = null  # Deselect the unit after movement
					print("Unit moved to second target position: ", second_target_position)  # Debugging

# Function to check if the target tile is within movement range
func is_within_range(target_tile_pos: Vector2i) -> bool:
	var distance = abs(tile_pos.x - target_tile_pos.x) + abs(tile_pos.y - target_tile_pos.y)
	return distance <= movement_range

# Move to tile function, updated to check if it's the unit's turn
func move_to_tile(first_tile_pos: Vector2i, target_tile_pos: Vector2i) -> void:
	# Only allow movement during the unit's turn
	if turn_manager != null and turn_manager.current_unit != self:
		return  # Not this unit's turn, ignore the movement

	if is_moving:
		return  # Ignore input if the unit is currently moving

	# Check if a valid path exists using the A* algorithm
	var path = astar_grid.get_point_path(first_tile_pos, target_tile_pos)
	if path.size() > 0:
		is_moving = true  # Lock the unit while it's moving

		# Store the last position before moving
		last_position = position

		# Start the movement animation
		sprite.play("move")  # Assuming the walking animation is named "move"

		# Move the unit along the calculated path
		for point in path:
			var target_world_pos = tilemap.map_to_local(point)
			await move_to_position(target_world_pos)

		# Get the world position of the target tile
		var target_world_pos = tilemap.map_to_local(target_tile_pos)			
		# Move the unit to the target tile's world position
		position = target_world_pos

		# Determine the direction of movement based on current and last position
		if position.x > last_position.x:
			scale.x = -1  # Facing right (East)
		elif position.x < last_position.x:
			scale.x = 1  # Facing left (West)

		# Update the unit's tile position after reaching the final point in the path
		tile_pos = target_tile_pos
		# Update the z_index based on the new tile position
		update_z_index()

		# Stop the movement animation and switch to idle animation
		sprite.play("default")  # Assuming the idle animation is named "idle"
		
		is_moving = false  # Unlock the unit after movement
		
		if is_zombie:
			self.has_moved = true
		
		# Signal that the unit's turn is done
		end_turn()
		GlobalManager.end_current_unit_turn()
		check_for_attack()
		print("Unit moved to tile: ", tile_pos)  # Debugging
	else:
		print("No valid path to target tile.")  # Debugging message

# Move to a random tile function
func move_to_random_tile() -> void:
	# Only allow movement during the unit's turn
	if turn_manager != null and turn_manager.current_unit != self:
		return  # Not this unit's turn, ignore the movement

	if is_moving:
		return  # Ignore input if the unit is currently moving

	var valid_tiles: Array = []  # Array to store walkable tiles within movement range

	# Loop over all possible tiles within movement range using Manhattan distance
	for x_offset in range(-movement_range, movement_range + 1):
		for y_offset in range(-movement_range, movement_range + 1):
			if abs(x_offset) + abs(y_offset) <= movement_range:
				var target_tile_pos = tile_pos + Vector2i(x_offset, y_offset)

				# Only consider valid tiles within the bounds of the tilemap
				if tilemap.get_used_rect().has_point(target_tile_pos) and is_walkable(target_tile_pos):
					valid_tiles.append(target_tile_pos)  # Add to valid tiles if walkable

	# Check if there are any valid tiles
	if valid_tiles.size() == 0:
		print("No valid tiles available for movement.")  # Debugging
		return

	# Select a random tile from the valid tiles
	var random_target_tile_pos = valid_tiles[randi() % valid_tiles.size()]

	# Move to the randomly selected tile
	move_to_tile(tile_pos, random_target_tile_pos)

	print("Unit will move to random tile: ", random_target_tile_pos)  # Debugging

# Reset target positions
func reset_targets() -> void:
	first_target_position = Vector2i(-1, -1)  # Reset first target position
	second_target_position = Vector2i(-1, -1)  # Reset second target position
	active_target_position = Vector2i(-1, -1)  # Reset active target

# Called when the unit's turn begins
func start_turn() -> void:
	state = State.IDLE  # The unit starts in the idle state
	is_moving = false  # Ensure that the unit is not in the middle of a move
	selected_unit = self  # Mark this unit as the selected one
	if is_zombie:
		await move_to_nearest_non_zombie()  # Move towards the nearest non-zombie unit

	if !is_zombie:
		check_for_attack()  # Check for adjacent player units to attack


# Check for adjacent player units to attack
func check_for_attack() -> void:
	var adjacent_positions = [
		tile_pos + Vector2i(1, 0),   # Right
		tile_pos + Vector2i(-1, 0),  # Left
		tile_pos + Vector2i(0, 1),   # Down
		tile_pos + Vector2i(0, -1)   # Up
	]
	
	for target_tile in adjacent_positions:
		if is_tile_occupied_by_player(target_tile):
			perform_attack(target_tile)  # Attack if a player unit is found

# Check if a given tile is occupied by a player unit
func is_tile_occupied_by_player(tile_pos: Vector2i) -> bool:
	for unit in get_tree().get_nodes_in_group("units"):
		if unit.is_zombie and unit.tile_pos == tile_pos:  # Check if it's a non-zombie unit
			return true  # Tile is occupied by a player unit
	return false  # No player unit on the tile

# Perform the attack on the target unit
func perform_attack(target_tile: Vector2i) -> void:
	# Play the attack animation
	sprite.play("attack")  # Play the attack animation

	# Determine the target type (player or zombie)
	var target_is_zombie = !is_zombie  # If this unit is a player, attack zombies; if a zombie, attack players

	# Find the correct unit to deal damage
	for unit in get_tree().get_nodes_in_group("units"):
		if unit.is_zombie == target_is_zombie and unit.tile_pos == target_tile:
			unit.take_damage(attack_damage)  # Apply damage to the target unit
			print(unit.unit_type + " attacked at tile: ", target_tile)
			break  # Exit after attacking the first adjacent target unit

# Method to take damage (should be part of your player unit script)
func take_damage(amount: int) -> void:
	# Assuming you have a health property
	health -= amount
	if health <= 0:
		die()  # Handle zombie death
	else:
		# Optional: Play damage feedback animation/sound
		sprite.play("hurt")  # Play a hurt animation or sound

# Handle player death
func die() -> void:
	# Play the death animation
	sprite.play("death")  # Play the death animation

	# Optionally, you can check if the animation is finished before continuing.
	# This assumes your animation has a specific length; replace '2' with your animation duration if needed.
	await get_tree().create_timer(0.5).timeout  # Wait for the death animation to finish

	# Update units in GlobalManager
	if GlobalManager.units.has(self):  # Check if this unit is in the global list before removing
		GlobalManager.units.erase(self)  # Remove this unit from the global list of units

	queue_free()  # Remove the unit from the scene
	
	GlobalManager.current_unit_index = 0

# Called when the unit's turn ends
func end_turn() -> void:
	clear_walkable_tiles()  # Clear any walkable tile markers
	selected_unit = null  # Deselect the unit
	state = State.IDLE  # Reset state to idle
	
# Move towards the nearest non-zombie unit
func move_to_nearest_non_zombie() -> void:
	var nearest_unit: Node2D = null
	var nearest_distance = INF  # Start with a large distance

	# Iterate through all units in the group
	for unit in get_tree().get_nodes_in_group("units"):
		if unit.is_zombie:
			continue  # Skip zombie units

		var distance = tile_pos.distance_to(unit.tile_pos)  # Calculate distance to unit
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_unit = unit  # Update nearest non-zombie unit

	if nearest_unit:
		# Only move if the nearest unit is within a certain range
		if nearest_distance <= movement_range:
			# Move towards the nearest unit's tile position
			var target_tile_pos = nearest_unit.tile_pos
			move_to_tile(tile_pos, target_tile_pos)  # Move to the non-zombie unit's tile
			print("Zombie moving to nearest non-zombie unit at position: ", target_tile_pos)
		else:
			move_to_random_tile()
			print("No non-zombie units within movement range.")
	else:
		print("No non-zombie units found.")
		
