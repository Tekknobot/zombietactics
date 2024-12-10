extends CanvasLayer

@onready var portrait = $HUD/Portrait
@onready var health_bar = $HUD/HealthBar
@onready var player_name = $HUD/LevelStatName/Name
@onready var xp_bar = $HUD/XPBar
@onready var level = $HUD/LevelStatName/Level

@onready var hp = $HUD/StatContainer/HP
@onready var xp = $HUD/StatContainer/XP
@onready var atk = $HUD/StatContainer/ATK

@onready var missile = $HUD/Missile 
@onready var landmine = $HUD/Landmine
@onready var mek = $HUD/Mek
@onready var dynamite = $HUD/Dynamite
@onready var thread = $HUD/Thread
@onready var dash = $HUD/Dash
@onready var claw = $HUD/Claw
@onready var hellfire = $HUD/Hellfire
@onready var barrage = $HUD/Barrage

@onready var end_turn = $HUD/EndTurn
@onready var turn_manager = get_node("/root/MapManager/TurnManager")

func _ready():
	if portrait:
		print("Portrait node found!")
	else:
		print("Portrait node not found!")

	# Connect the toggled signal for special button
	if end_turn:
		end_turn.connect("pressed", Callable(self, "_on_endturn_pressed"))
		print("EndTurn connected")
			
	if missile:
		missile.connect("toggled", Callable(self, "_on_missile_toggled"))
		print("Missile connected")

	if landmine:
		landmine.connect("toggled", Callable(self, "_on_landmine_toggled"))
		print("Landmine connected")

	if mek:
		mek.connect("toggled", Callable(self, "_on_mek_toggled"))
		print("Mek connected")

	if dynamite:
		dynamite.connect("toggled", Callable(self, "_on_dynamite_toggled"))
		print("Dynamite connected")

	if thread:
		thread.connect("toggled", Callable(self, "_on_thread_toggled"))
		print("Thread connected")

	if dash:
		dash.connect("toggled", Callable(self, "_on_dash_toggled"))
		print("Dash connected")

	if claw:
		claw.connect("toggled", Callable(self, "_on_claw_toggled"))
		print("Claw connected")
					
	if hellfire:
		hellfire.connect("toggled", Callable(self, "_on_hellfire_toggled"))
		print("Hellfire connected")

	if barrage:
		barrage.connect("toggled", Callable(self, "_on_barrage_toggled"))
		print("Barrage connected")
							
# Method to handle the toggle state change
func _on_endturn_pressed() -> void:
	print("End Turn button pressed")
	var hovertiles = get_tree().get_nodes_in_group("hovertile")
	for hovertile in hovertiles:
		hovertile.clear_action_tiles()
	turn_manager.on_player_action_completed()

func _on_missile_toggled(button_pressed: bool) -> void:
	if button_pressed:
		GlobalManager.missile_toggle_active = true  # Set the flag to true
		print("Missile toggle activated!")
		
		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_attack_range_tiles()			
	else:
		GlobalManager.missile_toggle_active = false  # Set the flag to false
		print("Missile toggle deactivated!")

func _on_landmine_toggled(button_pressed: bool) -> void:
	if button_pressed:
		GlobalManager.landmine_toggle_active = true  # Set the flag to true
		print("Landmine toggle activated!")	
				
		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_attack_range_tiles()	
	else:
		GlobalManager.landmine_toggle_active = false  # Set the flag to false
		print("Landmine toggle deactivated!")

func _on_mek_toggled(button_pressed: bool) -> void:
	if button_pressed:
		GlobalManager.mek_toggle_active = true  # Set the flag to true
		print("Mek toggle activated!")	
		
		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_attack_range_tiles()	
	else:
		GlobalManager.mek_toggle_active = false  # Set the flag to false
		print("Mek toggle deactivated!")

func _on_dynamite_toggled(button_pressed: bool) -> void:
	if button_pressed:
		GlobalManager.dynamite_toggle_active = true  # Set the flag to true
		print("Dynamite toggle activated!")	

		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_attack_range_tiles()	
	else:
		GlobalManager.dynamite_toggle_active = false  # Set the flag to false
		print("Dynamite toggle deactivated!")

func _on_thread_toggled(button_pressed: bool) -> void:
	if button_pressed:
		GlobalManager.thread_toggle_active = true  # Set the flag to true
		print("Thread toggle activated!")	

		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_attack_range_tiles()	
	else:
		GlobalManager.thread_toggle_active = false  # Set the flag to false
		print("Thread toggle deactivated!")

func _on_dash_toggled(button_pressed: bool) -> void:
	if button_pressed:
		GlobalManager.dash_toggle_active = true  # Set the flag to true
		print("Dash toggle activated!")	

		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_attack_range_tiles()	
	else:
		GlobalManager.dash_toggle_active = false  # Set the flag to false
		print("Dash toggle deactivated!")

func _on_claw_toggled(button_pressed: bool) -> void:
	if button_pressed:
		GlobalManager.claw_toggle_active = true  # Set the flag to true
		print("Dash toggle activated!")	

		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_attack_range_tiles()	
	else:
		GlobalManager.claw_toggle_active = false  # Set the flag to false
		print("Dash toggle deactivated!")

func _on_hellfire_toggled(button_pressed: bool) -> void:
	if button_pressed:
		GlobalManager.hellfire_toggle_active = true  # Set the flag to true
		print("Hellfire toggle activated!")	

		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_attack_range_tiles()	
	else:
		GlobalManager.hellfire_toggle_active = false  # Set the flag to false
		print("Hellfire toggle deactivated!")

