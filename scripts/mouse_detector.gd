extends Area2D

# The parent node this detector will set as a target
var parent_node = null
@export var detection_radius_multiplier: float = 1.0  # Scale factor for existing collision shape
@export var target_group: String = "Targetable"  # Group the parent should be in to be targeted

func _ready():
	# Get the parent node (can be any type, not just a dummy)
	parent_node = get_parent()
	if not parent_node:
		push_error("MouseDetector must be a child of another node!")
		return
	
	# Make sure parent is in the targetable group
	if not parent_node.is_in_group(target_group):
		print("Warning: Parent not in group '" + target_group + "'. Adding it now.")
		parent_node.add_to_group(target_group)
	
	# Essential for mouse detection
	input_pickable = true
	
	# Find and scale existing collision shapes
	var found_shape = false
	for child in get_children():
		if child is CollisionShape2D:
			found_shape = true
			# Scale the existing collision shape
			child.scale = Vector2(detection_radius_multiplier, detection_radius_multiplier)
			print("Found and scaled existing collision shape:", child.name)
	
	if not found_shape:
		push_error("MouseDetector requires a CollisionShape2D child! Add one in the editor.")
	
	# Enable ALL collision layers/masks for mouse detection
	for i in range(1, 33):
		set_collision_layer_value(i, true)
		set_collision_mask_value(i, true)
	
	# Connect mouse signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	print("MouseDetector initialized for:", parent_node.name)

func _on_mouse_entered():
	print("MOUSE DETECTOR: Mouse entered detection area for:", parent_node.name)
	
	# DIRECTLY set the parent as player's target
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("set_current_target"):
		player.set_current_target(parent_node)
		print("Set player target to:", parent_node.name)
	
	# Show selector if it exists
	var selector = parent_node.get_node_or_null("Selector")
	if selector:
		selector.visible = true
		print("Made selector visible for:", parent_node.name)
	
	# Also notify the parent if it has a method to handle this
	if parent_node.has_method("_on_hover_start"):
		parent_node._on_hover_start()

func _on_mouse_exited():
	print("MOUSE DETECTOR: Mouse exited detection area for:", parent_node.name)
	
	# DIRECTLY clear the parent as player's target
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("clear_current_target"):
		player.clear_current_target()
		print("Cleared player target from:", parent_node.name)
	
	# Hide selector if it exists
	var selector = parent_node.get_node_or_null("Selector")
	if selector:
		selector.visible = false
		print("Made selector invisible for:", parent_node.name)
	
	# Also notify the parent if it has a method to handle this
	if parent_node.has_method("_on_hover_end"):
		parent_node._on_hover_end()
