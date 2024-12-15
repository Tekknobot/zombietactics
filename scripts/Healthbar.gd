extends ProgressBar

# Define the color tiers
@export var high_color: Color = Color(0, 1, 0) # Green
@export var medium_color: Color = Color(1, 1, 0) # Yellow
@export var low_color: Color = Color(1, 0, 0) # Red

# StyleBoxFlat for the fill
var fill_stylebox: StyleBoxFlat

func _ready() -> void:	
	if name == "HealthBar":
		fill_stylebox = self.get_theme_stylebox("fill") as StyleBoxFlat
		_update_fill_color()
	else:
		# Create a new StyleBoxFlat for the fill if it doesn't exist
		fill_stylebox = StyleBoxFlat.new()
		self.add_theme_stylebox_override("fill", fill_stylebox)
		_update_fill_color()			

func _process(delta: float) -> void:
	# Continuously check and update the fill color based on value
	_update_fill_color()

func _update_fill_color() -> void:
	"""
	Updates the fill color of the ProgressBar based on its current percentage.
	"""
	if max_value <= 0:
		return # Avoid division by zero

	var percentage: float = value / max_value * 100.0

	if percentage >= 66.67:
		fill_stylebox.bg_color = high_color
	elif percentage >= 33.33:
		fill_stylebox.bg_color = medium_color
	else:
		fill_stylebox.bg_color = low_color
