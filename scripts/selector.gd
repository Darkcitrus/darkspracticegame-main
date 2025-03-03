extends Node2D  # Changed from Area2D since we don't need collision detection here

var player = null

func _ready():
	visible = false
	call_deferred("find_player")

func find_player():
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("Player")
	if player:
		print("Selector: Found player")

# The dummy will handle showing/hiding the selector
