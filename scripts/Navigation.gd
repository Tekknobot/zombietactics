extends Control

# Load your game scene
@onready var game_scene_path = "res://assets/scenes/TitleScreen.tscn"  # Adjust the path to your scene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Connect button signals
	$HBoxContainer/Button.pressed.connect(_on_menu_button_pressed)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func _on_menu_button_pressed():
	GlobalManager.current_map_index -= 1
	get_tree().change_scene_to_file(game_scene_path)  # Use the updated method
