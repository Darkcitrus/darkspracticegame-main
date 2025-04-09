extends Node2D

var start_point: Vector2 = Vector2.ZERO
var end_point: Vector2 = Vector2.ZERO
var rope_width: float = 4.0  # Slightly wider for texture
var rope_texture: Texture2D = null
var segment_length: float = 16.0  # Length of each rope segment

func _ready():
	visible = false  # Start invisible
	# Load the rope texture
	if ResourceLoader.exists("res://assets/rope.png"):
		rope_texture = load("res://assets/rope.png")
		if rope_texture:
			print("Rope texture loaded successfully")
		else:
			push_error("Failed to load rope texture")
	else:
		push_error("Rope texture not found")

func _draw():
	# Draw a simple brown line as a placeholder for the rope
	var fallback_color = Color(0.6, 0.4, 0.2, 1.0)  # Brown rope color
	draw_line(to_local(start_point), to_local(end_point), fallback_color, rope_width)

func set_points(start: Vector2, end: Vector2):
	start_point = start
	end_point = end
	visible = true  # Ensure the rope is visible
	queue_redraw()  # Request redraw with the updated points
