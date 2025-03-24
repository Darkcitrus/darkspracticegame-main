extends Node2D

var dummy_scene = preload("res://scenes/dummy.tscn")
var spawn_position: Vector2
var original_scale: Vector2 = Vector2(0.5, 0.5) # Store the original scale

func _ready():
	# Use global position to ensure accuracy regardless of parent transforms
	global_position = Vector2.ZERO
	print("DummyManager: Set global position to origin:", global_position)
	
	# Print the full node path to understand parent hierarchy
	print("DummyManager full path:", get_path())
	
	if get_child_count() > 0:
		var first_dummy = get_child(0)
		# Use global_position for accurate placement
		var viewport_center = get_viewport().get_visible_rect().size / 2
		first_dummy.global_position = viewport_center
		spawn_position = first_dummy.position
		original_scale = first_dummy.scale
		print("DummyManager: Original dummy scale is ", original_scale)
		print("DummyManager: Setting dummy global position to ", viewport_center)
		print("DummyManager: Resulting dummy position is ", first_dummy.position)

		connect_dummy(first_dummy)
		print("DummyManager: First dummy global position is:", first_dummy.global_position)

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
	print("DummyManager: New dummy spawned at global position:", new_dummy.global_position)

func connect_dummy(dummy):
	if not dummy.is_connected("dummy_died", _on_dummy_died):
		dummy.connect("dummy_died", _on_dummy_died)
	dummy.add_to_group("Enemy")
	dummy.add_to_group("Targetable")
	dummy.set_process_input(true)
	dummy.input_pickable = true
	print("DummyManager: Dummy connected and configured")
