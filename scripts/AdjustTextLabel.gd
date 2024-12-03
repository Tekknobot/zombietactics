extends RichTextLabel

# Define the padding or margin value
const RIGHT_MARGIN = 10  # Adjust this value to set the desired padding

func _ready():
	# Adjust size to fit content dynamically
	adjust_size_to_content()

func adjust_size_to_content():
	# Get the required width and height to fit the content
	var content_width = get_content_width() + RIGHT_MARGIN  # Add the right margin
	var content_height = get_content_height()
	
	# Set the minimum size to match the content with padding
	custom_minimum_size = Vector2(content_width, content_height)
