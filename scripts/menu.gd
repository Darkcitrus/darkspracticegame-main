extends Node2D

@onready var game_world = null

func _ready():
	show()
	print("Menu: Ready. Waiting for user interaction.")

func _input(event):
	if event.is_action_pressed("ui_cancel"):  # ESC key
		toggle_menu()

func respawn_game_world():
	if game_world:
		game_world.queue_free()
		print("Menu: Existing game world freed.")
	
	var game_scene = load("res://scenes/game_world.tscn")
	game_world = game_scene.instantiate()
	get_parent().add_child(game_world)
	game_world.hide()
	print("Menu: New game world instantiated and hidden.")

	# Ensure the GameManager is properly initialized
	var game_manager = game_world.get_node_or_null("GameManager")
	if not game_manager:
		print("Menu: GameManager not found in GameWorld. Adding GameManager.")
		var game_manager_scene = load("res://game_manager.tscn")
		game_manager = game_manager_scene.instantiate()
		game_world.add_child(game_manager)
		print("Menu: GameManager instantiated and added to GameWorld.")

	# Call _position_entities after ensuring GameManager is fully initialized
	if game_manager:
		print("Menu: Found GameManager. Repositioning entities.")
		game_manager.call_deferred("_position_entities")
	else:
		print("Menu: GameManager still not found after instantiation.")

	# Do not modify the dummy's position here
	print("Menu: Dummy position is managed by the oscillation script.")

func toggle_menu():
	if visible:
		if !game_world:
			respawn_game_world()
		hide()
		game_world.show()
	else:
		show()
		if game_world:
			game_world.hide()
