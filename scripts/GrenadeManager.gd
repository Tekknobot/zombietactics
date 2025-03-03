extends Node2D

signal player_action_completed

@export var Map: TileMap

var line2D_scene = preload("res://assets/scenes/prefab/Line_2d.tscn")
var explosion_scene = preload("res://assets/scenes/vfx/explosion.tscn")

var onTrajectory = false  # Indicates if missile is currently on a trajectory
var right_click_position: Vector2
var target_position: Vector2

var genade_launched : int = 0

var hud: Control

var player_to_act
var player_temp = null

# Soldier's current tile position
var tile_pos: Vector2i
var coord: Vector2
var layer: int

@onready var turn_manager = get_node("/root/MapManager/TurnManager")  # Reference to the SpecialToggleNode
var missiles_canceled = false

# Declare necessary variables for attack
@export var grenade_scene: PackedScene  # Packed scene for the projectile

@onready var mission_manager = get_node("/root/MapManager/MissionManager")  # Reference to the SpecialToggleNode
@onready var item_manager = get_node("/root/MapManager/ItemManager")  # Reference to the SpecialToggleNode

var explosions_triggered: int = 0

# Declare a flag to track if XP has been added
var xp_added: bool = false

var is_mouse_over_gui_flag = false

signal turn_completed
var candidate_size
	
# Ensure input is processed by this node and its parent
func _ready() -> void:
	Map = get_node("/root/MapManager/TileMap")
	#debug_ui_rectangles()
	
	get_parent().connect("turn_completed", Callable(self, "_on_turn_completed"))

# Called every frame to process input and update hover tile position
func _process(delta: float) -> void:
	is_mouse_over_gui()
	
func _input(event: InputEvent) -> void:
	# Only respond to clicks if the special toggle is active
	if not GlobalManager.grenade_toggle_active:
		#print("Special toggle is off, ignoring mouse clicks.")
		return

	if genade_launched >= 1:
		return

	# Handle mouse button events (right and left-click)
	if event is InputEventMouseButton:
		# Block gameplay input if the mouse is over GUI
		if is_mouse_over_gui():
			print("Input blocked by GUI.")
			return  # Prevent further input handling

		# Right-click to set the target position
		if event.button_index == MOUSE_BUTTON_RIGHT and not onTrajectory:
			if event.pressed:
				# Set the position of the right-click as the target position
				right_click_position = get_global_mouse_position()
				print("Right-click position set to:", right_click_position)

		# Left-click to launch missile trajectory (only if right-click has been used to set target)
		if event.button_index == MOUSE_BUTTON_LEFT and not onTrajectory and genade_launched < 1:
			if event.pressed:								
				explosions_triggered = 0

				# Reference the TileMap node
				var tilemap: TileMap = get_node("/root/MapManager/TileMap")

				# Get the boundaries of the map's used rectangle
				var map_size = tilemap.get_used_rect()  # Rect2: position and size of the used tiles
				var map_origin_x = map_size.position.x  # Starting x-coordinate of the used rectangle
				var map_origin_y = map_size.position.y  # Starting y-coordinate of the used rectangle
				var map_width = map_size.size.x         # Width of the map in tiles
				var map_height = map_size.size.y        # Height of the map in tiles

				var mouse_position = get_global_mouse_position() 
				mouse_position.y += 8
				var mouse_local = Map.local_to_map(mouse_position)

				# Check if the mouse is outside the bounds of the used rectangle
				if mouse_local.x < map_origin_x or mouse_local.x >= map_origin_x + map_width or \
				   mouse_local.y < map_origin_y or mouse_local.y >= map_origin_y + map_height:
					return  # Exit the function if the mouse is outside the map

				# Check if mouse_local matches the local_to_map position of any special tile
				var position_matches_tile = false

				for special_tile in get_parent().special_tiles:
					# Assuming each special_tile has a position in world coordinates
					if special_tile is Node2D:
						var tile_map_position = tilemap.local_to_map(special_tile.position)  # Convert to map coordinates
						if mouse_local == tile_map_position:
							position_matches_tile = true
							break
							
									
				# Get the current position in tile coordinates
				var current_position = mouse_local

				# Get the current facing direction of the parent (1 for right, -1 for left)
				var current_facing = 1 if get_parent().scale.x > 0 else -1

				if position_matches_tile and is_unit_present(mouse_local):	
					# Determine sprite flip based on target_position relative to the parent
					if get_global_mouse_position().x > global_position.x and current_facing == 1:
						get_parent().scale.x = -abs(get_parent().scale.x)  # Flip to face left
					elif get_global_mouse_position().x < global_position.x and current_facing == -1:
						get_parent().scale.x = abs(get_parent().scale.x)  # Flip to face right
					
					get_parent().clear_special_tiles()	
					
					if get_parent().is_in_group("untiAI"):
						pass
					else:						
						await find_closest_zombies(get_global_mouse_position())  # Find 2 closest zombies

					# Hide special buttons and trigger zombie actions
					var hud_manager = get_parent().get_parent().get_parent().get_node("HUDManager")
					hud_manager.hide_special_buttons()
					clear_zombie_tiles()

