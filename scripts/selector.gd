extends Node2D  # Change back to Node2D since we're using a separate mouse detector

var player = null
@export var hover_area_scale: float = 1  # How much larger the hover area is

func _ready():
	# Start invisible - will be shown by the MouseDetector
	visible = false
	print("Selector visual ready (purely visual)")
