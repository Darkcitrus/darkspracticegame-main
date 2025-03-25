extends Node2D

var dummy_scene = preload("res://scenes/dummy.tscn")
var spawn_position: Vector2
var original_scale: Vector2 = Vector2(0.5, 0.5) # Store the original scale

@onready var dummy = $Dummy

func _ready():
	# Use global position to ensure accuracy regardless of parent transforms
	global_position = Vector2.ZERO
	print("DummyManager: Set global position to origin:", global_position)
	
	# Print the full node path to understand parent hierarchy
	print("DummyManager full path:", get_path())
	
	if get_child_count() > 0:
		var first_dummy = get_child(0)
		# Store original scale for future respawns
		original_scale = first_dummy.scale
		print("DummyManager: Original dummy scale is ", original_scale)
		
		# Handle initial dummy with EXACTLY the same logic as respawn
		# Set global position directly
		var viewport_center = get_viewport().get_visible_rect().size / 2
		first_dummy.global_position = viewport_center
		
		# Connect signals and set proper groups
		connect_dummy(first_dummy)
		
		# Call reset_position just like respawns do
		if first_dummy.has_method("reset_position"):
			first_dummy.reset_position()
		
		# Explicitly ensure input properties are set
		first_dummy.set_process_input(true)
		first_dummy.input_pickable = true
		
		# Make sure mouse detection is active
		var mouse_detector = first_dummy.get_node_or_null("MouseDetector")
		if mouse_detector:
			mouse_detector.monitoring = true
			mouse_detector.monitorable = true
			print("DummyManager: Initial dummy mouse detector enabled.")
			
		# Enhanced mouse detection setup for initial dummy
		setup_mouse_detection(first_dummy)
		
		print("DummyManager: Initial dummy positioned and configured at:", first_dummy.global_position)

# New function to set up mouse detection with debug info
func setup_mouse_detection(target_dummy):
	# Enable input processing
	target_dummy.set_process_input(true)
	target_dummy.input_pickable = true
	print("DummyManager: Input processing enabled for dummy")
	
	# Set up mouse detector
	var mouse_detector = target_dummy.get_node_or_null("MouseDetector")
	if mouse_detector:
		# Ensure it's enabled
		mouse_detector.monitoring = true
		mouse_detector.monitorable = true
		
		# Check for collision shape
		var collision_shape = mouse_detector.get_node_or_null("CollisionShape2D")
		if collision_shape:
			collision_shape.disabled = false
			var shape = collision_shape.shape
			print("DummyManager: Mouse detector collision shape enabled:", 
				  "Type:", shape.get_class(), 
				  "Size:", shape.get_rect().size if shape.has_method("get_rect") else "N/A")
		else:
			print("DummyManager: WARNING - No collision shape found in MouseDetector!")
		
		# Connect mouse detection signals if they exist
		if mouse_detector.has_signal("mouse_entered") and not mouse_detector.is_connected("mouse_entered", _on_mouse_entered):
			mouse_detector.connect("mouse_entered", _on_mouse_entered)
			print("DummyManager: Connected mouse_entered signal")
		
		if mouse_detector.has_signal("mouse_exited") and not mouse_detector.is_connected("mouse_exited", _on_mouse_exited):
			mouse_detector.connect("mouse_exited", _on_mouse_exited)
			print("DummyManager: Connected mouse_exited signal")
		
		print("DummyManager: Mouse detector fully configured")
	else:
		print("DummyManager: WARNING - No MouseDetector found on dummy!")

# Callback functions for mouse detection
func _on_mouse_entered():
	print("DummyManager: Mouse entered dummy area")

func _on_mouse_exited():
	print("DummyManager: Mouse exited dummy area")

func _on_dummy_died(pos: Vector2):
	print("DummyManager: Dummy died at position ", pos, ", respawning in 1 second...")
	await get_tree().create_timer(1.0).timeout
	spawn_new_dummy(pos)

func spawn_new_dummy(_pos: Vector2):
	var new_dummy = dummy_scene.instantiate()
	add_child(new_dummy)

	# Set scale to match the original dummy
	new_dummy.scale = original_scale
	print("DummyManager: Setting new dummy scale to ", original_scale)

	# Set global position directly
	new_dummy.global_position = get_viewport().get_visible_rect().size / 2
	connect_dummy(new_dummy)
	# Use simplified reset
	new_dummy.reset_position()
	
	# Apply the enhanced mouse detection setup
	setup_mouse_detection(new_dummy)
	
	print("DummyManager: New dummy spawned at global position:", new_dummy.global_position)

func connect_dummy(dummy):
	if not dummy.is_connected("dummy_died", _on_dummy_died):
		dummy.connect("dummy_died", _on_dummy_died)
	dummy.add_to_group("Enemy")
	dummy.add_to_group("Targetable")
	dummy.set_process_input(true)
	dummy.input_pickable = true
	print("DummyManager: Dummy connected and configured")

func reset_dummy_position(position: Vector2):
	if dummy:
		dummy.global_position = position
		print("DummyManager: Dummy reset to position:", position)