# Check if there is a unit on the tile
func is_unit_present(tile_pos: Vector2i) -> bool:
	var tilemap: TileMap = get_node("/root/MapManager/TileMap")
	var all_units = get_tree().get_nodes_in_group("zombies") + get_tree().get_nodes_in_group("unitAI")
	for unit in all_units:
		var unit_tile_pos = tilemap.local_to_map(unit.global_position)
		if tile_pos == unit_tile_pos:
			return true
	return false

func find_closest_zombies(target_position: Vector2):
	# Get all zombie positions
	var zombies = get_tree().get_nodes_in_group("zombies") + get_tree().get_nodes_in_group("unitAI")  # Custom function to fetch all zombies on the map
	var zombie_positions = []
	for zombie in zombies:
		zombie_positions.append(zombie.global_position)

	# Sort zombies by distance from the trigger location
	zombie_positions.sort_custom(func(a, b):
		return target_position.distance_to(a) < target_position.distance_to(b))

	# Select the 7 closest zombies
	var closest_zombies = zombie_positions.slice(0, min(8, zombie_positions.size()))

	# Trigger trajectories towards the closest zombies sequentially
	for zombie_pos in closest_zombies:
		get_parent().get_child(0).play("attack")		
		await get_tree().create_timer(0.1).timeout
		start_trajectory(zombie_pos, get_parent().position)

func find_closest_zombies_for_ai(target_position: Vector2) -> void:
	# Get all enemies from "zombies" and "player_units"
	var all_enemies = get_tree().get_nodes_in_group("zombies") + get_tree().get_nodes_in_group("player_units")
	var candidates = []
	# Filter out any enemies that are in the "unitAI" group.
	for enemy in all_enemies:
		if not enemy.is_in_group("unitAI"):
			candidates.append(enemy)
	
	candidate_size = candidates.size()
	
	# If no candidate is found, do nothing.
	if candidates.size() == 0:
		print("No enemy available for grenade special attack.")
		return

	# Sort the candidates by their Euclidean distance from the target_position.
	candidates.sort_custom(func(a, b):
		return target_position.distance_to(a.global_position) < target_position.distance_to(b.global_position)
	)

	# Select the 7 closest candidates.
	var closest_candidates = candidates.slice(0, min(7, candidates.size()))

	# Trigger trajectories towards the closest candidates sequentially.
	for enemy in closest_candidates:
		get_parent().get_child(0).play("attack")
		await get_tree().create_timer(0.1).timeout
		start_trajectory(enemy.global_position, get_parent().position)

	get_parent().clear_special_tiles()
		
func _compare_distance_to_target(zombie_a: Node2D, zombie_b: Node2D, target_position: Vector2) -> bool:
	return zombie_a.position.distance_to(target_position) < zombie_b.position.distance_to(target_position)


