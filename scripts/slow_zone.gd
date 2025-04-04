extends Area2D

# Percentage to slow the player by (0.5 = 50% of normal speed = 50% slowdown)
@export var slow_factor: float = 0.5

# Variables to store player reference and original speed
var player_in_zone: bool = false
var player_ref: Node = null
var original_speed: float = 0.0

func _ready():
	# Connect signals for player entering and exiting the zone
	if not is_connected("body_entered", _on_body_entered):
		connect("body_entered", _on_body_entered)
	if not is_connected("body_exited", _on_body_exited):
		connect("body_exited", _on_body_exited)

# When a body enters the slow zone
func _on_body_entered(body: Node):
	# Check if it's the player
	if body.is_in_group("Player") and not player_in_zone:
		player_in_zone = true
		player_ref = body
		# Store the original speed before modifying it
		original_speed = player_ref.run_speed
		
		# Apply slowdown effect
		player_ref.run_speed *= slow_factor
		print("Player slowed to " + str(player_ref.run_speed) + " (original: " + str(original_speed) + ")")

# When a body exits the slow zone
func _on_body_exited(body: Node):
	# Check if it's the player we slowed down
	if body.is_in_group("Player") and player_in_zone and body == player_ref:
		# Restore original speed
		player_ref.run_speed = original_speed
		print("Player speed restored to " + str(original_speed))
		
		# Reset tracking variables
		player_in_zone = false
		player_ref = null

# Add cleanup when scene changes or node is removed
func _exit_tree():
	# Make sure player speed is reset if zone is removed while player is inside
	if player_in_zone and player_ref != null and is_instance_valid(player_ref):
		player_ref.run_speed = original_speed
		print("Cleanup: Player speed restored to " + str(original_speed))
