extends CollisionShape2D

@export var scale_factor: float = 3.0

func _ready():
	# Just scale up the shape - the parent Area2D will handle input
	scale = Vector2(scale_factor, scale_factor)
	print("Selector hitbox scaled to:", scale_factor)
