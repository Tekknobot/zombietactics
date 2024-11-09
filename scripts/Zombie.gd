extends Area2D

# Movement range for the soldier
@export var movement_range: int = 3  # Adjustable movement range

# Packed scene for the movement tile (ensure you assign the movement tile scene in the editor)
@export var movement_tile_scene: PackedScene

# Store references to instantiated movement tiles for easy cleanup
var movement_tiles: Array[Node2D] = []

# Soldier's current tile position
var tile_pos: Vector2i
var coord: Vector2
var layer: int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	update_tile_position()

# Called every frame
func _process(delta: float) -> void:
	update_tile_position()

	# Check if the zombie has an AnimatedSprite2D node
	var animated_sprite = get_node("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite:
		# Check if the current animation is "death"
		if animated_sprite.animation == "death":
			# Get the SpriteFrames resource for the current animation
			var sprite_frames = animated_sprite.sprite_frames
			
			# Check if the current frame is the last frame of the "death" animation
			if animated_sprite.frame == sprite_frames.get_frame_count("death") - 1:
				print("Death animation finished, destroying zombie.")
				queue_free()  # Destroy the zombie once the death animation ends

# Function to update the tile position based on the current Area2D position
func update_tile_position() -> void:
	# Get the TileMap node
	var tile_map: TileMap = get_node("/root/MapManager/TileMap")  # Adjust path based on your scene structure
	
	# Convert the current position to tile coordinates
	tile_pos = tile_map.local_to_map(position)

	# Store the tile coordinates
	coord = tile_pos
	
	# Update z_index for layering based on tile position
	layer = (tile_pos.x + tile_pos.y) + 1
	self.z_index = layer
