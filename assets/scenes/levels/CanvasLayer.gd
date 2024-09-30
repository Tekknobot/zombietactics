extends CanvasLayer

# Called when the node enters the scene tree for the first time.
func _ready():
	# Create a Label
	var label = Label.new()
	label.text = "Hello, World!"
	
	# Add the Label as a child to this CanvasLayer
	add_child(label)

	# Center the Label in the viewport
	var viewport_size = get_viewport().size
	label.rect_position = Vector2((viewport_size.x - label.rect_size.x) / 2, 
								   (viewport_size.y - label.rect_size.y) / 2)
