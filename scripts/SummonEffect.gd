extends Node2D

@onready var animation_player = $AnimationPlayer

func _ready():
	# Play the animation automatically
	if animation_player:
		animation_player.play("summon")
	else:
		# Self-destruct if no animation player
		queue_free()

func _on_animation_completed():
	# Remove the effect when animation is done
	queue_free()

func play():
	# Alternative way to play the animation
	if animation_player:
		animation_player.play("summon")
