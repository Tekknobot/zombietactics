extends ColorRect

# The duration of the fade-out effect, in seconds
@export var fade_duration: float = 2.0

@onready var start_button = get_parent().get_node("VBoxContainer/StartButton")
@onready var map_scene_name = "map_manager"  # The scene name you're checking
@onready var titlescreen_name = "TitleScreen"  # The scene name you're checking

signal fade_complete  # Define a signal to emit when fade-in is complete

# Ready function starts the fade-out effect if necessary
func _ready():
	var root_node = get_tree().current_scene  # Get the root node of the current scene
	if root_node.has_meta("scene_name") and root_node.get_meta("scene_name") == map_scene_name:
		fade_out()
		print("This is the map_manager scene.")
	else:
		print("This is not the map_manager scene.")

	if root_node.has_meta("scene_name") and root_node.get_meta("scene_name") == titlescreen_name:
		modulate.a = 0
		print("This is the map_manager scene.")
	else:
		print("This is not the map_manager scene.")


# Function to handle the fade-out effect
func fade_out():
	# Ensure the ColorRect starts fully opaque
	modulate.a = 1.0

	# Start a tween to fade out
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)	# Optionally, queue_free() after fading out if desired
	tween.finished.connect(Callable(self, "_on_fade_out_finished"))

# Function to handle the fade-in effect
func fade_in():
	# Ensure the ColorRect starts fully transparent
	modulate.a = 0.0

	# Start a tween to fade in
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fade_duration).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	# Connect to the finished signal of the tween to call the _on_fade_in_finished method
	tween.finished.connect(Callable(self, "_on_fade_in_finished"))
	
# Function to handle the completion of the fade-in
func _on_fade_in_finished():
	get_parent()._on_fade_in_complete() # See Map Manager node script.
	emit_signal("fade_complete")  # Emit the signal indicating fade-in is complete	

# Function to handle the completion of the fade-out (if needed)
func _on_fade_out_finished():
	# You can connect this function to any additional logic you'd like when fade-out finishes
	print("Fade-out complete.")
