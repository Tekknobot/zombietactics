extends Node2D

@export var speed: float = 400.0
@export var range: float
@export var tilemap_path: NodePath = "/root/MapManager/TileMap"  # Path to the TileMap

var start_position: Vector2
var direction: Vector2

# Declare member variables
var tile_pos: Vector2i
var coord: Vector2
var layer: int

# Target position and speed properties
@export var target_position: Vector2
@export var rotation_speed: float = 5.0

# Optional: Scene to instantiate for explosion effect
@export var explosion_scene: PackedScene
@export var explosion_radius: float = 8.0  # Radius to check for units at the target position

var projectile_hit: bool = false

# Assuming `attacker` is set when the projectile is spawned
var attacker: Area2D = null  # Reference to the unit that fired the projectile


func _ready():
	# Record the starting position
	start_position = position

func _process(delta: float):
	# Move the projectile
	position += direction * speed * delta

	# Camera focuses on the active projectile
	var camera: Camera2D = get_node("/root/MapManager/Camera2D")
	camera.focus_on_position(position)

	# Check if the projectile has reached its range
	if position.distance_to(start_position) >= range and projectile_hit == false:
		snap_to_tile()
		_create_explosion()  # Trigger the explosion effect
		projectile_hit = true
		return
		
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
	layer = (tile_pos.x + tile_pos.y) + 1

	# Optionally, set the z_index in the node to ensure proper rendering order
	self.z_index = layer
			
func snap_to_tile():
	var tilemap = get_node(tilemap_path) as TileMap
	if tilemap:
		# Snap the current position to the nearest tile center
		var tile_pos = tilemap.local_to_map(position)
		var snapped_position = tilemap.map_to_local(tile_pos)
		position = snapped_position
		target_position = snapped_position
		print("Projectile snapped to tile center: ", tile_pos, " -> ", snapped_position)

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
	
	# Set the explosion's position to the projectile's impact location
	explosion.position = target_position
	explosion.z_index = int(target_position.y)  # Ensure explosion is layered correctly
	
	# Add explosion to the parent scene
	get_parent().add_child(explosion)
	print("Explosion created at position: ", explosion.position)

	# Check for any zombie units in the target area and destroy them
	_check_for_zombies_at_target()
	if self.is_in_group("unitAI"):
		pass
	elif self.is_in_group("player_units"):
		_check_for_players_at_target()
	_check_for_structure_at_target()
	
	queue_free()  # Destroy the projectile
	
	attacker.has_attacked = true
	attacker.has_moved = true

func _check_for_zombies_at_target() -> void:
	# Ensure `attacker` is valid
	if attacker == null:
		print("Projectile has no attacker reference.")
		return
			
	# Find all nodes in the group "zombies"
	for zombie in get_tree().get_nodes_in_group("zombies") + get_tree().get_nodes_in_group("unitAI"):
		if not zombie is Node2D:
			continue  # Skip any non-Node2D members of the group
		
		# Check if the zombie is within the explosion radius
		if zombie.position.distance_to(target_position) <= explosion_radius:
			print("Zombie found at explosion position, destroying:", zombie.name)
				
			# Play the death animation on the zombie (assuming it has an animation called "death")
			attack_zombie(zombie)

			# Use the attacker's attack damage
			var damage = 25  # Default value in case attacker doesn't have damage info
			if attacker.has_method("get_attack_damage"):
				damage = attacker.get_attack_damage()
			
			# Apply damage to the zombie
			zombie.apply_damage(damage)

			if get_parent().is_in_group("unitAI"):					
				zombie.second_audio_player.stream = zombie.hurt_audio
				zombie.second_audio_player.play()				
			
			# Access the HUDManager (move up the tree from PlayerUnit -> UnitSpawn -> parent (to HUDManager)
			var hud_manager = get_parent().get_parent().get_node("HUDManager")
			if self.is_in_group("unitAI"):
				hud_manager.update_hud(zombie)
				
func _check_for_players_at_target() -> void:
	# Find all nodes in the group "player_units"
	for player in get_tree().get_nodes_in_group("player_units"):
		if not player is Node2D:
			continue  # Skip any non-Node2D members of the group
		
		# Check if the zombie is within the explosion radius
		if player.position.distance_to(target_position) <= explosion_radius:
			print("Player found at explosion position, destroying:", player.name)
			
			attack_player(player)
			player.apply_damage(player.attack_damage)

			# Access the HUDManager (move up the tree from PlayerUnit -> UnitSpawn -> parent (to HUDManager)
			var hud_manager = get_parent().get_parent().get_node("HUDManager")
			hud_manager.update_hud(player)  # Pass the selected unit to the HUDManager # Pass the current unit (self) to the HUDManager
			
			if player.player_name == "Yoshida. Boi":
				return
			
			player.audio_player.stream = player.hurt_audio
			player.audio_player.play()		

func _check_for_structure_at_target() -> void:
	# Find all nodes in the group "structures"
	for structure in get_tree().get_nodes_in_group("structures"):
		if not structure is Node2D:
			continue  # Skip any non-Node2D members of the group
		
		# Check if the structure is within the explosion radius
		if structure.position.distance_to(target_position) <= explosion_radius:
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

# Function to handle the friendly attack logic
func attack_zombie(zombie: Area2D) -> void:
	if zombie.has_method("flash_damage"):
		zombie.flash_damage()
