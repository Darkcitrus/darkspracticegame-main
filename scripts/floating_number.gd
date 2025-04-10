extends Label

var start_pos: Vector2

func setup(damage: int, is_crit: bool = false, pos: Vector2 = Vector2.ZERO):
	# For backward compatibility, assume physical damage
	setup_with_type(damage, is_crit, "physical", pos)

# New function to handle different damage types with appropriate colors
func setup_with_type(damage: int, is_crit: bool = false, damage_type: String = "physical", pos: Vector2 = Vector2.ZERO):
	# Set text with exclamation mark for crits
	text = str(damage) + ("!" if is_crit else "")
	
	# Set colors based on damage type
	var damage_type_lower = damage_type.to_lower()
	if damage_type_lower == "physical":
		if is_crit:
			# Yellow for physical crits
			add_theme_color_override("font_color", Color(1.0, 1.0, 0.0))  # Bright yellow
		else:
			# Orange for physical damage
			add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))  # Orange
	elif damage_type_lower == "magical":
		if is_crit:
			# Purple for magical crits
			add_theme_color_override("font_color", Color(0.8, 0.0, 1.0))  # Purple
		else:
			# Blue for magical damage
			add_theme_color_override("font_color", Color(0.0, 0.7, 1.0))  # Blue
	elif damage_type_lower == "true":
		if is_crit:
			# Bright white for true damage crits
			add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))  # Pure white
		else:
			# White for true damage
			add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))  # Slightly dimmer white
	else:
		# Default white for unknown damage types
		add_theme_color_override("font_color", Color.WHITE)
	
	# Center the text
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Position adjustment (center above the entity)
	start_pos = pos + Vector2(0, -30)  # Offset upward only
	set_deferred("size", Vector2(100, 40))  # Set fixed size using set_deferred
	position = start_pos - size * 0.5  # Center the text at the spawn point

func setup_heal(amount: int, pos: Vector2 = Vector2.ZERO):
	# Set text with a + prefix for healing
	text = "+" + str(amount)
	
	# Set green color for healing
	add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))  # Bright green
	
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
