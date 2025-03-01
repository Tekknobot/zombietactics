extends CanvasLayer

@onready var portrait = $HUD/Portrait

@onready var player_name = $HUD/LevelStatName/Name
@onready var level = $HUD/LevelStatName/Level
@onready var turn = $HUD/LevelStatName/Turn

@onready var health_bar = $HUD/HealthBar
@onready var xp_bar = $HUD/XPBar

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
@onready var octoblast = $HUD/Octoblast
@onready var grenade = $HUD/Grenade

@onready var slash = $HUD/Slash
@onready var shadows = $HUD/Shadows
@onready var prowler = $HUD/Prowler
@onready var regenerate = $HUD/Regenerate
@onready var transport = $HUD/Transport

@onready var end_turn = $HUD/EndTurn
@onready var info = $HUD/Info
@onready var turn_manager = get_node("/root/MapManager/TurnManager")
@onready var zombie_spawn_manager = get_parent().get_node("/root/MapManager/SpawnZombies")  

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

	if octoblast:
		octoblast.connect("toggled", Callable(self, "_on_octoblast_toggled"))
		print("Octoblast connected")

	if grenade:
		grenade.connect("toggled", Callable(self, "_on_grenade_toggled"))
		print("Grenade connected")

	if slash:
		slash.connect("toggled", Callable(self, "_on_slash_toggled"))
		print("Slash connected")

	if shadows:
		shadows.connect("toggled", Callable(self, "_on_shadows_toggled"))
		print("Shadows connected")
		
	if prowler:
		prowler.connect("toggled", Callable(self, "_on_prowler_toggled"))
		print("Prowler connected")		

	if regenerate:
		regenerate.connect("toggled", Callable(self, "_on_regenerate_toggled"))
		print("Regenerate connected")	

	if transport:
		transport.connect("toggled", Callable(self, "_on_transport_toggled"))
		print("Transport connected")																			
		
# Method to handle the toggle state change
func _on_endturn_pressed() -> void:
	print("End Turn button pressed")
	var hovertiles = get_tree().get_nodes_in_group("hovertile")
	for hovertile in hovertiles:
		hovertile.clear_action_tiles()
	GlobalManager.zombies_processed = 0
	GlobalManager.zombie_queue.clear()
	await get_tree().create_timer(0.5).timeout
	await zombie_spawn_manager.spawn_zombies()
	turn_manager.on_player_action_completed()
	turn_manager.used_turns_count = 0
	for hovertile in hovertiles:
		update_hud(hovertile.selected_player)

func _on_missile_toggled(button_pressed: bool) -> void:
	if button_pressed:
		GlobalManager.landmine_toggle_active = true  # Set the flag to true
		print("Missile toggle activated!")
		landmine.button_pressed = false
		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_attack_range_tiles()	
			if player.player_name == "Yoshida. Boi" and !player.is_in_group("unitAI"):
				player.display_special_attack_tiles()		
	else:
		GlobalManager.landmine_toggle_active = false  # Set the flag to false
		print("Missile toggle deactivated!")	
		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_special_tiles()
			
func _on_landmine_toggled(button_pressed: bool) -> void:
	if button_pressed:
		GlobalManager.landmine_toggle_active = true  # Set the flag to true
		print("Landmine toggle activated!")	
		missile.button_pressed = false		
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
		grenade.button_pressed = false
		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_attack_range_tiles()	
	else:
		GlobalManager.mek_toggle_active = false  # Set the flag to false
		print("Mek toggle deactivated!")

func _on_dynamite_toggled(button_pressed: bool) -> void:
	if button_pressed:
		GlobalManager.dynamite_toggle_active = true  # Set the flag to true
		slash.button_pressed = false
		print("Dynamite toggle activated!")	
		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_attack_range_tiles()	
			if player.player_name == "Dutch. Major":
				player.display_special_attack_tiles()	
	else:
		GlobalManager.dynamite_toggle_active = false  # Set the flag to false
		print("Dynamite toggle deactivated!")
		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_special_tiles()
			
