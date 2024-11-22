extends Node2D

@export var fade_duration: float = 1.5  # Time for the fade-out effect
@export var rotate_speed: float = 1.0  # Degrees per second for back-and-forth rotation
@export var max_rotation: float = 15.0  # Maximum angle for the back-and-forth rotation

@onready var sprite: Sprite2D = $Sprite2D  # Adjust if you use a different node name

var fade_timer: Timer
var rotation_direction: float = 1.0  # 1 for clockwise, -1 for counterclockwise
var fade_out: bool = false  # Flag to trigger fade-out

func _ready():
	# Start the rotation animation
	set_process(true)

	# Start the fade timer
	fade_timer = Timer.new()
	fade_timer.wait_time = fade_duration
	fade_timer.one_shot = true
	fade_timer.timeout.connect(_on_fade_timeout)
	add_child(fade_timer)
	fade_timer.start()

func _process(delta: float):
	# Handle back-and-forth rotation
	rotation += rotation_direction * rotate_speed * delta
	if abs(rotation) >= max_rotation * (PI / 180.0):  # Convert degrees to radians
		rotation_direction *= -1.0  # Reverse direction at the limits

func _on_fade_timeout():
	# Trigger fade-out effect
	fade_out = true
