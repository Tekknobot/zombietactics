extends Node2D

signal player_action_completed

@export var Map: TileMap

var line2D_scene = preload("res://assets/scenes/prefab/Line_2d.tscn")
var explosion_scene = preload("res://assets/scenes/vfx/explosion.tscn")

var onTrajectory = false  # Indicates if missile is currently on a trajectory
var right_click_position: Vector2
var target_position: Vector2

var missiles_launched : int = 0

@onready var global_manager = get_node("/root/MapManager/GlobalManager")  # Reference to the SpecialToggleNode

var hud: Control

# Ensure input is processed by this node and its parent
func _ready() -> void:
	Map = get_node("/root/MapManager/TileMap")
	
# Handling input events (mouse clicks)
func _input(event: InputEvent) -> void:
	# Only respond to clicks if the special toggle is active
	if not global_manager.special_toggle_active:
		#print("Special toggle is off, ignoring mouse clicks.")
		return
	
	if missiles_launched >= 1:
		return
			
	# Handle mouse button events (right and left-click)
	if event is InputEventMouseButton:
		# Right-click to set the target position
		if event.button_index == MOUSE_BUTTON_RIGHT and not onTrajectory:
			if event.pressed:
				# Set the position of the right-click as the target position
				right_click_position = get_global_mouse_position()
				print("Right-click position set to:", right_click_position)

		# Left-click to launch missile trajectory (only if right-click has been used to set target)
		if event.button_index == MOUSE_BUTTON_LEFT and not onTrajectory:
			if event.pressed and right_click_position != Vector2.ZERO:
				print("Left-click detected, initiating trajectory.")
				# Get mouse position for trajectory path and adjust for map conversion
				var mouse_position = get_global_mouse_position()
				mouse_position.y += 8  # Adjust for map-specific offsets if needed
				var mouse_local = Map.local_to_map(mouse_position)
				print("Mouse position adjusted to:", mouse_position, "converted to map coordinates:", mouse_local)

				# Create a new trajectory instance
				var trajectory_instance = self.duplicate()
				self.get_parent().add_child(trajectory_instance)
				trajectory_instance.add_to_group("trajectories")
				print("Trajectory instance created and added to the scene.")

				# Set the target for the missile
				target_position = right_click_position
				
				# Convert the global mouse position to the local position relative to the TileMap
				var map_mouse_position = Map.local_to_map(mouse_position)  # Convert to TileMap local coordinates
				var map_mouse_tile_pos = Map.map_to_local(map_mouse_position) + Vector2(0,0) / 2 # Convert to tile coordinates

				# Convert the target position (assumed to be global) to local
				var map_target_position = Map.local_to_map(target_position)  # Convert target to TileMap local
				var map_target_tile_pos = Map.map_to_local(map_target_position)  # Convert to tile coordinates
			
				missiles_launched += 1
				trajectory_instance.start_trajectory(map_mouse_tile_pos, map_target_tile_pos)
				
				await get_tree().create_timer(3).timeout
				on_player_action_completed()	
				
# Function to start the missile trajectory and visualize with Line2D
func start_trajectory(start: Vector2, target: Vector2):
	onTrajectory = true
	print("Starting trajectory to target:", target)

	# Create a Line2D instance for visualizing the missile's trajectory
	var line_inst = line2D_scene.instantiate()
	add_child(line_inst)
	print("Line2D instance created for trajectory visualization.")

	# Define control points for a cubic Bézier curve (used for missile path simulation)
	var control1 = Vector2(start.x, start.y - 100)  # Slight upward control point
	var control2 = Vector2(target.x, target.y - 100)  # Same for target
	var end = target

	print("Bezier control points: start =", start, "control1 =", control1, "control2 =", control2, "end =", end)

	# Generate the points from the Bézier curve using the cubic formula
	var points = generate_bezier_curve(end, control2, control1, start)

	# Add the points to the Line2D for trajectory visualization
	for point in points:
		line_inst.add_point(point)

	# Animate the missile trajectory by moving through the Bézier points
	await animate_trajectory(line_inst, points)
	
	# Cleanup: Remove Line2D after animation
	line_inst.queue_free()
	onTrajectory = false
	
	missiles_launched = 0
	print("Trajectory animation completed and cleaned up.")

