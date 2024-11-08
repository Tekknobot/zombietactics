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

# Function to get all tiles within movement range based on Manhattan distance
func get_movement_tiles() -> Array[Vector2i]:
	var tiles_in_range: Array[Vector2i] = []
	var tile_map: TileMap = get_node("/root/MapManager/TileMap")

	# Loop through each tile within range using Manhattan distance
	for x in range(-movement_range, movement_range + 1):
		for y in range(-movement_range, movement_range + 1):
			if abs(x) + abs(y) <= movement_range:
				var target_tile_pos: Vector2i = tile_pos + Vector2i(x, y)
				# Check if the target tile is within the bounds of the map
				if tile_map.get_used_rect().has_point(target_tile_pos):
					tiles_in_range.append(target_tile_pos)

	return tiles_in_range

# Function to display movement tiles within range
func display_movement_tiles() -> void:
	clear_movement_tiles()  # Clear existing movement tiles first

	# Get the TileMap node
	var tile_map: TileMap = get_node("/root/MapManager/TileMap")

	# Loop through each tile in the movement range and instantiate a movement tile
	for tile in get_movement_tiles():
		# Convert the tile position to the correct world position
		var world_pos: Vector2 = tile_map.map_to_local(tile)  # Aligns with 4.x coordinate system
		
		# Instantiate the movement tile and set its position
		var movement_tile_instance: Node2D = movement_tile_scene.instantiate() as Node2D
		movement_tile_instance.position = world_pos  # Position within the tile map
		tile_map.add_child(movement_tile_instance)  # Add to the TileMap node directly
		movement_tiles.append(movement_tile_instance)

# Function to clear displayed movement tiles
func clear_movement_tiles() -> void:
	for tile in movement_tiles:
		tile.queue_free()
	movement_tiles.clear()
