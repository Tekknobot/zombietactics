extends Node

@export var item_name: String = "Secret Document"  # The name of the item to be found
var item_structure: Node = null  # The structure containing the item

@onready var tilemap: TileMap = $TileMap  # Reference your TileMap node

@export var item_scene: PackedScene  # Assign the Item.tscn in the Inspector

var item_discovered: bool = false
var item_handled: bool = false  # Prevents multiple checks once the outcome is decided

func _ready():
	await get_tree().create_timer(1).timeout
	assign_item_to_structure()

func check_item_destroyed():
	# Skip if the item has already been handled
	if item_handled:
		return
	
	# Wait for 1 second before checking (e.g., to allow animations to play)
	await get_tree().create_timer(1).timeout

	var animated_sprite = item_structure.get_node("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite.animation == "demolished":
		GlobalManager.secret_item_destroyed = true
		item_handled = true  # Prevent further checks
		print("Secret Item Destroyed: GAME OVER")

# Function to assign the item to a random structure
func assign_item_to_structure():
	# Get all structures in the group
	var structures = get_tree().get_nodes_in_group("structures")
	if structures.size() == 0:
		print("No structures found in the group!")
		return

	# Select a random structure
	item_structure = structures[randi() % structures.size()]
	print("Item assigned to structure:", item_structure.name)
	
	item_structure.modulate = Color(0.5, 0.5, 0.5)

	# Optionally, you can mark the structure visually or with metadata
	item_structure.set_meta("contains_item", true)  # Tag the structure
	# Example: Highlight the structure for debugging (remove in final version)
	if item_structure.has_method("highlight"):
		item_structure.highlight(true)

# Function to check if a player is adjacent to the structure containing the item
func check_for_item_discovery(player: Area2D):
	if not item_structure:
		print("No item structure assigned!")
		return

	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	
	# Get the player's and structure's tile positions
	var player_tile_pos = tilemap.local_to_map(player.global_position)
	var structure_tile_pos = tilemap.local_to_map(item_structure.global_position)

	# Check if the player is adjacent to the structure
	if is_adjacent(player_tile_pos, structure_tile_pos):
		print("Player discovered the item:", item_name)

		# Trigger the discovery event (e.g., collect the item, update UI)
		on_item_discovered(player, item_structure)

# Helper function to check adjacency between two tiles
func is_adjacent(tile_a: Vector2i, tile_b: Vector2i) -> bool:
	var delta = tile_a - tile_b
	return abs(delta.x) + abs(delta.y) == 1  # Manhattan distance = 1 for adjacency

func on_item_discovered(player: Area2D, structure: Node):
	# Only allow item discovery if it has not been discovered yet
	if item_discovered:
		return  # Exit early if the item is already discovered

	# Print information about the item discovery
	print("Item found by player:", player.player_name)
	item_discovered = true  # Set the flag to true indicating item was discovered
	
	# Update global manager to reflect item discovery
	GlobalManager.secret_item_found = true
	
	# Instantiate the item scene
	if item_scene:
		var item_instance = item_scene.instantiate()
		add_child(item_instance)  # Add to the current scene
		
		# Adjust item position based on the structure type
		match structure.structure_type:
			"Building":
				item_instance.position = structure.global_position + Vector2(0, -40)
			"Tower":
				item_instance.position = structure.global_position + Vector2(0, -58)
			"Stadium":
				item_instance.position = structure.global_position + Vector2(0, -32)
			"District":
				item_instance.position = structure.global_position + Vector2(0, -48)

	# Perform your item discovery logic
	structure.set_meta("contains_item", false)  # Mark the item as collected
	
	# Optional: Remove the highlight (if any)
	if structure.has_method("highlight"):
		structure.highlight(false)
