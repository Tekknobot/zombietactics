extends Area2D

# Declare member variables
var tile_pos: Vector2i
var coord: Vector2
var layer: int

@export var structure_type: String
@export var explosion_radius: float = 1.0  # Radius to check for adjacent zombies or player units
@export var explosion_scene: PackedScene  # Optional: Scene to instantiate for the explosion effect

@onready var mission_manager = get_node("/root/MapManager/MissionManager")  # Reference to the SpecialToggleNode
@onready var item_manager = get_node("/root/MapManager/ItemManager")  # Reference to the SpecialToggleNode

var is_demolished: bool = false
var selected = false

var has_item: bool = false
var demolished_flag: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Optionally, initialize any variables or states here
	update_tile_position()

# Update the zombie's tile position and z_index
func _process(delta: float) -> void:
	# Check for demolished state based on the structure type
	if get_structure_type() == "Building":
		_check_for_demolished_building_and_trigger_explosion()
	elif get_structure_type() == "Tower":
		_check_for_demolished_tower_and_trigger_explosion()
	elif get_structure_type() == "District":
		_check_for_demolished_district_and_trigger_explosion()
	elif get_structure_type() == "Stadium":
		_check_for_demolished_stadium_and_trigger_explosion()

	update_tile_position()

	var animated_sprite = self.get_node("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite.animation == "demolished" and !demolished_flag:
		demolished_flag = true
		#item_manager.check_item_destroyed()
		await get_tree().create_timer(1).timeout
		mission_manager.check_mission_manager()	
		if GlobalManager.secret_item_destroyed:
			mission_manager.audio_player.stream = mission_manager.gameover_audio
			mission_manager.audio_player.play()		
		

# Function to handle the demolished "Building" type
func _check_for_demolished_building_and_trigger_explosion():
	var animated_sprite = get_child(0) as AnimatedSprite2D
	if animated_sprite and animated_sprite.animation == "demolished" and self.visible and is_demolished == false:
		_check_for_adjacent_units_and_trigger_explosion()
		is_demolished = true
		modulate = Color (1, 1, 1)
		print("Building demolished, but not removed.")

# Function to handle the demolished "Tower" type
func _check_for_demolished_tower_and_trigger_explosion():
	var animated_sprite = get_child(0) as AnimatedSprite2D
	if animated_sprite and animated_sprite.animation == "demolished" and self.visible and is_demolished == false:
		_check_for_adjacent_units_and_trigger_explosion()
		is_demolished = true
		modulate = Color (1, 1, 1)
		print("Tower demolished, but not removed.")

# Function to handle the demolished "District" type
func _check_for_demolished_district_and_trigger_explosion():
	var animated_sprite = get_child(0) as AnimatedSprite2D
	if animated_sprite and animated_sprite.animation == "demolished" and self.visible and is_demolished == false:
		_check_for_adjacent_units_and_trigger_explosion()
		is_demolished = true
		modulate = Color (1, 1, 1)
		print("District demolished, but not removed.")

# Function to handle the demolished "Stadium" type
func _check_for_demolished_stadium_and_trigger_explosion():
	var animated_sprite = get_child(0) as AnimatedSprite2D
	if animated_sprite and animated_sprite.animation == "demolished" and self.visible and is_demolished == false:
		_check_for_adjacent_units_and_trigger_explosion()
		is_demolished = true
		modulate = Color (1, 1, 1)
		print("Stadium demolished, but not removed.")

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
	z_index = layer

# Getter method for structure_type
func get_structure_type() -> String:
	# Return the structure type
	return structure_type

# Check for adjacent zombies or player units and trigger an explosion
func _check_for_adjacent_units_and_trigger_explosion() -> void:
	# Find all nodes in the "zombies" group and "player_units" group
	var zombies = get_tree().get_nodes_in_group("zombies")
	var player_units = get_tree().get_nodes_in_group("player_units")
	
	# Check the surrounding tiles for any zombies or player units
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var adjacent_tiles = get_adjacent_tiles(tile_pos)

	for adj_tile in adjacent_tiles:
		# Check for zombies in the adjacent tiles
		for zombie in zombies:
			var zombie_tile_pos = tilemap.local_to_map(zombie.position)
			if adj_tile == zombie_tile_pos:
				print("Zombie found adjacent to demolished structure, triggering explosion.")
				_create_explosion_at_tile(adj_tile, zombie)  # Create explosion at the zombie's tile
				_remove_unit_from_group(zombie, "zombies")
				
				if zombies.size() <= 0:
					zombie.reset_player_units()
					GlobalManager.zombies_cleared = true
					mission_manager.check_mission_manager()	
								
				#return  # Trigger the explosion once for the first adjacent zombie found

		# Check for player units in the adjacent tiles
		for player in player_units:
			var player_tile_pos = tilemap.local_to_map(player.position)
			if adj_tile == player_tile_pos:
				print("Player unit found adjacent to demolished structure, triggering explosion.")
				_create_explosion_at_tile(adj_tile, player)  # Create explosion at the player's tile
				_remove_unit_from_group(player, "player_units")
				player.update_astar_grid()
				
				if player_units.size() <= 0:
					GlobalManager.players_killed = true
					mission_manager.check_mission_manager()					
				#return  # Trigger the explosion once for the first adjacent player unit found

# Get adjacent tiles based on the current tile position
func get_adjacent_tiles(tile_pos: Vector2i) -> Array:
	var adjacent_tiles = []
	# Define the 8 possible adjacent tiles (left, right, up, down, and diagonals)
	adjacent_tiles.append(Vector2i(tile_pos.x - 1, tile_pos.y))  # Left
	adjacent_tiles.append(Vector2i(tile_pos.x + 1, tile_pos.y))  # Right
	adjacent_tiles.append(Vector2i(tile_pos.x, tile_pos.y - 1))  # Up
	adjacent_tiles.append(Vector2i(tile_pos.x, tile_pos.y + 1))  # Down
	#adjacent_tiles.append(Vector2i(tile_pos.x - 1, tile_pos.y - 1))  # Top-left
	#adjacent_tiles.append(Vector2i(tile_pos.x + 1, tile_pos.y - 1))  # Top-right
	#adjacent_tiles.append(Vector2i(tile_pos.x - 1, tile_pos.y + 1))  # Bottom-left
	#adjacent_tiles.append(Vector2i(tile_pos.x + 1, tile_pos.y + 1))  # Bottom-right
	
	return adjacent_tiles

# Create the explosion effect at a specific tile position
func _create_explosion_at_tile(explosion_position: Vector2i, unit: Node) -> void:
	# Check if explosion_scene is assigned
	if explosion_scene == null:
		print("Error: Explosion scene is not assigned!")
		return

	# Instantiate the explosion effect
	var explosion = explosion_scene.instantiate() as Node2D
	if explosion == null:
		print("Error: Failed to instantiate explosion!")
		return
	
	# Convert the tile position to world position
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var world_position = tilemap.map_to_local(explosion_position)
	
	# Set the explosion's position to the target tile's world position
	explosion.position = world_position

	# Add explosion to the parent scene
	get_parent().add_child(explosion)
	print("Explosion created at position: ", explosion.position)

# Remove the unit from its group and make it invisible
func _remove_unit_from_group(unit: Node, group_name: String) -> void:
	unit.get_child(0).play("death")
	await get_tree().create_timer(1).timeout
	unit.visible = false  # Hide the unit
	unit.remove_from_group(group_name)  # Remove it from its group
	unit.current_health = 0
	unit.current_xp = 0
	print("Unit removed from group: ", group_name)