func launch_trajectory_to_target(target_position: Vector2) -> void:
	var start_position = player_to_act.position
	var trajectory_instance = line2D_scene.instantiate()
	add_child(trajectory_instance)
	trajectory_instance.add_to_group("trajectories")

	var control1 = Vector2(start_position.x, start_position.y - 200)  # Adjust for arc
	var control2 = Vector2(target_position.x, target_position.y - 200)
	var points = generate_bezier_curve(start_position, control1, control2, target_position)

	# Visualize the trajectory
	for point in points:
		trajectory_instance.add_point(point)

	# Instantiate and animate the grenade
	if grenade_scene:
		var grenade_inst = grenade_scene.instantiate()
		add_child(grenade_inst)
		grenade_inst.global_position = start_position
		animate_grenade_trajectory(grenade_inst, points)

func debug_ui_rectangles():
	var hud_controls = get_tree().get_nodes_in_group("hud_controls")
	for control in hud_controls:
		if control is Button:
			var rect = control.get_global_rect()
			print("Button:", control.name, "Global Rect:", rect)

			# Create a ColorRect to represent the button's rectangle
			var debug_rect = ColorRect.new()
			debug_rect.size = rect.size  # Set the size of the rectangle
			debug_rect.position = rect.position  # Set the position of the rectangle
			debug_rect.color = Color(1, 0, 0, 1)  # Solid red

			# Add the debug rectangle to the CanvasLayer
			get_parent().get_node("HUDManager").add_child(debug_rect)  # Adjust as necessary

						
# Function to trigger the zombies' actions: find and chase player
func clear_zombie_tiles():
	# Get all zombies in the "zombie" group
	var zombies = get_tree().get_nodes_in_group("zombies")
	
	# Iterate over each zombie in the group
	for zombie in zombies:
		zombie.clear_movement_tiles()

func launch_grenade(start: Vector2, points: Array):
	if grenade_scene and genade_launched == 0:  # Ensure only one grenade can be launched
		var grenade_inst = grenade_scene.instantiate()
		add_child(grenade_inst)
		grenade_inst.global_position = start
		grenade_inst.attacker = get_parent()
		grenade_inst.target_position = points[points.size() - 1]
		print("Grenade instance created and placed at start position.")

		# Animate the grenade along the trajectory points
		await animate_grenade_trajectory(grenade_inst, points)

		grenade_inst.queue_free()
		genade_launched += 1

						
# Function to start the missile trajectory and visualize with Line2D
func start_trajectory(start: Vector2, target: Vector2) -> void:
	onTrajectory = true
	print("Starting trajectory to target:", target)

	# Create a Line2D instance for visualizing the missile's trajectory
	var line_inst = line2D_scene.instantiate()
	add_child(line_inst)
	line_inst.visible = false

	# Destroy any line renderers
	var line_2D = get_tree().get_nodes_in_group("Line2D")
	for line in line_2D:
		line.queue_free()
		
	print("Line2D instance hidden.")

	# Define control points for a cubic Bézier curve (used for missile path simulation)
	var control1 = Vector2(start.x, start.y - 200)  # Slight upward control point
	var control2 = Vector2(target.x, target.y - 200)  # Same for target
	var end = target

	print("Bezier control points: start =", start, "control1 =", control1, "control2 =", control2, "end =", end)

	# Generate the points from the Bézier curve using the cubic formula
	var points = generate_bezier_curve(end, control2, control1, start)

	# Add the points to the Line2D for trajectory visualization
	for point in points:
		line_inst.add_point(point)

	# Instantiate and animate the grenade projectile
	if grenade_scene:
		var grenade_inst = grenade_scene.instantiate()
		add_child(grenade_inst)
		grenade_inst.global_position = start
		grenade_inst.attacker = get_parent()
		grenade_inst.target_position = points[points.size() - 1]
		print("Grenade instance created and placed at start position.")

		# Animate the grenade along the trajectory points
		await animate_grenade_trajectory(grenade_inst, points)
		
		# Cleanup after animation
		grenade_inst.queue_free()

	onTrajectory = false
	
	print("Trajectory animation completed and cleaned up.")

