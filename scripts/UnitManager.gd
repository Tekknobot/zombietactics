extends Node2D

# Variables for the unit manager
var unit_id: int = -1   # Each unit should have a unique ID
var coord: Vector2
var tile_pos: Vector2i  # Position of the unit in the tile grid
var layer: int

func _ready() -> void:
	# Assign a unique ID to each unit. You could also manually set these for each unit if necessary.
	unit_id = GlobalManager.unit_positions.size()
	
	# Initialize the unit position based on the current position
	tile_pos = Vector2i(floor(position.x), floor(position.y))
	
	# Store the initial position in the global array
	GlobalManager.update_unit_position(unit_id, tile_pos)

# Update the zombie's tile position and z_index
func _process(delta: float) -> void:
	update_tile_position()

# Function to update the tile position based on the current Area2D position
func update_tile_position() -> void:
	# Get the TileMap node
	var tile_map = get_tree().get_root().get_node("MapManager/TileMap")  # Adjust path based on your scene structure
	
	# Convert the current position to tile coordinates
	tile_pos = tile_map.local_to_map(self.position)

	# Store the tile coordinates
	coord = tile_pos
	
	# Update z_index for layering based on tile position
	layer = (tile_pos.x + tile_pos.y) + 1

	# Optionally, set the z_index in the node to ensure proper rendering order
	self.z_index = layer
	
		# Store the initial position in the global array
	GlobalManager.update_unit_position(unit_id, tile_pos)
