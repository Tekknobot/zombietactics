extends CanvasLayer

@onready var portrait = $HUD/Portrait  # Ensure Portrait node exists in the scene
@onready var health_bar = $HUD/HealthBar  # Reference to the ProgressBar node
@onready var player_name = $HUD/Name  # Reference to the Label node (for player's name)
@onready var xp_bar = $HUD/XPBar  # Reference to the Label node (for player's name)

func _ready():
	if portrait:
		print("Portrait node found!")
	else:
		print("Portrait node not found!")

# Function to update the HUD based on the selected player unit
func update_hud(character: PlayerUnit):
	# Debugging: Check if the correct character is passed
	print("Updating HUD for: ", character)

	# Ensure that portrait texture is assigned when the character has a valid texture
	if character.portrait_texture:
		if portrait:  # Only update if portrait exists
			portrait.texture = character.portrait_texture
			print("Portrait texture updated")
		else:
			print("Portrait node is null!")
	else:
		print("No valid portrait texture found for: ", character)

	# Update health bar based on character's health
	if character.max_health > 0:
		health_bar.max_value = character.max_health  # Set the maximum value to the character's max health
		health_bar.value = character.current_health  # Set the current value to the character's current health
		print("Health Bar Updated: Max: ", health_bar.max_value, " Current: ", health_bar.value)
	else:
		print("Max health is 0 or invalid")
	
	# Update player name if the player_name label exists
	if player_name:
		player_name.text = character.player_name  # Set the player name text from the character
		print("Player name updated to: ", player_name.text)
	else:
		print("Player name node is null!")

	# Update health bar based on character's health
	if character.max_health > 0:
		xp_bar.max_value = character.max_xp  # Set the maximum value to the character's max health
		xp_bar.value = character.current_xp  # Set the current value to the character's current health
		print("Health Bar Updated: Max: ", xp_bar.max_value, " Current: ", xp_bar.value)
	else:
		print("Max health is 0 or invalid")
	
