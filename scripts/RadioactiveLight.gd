extends PointLight2D

var tile_pos: Vector2i
var coord: Vector2
var layer: int

# Light animation variables
var max_energy: float = 1.5  # Peak energy of the light
var energy_duration: float = 0.5  # Duration of the explosion light effect in seconds
var timer: float = 0.0  # Internal timer to track the light's animation state

@onready var tilemap = get_node("/root/MapManager/TileMap")

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	# Update tile position based on the sprite's world position
	tile_pos = tilemap.local_to_map(position)
	coord = tile_pos
	layer = (tile_pos.x + tile_pos.y) - 2

	# Set the z-index of the sprite to reflect its "layer" for rendering order
	z_index = layer

	if get_parent().name == "Explosion":
		# Handle explosion lighting animation
		if timer < energy_duration:
			timer += delta
			# Increase energy to peak and then fade out over time
			energy = max_energy * (1.0 - abs((2.0 * timer / energy_duration) - 1.0))
		else:
			energy = 0  # Reset energy to 0 when animation is complete
