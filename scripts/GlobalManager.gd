extends Node

# Array to store the positions of all units
var unit_positions: Array = []

# Function to add or update a unit's position
func update_unit_position(unit_id: int, tile_pos: Vector2i) -> void:
	if unit_id >= 0 and unit_id < unit_positions.size():
		# Update existing unit position
		unit_positions[unit_id] = tile_pos
	else:
		# Append a new entry if the unit ID doesn't exist yet
		unit_positions.append(tile_pos)

# Function to remove a unit's position
func remove_unit_position(unit_id: int) -> void:
	if unit_id >= 0 and unit_id < unit_positions.size():
		unit_positions.remove_at(unit_id)
		# After removing, you may want to adjust the IDs of the remaining units, 
		# since removing shifts the array elements

# Function to get the position of a unit by ID
func get_unit_position(unit_id: int) -> Vector2i:
	if unit_id >= 0 and unit_id < unit_positions.size():
		return unit_positions[unit_id]
	return Vector2i(-1, -1)  # Return an invalid position if unit not found
