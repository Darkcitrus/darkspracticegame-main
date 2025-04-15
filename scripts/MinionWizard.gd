extends CharacterBody2D

# Combat variables
var attack_damage: float = 10.0
var attack_cooldown: float = 1.0  # 1 second between fireball casts
var last_attack_time: float = 0.0
var attack_range: float = 300.0    # Longer range than knights for ranged attacks
var detection_range: float = 350.0  # Larger detection range than knights

# Movement variables
var move_speed: float = 180.0  # Slightly slower than knights
var follow_distance: float = 100.0  # How far away from player to maintain when following
var owner_node: Node2D = null      # Reference to the player who summoned this minion
var target: Node2D = null          # Current enemy target
var fire_ball: PackedScene = null  # Fireball scene reference

# Walking animation variables
var walk_tilt_angle: float = 12.0   # Maximum tilt angle in degrees
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
	area.name = "DetectionArea"
	add_child(area)
	
	var collision = CollisionShape2D.new()
	collision.name = "DetectionCollision"
	
	# Create a large circular shape for detection
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = detection_range
	collision.shape = circle_shape
	
	area.add_child(collision)
	
	# Set up area collision properties
	area.collision_layer = 0
	area.collision_mask = 2  # Detect only enemies (layer 2)
	
	# Connect signals
	area.body_entered.connect(_on_detection_area_body_entered)
	area.body_exited.connect(_on_detection_area_body_exited)
	
	# Slightly randomize the speed to prevent minions from stacking
	move_speed = move_speed * (0.9 + randf() * 0.2)  # 90% to 110% of base speed
	
	# Load the fireball scene
	if ResourceLoader.exists("res://scenes/fire_ball.tscn"):
		fire_ball = load("res://scenes/fire_ball.tscn")
	else:
		push_error("Failed to load fireball resource!")

func initialize(summoner: Node2D):
	# Store reference to the player
	owner_node = summoner
	
	# Set initial position slightly offset from player
	var offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
	global_position = summoner.global_position + offset
	
	print("Minion wizard initialized, following: ", summoner.name)

func _physics_process(delta):
	# Check if lifetime has expired
	var current_time = Time.get_ticks_msec() / 1000.0
	var alive_time = current_time - spawned_time
	
	# Start fading when 80% of lifetime has passed
	if alive_time > lifetime * 0.8 and not is_fading:
		is_fading = true
		var tween = create_tween()
		tween.tween_property($MinionWizardSprite, "modulate", Color(1, 1, 1, 0), fade_duration)
		tween.tween_callback(_on_fade_complete)
	
	# Remove when lifetime expired
	if alive_time >= lifetime:
		queue_free()
		return
		# Determine behavior - wizards always follow the player
	if owner_node and is_instance_valid(owner_node):
		# Always follow owner (player)
		var distance_to_owner = global_position.distance_to(owner_node.global_position)
		
		if distance_to_owner > follow_distance:
			# Move toward owner if too far away
			var direction = global_position.direction_to(owner_node.global_position)
			velocity = direction * move_speed
		else:
			# Stay roughly in position if at good distance
			velocity = Vector2.ZERO
		
		# Actively search for a target if we don't have one
		if not target or not is_instance_valid(target):
			find_closest_target()
			
		# Try to attack a target if one exists
		if target and is_instance_valid(target) and is_target_in_range(target):
			attempt_fireball_attack(target)
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
		$MinionWizardSprite.rotation_degrees = current_tilt
	else:
		# Gradually return to upright position when not moving
		current_tilt = move_toward(current_tilt, 0, walk_tilt_speed * 2 * delta)
		$MinionWizardSprite.rotation_degrees = current_tilt
	
	# Face the right direction
	if velocity.length() > 5.0:
		# When moving, face in the direction of movement
		$MinionWizardSprite.flip_h = velocity.x < 0
	elif target and is_instance_valid(target):
		# When not moving but has a target, face toward the target
		$MinionWizardSprite.flip_h = global_position.x > target.global_position.x

func is_target_in_range(enemy_target) -> bool:
	if not is_instance_valid(enemy_target):
		return false
		
	var distance = global_position.distance_to(enemy_target.global_position)
	return distance <= attack_range

func attempt_fireball_attack(enemy_target):
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Check cooldown
	if current_time - last_attack_time >= attack_cooldown:
		last_attack_time = current_time
		
		# Spawn fireball
		shoot_fireball_at(enemy_target)
		
		# Visual feedback for attack
		cast_effect()

func shoot_fireball_at(enemy_target):
	if not fire_ball or not is_instance_valid(enemy_target) or not is_instance_valid(owner_node):
		return
		
	# Instance a new fireball
	var fireball_instance = fire_ball.instantiate()
	if fireball_instance:
		get_tree().get_root().add_child(fireball_instance)
		
		# Position the fireball at the wizard
		fireball_instance.global_position = global_position
		
		# Set the direction towards the enemy
		var direction = global_position.direction_to(enemy_target.global_position)
				# Use initialize method if available
		if fireball_instance.has_method("initialize"):
			# Pass the correct parameters in the right order
			# (direction, target, damage, speed, homing, allow_crits, source)
			fireball_instance.initialize(direction, enemy_target, attack_damage, -1, -1, true, owner_node)
		else:
			# Set basic properties directly if no initialize method
			fireball_instance.direction = direction
			if fireball_instance.has_method("set_damage"):
				fireball_instance.set_damage(attack_damage)
		
		print("Wizard minion cast fireball at: ", enemy_target.name)

func cast_effect():
	# Flash the sprite to indicate casting
	var tween = create_tween()
	tween.tween_property($MinionWizardSprite, "modulate", Color(0.7, 0.7, 1.2), 0.1)
	tween.tween_property($MinionWizardSprite, "modulate", Color(1, 1, 1), 0.1)

func find_closest_target():
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
		print("Wizard minion found new target: ", target.name)

func _on_detection_area_body_entered(body):
	# Check if the colliding body is an enemy
	if body.is_in_group("Enemy"):
		# Set as target if we don't have one already or this one is closer
		if not target or not is_instance_valid(target) or global_position.distance_to(body.global_position) < global_position.distance_to(target.global_position):
			target = body
			print("Wizard minion detected enemy: ", body.name)

func _on_detection_area_body_exited(body):
	# If current target leaves detection area, clear target and find a new one
	if body == target:
		target = null
		find_closest_target()
		print("Wizard minion lost target, searching for new one")

func _on_fade_complete():
	# Called after fade animation completes
	queue_free()
