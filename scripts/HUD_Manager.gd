extends CanvasLayer

@onready var portrait = $HUD/Portrait
@onready var health_bar = $HUD/HealthBar
@onready var player_name = $HUD/Name
@onready var xp_bar = $HUD/XPBar
@onready var level = $HUD/Level
@onready var special = $HUD/Special  # Reference to the Special toggle
@onready var global_manager = get_node("/root/MapManager/GlobalManager")  # Reference to the GlobalManager in the scene

func _ready():
	if portrait:
		print("Portrait node found!")
	else:
		print("Portrait node not found!")

	# Connect the toggled signal for special button
	if special:
		special.connect("toggled", Callable(self, "_on_special_toggled"))
	
# Method to handle the toggle state change
func _on_special_toggled(button_pressed: bool) -> void:
	if button_pressed:
		global_manager.special_toggle_active = true  # Set the flag to true
		print("Special toggle activated!")
	else:
		global_manager.special_toggle_active = false  # Set the flag to false
		print("Special toggle deactivated!")

# Access and update HUD elements based on the selected player unit
func update_hud(character: PlayerUnit):
	# Debugging: Check if the correct character is passed
	print("Updating HUD for: ", character)

	# Reset the special toggle to "off" when updating the HUD
	if special:
		special.button_pressed = false  # This ensures the toggle is visually set to off
		global_manager.special_toggle_active = false  # Reset the special flag in global_manager

		# Optionally emit the toggled signal to indicate the toggle state reset
		special.emit_signal("toggled", false)
		print("Special toggle reset to off")

	# Update the rest of the HUD elements
	if character.portrait_texture and portrait:
		portrait.texture = character.portrait_texture
		print("Portrait texture updated")

	if character.max_health > 0:
		health_bar.max_value = character.max_health
		health_bar.value = character.current_health
		print("Health Bar Updated: Max: ", health_bar.max_value, " Current: ", health_bar.value)
	else:
		print("Max health is 0 or invalid")
	
	if character.max_xp > 0:
		xp_bar.max_value = character.max_xp
		xp_bar.value = character.current_xp
		print("XP Bar Updated: Max: ", xp_bar.max_value, " Current: ", xp_bar.value)
	else:
		print("Max XP is 0 or invalid")
	
	if level:
		level.text = "Level " + str(character.current_level)
		print("Level updated to: ", level.text)
	else:
		print("Level node is null!")