# Function to animate the grenade projectile along the Bézier curve points
func animate_grenade_trajectory(grenade_inst: Node2D, points: Array) -> void:
	var total_time = 0.01  # Total time to move from start to end (in seconds)
	var steps = points.size()
	var step_time = total_time / steps  # Time per step to move along the path
	
	var elapsed_time = 0.0  # Track the elapsed time

	for i in range(steps - 1):
		var start_point = points[i]
		var end_point = points[i + 1]
		
		var tilemap: TileMap = get_node("/root/MapManager/TileMap")
		var camera: Camera2D = get_node("/root/MapManager/Camera2D")
			
		await camera.focus_on_trajectory(points[i])
					
		while elapsed_time < step_time:
			# Calculate the time ratio
			var t = elapsed_time / step_time
			# Lerp between start and end point based on the ratio
			grenade_inst.global_position = start_point.lerp(end_point, t)
			elapsed_time += get_process_delta_time()
			
			await get_tree().create_timer(0.02).timeout  # Wait until the next frame (await instead of yield)
			
		# Reset elapsed time for the next segment
		elapsed_time = 0.0

	# Ensure grenade reaches the final point exactly
	grenade_inst.global_position = points[points.size() - 1]
	
	await _trigger_explosion(points[points.size() - 1])
	var hud_manager = get_parent().get_parent().get_parent().get_node("HUDManager")  # Adjust the path if necessary
					
	# Access the 'special' button within HUDManager
	var grenade_button = hud_manager.get_node("HUD/Grenade")
	grenade_button.button_pressed = true	
	GlobalManager.grenade_toggle_active = false
	
	explosions_triggered += 1
	
	if explosions_triggered == 1:
		add_xp()
		get_parent().has_attacked = true
		get_parent().has_moved = true
		get_parent().check_end_turn_conditions()

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
	get_parent().get_parent().get_parent().get_parent().add_child(explosion_instance)
	explosion_instance.position = last_point
	print("Explosion instance added to scene at:", last_point)

	# Explosion radius (adjust this as needed)
	var explosion_radius = 1.0
			
	# Check for PlayerUnit within explosion radius
	for player in get_tree().get_nodes_in_group("player_units"):
		if player.position.distance_to(last_point) <= explosion_radius:	
			player.flash_damage()
			player.apply_damage(player.attack_damage)
				
			var hud_manager = get_parent().get_parent().get_parent().get_node("HUDManager") 
			hud_manager.update_hud(player)	

	# Check for ZombieUnit within explosion radius
	for zombie in get_tree().get_nodes_in_group("zombies"):
		if zombie.position.distance_to(last_point) <= explosion_radius:			
			zombie.flash_damage()
			# Check for PlayerUnit within explosion radius
			for player in get_tree().get_nodes_in_group("player_units"):
				if player.player_name == "Logan. Raines":			
					zombie.apply_damage(player.attack_damage)	
						
			print("Zombie Unit removed from explosion")
			
			var hud_manager = get_parent().get_parent().get_parent().get_node("HUDManager") 
			hud_manager.update_hud_zombie(zombie)

	# Check for Structures within explosion radius
	for structure in get_tree().get_nodes_in_group("structures"):
		if structure.position.distance_to(last_point) <= explosion_radius:
			structure.get_child(0).play("demolished")  # Play "collapse" animation if applicable
			
			
