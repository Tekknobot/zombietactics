extends Node2D

# Declare member variables
var tile_pos: Vector2i
var coord: Vector2
var layer: int

# Target position and speed properties
@export var target_position: Vector2
@export var speed: float = 200.0
@export var rotation_speed: float = 5.0

# Optional: Scene to instantiate for explosion effect
@export var explosion_scene: PackedScene
@export var explosion_radius: float = 1.0  # Radius to check for units at the target position

var projectile_hit: bool = false

# Assuming `attacker` is set when the projectile is spawned
var attacker: Area2D = null  # Reference to the unit that fired the projectile

@onready var global_manager = get_node("/root/MapManager/GlobalManager")  # Reference to the SpecialToggleNode
@onready var audio_player = $AudioStreamPlayer2D 

func _ready() -> void:
	# Set the initial z_index based on y-position for correct layering
	#z_index = int(position.y)
	pass
	
func _process(delta: float) -> void:	
	# If the projectile is TNT, rotate its AnimatedSprite2D child
	if name == "TNT":
		var animated_sprite = $AnimatedSprite2D  # Reference to the AnimatedSprite2D child
		if animated_sprite:
			animated_sprite.rotation += rotation_speed * delta  # Increment rotation relative to its center
		
	# Adjust z_index to ensure layering as it moves
	#update_tile_position()

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
	
