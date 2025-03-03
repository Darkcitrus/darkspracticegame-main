extends Button

func _ready():
	pressed.connect(_on_pressed)

func _on_pressed():
	var menu = get_parent()
	menu.respawn_game_world()
	menu.toggle_menu()
