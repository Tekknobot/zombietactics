extends Node2D

signal player_action_completed

@export var Map: TileMap

var line2D_scene = preload("res://assets/scenes/prefab/Line_2d.tscn")
var explosion_scene = preload("res://assets/scenes/vfx/explosion.tscn")

var onTrajectory = false  # Indicates if missile is currently on a trajectory
var right_click_position: Vector2
var target_position: Vector2

var dynamite_launched : int = 0

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
@export var dynamite_scene: PackedScene  # Packed scene for the projectile

@onready var mission_manager = get_node("/root/MapManager/MissionManager")  # Reference to the SpecialToggleNode
@onready var item_manager = get_node("/root/MapManager/ItemManager")  # Reference to the SpecialToggleNode


# Declare a flag to track if XP has been added
var xp_added: bool = false

var is_mouse_over_gui_flag = false

# Ensure input is processed by this node and its parent
func _ready() -> void:
	Map = get_node("/root/MapManager/TileMap")
	#debug_ui_rectangles()

# Called every frame to process input and update hover tile position
func _process(delta: float) -> void:
	is_mouse_over_gui()
	
func _input(event: InputEvent) -> void:			
	# Only respond to clicks if the special toggle is active
	if not GlobalManager.dynamite_toggle_active:
		print("Special toggle is off, ignoring mouse clicks.")
		return
		
	if dynamite_launched >= 1:
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
		if event.button_index == MOUSE_BUTTON_LEFT and not onTrajectory and dynamite_launched < 3:
			if event.pressed:													
				# Get all nodes in the 'hovertile' group
				var hover_tiles = get_tree().get_nodes_in_group("hovertile")

				# Iterate through the list and find the HoverTile node
				for hover_tile in hover_tiles:
					if hover_tile.name == "HoverTile":
						# Check if 'selected_player' exists on the hover_tile
						if hover_tile.selected_player:
							# Access the selected player's position and assign it to 'tile_pos'
							var selected_player = hover_tile.selected_player
							var selected_player_position = selected_player.position  # Assuming position is a Vector2
							
							player_to_act = selected_player
							
							# Convert the world position of the player to the tile's position
							var tilemap: TileMap = get_node("/root/MapManager/TileMap")
							tile_pos = tilemap.local_to_map(selected_player_position)  # Convert to map coordinates (tile position)
							
							print("Selected player's tile position:", tile_pos)  # Optional: Debug log to confirm the position
				
				print("Left-click detected, initiating trajectory.")
				
				# Ensure the selected player has not already attacked
				if player_to_act.has_attacked:
					print("Player has already attacked. Trajectory will not be started.")										
					return  # Exit the function without starting the trajectory
				
				# Get mouse position for trajectory path and adjust for map conversion
				var mouse_position = get_global_mouse_position()
				mouse_position.y += 8  # Adjust for map-specific offsets if needed
				var mouse_local = Map.local_to_map(mouse_position)
				print("Mouse position adjusted to:", mouse_position, "converted to map coordinates:", mouse_local)

				# Ensure the mouse position is within map boundaries
				var tilemap: TileMap = get_node("/root/MapManager/TileMap")
				var map_size = tilemap.get_used_rect()  # Get the map's used rectangle
				var map_width = map_size.size.x
				var map_height = map_size.size.y
				
				# Check if the mouse position is within map bounds
				if mouse_local.x >= 0 and mouse_local.x < map_width and mouse_local.y >= 0 and mouse_local.y < map_height:
					# The mouse position is within the map boundaries
					# Check if mouse_local matches the local_to_map position of any special tile
					var position_matches_tile = false

					for special_tile in player_to_act.special_tiles:
						# Assuming each special_tile has a position in world coordinates
						if special_tile is Node2D:
							var tile_map_position = tilemap.local_to_map(special_tile.position)  # Convert to map coordinates
							if mouse_local == tile_map_position:
								position_matches_tile = true
								break
								
					if position_matches_tile:								
						# Create a new trajectory instance
						var trajectory_instance = self.duplicate()
						self.get_parent().add_child(trajectory_instance)
						trajectory_instance.add_to_group("trajectories")
						print("Trajectory instance created and added to the scene.")
						
						# Convert the global mouse position to the local position relative to the TileMap
						var map_mouse_position = Map.local_to_map(mouse_position)  # Convert to TileMap local coordinates
						var map_mouse_tile_pos = Map.map_to_local(map_mouse_position) + Vector2(0,0) / 2 # Convert to tile coordinates

						# Convert the target position (assumed to be global) to local
						var map_target_tile_pos = Map.map_to_local(tile_pos)  # Convert to tile coordinates
						
						dynamite_launched += 1
																
						# Start the trajectory
						await trajectory_instance.start_trajectory(map_mouse_tile_pos, map_target_tile_pos)
						
						player_to_act.has_attacked = true
						player_to_act.has_moved = true
						player_to_act.check_end_turn_conditions()
						
						var hud_manager = get_parent().get_node("HUDManager")  # Adjust the path if necessary
						hud_manager.hide_special_buttons()	
						
						# Trigger zombie action: find and chase player
						clear_zombie_tiles()					
				else:
					# If the mouse position is out of bounds, print a message or handle it as needed
					print("Mouse position out of map bounds:", mouse_local)
					return

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

	# Instantiate and animate the dynamite projectile
	if dynamite_scene:
		var dynamite_inst = dynamite_scene.instantiate()
		add_child(dynamite_inst)
		dynamite_inst.global_position = start
		print("Dynamite instance created and placed at start position.")

		# Animate the dynamite along the trajectory points
		await animate_dynamite_trajectory(dynamite_inst, points)
		
		# Cleanup after animation
		dynamite_inst.queue_free()

	onTrajectory = false
	
	print("Trajectory animation completed and cleaned up.")

