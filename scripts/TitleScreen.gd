extends CanvasLayer

# Load your game scene
@onready var game_scene_path = "res://assets/scenes/map_manager.scn"  # Adjust the path to your scene
@onready var map_fader = $MapFader
@onready var start_button = $VBoxContainer/StartButton
@onready var quit_button = $VBoxContainer/QuitButton

@onready var audio_player = $AudioStreamPlayer2D 
@export var zombie_audio: AudioStream

func _ready():
	# Connect button signals
	start_button.pressed.connect(_on_start_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)

# Function to handle the start button press
func _on_start_button_pressed():
	audio_player.stream = zombie_audio
	audio_player.play()
	
	map_fader.fade_in()
	print("Start button pressed, starting fade in...")
	
# Function to handle the quit button press
func _on_quit_button_pressed():
	print("Quit button pressed, exiting game...")
	get_tree().quit()

# Function to be called when fade-in is complete
func _on_fade_in_complete():
	print("Fade-in complete, changing scene...")
	get_tree().change_scene_to_file(game_scene_path)  # Change the scene after fade-in completes
