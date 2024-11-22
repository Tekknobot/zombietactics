extends Node2D

var missile_toggle_active: bool = false 
var landmine_toggle_active: bool = false

var mek_toggle_active: bool = false
var dynamite_toggle_active: bool = false

var secret_item_destroyed: bool = false
var secret_item_found: bool = false
var zombies_cleared: bool = false
var players_killed: bool = false

var current_map_index: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