# Function to animate the dynamite projectile along the Bézier curve points
func animate_dynamite_trajectory(dynamite_inst: Node2D, points: Array) -> void:
	var total_time = 0.01  # Total time to move from start to end (in seconds)
	var steps = points.size()
	var step_time = total_time / steps  # Time per step to move along the path
	
	var elapsed_time = 0.0  # Track the elapsed time

	for i in range(steps - 1):
		var start_point = points[i]
		var end_point = points[i + 1]
		
		var tilemap: TileMap = get_node("/root/MapManager/TileMap")
		var camera: Camera2D = get_node("/root/MapManager/Camera2D")
			
		camera.focus_on_trajectory(points[i])
					
		while elapsed_time < step_time:
			# Calculate the time ratio
			var t = elapsed_time / step_time
			# Lerp between start and end point based on the ratio
			dynamite_inst.global_position = start_point.lerp(end_point, t)
			elapsed_time += get_process_delta_time()
			
			await get_tree().create_timer(0.02).timeout  # Wait until the next frame (await instead of yield)
			
		# Reset elapsed time for the next segment
		elapsed_time = 0.0

	# Ensure dynamite reaches the final point exactly
	dynamite_inst.global_position = points[points.size() - 1]
	
	_trigger_explosion(points[points.size() - 1])
	var hud_manager = get_parent().get_node("HUDManager")  # Adjust the path if necessary
					
	# Access the 'special' button within HUDManager
	var dynamite_button = hud_manager.get_node("HUD/Dynamite")
	dynamite_button.button_pressed = false	
	GlobalManager.dynamite_toggle_active = false

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
	
	var xp_awarded = false
			
	# Check for PlayerUnit within explosion radius
	for player in get_tree().get_nodes_in_group("player_units"):
		if player.position.distance_to(last_point) <= explosion_radius:	
			player.flash_damage()
			player.apply_damage(player.attack_damage)
					
			xp_awarded = true  # Mark XP as earned for this explosion

			var hud_manager = get_parent().get_node("HUDManager") 
			hud_manager.update_hud(player)	

	# Check for ZombieUnit within explosion radius
	for zombie in get_tree().get_nodes_in_group("zombies"):
		if zombie.position.distance_to(last_point) <= explosion_radius:			
			zombie.flash_damage()
			# Check for PlayerUnit within explosion radius
			for player in get_tree().get_nodes_in_group("player_units"):
				if player.player_name == "Dutch. Major":			
					zombie.apply_damage(player.attack_damage)	
						
			print("Zombie Unit removed from explosion")
			
			xp_awarded = true
			
			var hud_manager = get_parent().get_node("HUDManager") 
			hud_manager.update_hud_zombie(zombie)

	# Check for Structures within explosion radius
	for structure in get_tree().get_nodes_in_group("structures"):
		if structure.position.distance_to(last_point) <= explosion_radius:
			structure.get_child(0).play("demolished")  # Play "collapse" animation if applicable
			xp_awarded = true
			
	# Add XP if at least one target was hit
	if xp_awarded:
		await get_tree().create_timer(1).timeout
		add_xp()		
			
func add_xp():
	# Add XP
	# Access the HUDManager (move up the tree from PlayerUnit -> UnitSpawn -> parent to HUDManager)
	var hud_manager = get_parent().get_node("HUDManager")  # Adjust the path if necessary
	
	# Access the 'special' button within HUDManager
	var missile_button = hud_manager.get_node("HUD/Missile")
	GlobalManager.missile_toggle_active = false  # Deactivate the special toggle

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
			print("Checking button:", control.name, "Rect:", rect, "Mouse Pos:", mouse_pos)
			if rect.has_point(mouse_pos):
				print("Mouse is over button:", control.name, "Rect:", rect, "Mouse Pos:", mouse_pos)
				return true
	print("Mouse is NOT over any button.")
	return false
