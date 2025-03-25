extends Node

signal respawn_requested(position: Vector2)

func request_respawn(pos: Vector2):
	print("RespawnManager: Respawn requested at position:", pos)
	# Emit the respawn signal immediately for initial spawn
	respawn_requested.emit(pos)
	print("RespawnManager: Respawn emitted at position:", pos)
