extends Area2D  # Changed back to Area2D to use collision detection

var player = null

func _ready():
	visible = false
	call_deferred("find_player")
	# Ensure only the mouse can collide with the selector
	set_collision_layer_value(1, true)  # Enable the first layer (default for mouse)
	set_collision_mask_value(1, true)  # Enable the first mask (default for mouse)
	connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	connect("mouse_exited", Callable(self, "_on_mouse_exited"))

func find_player():
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("Player")
	if player:
		print("Selector: Found player")

func _on_mouse_entered():
	visible = true
	print("Mouse entered selector area")

func _on_mouse_exited():
	visible = false
	print("Mouse exited selector area")
