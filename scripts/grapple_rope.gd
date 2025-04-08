extends Node2D

var start_point: Vector2 = Vector2.ZERO
var end_point: Vector2 = Vector2.ZERO
var rope_width: float = 2.0
var rope_color: Color = Color(0.6, 0.4, 0.2, 1.0)  # Brown rope color

func _ready():
	visible = false  # Start invisible

func _draw():
	# Draw the rope line
	draw_line(to_local(start_point), to_local(end_point), rope_color, rope_width)

func set_points(start: Vector2, end: Vector2):
	start_point = start
	end_point = end
	queue_redraw()  # Request redraw with the updated points
