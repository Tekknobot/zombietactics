extends Node2D

@export var rain: Node2D
@export var snow: Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Randomly determine whether the node should be visible or not
	var is_visible = randi() % 2 == 0  # Randomly pick true or false
	visible = is_visible  # Set visibility based on the random result

	if rain.visible:
		snow.visible = false
	if snow.visible:
		rain.visible = false

	pass
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
