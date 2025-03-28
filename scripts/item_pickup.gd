extends Area2D
class_name ItemPickup

# Base Properties
@export var oscillation_intensity: float = 5.0
@export var oscillation_speed: float = 5.0
@export var attraction_range: float = 150.0
@export var attraction_speed: float = 600.0
@export var respawn_time: float = 5.0

# Node References
var initial_position: Vector2
var current_base_position: Vector2
var oscillation_start_time: float = 0.0
var player_node: Node2D = null
var was_in_attraction_range: bool = false
var respawn_timer: Timer

# Override these in child classes
func can_be_attracted_to_player() -> bool:
	return true

func should_attract_to_player() -> bool:
	return true

func apply_pickup_effect(player):
	# Child classes should override this method to apply their specific effects
	pass

func _ready():
	initial_position = position
	current_base_position = initial_position
	oscillation_start_time = Time.get_ticks_msec() / 1000.0
	
	# Connect signals
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	
	# Create respawn timer
	respawn_timer = Timer.new()
	respawn_timer.one_shot = true
	respawn_timer.wait_time = respawn_time
	respawn_timer.connect("timeout", _on_respawn_timer_timeout)
	add_child(respawn_timer)
	
	# Force it to check for any player in range on start
	call_deferred("_check_for_player")

func _check_for_player():
	# Find any player in the scene
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		player_node = players[0]

func _process(delta: float):
	# Skip processing if invisible (collected)
	if not visible:
		return
		
	# Calculate oscillation
	var elapsed_time = Time.get_ticks_msec() / 1000.0 - oscillation_start_time
	var oscillation_offset = sin(elapsed_time * oscillation_speed) * oscillation_intensity
	
	# Player detection - if we don't have a reference to the player, try to find one
	if not player_node:
		var players = get_tree().get_nodes_in_group("Player")
		if players.size() > 0:
			player_node = players[0]
	
	# Attraction logic
	if player_node and player_node.is_inside_tree() and can_be_attracted_to_player() and should_attract_to_player():
		var distance_to_player = position.distance_to(player_node.position)
		
		if distance_to_player <= attraction_range:
			was_in_attraction_range = true
			
			# Calculate direction vector to player
			var direction_to_player = (player_node.position - position).normalized()
			
			# Stronger attraction force calculation
			var attraction_force = attraction_speed * pow(1.0 - (distance_to_player / attraction_range), 2.0)
			
			# Apply movement in both X and Y directions
			position += direction_to_player * attraction_force * delta
			
			# Update the current base position (without the oscillation)
			current_base_position = Vector2(position.x, position.y - oscillation_offset)
		else:
			# Not in range, just oscillate from current position
			position.y = current_base_position.y + oscillation_offset
	else:
		# No player attraction needed, just oscillate from current position
		position.y = current_base_position.y + oscillation_offset

func _on_body_entered(body):
	if not visible:  # Skip if already collected
		return
		
	if body.is_in_group("Player") and can_be_picked_up_by(body):
		player_node = body
		
		# Apply the pickup effect
		apply_pickup_effect(body)
		
		# Hide instead of destroying
		visible = false
		
		# Disable collision
		for child in get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred("disabled", true)
				
		# Start respawn timer
		respawn_timer.start()

func _on_body_exited(body):
	if body == player_node:
		# Do NOT set player_node to null, we still want to track them for attraction
		pass

func _on_respawn_timer_timeout():
	# Reset position to initial position
	position = initial_position
	current_base_position = initial_position
	
	# Reset oscillation time
	oscillation_start_time = Time.get_ticks_msec() / 1000.0
	
	# Make visible again
	visible = true
	
	# Enable collision
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", false)

# Override in child classes if needed
func can_be_picked_up_by(player) -> bool:
	return true