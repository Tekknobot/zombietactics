extends Node2D

# Adjustable lifespan in seconds for timing the effect duration
@export var lifespan: float = 2.0

# Declare member variables
var tile_pos: Vector2i
var coord: Vector2
var layer: int

# Called when the node enters the scene tree
func _ready() -> void:
	# Set initial z_index based on y-position for correct layering
	z_index = int(position.y)
	
	# Play explosion animation if available
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play()
	elif has_node("Particles2D"):
		$Particles2D.emitting = true  # Start the particle effect

	# Schedule the explosion to be deleted after the lifespan ends
	await get_tree().create_timer(lifespan).timeout
	queue_free()

# Continuously update z_index to ensure correct layering as it animates or moves
func _process(delta: float) -> void:
	# Adjust z_index to ensure layering as it moves
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
	layer = tile_pos.x + tile_pos.y

	# Optionally, set the z_index in the node to ensure proper rendering order
	self.z_index = layer
