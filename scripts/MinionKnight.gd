extends CharacterBody2D

# Combat variables
var attack_damage: float = 8.0
var attack_cooldown: float = 1.0  # 1 second between attacks
var last_attack_time: float = 0.0
var attack_range: float = 50.0    # Range at which minion will start attacking
var detection_range: float = 200.0  # Range at which minion can detect enemies

# Movement variables
var move_speed: float = 200.0
var follow_distance: float = 70.0  # How far away from player to maintain when following
var follow_owner: bool = true      # If true, follow owner; if false, move to target
var owner_node: Node2D = null      # Reference to the player who summoned this minion
var target: Node2D = null          # Current enemy target

# Walking animation variables
var walk_tilt_angle: float = 15.0   # Maximum tilt angle in degrees
var walk_tilt_speed: float = 90.0   # Speed of the tilt animation
var current_tilt: float = 0.0       # Current tilt angle
var tilt_direction: int = 1         # Direction of tilt (1 or -1)

# State control
var lifetime: float = 15.0         # Lifetime in seconds
var spawned_time: float = 0.0      # When this minion was spawned
var is_fading: bool = false        # If true, the minion is currently fading out
var fade_duration: float = 1.0     # How long the fade out animation takes

func _ready():
	# Add to appropriate groups
	add_to_group("Minion")
	add_to_group("Effect")
	
	# Initialize spawn time
	spawned_time = Time.get_ticks_msec() / 1000.0
	
	# Setup the collision to avoid colliding with player but to detect enemies
	set_collision_layer_value(4, true)  # Layer 4 for minions
	set_collision_mask_value(2, true)   # Collide with enemies (layer 2)
	set_collision_mask_value(1, false)  # Don't collide with player (layer 1)
	set_collision_mask_value(4, true)   # Collide with other minions (layer 4)
	
	# Create hitbox area for detecting enemies
	var area = Area2D.new()
	area.name = "HitArea"
	add_child(area)
	
	var collision = CollisionShape2D.new()
	collision.name = "HitCollision"
	collision.shape = $MinionKnightCollision.shape.duplicate()
	# Make detection shape slightly larger
	collision.shape.radius *= 1.2
	collision.shape.height *= 1.2
	area.add_child(collision)
	
	# Set up area collision properties
	area.collision_layer = 0
	area.collision_mask = 2  # Detect only enemies (layer 2)
	
	# Connect signals
	area.body_entered.connect(_on_hit_area_body_entered)
	area.body_exited.connect(_on_hit_area_body_exited)
	
	# Slightly randomize the speed to prevent minions from stacking
	move_speed = move_speed * (0.9 + randf() * 0.2)  # 90% to 110% of base speed

func initialize(summoner: Node2D):
	# Store reference to the player
	owner_node = summoner
	
	# Set initial position slightly offset from player
	var offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
	global_position = summoner.global_position + offset
	
	print("Minion knight initialized, following: ", summoner.name)

func _physics_process(delta):
	# Check if lifetime has expired
	var current_time = Time.get_ticks_msec() / 1000.0
	var alive_time = current_time - spawned_time
	
	# Start fading when 80% of lifetime has passed
	if alive_time > lifetime * 0.8 and not is_fading:
		is_fading = true
		var tween = create_tween()
		tween.tween_property($MinionKnightSprite, "modulate", Color(1, 1, 1, 0), fade_duration)
		tween.tween_callback(_on_fade_complete)
	
	# Remove when lifetime expired
	if alive_time >= lifetime:
		queue_free()
		return
	
	# Determine movement behavior
	if target and is_instance_valid(target):
		# Move towards target enemy
		follow_owner = false
		var direction = global_position.direction_to(target.global_position)
		velocity = direction * move_speed
		
		# Check if in attack range
		if global_position.distance_to(target.global_position) <= attack_range:
			# Try to attack
			attempt_attack(target)
	elif owner_node and is_instance_valid(owner_node):
		# Follow owner (player) when no target
		follow_owner = true
		var distance_to_owner = global_position.distance_to(owner_node.global_position)
		
		if distance_to_owner > follow_distance:
			# Move toward owner if too far away
			var direction = global_position.direction_to(owner_node.global_position)
			velocity = direction * move_speed
		else:
			# Stay roughly in position if at good distance
			velocity = Vector2.ZERO
			
			# Look for a new target
			find_new_target()
	else:
		# Owner is gone, self-destruct
		queue_free()
		return
		
	# Apply movement
	move_and_slide()
	
	# Apply walking animation (tilting) if moving
	if velocity.length() > 5.0:
		# Calculate tilt based on movement
		current_tilt += tilt_direction * walk_tilt_speed * delta
		
		# Change direction when reaching the max tilt in either direction
		if abs(current_tilt) >= walk_tilt_angle:
			current_tilt = tilt_direction * walk_tilt_angle  # Clamp to max angle
			tilt_direction *= -1  # Reverse the tilt direction
		
		# Apply the tilt rotation to the sprite
		$MinionKnightSprite.rotation_degrees = current_tilt
	else:
		# Gradually return to upright position when not moving
		current_tilt = move_toward(current_tilt, 0, walk_tilt_speed * 2 * delta)
		$MinionKnightSprite.rotation_degrees = current_tilt
	
	# Face the right direction
	if velocity.x != 0:
		$MinionKnightSprite.flip_h = velocity.x < 0

func attempt_attack(enemy_target):
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Check cooldown
	if current_time - last_attack_time >= attack_cooldown:
		last_attack_time = current_time
		
		# Apply damage to the enemy
		if enemy_target.has_method("take_damage"):
			enemy_target.take_damage(attack_damage, false, "physical")
			print("Minion knight attacked for ", attack_damage, " damage!")
			
			# Visual feedback for attack
			flash_on_attack()

func flash_on_attack():
	# Flash the sprite to indicate an attack
	var tween = create_tween()
	tween.tween_property($MinionKnightSprite, "modulate", Color(1, 0.7, 0.7), 0.1)
	tween.tween_property($MinionKnightSprite, "modulate", Color(1, 1, 1), 0.1)

func find_new_target():
	# Look for enemies within detection range
	if not owner_node or not is_instance_valid(owner_node):
		return
		
	var potential_targets = get_tree().get_nodes_in_group("Enemy")
	var closest_distance = detection_range
	var closest_enemy = null
	
	for enemy in potential_targets:
		if is_instance_valid(enemy):
			var distance = global_position.distance_to(enemy.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_enemy = enemy
	
	# Set the closest enemy as the new target
	target = closest_enemy
	
	if target:
		print("Minion knight found new target: ", target.name)

func _on_hit_area_body_entered(body):
	# Check if the colliding body is an enemy
	if body.is_in_group("Enemy"):
		# Set as target
		target = body
		follow_owner = false
		print("Minion knight detected enemy: ", body.name)

func _on_hit_area_body_exited(body):
	# If current target leaves detection area, clear target
	if body == target:
		target = null
		follow_owner = true
		print("Minion knight lost target, following owner again")

func _on_fade_complete():
	# Called after fade animation completes
	queue_free()
