extends Node2D

@export var dummy_scene: PackedScene
@export var respawn_time: float = 1.0

func spawn_dummy(pos: Vector2):
	if dummy_scene:
		# Wait for respawn time
		await get_tree().create_timer(respawn_time).timeout
		# Create new dummy
		var new_dummy = dummy_scene.instantiate()
		add_child(new_dummy)
		new_dummy.position = pos
		new_dummy.connect("dummy_died", Callable(self, "_on_dummy_died"))
		new_dummy.reset_position(pos)  # Ensure initial position is set correctly

func _on_dummy_died(pos: Vector2):
	spawn_dummy(pos)
