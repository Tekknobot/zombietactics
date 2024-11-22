extends Control

# Variables for dialogue data
var dialogue = [
	{ "speaker": "Logan. Raines", "text": "Major, I told you—this wasn’t a solo op. If we fail, millions die.", "portrait": "res://assets/portraits/soldier_port.png" },
	{ "speaker": "Dutch. Major", "text": "And I told *you*, soldier boy, I don’t work for free. This intel better be worth it.", "portrait": "res://assets/portraits/rambo_port.png" },
	{ "speaker": "Yoshida. Boi", "text": "Statistically speaking, your chances of survival are slim. But hey, I’m just the dog.", "portrait": "res://assets/portraits/dog_port.png" },
	{ "speaker": "Logan. Raines", "text": "We’re in Novacrest, Sector 13. Used to be a manufacturing hub before the outbreak.", "portrait": "res://assets/portraits/soldier_port.png" },
	{ "speaker": "Dutch. Major", "text": "Yeah, yeah, I remember. The last time I was here, it wasn’t crawling with brain-eaters. I liked it better then.", "portrait": "res://assets/portraits/rambo_port.png" },
	{ "speaker": "Yoshida. Boi", "text": "Noted: Dutch prefers his cities uninfested. Scanning Sector 13... Little power, minimal heat signatures, but plenty of undead activity.", "portrait": "res://assets/portraits/dog_port.png" },
	{ "speaker": "Logan. Raines", "text": "The objective is clear. We find the data core in this sector and secure it. No mistakes.", "portrait": "res://assets/portraits/soldier_port.png" },
	{ "speaker": "Dutch. Major", "text": "Mistakes? Me? You’re lucky I’m even here. Let’s just grab the intel and get out before things get messy.", "portrait": "res://assets/portraits/rambo_port.png" },
	{ "speaker": "Yoshida. Boi", "text": "Too late for that. Zombies inbound. Shall I mark their positions on your HUDs, or do you prefer surprises?", "portrait": "res://assets/portraits/dog_port.png" },
	{ "speaker": "Logan. Raines", "text": "Yoshida, mark them. We’ll clear the streets one tile at a time. Let’s move, and spread out!", "portrait": "res://assets/portraits/soldier_port.png" }
]

var dialogue_2 = [
	{ "speaker": "Yoshida. Boi", "text": "We’re approaching the core. Radiation levels are spiking again. I’d advise against prolonged exposure, but hey, I’m just a dog.", "portrait": "res://assets/portraits/dog_port.png" },
	{ "speaker": "Logan. Raines", "text": "We’ll move fast. Stay sharp. Dutch, keep an eye on our six while we search for the core.", "portrait": "res://assets/portraits/soldier_port.png" },
	{ "speaker": "Dutch. Major", "text": "Don’t worry about me. I’ve got this. But I’m not sure how much longer I can handle the heat. These zombies are getting thicker.", "portrait": "res://assets/portraits/rambo_port.png" },
	{ "speaker": "Yoshida. Boi", "text": "You’re not the only one dealing with the heat, Dutch. These zombies are becoming a serious issue. Let’s find that core before they find us.", "portrait": "res://assets/portraits/dog_port.png" },
	{ "speaker": "Logan. Raines", "text": "Focus, people. The core is in a nearby facility—Yoshida, scan for any signs of it. We don’t have much time.", "portrait": "res://assets/portraits/soldier_port.png" },
	{ "speaker": "Yoshida. Boi", "text": "I’m on it. Scanners are picking up a signal. But it’s faint. This facility must be heavily damaged, or someone’s messing with the data.", "portrait": "res://assets/portraits/dog_port.png" },
	{ "speaker": "Dutch. Major", "text": "Faint signals, radiation spikes, and an army of zombies? Perfect. What could possibly go wrong?", "portrait": "res://assets/portraits/rambo_port.png" },
	{ "speaker": "Logan. Raines", "text": "Cut the sarcasm, Dutch. We find that core, extract the data, and get out. Easy, right?", "portrait": "res://assets/portraits/soldier_port.png" },
	{ "speaker": "Yoshida. Boi", "text": "Hold up. Scanners are picking up a cluster of zombies ahead. They’re closing in on the core’s location.", "portrait": "res://assets/portraits/dog_port.png" },
	{ "speaker": "Dutch. Major", "text": "Zombies ahead? What else is new? Just tell me where to shoot.", "portrait": "res://assets/portraits/rambo_port.png" },
	{ "speaker": "Yoshida. Boi", "text": "It’s not just about shooting. We need to move carefully, take them out quietly. We don’t want the whole facility on us at once.", "portrait": "res://assets/portraits/dog_port.png" },
	{ "speaker": "Logan. Raines", "text": "Agreed. Focus fire, clean shots. Dutch, lead the way. Yoshida, stay on comms and monitor the signal. I’ll cover the rear.", "portrait": "res://assets/portraits/soldier_port.png" },
	{ "speaker": "Dutch. Major", "text": "Lead the way? Sure, as long as there’s something to shoot at. Let’s just get this done.", "portrait": "res://assets/portraits/rambo_port.png" },
	{ "speaker": "Yoshida. Boi", "text": "I’m detecting more movement... too many for a quiet approach. We’ll need to fight our way through.", "portrait": "res://assets/portraits/dog_port.png" },
	{ "speaker": "Logan. Raines", "text": "Then we fight. Just don’t let them overwhelm us. We stick together, focus on the objective: the core.", "portrait": "res://assets/portraits/soldier_port.png" },
	{ "speaker": "Dutch. Major", "text": "Sounds like a plan. I’ve got your back, just don’t expect me to go easy on the zombies.", "portrait": "res://assets/portraits/rambo_port.png" },
	{ "speaker": "Yoshida. Boi", "text": "I’ll keep scanning. The core should be in the next room. Let’s move.", "portrait": "res://assets/portraits/dog_port.png" },
	{ "speaker": "Logan. Raines", "text": "Once we get the core, we extract. No detours, no heroics. We finish this and get out.", "portrait": "res://assets/portraits/soldier_port.png" }
]



var chapter_text: String = "Chapter 1: No Way Out — The Descent into Sector 13"
var chapter_text_2: String = "Chapter 2: Into the Dark — The Heart of Sector 13"

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
@onready var story_chapter = $StoryChapter  # Timer node for the typewriter effect
@onready var skip_button = $Skip  # Timer node for the typewriter effect

func _ready():
	GlobalManager.current_map_index += 1
	
	next_button.connect("pressed", Callable(self, "_on_next_button_pressed"))
	typing_timer.connect("timeout", Callable(self, "_on_typing_timer_timeout"))
	skip_button.connect("pressed", Callable(self, "_on_skip_button_pressed"))    
	next_button.visible = false
	
	# Set dialogue and chapter text based on the current map index
	match GlobalManager.current_map_index:
		1:
			story_chapter.text = chapter_text
			dialogue = dialogue  # Use Chapter 1 dialogue
		2:
			story_chapter.text = chapter_text_2
			dialogue = dialogue_2  # Use Chapter 2 dialogue
		_:
			story_chapter.text = "Chapter Unknown"
			dialogue = []  # Fallback for undefined chapters

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

func _on_skip_button_pressed():
	# Replace with your logic for transitioning to the gameplay map
	get_tree().change_scene_to_file("res://assets/scenes/map_manager.scn")

		
func start_map_generation():
	# Replace with your logic for transitioning to the gameplay map
	get_tree().change_scene_to_file("res://assets/scenes/map_manager.scn")
