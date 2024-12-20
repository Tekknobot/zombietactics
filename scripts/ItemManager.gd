extends Node

@export var item_names: Array[String] = ["Secret Document", "A.I. Relic", "Mysterious Artifact"]
var item_structures: Array = []  # The structures containing the items

@onready var tilemap: TileMap = $TileMap  # Reference your TileMap node
@export var item_scene: PackedScene  # Assign the Item.tscn in the Inspector

var items_discovered: int = 0
var item_handled: Array = []  # Prevents multiple checks per item

@onready var mission_manager = get_node("/root/MapManager/MissionManager")

func _ready():
	await get_tree().create_timer(0.1).timeout
	assign_items_to_structures()

# Function to assign items to 3 random structures
func assign_items_to_structures():
	var structures = get_tree().get_nodes_in_group("structures")
	if structures.size() < 3:
		print("Not enough structures to assign items!")
		return

	# Shuffle the structures and select the first 3 unique ones
	structures.shuffle()
	item_structures = structures.slice(0, 3)
	item_handled = [false, false, false]  # Initialize handling flags for each item

	# Assign items to structures
	for i in range(item_structures.size()):
		var structure = item_structures[i]
		print("Item assigned:", item_names[i], "to structure:", structure.name)
		structure.set_meta("contains_item", true)  # Mark the structure
		structure.has_item = true

		# Optional highlight
		structure.modulate = Color(0.5, 0.5, 0.5)

# Function to check if a player is adjacent to any item structure
func check_for_item_discovery(player: Area2D):
	for i in range(item_structures.size()):
		var structure = item_structures[i]
		if not structure or item_handled[i]:  # Skip handled items
			continue
		
		var tilemap: TileMap = get_node("/root/MapManager/TileMap")
		var player_tile_pos = tilemap.local_to_map(player.global_position)
		var structure_tile_pos = tilemap.local_to_map(structure.global_position)

		# Check adjacency
		if is_adjacent(player_tile_pos, structure_tile_pos):
			print("Player discovered the item:", item_names[i])
			on_item_discovered(player, structure, i)

# Function to handle item discovery
func on_item_discovered(player: Area2D, structure: Node, item_index: int):
	if item_handled[item_index]:  # Ensure the item is not handled twice
		return

	item_handled[item_index] = true
	items_discovered += 1

	# Instantiate the item scene
	if item_scene:
		var item_instance = item_scene.instantiate()
		add_child(item_instance)
		item_instance.position = structure.global_position + Vector2(0, -40)  # Adjust position as needed
		print("Item added to scene:", item_names[item_index])

		# Adjust item position based on the structure type
		match structure.structure_type:
			"Building":
				item_instance.position = structure.global_position + Vector2(0, -44)
			"Tower":
				item_instance.position = structure.global_position + Vector2(0, -58)
			"Stadium":
				item_instance.position = structure.global_position + Vector2(0, -32)
			"District":
				item_instance.position = structure.global_position + Vector2(0, -48)

	# Perform your item discovery logic
	structure.set_meta("contains_item", false)
	GlobalManager.secret_items_found += 1  # Increment global item count
	print("Total items discovered:", items_discovered)

	var zombies = get_tree().get_nodes_in_group("zombies")
	# Optional: Check if all items are discovered
	if items_discovered >= 3 and zombies.size() <= 0:
		print("All items discovered and map cleared! Congratulations!")
		mission_manager.check_mission_manager()

# Helper function to check adjacency between two tiles
func is_adjacent(tile_a: Vector2i, tile_b: Vector2i) -> bool:
	var delta = tile_a - tile_b
	return abs(delta.x) + abs(delta.y) == 1  # Manhattan distance = 1 for adjacency

func check_item_destroyed():
	# Loop through all item structures to check if any is destroyed
	for i in range(item_structures.size()):
		var structure = item_structures[i]
		if not structure or item_handled[i]:  # Skip handled or invalid structures
			continue

		# Ensure the structure has an AnimatedSprite2D node
		if structure.has_node("AnimatedSprite2D"):
			var animated_sprite = structure.get_node("AnimatedSprite2D") as AnimatedSprite2D

			# Check if the structure's animation is "demolished"
			if animated_sprite.animation == "demolished":
				on_item_destroyed(structure, i)

				# Mark the item as handled and set global flags
				GlobalManager.secret_item_destroyed = true
				item_handled[i] = true  # Prevent further checks for this item
				print("Secret Item Destroyed: GAME OVER")

func on_item_destroyed(structure: Node, item_index: int):
	# Instantiate the item scene
	if item_scene:
		var item_instance = item_scene.instantiate()
		add_child(item_instance)
		item_instance.position = structure.global_position + Vector2(0, -40)  # Adjust position as needed
		print("Destroyed item instantiated:", item_names[item_index])

	# Print feedback and update global state
	print("Item destroyed:", item_names[item_index], "at structure:", structure.name)
	GlobalManager.secret_items_found -= 1  # Optionally decrement items found
