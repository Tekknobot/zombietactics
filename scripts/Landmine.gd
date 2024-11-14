extends Node2D

@export var explosion_scene: PackedScene
@export var explosion_radius: float = 1.0  # Radius to check for units at the target position

var tile_pos: Vector2i
var coord: Vector2
var layer: int

func _process(delta: float) -> void:
	update_tile_position()
	check_for_units_on_tile()
	
# Function to update the tile position based on the current Area2D position
func update_tile_position() -> void:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	tile_pos = tilemap.local_to_map(position)
	coord = tile_pos
	layer = tile_pos.x + tile_pos.y
	self.z_index = layer

# Check for any units (player or zombies) on the same tile as the landmine
func check_for_units_on_tile() -> void:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")

	# Check for zombies on the tile
	for zombie in get_tree().get_nodes_in_group("zombies"):
		if not zombie is Node2D:
			continue
		
		var zombie_tile_pos = tilemap.local_to_map(zombie.position)
		if zombie_tile_pos == tile_pos:
			print("Zombie stepped on landmine at tile: ", tile_pos)
			zombie.get_child(0).play("death")
			await get_tree().create_timer(0.1).timeout
			zombie.visible = false  # Hide the zombie unit
			zombie.remove_from_group("zombies")  # Remove from the group
			print("Zombie Unit removed from landmine.")
			_create_explosion()
			return  # Only trigger once per check

	# Check for player units on the tile
	for player in get_tree().get_nodes_in_group("player_units"):
		if not player is Node2D:
			continue

		var player_tile_pos = tilemap.local_to_map(player.position)
		if player_tile_pos == tile_pos:
			print("Player stepped on landmine at tile: ", tile_pos)
			player.get_child(0).play("death")
			await get_tree().create_timer(0.1).timeout
			player.visible = false  # Hide the zombie unit
			player.remove_from_group("player_units")  # Remove from the group
			print("Player Unit removed from landmine.")			
			_create_explosion()
			return  # Only trigger once per check

# Function to create the explosion effect
func _create_explosion() -> void:
	# Check if explosion_scene is assigned
	if explosion_scene == null:
		print("Error: Explosion scene is not assigned!")
		return

	# Instantiate the explosion effect
	var explosion = explosion_scene.instantiate() as Node2D
	if explosion == null:
		print("Error: Failed to instantiate explosion!")
		return
	
	# Set the explosion's position to the mine's position
	explosion.position = self.position
	explosion.z_index = int(self.position.y)
	
	# Add explosion to the parent scene
	get_parent().add_child(explosion)
	print("Explosion created at position: ", explosion.position)

	# Check for any zombies, players, or structures in the explosion radius
	_check_for_zombies_at_target()
	_check_for_players_at_target()
	_check_for_structure_at_target()

	# Optionally, you can queue_free() the landmine itself after the explosion
	queue_free()

func _check_for_zombies_at_target() -> void:
	# Find all nodes in the group "zombies"
	for zombie in get_tree().get_nodes_in_group("zombies"):
		if not zombie is Node2D:
			continue  # Skip any non-Node2D members of the group
		
		# Check if the zombie is within the explosion radius
		if zombie.position.distance_to(self.position) <= explosion_radius:
			print("Zombie found at explosion position, destroying:", zombie.name)
			
			# Play the death animation on the zombie (assuming it has an animation called "death")
			zombie.get_child(0).play("death")

func _check_for_players_at_target() -> void:
	# Find all nodes in the group "zombies"
	for player in get_tree().get_nodes_in_group("player_units"):
		if not player is Node2D:
			continue  # Skip any non-Node2D members of the group
		
		# Check if the zombie is within the explosion radius
		if player.position.distance_to(self.position) <= explosion_radius:
			print("Player found at explosion position, destroying:", player.name)
			
			# Play the death animation on the zombie (assuming it has an animation called "death")
			attack_player(player)
			player.apply_damage(50)

func _check_for_structure_at_target() -> void:
	# Find all nodes in the group "structures"
	for structure in get_tree().get_nodes_in_group("structures"):
		if not structure is Node2D:
			continue  # Skip any non-Node2D members of the group
		
		# Check if the structure is within the explosion radius
		if structure.position.distance_to(self.position) <= explosion_radius:
			print("Structure found at explosion position, handling:", structure.name)
			
			# Ensure the structure has a structure_type property before accessing it
			if structure.has_method("get_structure_type"):
				# Check the type of the structure (Building, Tower, Stadium, District, etc.)
				var structure_type = structure.get_structure_type()
				
				# Handle the different structure types
				match structure_type:
					"Building":
						# Assuming the first child of the structure is an AnimationPlayer or AnimatedSprite2D
						if structure.get_child_count() > 0 and structure.get_child(0) is AnimatedSprite2D:
							# Play the "demolished" animation on the animation player
							structure.get_child(0).play("demolished")
						else:
							print("Error: No animation player found or the first child is not an AnimatedSprite2D.")
					
					"Tower":
						# Handle Tower-specific logic (e.g., maybe a different animation or effect)
						print("Tower found, applying damage or effect.")
						# Example: Play tower's destruction animation or effect
						if structure.get_child_count() > 0 and structure.get_child(0) is AnimatedSprite2D:
							structure.get_child(0).play("demolished")
						else:
							print("Error: No animation player found for Tower.")
					
					"Stadium":
						# Handle Stadium-specific logic (e.g., different animation or effect)
						print("Stadium found, applying damage or effect.")
						if structure.get_child_count() > 0 and structure.get_child(0) is AnimatedSprite2D:
							structure.get_child(0).play("demolished")
						else:
							print("Error: No animation player found for Stadium.")
					
					"District":
						# Handle District-specific logic (e.g., different animation or effect)
						print("District found, applying damage or effect.")
						if structure.get_child_count() > 0 and structure.get_child(0) is AnimatedSprite2D:
							structure.get_child(0).play("demolished")
						else:
							print("Error: No animation player found for District.")
					
					_:
						print("Unknown structure type:", structure_type)

			else:
				print("Structure does not have a valid 'structure_type' or 'get_structure_type' method.")

# Function to handle the friendly attack logic
func attack_player(player: Area2D) -> void:
	if player.has_method("flash_damage"):
		player.flash_damage()
