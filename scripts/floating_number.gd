extends Label

var start_pos: Vector2

func setup(damage: int, is_crit: bool = false, pos: Vector2 = Vector2.ZERO):
	# Set text and colors
	text = str(damage) + ("!" if is_crit else "")
	if is_crit:
		add_theme_color_override("font_color", Color.YELLOW)
	else:
		add_theme_color_override("font_color", Color.WHITE)
	
	# Center the text
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Position adjustment (center above the entity)
	start_pos = pos + Vector2(0, -30)  # Offset upward only
	set_deferred("size", Vector2(100, 40))  # Set fixed size using set_deferred
	position = start_pos - size * 0.5  # Center the text at the spawn point

func _ready():
	# Set up the label appearance
	add_theme_font_size_override("font_size", 36)
	add_theme_constant_override("outline_size", 4)
	add_theme_color_override("font_outline_black", Color.BLACK)
	
	# Create the floating animation
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Move straight up
	tween.tween_property(self, "global_position:y", global_position.y - 60, 1.5)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 1.5)
	
	# Delete after animation completes
	tween.chain().tween_callback(queue_free)
