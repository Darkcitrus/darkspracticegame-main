extends Node2D

@onready var game_world = $"../GameWorld"

func _ready():
	show()
	game_world.hide()

func _input(event):
	if event.is_action_pressed("ui_cancel"):  # ESC key
		toggle_menu()

func respawn_game_world():
	if game_world:
		game_world.queue_free()
	var game_scene = load("res://scenes/game_world.tscn")
	game_world = game_scene.instantiate()
	get_parent().add_child(game_world)
	game_world.hide()

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
