extends Node2D

var missile_toggle_active: bool = false 
var landmine_toggle_active: bool = false
var mek_toggle_active: bool = false
var dynamite_toggle_active: bool = false
var thread_toggle_active: bool = false
var dash_toggle_active: bool = false
var claw_toggle_active: bool = false
var hellfire_toggle_active: bool = false
var barrage_toggle_active: bool = false
var octoblast_toggle_active: bool = false

var grenade_toggle_active: bool = false
var slash_toggle_active: bool = false
var shadows_toggle_active: bool = false
var prowler_toggle_active: bool = false
var regenerate_toggle_active: bool = false

var secret_item_destroyed: bool = false
var secret_item_found: bool = false
var zombies_cleared: bool = false
var players_killed: bool = false

var current_map_index: int = 1 # Level 

var gameover: bool = false
var map_cleared: bool = false

var active_zombie: Area2D = null

var zombie_queue: Array = []
var zombies_processed = 0  # Counter for zombies processed
var zombie_limit = 3

var secret_items_found: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func reset_global_manager():
	GlobalManager.missile_toggle_active = false 
	GlobalManager.landmine_toggle_active = false
	GlobalManager.mek_toggle_active = false
	GlobalManager.dynamite_toggle_active = false
	GlobalManager.thread_toggle_active = false
	GlobalManager.dash_toggle_active = false	
	GlobalManager.claw_toggle_active = false
	GlobalManager.hellfire_toggle_active = false
	GlobalManager.barrage_toggle_active = false
	GlobalManager.octoblast_toggle_active = false
	GlobalManager.grenade_toggle_active = false
	
	GlobalManager.slash_toggle_active = false
	GlobalManager.shadows_toggle_active = false
	GlobalManager.prowler_toggle_active = false
	GlobalManager.regenerate_toggle_active = false
	
	GlobalManager.secret_item_destroyed = false
	GlobalManager.secret_item_found = false
	GlobalManager.zombies_cleared = false
	GlobalManager.players_killed = false	
	
	# Reset has attacked
	var players = get_tree().get_nodes_in_group("player_units")
	for player in players:	
		player.has_attacked = false
