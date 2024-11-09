extends Node2D

# Adjustable lifespan in seconds for timing the effect duration
@export var lifespan: float = 1.0

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
	z_index = int(position.y)
