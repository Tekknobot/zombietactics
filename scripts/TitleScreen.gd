extends CanvasLayer

# Load your game scene
@onready var game_scene_path = "res://assets/scenes/map_manager.scn"  # Adjust the path to your scene

func _ready():
	# Connect button signals
	$VBoxContainer/StartButton.pressed.connect(_on_start_button_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_button_pressed)

func _on_start_button_pressed():
	print("Start button pressed, loading game...")
	get_tree().change_scene_to_file(game_scene_path)  # Use the updated method

func _on_quit_button_pressed():
	print("Quit button pressed, exiting game...")
	get_tree().quit()
