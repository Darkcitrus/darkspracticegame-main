extends Node2D

@export var dummy_scene: PackedScene
@export var respawn_time: float = 1.0
var original_scale: Vector2 = Vector2(0.5, 0.5) # Store the original dummy scale

# Add a method to capture the original dummy scale
func record_original_dummy_scale(dummy: Node2D):
	original_scale = dummy.scale
	print("DummySpawner: Recorded original dummy scale: ", original_scale)

func spawn_dummy(pos: Vector2):
	if dummy_scene:
		# Wait for respawn time
		await get_tree().create_timer(respawn_time).timeout
		# Create new dummy
		var new_dummy = dummy_scene.instantiate()
		add_child(new_dummy)
		# Apply original scale
		new_dummy.scale = original_scale
		print("DummySpawner: Applied scale to new dummy: ", original_scale)
		
		new_dummy.position = pos  # Set position before reset_position
		new_dummy.connect("dummy_died", Callable(self, "_on_dummy_died"))
		# Reset position to ensure oscillation works correctly from this point
		new_dummy.reset_position(pos)
		print("Dummy spawner: New dummy spawned at: ", pos)

func _on_dummy_died(pos: Vector2):
	print("Dummy spawner: Dummy died, respawning at: ", pos)
	spawn_dummy(pos)
