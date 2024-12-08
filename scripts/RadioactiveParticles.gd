extends GPUParticles2D

var tile_pos: Vector2i
var coord: Vector2
var layer: int

@onready var map_manager = get_parent().get_node("/root/MapManager")
@onready var tilemap = get_node("/root/MapManager/TileMap")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Update tile position based on the sprite's world position
	tile_pos = tilemap.local_to_map(position)
	coord = tile_pos
	layer = get_parent().get_parent().layer

	# Set the z-index of the sprite to reflect its "layer" for rendering order
	z_index = layer
