extends Control

# Variables to store references to HUD elements
var healthbar: ProgressBar
var unit_name: Label
var unit_health: Label
var unit_damage: Label
var attack_button: Button
var portrait: TextureRect  # Single portrait display area

# Preload the portrait assets
var portrait_zombie = preload("res://assets/portraits/zombie_port.png")
var portrait_merc = preload("res://assets/portraits/rambo_port.png")
var portrait_soldier = preload("res://assets/portraits/soldier_port.png")
var portrait_dog = preload("res://assets/portraits/dog_port.png")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Get references to HUD elements by their node paths
	healthbar = $Healthbar
	unit_name = $UnitName
	unit_health = $HBoxContainer/UnitHealth
	unit_damage = $HBoxContainer/UnitDamage
	attack_button = $Buttons/Attack
	portrait = $Background  # Reference to the portrait display area (TextureRect)

	# Connect the attack button signal to a custom function using a Callable
	attack_button.connect("pressed", Callable(self, "_on_attack_button_pressed"))

# Public function to update the health bar
func update_health(current_health: int, max_health: int) -> void:
	healthbar.max_value = max_health
	healthbar.value = current_health
	unit_health.text = "HP: " + str(current_health) + "-" + str(max_health)

# Public function to update the unit name
func update_unit_name(name: String) -> void:
	unit_name.text = name

# Public function to update the unit damage
func update_unit_damage(damage: int) -> void:
	unit_damage.text = "POW: " + str(damage)

# Public function to update the portrait based on unit name (e.g., "Zombie", "Merc", "Soldier", "Dog")
func update_portrait(unit_type: String) -> void:
	match unit_type:
		"Zombie":
			portrait.texture = portrait_zombie  # Display zombie.png
		"Merc":
			portrait.texture = portrait_merc  # Display merc.png
		"Soldier":
			portrait.texture = portrait_soldier  # Display soldier.png
		"Dog":
			portrait.texture = portrait_dog  # Display dog.png
		_:
			portrait.texture = null  # Clear portrait if no valid unit type

# Public function to update the entire HUD based on the selected unit
func update_hud_for_unit(unit_type: String, unit_health_value: int, unit_max_health_value: int, unit_damage_value: int) -> void:
	update_unit_name(unit_type)
	update_health(unit_health_value, unit_max_health_value)
	update_unit_damage(unit_damage_value)
	update_portrait(unit_type)

# Handle the attack button press
func _on_attack_button_pressed() -> void:
	print("Attack button pressed!")
	# Trigger attack logic in your game (you might want to notify your main game script here)
