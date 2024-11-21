extends CanvasLayer

# Load your game scene
@onready var game_scene_path = "res://assets/scenes/dialogue_scene.tscn"  # Adjust the path to your scene
@onready var map_fader = $MapFader
@onready var start_button = $VBoxContainer/StartButton
@onready var quit_button = $VBoxContainer/QuitButton

@onready var introduction = $Control  # The node that will hold the scrolling text, assuming it's a Control or RichTextLabel
@onready var intro_text = $Control/Introduction  # The node that will hold the scrolling text, assuming it's a Control or RichTextLabel

@onready var audio_player = $AudioStreamPlayer2D 
@export var zombie_audio: AudioStream

var scrolling_duration : float = 60.0  # Time it takes for the text to scroll up
var start_pos : float = 0  # Start position of the text (adjust based on your scene)
var target_pos : float = -1500  # End position (adjust based on your scene)

var speed : float = 1.0 / scrolling_duration  # Speed for the scroll

var scrolling_done : bool = false
var elapsed_time : float = 0.0

var introduction_text : String = """
"The world has fallen."

The outbreak spread faster than anyone could predict, turning cities into graveyards and humanity’s last hope into a distant memory. Governments crumbled, and entire sectors became nothing but ruins, overrun by the undead.

In the shadows of a broken world, a team of unlikely allies has been assembled. Bournetu Kill, a hardened soldier with the rare and coveted skill to summon Mechas, leads the charge. His ability to call forth massive mechanical warriors could turn the tide in the ongoing battle, but it's a power that comes with its own price. Dutch Major, a mercenary with a reputation for not caring about anything but the payout, provides the muscle. And Yoshida Boi, a robot dog with artifical intelligence turned reluctant guide, crunches the numbers, knowing the chances of survival are slim.

Their mission: retrieve vital data from Novacrest, Sector 13. Once a manufacturing hub, now a war zone teeming with the undead. 

The risks are high, the objective clear, and the outcome uncertain. But with Bournetu's Mechas on their side, they may stand a chance. 

This is not a solo operation, but if they fail... millions will die and all hope for humanity will be lost.
"""


func _ready():
	# Connect button signals
	start_button.pressed.connect(_on_start_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)

	# Set the initial text for the introduction
	intro_text.text = introduction_text  # Assuming it's a RichTextLabel, set text this way
	introduction.position.y = start_pos  # Set the initial position of the introduction text
	start_scroll()
	
# Function to start scrolling the introduction when the intro button is pressed
func start_scroll():
	# Start the scrolling process
	scrolling_done = false
	elapsed_time = 0.0  # Reset the elapsed time
	set_process(true)  # Enable processing to update the scrolling each frame

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

# _process is called every frame and will handle the scrolling animation
func _process(delta: float) -> void:
	# Check if the scrolling is done
	if !scrolling_done:
		# Update the elapsed time with delta
		elapsed_time += delta
		
		# Calculate the interpolation value (alpha) between start_pos and target_pos
		var new_y = lerp(start_pos, target_pos, elapsed_time * speed)
		
		# Update the position of the introduction text
		introduction.position.y = new_y
		
		# If the scrolling is complete, stop the process and set final position
		if elapsed_time >= scrolling_duration:
			introduction.position.y = target_pos
			scrolling_done = true
			set_process(false)  # Stop the process function as scrolling is complete

	# Debugging message
	print("Scrolling introduction...")

# Function to be called when fade-in is complete
func _on_fade_in_complete():
	print("Fade-in complete, changing scene...")
	get_tree().change_scene_to_file(game_scene_path)  # Change the scene after fade-in completes
