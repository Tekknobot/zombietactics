extends Control

const portraitPaths = {
	"Logan": "res://assets/portraits/soldier_port.png",
	"Dutch": "res://assets/portraits/rambo_port.png",
	"Yoshida": "res://assets/portraits/dog_port.png",
	"Chuck": "res://assets/portraits/pilots/l0_por04.png",
	"Sarah": "res://assets/portraits/pilots/l0_por06.png",
	"Angel": "res://assets/portraits/pilots/l0_por07.png",
	"John": "res://assets/portraits/pilots/l0_por08.png",
	"Aleks": "res://assets/portraits/pilots/l0_por10.png",
	"Annie": "res://assets/portraits/pilots/l0_por03.png"
};

var dialogue = [
	{ "speaker": "Logan. Raines", "text": "Major, I told you—this wasn’t a solo op. If we fail, millions die.", "portrait": portraitPaths["Logan"] },
	{ "speaker": "Dutch. Major", "text": "And I told *you*, soldier boy, I don’t work for free. This intel better be worth it.", "portrait": portraitPaths["Dutch"] },
	{ "speaker": "Yoshida. Boi", "text": "Statistically speaking, your chances of survival are slim. But hey, I’m just the dog.", "portrait": portraitPaths["Yoshida"] },
	{ "speaker": "Chuck. Genius", "text": "Raines, I’ve been monitoring comms. This operation better not go sideways.", "portrait": portraitPaths["Chuck"] },
	{ "speaker": "Logan. Raines", "text": "We’re in Novacrest, Sector 13. Used to be a manufacturing hub before the outbreak.", "portrait": portraitPaths["Logan"] },
	{ "speaker": "Sarah. Reese", "text": "Focus, everyone. If this is as bad as it sounds, we need to stay sharp.", "portrait": portraitPaths["Sarah"] },
	{ "speaker": "Angel. Charlie", "text": "‘Stay sharp’? That’s the understatement of the year, Reese.", "portrait": portraitPaths["Angel"] },
	{ "speaker": "Dutch. Major", "text": "Yeah, yeah, I remember. I liked it better then.", "portrait": portraitPaths["Dutch"] },
	{ "speaker": "Annie. Switch", "text": "Alright, team. Less banter, more action. Let’s move.", "portrait": portraitPaths["Annie"] },
	{ "speaker": "Logan. Raines", "text": "Let’s move, and spread out!", "portrait": portraitPaths["Logan"] }
];

var dialogue_2 = [
	{ "speaker": "Yoshida. Boi", "text": "We’re approaching the core. Radiation levels are spiking again. I’d advise against prolonged exposure, but hey, I’m just a dog.", "portrait": portraitPaths["Yoshida"] },
	{ "speaker": "Chuck. Genius", "text": "Radiation? Wonderful. Just make sure my equipment doesn’t fry.", "portrait": portraitPaths["Chuck"] },
	{ "speaker": "Logan. Raines", "text": "We’ll move fast. Stay sharp. Dutch, keep an eye on our six while we search for the core.", "portrait": portraitPaths["Logan"] },
	{ "speaker": "Dutch. Major", "text": "Don’t worry about me. I’ve got this. But I’m not sure how much longer I can handle the heat.", "portrait": portraitPaths["Dutch"] },
	{ "speaker": "Angel. Charlie", "text": "You’re not the only one. Let’s find this core and get out.", "portrait": portraitPaths["Angel"] },
	{ "speaker": "Logan. Raines", "text": "Focus, people. The core is in a nearby facility—Yoshida, scan for any signs of it. We don’t have much time.", "portrait": portraitPaths["Logan"] },
	{ "speaker": "Sarah. Reese", "text": "On it. If something goes wrong, we’re not splitting up.", "portrait": portraitPaths["Sarah"] },
	{ "speaker": "Yoshida. Boi", "text": "I’m on it. Scanners are picking up a signal. But it’s faint. This facility must be heavily damaged.", "portrait": portraitPaths["Yoshida"] },
	{ "speaker": "Dutch. Major", "text": "Faint signals and radiation spikes? Perfect. What could possibly go wrong?", "portrait": portraitPaths["Dutch"] },
	{ "speaker": "Aleks. Ducat", "text": "Less sarcasm, more solutions. Let’s move.", "portrait": portraitPaths["Aleks"] },
	{ "speaker": "Logan. Raines", "text": "Cut the sarcasm, Dutch. We find that core, extract the data, and get out. Easy, right?", "portrait": portraitPaths["Logan"] }
];

var dialogue_3 = [
	{ "speaker": "Logan. Raines", "text": "Crimson District. Used to be biotech labs. Now it’s deserted.", "portrait": portraitPaths["Logan"] },
	{ "speaker": "Dutch. Major", "text": "You mean a dead zone. Something’s already creeping me out here.", "portrait": portraitPaths["Dutch"] },
	{ "speaker": "Yoshida. Boi", "text": "Scanners picking up significant activity ahead. The facility layout looks complex.", "portrait": portraitPaths["Yoshida"] },
	{ "speaker": "John. Doom", "text": "Complex or not, we adapt. Just point me in the right direction.", "portrait": portraitPaths["John"] },
	{ "speaker": "Dutch. Major", "text": "What exactly are we walking into?", "portrait": portraitPaths["Dutch"] },
	{ "speaker": "Sarah. Reese", "text": "Stay focused. This sector might still hold some surprises.", "portrait": portraitPaths["Sarah"] },
	{ "speaker": "Logan. Raines", "text": "Reports suggest this sector might have been critical for containment research. Stay alert.", "portrait": portraitPaths["Logan"] },
	{ "speaker": "Annie. Switch", "text": "I’ve marked potential routes on the HUD. Let’s stick to them.", "portrait": portraitPaths["Annie"] },
	{ "speaker": "Dutch. Major", "text": "Just what I needed—a maze with zero visibility. Let’s move.", "portrait": portraitPaths["Dutch"] },
	{ "speaker": "Logan. Raines", "text": "Stay sharp. No unnecessary risks.", "portrait": portraitPaths["Logan"] },
	{ "speaker": "Aleks. Ducat", "text": "No risks? This whole mission is a risk. Let’s keep moving.", "portrait": portraitPaths["Aleks"] }
];


var chapter_text_1: String = "Chapter 1: No Way Out — The Descent into Sector 13"
var chapter_text_2: String = "Chapter 2: Into the Dark — The Heart of Sector 13"
var chapter_text_3: String = "Chapter 3: Crimson Horizon — The Core Awakens"

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
	GlobalManager.reset_global_manager()
	
	next_button.connect("pressed", Callable(self, "_on_next_button_pressed"))
	typing_timer.connect("timeout", Callable(self, "_on_typing_timer_timeout"))
	skip_button.connect("pressed", Callable(self, "_on_skip_button_pressed"))    
	next_button.visible = false
	
	# Set dialogue and chapter text based on the current map index
	match GlobalManager.current_map_index:
		1:
			story_chapter.text = chapter_text_1
			dialogue = dialogue  # Use Chapter 1 dialogue
		2:
			story_chapter.text = chapter_text_2
			dialogue = dialogue_2  # Use Chapter 2 dialogue
		3:
			story_chapter.text = chapter_text_3
			dialogue = dialogue_3  # Use Chapter 2 dialogue			
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
