extends Area2D

# Declare member variables
var tile_pos: Vector2i
var coord: Vector2
var layer: int

@export var structure_type: String

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Optionally, initialize any variables or states here
	update_tile_position()

# Update the zombie's tile position and z_index
func _process(delta: float) -> void:
	update_tile_position()

# Function to update the tile position based on the current Area2D position
func update_tile_position() -> void:
	# Get the TileMap node
	var tile_map = get_tree().get_root().get_node("MapManager/TileMap")  # Adjust path based on your scene structure
	
	# Convert the current position to tile coordinates
	tile_pos = tile_map.local_to_map(position)

	# Store the tile coordinates
	coord = tile_pos
	
	# Update z_index for layering based on tile position
	layer = (tile_pos.x + tile_pos.y) + 1

	# Optionally, set the z_index in the node to ensure proper rendering order
	self.z_index = layer

# Getter method for structure_type
func get_structure_type() -> String:
	# Return the structure type
	return structure_type
