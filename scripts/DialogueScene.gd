extends Control

# Variables for dialogue data
var dialogue = [
	{ "speaker": "Bournetu. Kill", "text": "Major, I told you—this wasn’t a solo op. If we fail, millions die.", "portrait": "res://assets/portraits/soldier_port.png" },
	{ "speaker": "Dutch. Major", "text": "And I told *you*, soldier boy, I don’t work for free. This intel better be worth it.", "portrait": "res://assets/portraits/rambo_port.png" },
	{ "speaker": "Yoshida. Boi", "text": "Statistically speaking, your chances of survival are slim. But hey, I’m just the dog.", "portrait": "res://assets/portraits/dog_port.png" }
]
var current_line = 0
var displayed_text = ""  # Current visible text for typewriter effect
var full_text = ""       # The full line of text being typed
var text_index = 0       # Current character index
var typing_speed = 0.05  # Time delay (seconds) between each character

# Node references
@onready var portrait = $DialogueBox/CharacterRow/Portrait
@onready var speaker_label = $DialogueBox/Speaker
@onready var text = $DialogueBox/CharacterRow/Text
@onready var next_button = $DialogueBox/Button
@onready var typing_timer = $TypingTimer  # Timer node for the typewriter effect

func _ready():
	next_button.connect("pressed", Callable(self, "_on_next_button_pressed"))
	typing_timer.connect("timeout", Callable(self, "_on_typing_timer_timeout"))
	next_button.visible = false
	update_dialogue()

func update_dialogue():
	if current_line >= dialogue.size():
		# Dialogue finished, transition to gameplay
		start_map_generation()
		return
	
	# Get the current line of dialogue
	var line = dialogue[current_line]
	
	# Update the speaker and portrait immediately
	speaker_label.text = line["speaker"]
	portrait.texture = load(line["portrait"])  # Load the portrait texture
	
	# Start the typewriter effect for the text
	full_text = line["text"]
	displayed_text = ""
	text_index = 0
	text.text = displayed_text
	typing_timer.start(typing_speed)  # Start the timer for typing

func _on_typing_timer_timeout():
	if text_index < full_text.length():
		# Add the next character to the displayed text
		displayed_text += full_text[text_index]
		text.text = displayed_text
		text_index += 1
		next_button.visible = false
	else:
		# Stop the timer once the full text is displayed
		next_button.visible = true
		typing_timer.stop()

func _on_next_button_pressed():
	# If text is still typing, finish it instantly
	if text_index < full_text.length():
		typing_timer.stop()
		displayed_text = full_text
		text.text = displayed_text
	else:
		# Move to the next dialogue line		
		current_line += 1
		update_dialogue()

func start_map_generation():
	# Replace with your logic for transitioning to the gameplay map
	get_tree().change_scene_to_file("res://assets/scenes/map_manager.scn")