func _on_grenade_toggled(button_pressed: bool) -> void:
	if button_pressed:
		GlobalManager.grenade_toggle_active = true  # Set the flag to true
		mek.button_pressed = false
		print("Grenade toggle activated!")	
		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_attack_range_tiles()	
			if player.player_name == "Logan. Raines" and !player.is_in_group("unitAI"):
				player.display_special_attack_tiles()
	else:
		GlobalManager.grenade_toggle_active = false  # Set the flag to false
		print("Grenade toggle deactivated!")
		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_special_tiles()			

func _on_slash_toggled(button_pressed: bool) -> void:
	if button_pressed:
		GlobalManager.slash_toggle_active = true  # Set the flag to true
		dynamite.button_pressed = false
		print("Slash toggle activated!")	
		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_attack_range_tiles()	
		
		var hovertiles = get_tree().get_nodes_in_group("hovertile")
		for hovertile in hovertiles:
			if hovertile.selected_player and hovertile.selected_player.player_name == "Dutch. Major":
				hovertile.selected_player.get_child(7).display_slash_attack_range()
					
	else:	
		GlobalManager.slash_toggle_active = false  # Set the flag to false
		var hovertiles = get_tree().get_nodes_in_group("hovertile")
		for hovertile in hovertiles:
			if hovertile.selected_player and hovertile.selected_player.player_name == "Dutch. Major":
				hovertile.selected_player.get_child(7).clear_attack_range_tiles()
					
		print("Slash toggle deactivated!")

func _on_shadows_toggled(button_pressed: bool) -> void:
	if button_pressed:
		GlobalManager.shadows_toggle_active = true  # Set the flag to true
		print("Shadows toggle activated!")	
		dash.button_pressed = false
		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_attack_range_tiles()	
			if player.player_name == "Chuck. Genius" and !player.is_in_group("unitAI"):
				player.display_special_attack_tiles()
	else:
		GlobalManager.shadows_toggle_active = false  # Set the flag to false
		print("Shadows toggle deactivated!")
		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_special_tiles()	
			
func _on_thread_toggled(button_pressed: bool) -> void:
	if button_pressed:
		GlobalManager.thread_toggle_active = true  # Set the flag to true
		print("Thread toggle activated!")	
		regenerate.button_pressed = false
		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_attack_range_tiles()	
			if player.player_name == "Sarah. Reese" and !player.is_in_group("unitAI"):
				player.display_special_attack_tiles()
	else:
		GlobalManager.thread_toggle_active = false  # Set the flag to false
		print("Thread toggle deactivated!")
		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_special_tiles()			

func _on_dash_toggled(button_pressed: bool) -> void:
	if button_pressed:
		GlobalManager.dash_toggle_active = true  # Set the flag to true
		print("Dash toggle activated!")	
		shadows.button_pressed = false
		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_attack_range_tiles()	
	else:
		GlobalManager.dash_toggle_active = false  # Set the flag to false
		print("Dash toggle deactivated!")

func _on_prowler_toggled(button_pressed: bool) -> void:
	if button_pressed:
		GlobalManager.prowler_toggle_active = true  # Set the flag to true
		print("Prowler toggle activated!")	
		claw.button_pressed = false
		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_attack_range_tiles()	
			if player.player_name == "Aleks. Ducat" and !player.is_in_group("unitAI"):
				player.display_special_attack_tiles()
	else:
		GlobalManager.prowler_toggle_active = false  # Set the flag to false
		print("Prowler toggle deactivated!")
		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_special_tiles()		
		
func _on_claw_toggled(button_pressed: bool) -> void:
	if button_pressed:
		GlobalManager.claw_toggle_active = true  # Set the flag to true
		print("Claw toggle activated!")	
		prowler.button_pressed = false
		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_attack_range_tiles()	
	else:
		GlobalManager.claw_toggle_active = false  # Set the flag to false
		print("Claw toggle deactivated!")

func _on_regenerate_toggled(button_pressed: bool) -> void:
	if button_pressed:
		GlobalManager.regenerate_toggle_active = true  # Set the flag to true
		print("Regenerate toggle activated!")	
		thread.button_pressed = false
		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_attack_range_tiles()	
	else:
		GlobalManager.regenerate_toggle_active = false  # Set the flag to false
		print("Regenerate toggle deactivated!")

