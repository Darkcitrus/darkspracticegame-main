extends TextureProgressBar

@onready var entity = get_parent()
@onready var health_label = Label.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Set up basic properties
	show()  # Make sure it's visible
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't intercept mouse events
	
	# Set up size and position if not already set in editor
	if size.x == 0 or size.y == 0:
		custom_minimum_size = Vector2(100, 10)  # Default size if none set
		
	initialize_health_bar()
	
	# Add health label to the health bar
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Configure label size and position
	health_label.anchor_left = 0
	health_label.anchor_top = 0
	health_label.anchor_right = 1
	health_label.anchor_bottom = 1
	health_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	health_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# Configure label appearance
	health_label.add_theme_font_size_override("font_size", 36)
	health_label.add_theme_color_override("font_color", Color.WHITE)
	health_label.add_theme_constant_override("outline_size", 4)
	health_label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	add_child(health_label)

func initialize_health_bar() -> void:
	if not entity:
		push_error("HealthBar: No parent entity found!")
		return
		
	if not "health" in entity or not "max_health" in entity:
		push_error("HealthBar: Parent entity must have 'health' and 'max_health' properties!")
		return
	
	min_value = 0
	max_value = entity.max_health
	value = round(entity.health)
	health_label.text = str(value)
	show()

# Update the health bar value
func update_health(new_health: float) -> void:
	value = round(new_health)
	health_label.text = str(value)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if entity and "health" in entity:
		value = round(entity.health)
		health_label.text = str(value)
		if value <= 0:
			hide()
		else:
			show()