# Call this function after every player action
func on_player_action_completed():
	emit_signal("player_action_completed")

# Function to generate Bézier curve points
func generate_bezier_curve(start: Vector2, control1: Vector2, control2: Vector2, end: Vector2, steps: int = 100) -> Array:
	var points = []
	for i in range(steps):
		var t = i / float(steps - 1)  # t goes from 0 to 1
		var p = (1 - t) * (1 - t) * (1 - t) * start + 3 * (1 - t) * (1 - t) * t * control1 + 3 * (1 - t) * t * t * control2 + t * t * t * end
		points.append(p)
	return points

# Function to animate the missile's movement along the Bézier curve points
func animate_trajectory(line_inst: Line2D, points: Array):
	print("Animating missile trajectory with", points.size(), "points.")
	for i in range(points.size()):
		line_inst.clear_points()  # Clear existing points to update Line2D path
		for j in range(i):
			line_inst.add_point(points[j])

		# Check if missile has reached the target and trigger explosion
		if i == points.size() - 1:
			print("Target reached at:", points[points.size() - 1])
			_trigger_explosion(points[points.size() - 1])
			break

		# Simulate animation speed by waiting a short time before updating trajectory
		await get_tree().create_timer(0.01).timeout
	
	print("Trajectory animation function completed.")

# Trigger explosion at the target position after the missile reaches it
func _trigger_explosion(last_point: Vector2):
	print("Explosion triggered at position:", last_point)
	
	# Instantiate the explosion effect at the target's position
	var explosion_instance = explosion_scene.instantiate()
	get_parent().add_child(explosion_instance)
	explosion_instance.position = last_point
	print("Explosion instance added to scene at:", last_point)

	# Explosion radius (adjust this as needed)
	var explosion_radius = 1.0

	# Check for PlayerUnit within explosion radius
	for player in get_tree().get_nodes_in_group("player_units"):
		if player.position.distance_to(last_point) <= explosion_radius:
			player.get_child(0).play("death")
			await get_tree().create_timer(1.5).timeout
			player.visible = false  # Hide the player unit
			player.remove_from_group("player_units")  # Remove from the group
			print("Player Unit removed from explosion")

	# Check for ZombieUnit within explosion radius
	for zombie in get_tree().get_nodes_in_group("zombies"):
		if zombie.position.distance_to(last_point) <= explosion_radius:
			zombie.get_child(0).play("death")
			await get_tree().create_timer(1.5).timeout
			zombie.visible = false  # Hide the zombie unit
			zombie.remove_from_group("zombies")  # Remove from the group
			print("Zombie Unit removed from explosion")

	# Check for Structures within explosion radius
	for structure in get_tree().get_nodes_in_group("structures"):
		if structure.position.distance_to(last_point) <= explosion_radius:
			structure.get_child(0).play("demolished")  # Play "collapse" animation if applicable
			
	# Access the HUDManager (move up the tree from PlayerUnit -> UnitSpawn -> parent to HUDManager)
	var hud_manager = get_parent().get_node("HUDManager")  # Adjust the path if necessary
	
	# Access the 'special' button within HUDManager
	var special_button = hud_manager.get_node("HUD/Special")
	global_manager.special_toggle_active = false  # Deactivate the special toggle

	# Add XP
	# Get all nodes in the 'hovertile' group
	var hover_tiles = get_tree().get_nodes_in_group("hovertile")

	# Iterate through the list and find the HoverTile node
	for hover_tile in hover_tiles:
		if hover_tile.name == "HoverTile":
			# Check if 'last_selected_player' exists and has 'current_xp' property
			if hover_tile.selected_player:
				hover_tile.selected_player.current_xp += 25
				# Update the HUD to reflect new stats
				hud_manager.update_hud(hover_tile.selected_player)	
				print("Added 25 XP to", hover_tile.selected_player, "new XP:", hover_tile.selected_player.current_xp)		
			else:
				print("last_selected_player does not exist.")
