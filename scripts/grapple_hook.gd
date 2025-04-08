extends Area2D

signal grapple_hit(position)

var direction: Vector2 = Vector2.RIGHT
var speed: float = 800.0
var max_distance: float = 400.0
var initial_position: Vector2
var owner_node = null
var ignore_player: bool = true  # Flag to ignore collisions with the player
var attached: bool = false  # Flag to indicate the hook is attached

@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D

func _ready():
	initial_position = global_position
	
	# Rotate the sprite to match the direction
	sprite.rotation = direction.angle()
	
	# Connect area entered signal
	connect("area_entered", _on_area_entered)
	connect("body_entered", _on_body_entered)

func _physics_process(delta):
	# Check if owner still exists and is still grappling
	if owner_node and not owner_node.grappling and attached:
		# If owner released grapple while we're attached, make sure we're deleted
		queue_free()
		return
		
	# Only move if not attached
	if not attached:
		# Move the grapple in the direction
		global_position += direction * speed * delta
		
		# Check if we've gone too far
		if global_position.distance_to(initial_position) > max_distance:
			queue_free()
	else:
		# If attached, make sure the hook points away from the player
		if owner_node and owner_node.player:
			var player_pos = owner_node.player.global_position
			var direction_from_player = (global_position - player_pos).normalized()
			sprite.rotation = direction_from_player.angle()

func _on_area_entered(area):
	if area.is_in_group("Grappleable") and not attached:
		attached = true
		emit_signal("grapple_hit", global_position)

func _on_body_entered(body):
	# Debug output to help diagnose issues
	print("Grapple collided with: ", body.name, " - Groups: ", body.get_groups())
	
	# Skip if this is the player and we're ignoring player collisions
	if ignore_player and body.is_in_group("Player"):
		print("Ignoring collision with Player")
		return
	
	# Check for either Grappleable or world/World group (case insensitive)
	if not attached and (body.is_in_group("Grappleable") or body.is_in_group("world") or body.is_in_group("World")):
		print("Hit valid target! Emitting grapple_hit signal")
		attached = true
		emit_signal("grapple_hit", global_position)