func _on_transport_toggled(button_pressed: bool) -> void:
	if button_pressed:
		GlobalManager.transport_toggle_active = true  # Set the flag to true
		print("Transport toggle activated!")	
		hellfire.button_pressed = false
		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_attack_range_tiles()	
	else:
		GlobalManager.transport_toggle_active = false  # Set the flag to false
		print("Transport toggle deactivated!")
		
func _on_hellfire_toggled(button_pressed: bool) -> void:
	if button_pressed:
		GlobalManager.hellfire_toggle_active = true  # Set the flag to true
		print("Hellfire toggle activated!")	
		transport.button_pressed = false
		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_attack_range_tiles()	
			if player.player_name == "John. Doom" and !player.is_in_group("unitAI"):
				player.display_special_attack_tiles()
	else:
		GlobalManager.hellfire_toggle_active = false  # Set the flag to false
		print("Hellfire toggle deactivated!")
		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_special_tiles()
			
func _on_barrage_toggled(button_pressed: bool) -> void:
	if button_pressed:
		GlobalManager.barrage_toggle_active = true  # Set the flag to true
		print("Barrage toggle activated!")	

		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_attack_range_tiles()	
			if player.player_name == "Angel. Charlie" and !player.is_in_group("unitAI"):
				player.display_special_attack_tiles()	
	else:
		GlobalManager.barrage_toggle_active = false  # Set the flag to false
		print("Barrage toggle deactivated!")
		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_special_tiles()		
		
func _on_octoblast_toggled(button_pressed: bool) -> void:
	if button_pressed:
		GlobalManager.octoblast_toggle_active = true  # Set the flag to true
		print("Octoblast toggle activated!")	

		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_attack_range_tiles()	
			if player.player_name == "Annie. Switch" and !player.is_in_group("unitAI"):
				player.display_special_attack_tiles()	
	else:
		GlobalManager.octoblast_toggle_active = false  # Set the flag to false
		print("Octoblast toggle deactivated!")
		var players = get_tree().get_nodes_in_group("player_units")
		for player in players:
			player.clear_special_tiles()	
									
# Access and update HUD elements based on the selected player unit
func update_hud(character: PlayerUnit):
	# Debugging: Check if the correct character is passed
	print("Updating HUD for: ", character)

	turn.visible = true

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
		# If the character is part of the unitAI group, modulate the texture color
		if character.is_in_group("unitAI"):
			portrait.modulate = Color8(25, 25, 25)	
		else:
			portrait.modulate = Color(1, 1, 1, 1)  # Reset to default color if needed
			
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

	if turn:
		turn.text = "Player Turn: " + str(turn_manager.used_turns_count + 1) + " of " + str(turn_manager.max_turn_count)
		turn.adjust_size_to_content()
		print("Turn updated to: ", turn.text)
	else:
		print("Level node is null!")
	
	var zombies = get_tree().get_nodes_in_group("zombies")
		
	if info and zombies.size() <= 0:
		info.visible = true
		info.adjust_size_to_content()
		print("Info updated to: ", info.text)
	else:
		print("Info node is null!")		

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
	
	turn.visible = false	
		
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
		grenade.visible = true

	if character.player_name == "Dutch. Major":
		dynamite.visible = true
		slash.visible = true

	if character.player_name == "Chuck. Genius":
		dash.visible = true
		shadows.visible = true
				
	if character.player_name == "Sarah. Reese":
		thread.visible = true
		regenerate.visible = true					

	if character.player_name == "Aleks. Ducat":
		claw.visible = true	
		prowler.visible = true

	if character.player_name == "John. Doom":
		hellfire.visible = true	
		transport.visible = true
		
	if character.player_name == "Angel. Charlie":
		barrage.visible = true			

	if character.player_name == "Annie. Switch":
		octoblast.visible = true			
						
func hide_special_buttons():
	end_turn.visible = false
	
	missile.visible = false
	landmine.visible = false
	mek.visible = false
	dynamite.visible = false
	thread.visible = false
	dash.visible = false
	claw.visible = false
	hellfire.visible = false
	barrage.visible = false
	octoblast.visible = false
	grenade.visible = false
	
	slash.visible = false
	shadows.visible = false
	prowler.visible = false
	regenerate.visible = false
	transport.visible = false
