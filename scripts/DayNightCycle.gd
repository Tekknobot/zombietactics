extends TileMap

@export var day_length: float = 30.0  # Total duration of a full day-night cycle (in seconds)
@export var night_color: Color = Color(0.2, 0.2, 0.4)  # Color for the darkest point (night)
@export var day_color: Color = Color(1.0, 1.0, 1.0)  # Color for the brightest point (day)
@export var target_layer: int = 0  # The specific tilemap layer to modulate
var time_elapsed: float = 0.0  # Tracks the time within the cycle

func _ready() -> void:
	# Initialize the target layer with the day color
	set_layer_modulate(target_layer, day_color)

func _process(delta: float) -> void:
	if day_length <= 0.0:
		return  # Avoid division by zero or invalid input

	# Update the time within the cycle
	time_elapsed += delta
	time_elapsed = fmod(time_elapsed, day_length)  # Loop back to the beginning after a full cycle

	# Calculate the normalized time within the cycle (0.0 to 1.0)
	var cycle_position = time_elapsed / day_length

	# Determine whether we are transitioning to night or day
	var modulation_factor = abs(sin(cycle_position * PI * 2.0))

	# Calculate the interpolated color
	var current_color = Color(
		lerp(day_color.r, night_color.r, modulation_factor),
		lerp(day_color.g, night_color.g, modulation_factor),
		lerp(day_color.b, night_color.b, modulation_factor),
		lerp(day_color.a, night_color.a, modulation_factor)
	)

	# Apply the color modulation to the target layer
	set_layer_modulate(target_layer, current_color)
