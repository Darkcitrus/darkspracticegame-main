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

	# Ensure the GameManager is properly instantiated
	var game_manager = game_world.get_node_or_null("GameManager")
	if not game_manager:
		var game_manager_scene = load("res://game_manager.tscn")
		game_manager = game_manager_scene.instantiate()
		game_world.add_child(game_manager)
		print("Menu: GameManager instantiated and added to GameWorld.")

	# Reposition entities after ensuring GameManager exists
	if game_manager:
		print("Menu: Found GameManager. Repositioning entities.")
		game_manager.call_deferred("_position_entities")
	else:
		print("Menu: GameManager still not found after instantiation.")

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
