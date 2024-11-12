extends Control

@onready var portrait = $HUD/Portrait  # Path to Portrait node inside HUD
@onready var health_bar = $HUD/HealthBar

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
		health_bar.max_value = character.max_health
		health_bar.value = character.current_health
