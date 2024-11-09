extends Node2D

# Target position and speed properties
@export var target_position: Vector2
@export var speed: float = 200.0

# Optional: Scene to instantiate for explosion effect
@export var explosion_scene: PackedScene

func _ready() -> void:
	# Set the initial z_index based on y-position for correct layering
	z_index = int(position.y)


func _process(delta: float) -> void:
	# Adjust z_index to ensure layering as it moves
	z_index = int(position.y)

	# Calculate the distance to the target
	var distance_to_target = position.distance_to(target_position)
	
	# Check if the projectile has reached the target
	if distance_to_target <= speed * delta:
		position = target_position  # Snap to target
		print("Projectile reached target at: ", target_position)
		_create_explosion()  # Trigger the explosion effect
		queue_free()  # Destroy the projectile
		return
	
	# Calculate movement delta (movement direction * speed * delta time)
	var movement = (target_position - position).normalized() * speed * delta

	# Move the projectile towards the target
	position += movement
	print("Projectile position: ", position)


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
