extends Area2D

# Node References
var initial_position: Vector2
var current_base_position: Vector2  # New variable to track current base position
var oscillation_start_time: float = 0.0
var heal_amount: float = 25.0
var oscillation_intensity: float = 5.0
var oscillation_speed: float = 5.0

# Player attraction variables
var attraction_range: float = 150.0  # Reduced from 300.0 to 150.0
var attraction_speed: float = 600.0  # Increased from 200.0 to 600.0
var player_node: Node2D = null
var was_in_attraction_range: bool = false

# Respawn variables
var respawn_time: float = 5.0
var respawn_timer: Timer

func _ready():
	initial_position = position
	current_base_position = initial_position  # Initialize current base position
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
		print("Found player at start: ", player_node.position)

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
	
	# Attraction logic - only if player needs healing
	if player_node and player_node.is_inside_tree() and player_needs_healing():
		var distance_to_player = position.distance_to(player_node.position)
		print("Distance to player: ", distance_to_player)
		
		if distance_to_player <= attraction_range:
			was_in_attraction_range = true
			
			# Calculate direction vector to player (both X and Y)
			var direction_to_player = (player_node.position - position).normalized()
			
			# Stronger attraction force calculation
			var attraction_force = attraction_speed * pow(1.0 - (distance_to_player / attraction_range), 2.0)
			
			# Apply movement in both X and Y directions
			position += direction_to_player * attraction_force * delta
			print("Moving toward player with force: ", attraction_force)
			
			# Update the current base position (without the oscillation)
			current_base_position = Vector2(position.x, position.y - oscillation_offset)
		else:
			# Not in range, just oscillate from current position
			position.y = current_base_position.y + oscillation_offset
	else:
		# No player or player at full health, just oscillate from current position
		position.y = current_base_position.y + oscillation_offset

# Check if player needs healing (health below max)
func player_needs_healing() -> bool:
	if player_node and "health" in player_node and "max_health" in player_node:
		return player_node.health < player_node.max_health
	return false

func _on_body_entered(body):
	if not visible:  # Skip if already collected
		return
		
	if body.is_in_group("Player") and player_needs_healing():
		player_node = body
		print("Player entered burger area")
		
		if body.has_method("heal"):
			body.heal(heal_amount)
			print("Healing player for: ", heal_amount)
			
			# Hide instead of destroying
			visible = false
			# Turn off collision - use the correct node name "burgerbox"
			if has_node("burgerbox"):
				$burgerbox.set_deferred("disabled", true)
			# Start respawn timer
			respawn_timer.start()

func _on_body_exited(body):
	if body == player_node:
		print("Player exited burger area")
		# Do NOT set player_node to null, we still want to track them for attraction

func _on_respawn_timer_timeout():
	# Reset position to initial position
	position = initial_position
	current_base_position = initial_position
	# Reset oscillation time
	oscillation_start_time = Time.get_ticks_msec() / 1000.0
	# Make visible again
	visible = true
	# Enable collision - use the correct node name "burgerbox"
	if has_node("burgerbox"):
		$burgerbox.set_deferred("disabled", false)
	print("Burger respawned at: ", position)
