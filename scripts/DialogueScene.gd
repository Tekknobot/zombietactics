extends Control

# Variables for dialogue data
var dialogue = [
	{ "speaker": "Bournetu", "text": "Major, I told you—this wasn’t a solo op. If we fail, millions die.", "portrait": "res://portraits/bournetu.png" },
	{ "speaker": "Dutch", "text": "And I told *you*, soldier boy, I don’t work for free. This intel better be worth it.", "portrait": "res://portraits/dutch.png" },
	{ "speaker": "Yoshida", "text": "Statistically speaking, your chances of survival are slim. But hey, I’m just the dog.", "portrait": "res://portraits/yoshida.png" }
]
var current_line = 0

# Node references
@onready var portrait = $DialogueBox/HBoxContainer/Portrait
@onready var speaker_label = $DialogueBox/Speaker  # The first Label node for the speaker
@onready var dialogue_text = $DialogueBox/DialogueText # The second Label node for the dialogue
@onready var next_button = $DialogueBox/Button

func _ready():
	next_button.connect("pressed", Callable(self, "_on_next_button_pressed"))
	update_dialogue()

func update_dialogue():
	if current_line >= dialogue.size():
		# Dialogue finished, transition to gameplay
		start_map_generation()
		return
	
	# Get the current line of dialogue
	var line = dialogue[current_line]
	
	# Update UI elements
	speaker_label.text = line["speaker"]
	dialogue_text.text = line["text"]
	portrait.texture = load(line["portrait"])  # Load the portrait texture

func _on_next_button_pressed():
	current_line += 1
	update_dialogue()

func start_map_generation():
	# Replace with your logic for transitioning to the gameplay map
	get_tree().change_scene("res://scenes/MapScene.tscn")
