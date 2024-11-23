extends Node2D

@onready var map_fader = get_node("/root/MapManager/MapFader")
@onready var hud_manager = get_node("/root/MapManager/HUDManager")

@onready var audio_player = $AudioStreamPlayer2D
@export var gameover_audio = preload("res://audio/SFX/fast-game-over.wav")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func check_mission_manager():
	if GlobalManager.secret_item_destroyed or GlobalManager.players_killed:
		GlobalManager.gameover = true
		audio_player.stream = gameover_audio
		audio_player.play()
		
		hud_manager.visible = false
		map_fader.fade_in()
		
	if GlobalManager.zombies_cleared and GlobalManager.secret_item_found:		
		GlobalManager.map_cleared = true
		hud_manager.visible = false
		map_fader.fade_in()		
		
		
