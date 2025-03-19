extends Node2D

var dummy_scene = preload("res://scenes/dummy.tscn")
var spawn_position: Vector2
var original_scale: Vector2 = Vector2(0.5, 0.5) # Store the original scale

func _ready():
	# Force our position to the center of the viewport
	var viewport_center = get_viewport().get_visible_rect().size / 2
	position = viewport_center
	print("DummyManager: Forced position to viewport center:", position)
	print("DummyManager: Global position is:", global_position)

	if get_child_count() > 0:
		var first_dummy = get_child(0)
		# Adjust spawn position to account for DummyManager's position and scale
		spawn_position = Vector2(
			(first_dummy.position.x * scale.x) + position.x,
			(first_dummy.position.y * scale.y) + position.y
		)
		original_scale = first_dummy.scale
		print("DummyManager: Original dummy scale is ", original_scale)
		print("DummyManager: Adjusted dummy spawn position is ", spawn_position)

		connect_dummy(first_dummy)
		# Reset position explicitly to avoid oscillation offset on start
		first_dummy.reset_position(spawn_position)
		# Ensure dummy is exactly at its position without oscillation on start
		first_dummy.position = spawn_position
		print("DummyManager: Connected to first dummy at position ", spawn_position)
		print("DummyManager: First dummy global position is:", first_dummy.global_position)

func _on_dummy_died(pos: Vector2):
	print("DummyManager: Dummy died at position ", pos, ", respawning in 1 second...")
	await get_tree().create_timer(1.0).timeout
	spawn_new_dummy(pos)

func spawn_new_dummy(pos: Vector2):
	var new_dummy = dummy_scene.instantiate()
	add_child(new_dummy)

	# Set scale to match the original dummy
	new_dummy.scale = original_scale
	print("DummyManager: Setting new dummy scale to ", original_scale)

	# Position must be set before calling reset_position
	new_dummy.position = pos
	connect_dummy(new_dummy)
	# Reset oscillation parameters
	new_dummy.reset_position(pos)
	# Ensure position is exactly correct by setting it after reset
	new_dummy.position = pos
	print("DummyManager: New dummy spawned at position: ", pos)

func connect_dummy(dummy):
	if not dummy.is_connected("dummy_died", _on_dummy_died):
		dummy.connect("dummy_died", _on_dummy_died)
	dummy.add_to_group("Enemy")
	dummy.add_to_group("Targetable")
	dummy.set_process_input(true)
	dummy.input_pickable = true
	print("DummyManager: Dummy connected and configured")
