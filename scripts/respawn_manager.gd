extends Node

signal respawn_requested(position: Vector2)

func request_respawn(pos: Vector2):
	# Wait 1 second before respawning
	await get_tree().create_timer(1.0).timeout
	respawn_requested.emit(pos)