func add_xp():
	# Add XP
	# Access the HUDManager (move up the tree from PlayerUnit -> UnitSpawn -> parent to HUDManager)
	var hud_manager = get_parent().get_parent().get_parent().get_node("HUDManager")  # Adjust the path if necessary
	
	# Access the 'special' button within HUDManager
	var mek_button = hud_manager.get_node("HUD/Mek")
	GlobalManager.mek_toggle_active = false  # Deactivate the special toggle
	mek_button.button_pressed = false

	# Get all nodes in the 'hovertile' group
	var hover_tiles = get_tree().get_nodes_in_group("hovertile")

	# Iterate through the list and find the HoverTile node
	for hover_tile in hover_tiles:
		if hover_tile.name == "HoverTile":
			# Check if 'last_selected_player' exists and has 'current_xp' property
			if hover_tile.selected_player or hover_tile.selected_structure:
				hover_tile.selected_player.current_xp += 25
				
				# Update the HUD to reflect new stats
				hud_manager.update_hud(hover_tile.selected_player)	
				print("Added 25 XP to", hover_tile.selected_player, "new XP:", hover_tile.selected_player.current_xp)		

				# Optional: Check for level up, if applicable
				if hover_tile.selected_player.current_xp >= hover_tile.selected_player.xp_for_next_level:
					hover_tile.selected_player.level_up()	
					
					# Update the HUD to reflect new stats
					hud_manager.update_hud(hover_tile.selected_player)								
			else:
				print("last_selected_player does not exist.")

func is_mouse_over_gui() -> bool:
	# Get global mouse position
	var mouse_pos = get_viewport().get_mouse_position()

	# Get all nodes in the "hud_controls" group
	var hud_controls = get_tree().get_nodes_in_group("portrait_controls") + get_tree().get_nodes_in_group("hud_controls")
	for control in hud_controls:
		if control is TextureRect or Button and control.is_visible_in_tree():
			# Use global rect to check if mouse is over the button
			var rect = control.get_global_rect()
			#print("Checking button:", control.name, "Rect:", rect, "Mouse Pos:", mouse_pos)
			if rect.has_point(mouse_pos):
				#print("Mouse is over button:", control.name, "Rect:", rect, "Mouse Pos:", mouse_pos)
				return true
	#print("Mouse is NOT over any button.")
	return false

# Helper function to find the closest target (zombie or player unit) that isn't in the "unitAI" group.
func find_closest_target() -> Node:
	var candidates = get_tree().get_nodes_in_group("zombies") + get_tree().get_nodes_in_group("player_units")
	var target = null
	var min_distance = INF
	var parent_pos = get_parent().position  # Assume parent's position is used for measuring distance
	for candidate in candidates:
		if candidate.is_in_group("unitAI"):
			continue
		var d = parent_pos.distance_to(candidate.position)
		if d < min_distance:
			min_distance = d
			target = candidate
	return target

func execute_logan_raines_ai_turn() -> void:
	# Randomly decide which branch to execute: 0 = standard AI turn, 1 = special missile attack.
	var choice = randi() % 2
	
	if get_parent().has_moved:
		choice = 1
			
	if choice == 0:
		print("Random choice: Executing standard AI turn for Logan Raines.")
		await get_parent().execute_ai_turn()
	else:
		# If standard AI hasn't resulted in an attack…
		if not get_parent().has_attacked:
			print("Random choice: Executing Logan Raines special missile attack.")
			# Get the missile manager by its node path.
			var missile_manager = get_node("/root/MapManager/MissileManager")
			
			# Focus the camera on the current position.
			var tilemap: TileMap = get_node("/root/MapManager/TileMap")
			var camera: Camera2D = get_node("/root/MapManager/Camera2D")
			if camera:
				camera.focus_on_position(tilemap.map_to_local(self.tile_pos))
			
			# Find the closest target (zombie or player unit not in unitAI)
			var target = find_closest_target()
			if target:
				# Execute the special missile attack via the missile manager.
				await find_closest_zombies_for_ai(target.position)
			else:
				print("No valid target found for Logan Raines special attack.")
				get_parent().execute_ai_turn()

func _on_turn_completed():
	print("Turn has completed!")
	emit_signal("turn_completed")
	