func _on_barrage_toggled(button_pressed: bool) -> void:
	if button_pressed:
		GlobalManager.barrage_toggle_active = true  # Set the flag to true
		print("Barrage toggle activated!")	

		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_attack_range_tiles()	
	else:
		GlobalManager.barrage_toggle_active = false  # Set the flag to false
		print("Barrage toggle deactivated!")
		
				
# Access and update HUD elements based on the selected player unit
func update_hud(character: PlayerUnit):
	# Debugging: Check if the correct character is passed
	print("Updating HUD for: ", character)

	# Reset the missile toggle to "off" when updating the HUD
	if missile:
		missile.button_pressed = false  # This ensures the toggle is visually set to off
		GlobalManager.missile_toggle_active = false  # Reset the special flag in global_manager

		# Optionally emit the toggled signal to indicate the toggle state reset
		missile.emit_signal("toggled", false)
		print("Missile toggle reset to off")

	if landmine:
		landmine.button_pressed = false  # This ensures the toggle is visually set to off
		GlobalManager.landmine_toggle_active = false  # Reset the special flag in global_manager

		# Optionally emit the toggled signal to indicate the toggle state reset
		landmine.emit_signal("toggled", false)
		print("Landmine toggle reset to off")

	# Update the rest of the HUD elements
	if character.portrait_texture and portrait:
		portrait.texture = character.portrait_texture
		print("Portrait texture updated")

	# Update player name if the player_name label exists
	if player_name:
		player_name.text = character.player_name  # Set the player name text from the character
		player_name.adjust_size_to_content()
		print("Player name updated to: ", player_name.text)
	else:
		print("Player name node is null!")

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
		level.adjust_size_to_content()
		print("Level updated to: ", level.text)
	else:
		print("Level node is null!")

	if hp:
		hp.text = "HP: " + str(character.current_health) + " of " + str(character.max_health)
		hp.adjust_size_to_content()
		print("HP updated to: ", hp.text)
	else:
		print("HP node is null!")

	if xp:
		xp.text = "XP: " + str(character.current_xp) + " of " + str(character.xp_for_next_level)
		xp.adjust_size_to_content()
		print("XP updated to: ", xp.text)
	else:
		print("XP node is null!")

	if atk:
		atk.text = "ATK: " + str(character.attack_damage)
		atk.adjust_size_to_content()
		print("ATK updated to: ", atk.text)
	else:
		print("ATK node is null!")
		
	if health_bar:
		health_bar.max_value = character.max_health
		health_bar.value = character.current_health
		print("Updated health bar: Max=", health_bar.max_value, ", Current=", health_bar.value)

	if xp_bar:
		xp_bar.max_value = character.xp_for_next_level
		xp_bar.value = character.current_xp
		print("Updated XP bar: Max=", xp_bar.max_value, ", Current=", xp_bar.value)
			
# Access and update HUD elements based on the selected player unit
func update_hud_zombie(character: ZombieUnit):
	# Debugging: Check if the correct character is passed
	print("Updating HUD for: ", character)

	# Update the rest of the HUD elements
	if character.portrait_texture and portrait:
		portrait.texture = character.portrait_texture
		print("Portrait texture updated")

	# Update player name if the player_name label exists
	if player_name:
		player_name.text = character.zombie_name  # Set the player name text from the character
		player_name.adjust_size_to_content()
		print("Player name updated to: ", player_name.text)
	else:
		print("Player name node is null!")

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
		level.adjust_size_to_content()
		print("Level updated to: ", level.text)
	else:
		print("Level node is null!")

	if hp:
		hp.text = "HP: " + str(character.current_health) + " of " + str(character.max_health)
		hp.adjust_size_to_content()
		print("HP updated to: ", hp.text)
	else:
		print("HP node is null!")

	if xp:
		xp.text = "XP: " + str(character.current_xp) + " of " + str(character.xp_for_next_level)
		xp.adjust_size_to_content()
		print("XP updated to: ", xp.text)
	else:
		print("XP node is null!")

	if atk:
		atk.text = "ATK: " + str(character.attack_damage)
		atk.adjust_size_to_content()
		print("ATK updated to: ", atk.text)
	else:
		print("ATK node is null!")

	if health_bar:
		health_bar.max_value = character.max_health
		health_bar.value = character.current_health
		print("Updated health bar: Max=", health_bar.max_value, ", Current=", health_bar.value)

	if xp_bar:
		xp_bar.max_value = character.xp_for_next_level
		xp_bar.value = character.current_xp
		print("Updated XP bar: Max=", xp_bar.max_value, ", Current=", xp_bar.value)		

func show_special_buttons(character: PlayerUnit):
	end_turn.visible = true
	
	if character.player_name == "Yoshida. Boi":
		missile.visible = true
		landmine.visible = true

	if character.player_name == "Logan. Raines":
		mek.visible = true
		
	if character.player_name == "Dutch. Major":
		dynamite.visible = true
		
	if character.player_name == "Sarah. Reese":
		thread.visible = true		

	if character.player_name == "Chuck. Genius":
		dash.visible = true					

	if character.player_name == "Aleks. Ducat":
		claw.visible = true	

	if character.player_name == "John. Doom":
		hellfire.visible = true	
		
	if character.player_name == "Seraphina. Halcyon":
		barrage.visible = true			
				
func hide_special_buttons():
	end_turn.visible = false
	
	missile.visible = false
	landmine.visible = false
	mek.visible = false
	dynamite.visible = false
	thread.visible = false
	dash.visible = false
	dash.visible = false
	claw.visible = false
	hellfire.visible = false
	barrage.visible = false
