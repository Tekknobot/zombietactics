extends Node2D

@onready var global_manager = get_node("/root/MapManager/GlobalManager")  # Reference to the SpecialToggleNode
@onready var map_fader = get_node("/root/MapManager/MapFader")
@onready var hud_manager = get_node("/root/MapManager/HUDManager")



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if global_manager.secret_item_destroyed or global_manager.players_killed:
		hud_manager.visible = false
		map_fader.fade_in()
