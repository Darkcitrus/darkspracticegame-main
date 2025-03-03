extends CharacterBody2D 

# Current state variables
var can_dodge: bool = true
var dodging: bool = false
var attacking: bool = false
var dodge_recovering: bool = false
var attack_power = 20
var thrust_distance = 80
var thrust_modifier: float = 1.5  # Modifier for thrust attack
var sweep_modifier: float = 0.8  # Modifier for sweep attack
var swinging_left: bool = true  # Track the current direction of the swing
var swinging: bool = false  # Track if the sword is currently swinging
var current_tween: Tween = null  # Store the current tween
var attack_cooldown = 0.3  # attack cooldown in seconds
var last_attack_time = 0
var fire_ball: PackedScene = preload("res://scenes/fire_ball.tscn")
var health = 100
var max_health = 100
var crit_chance: float = 0.25
var crit_damage: float = 2.0
var alive: bool = true
var current_target: Node2D = null  # Add this near the other state variables

# Movement variables
var run_speed = 250
var dodge_speed: int = 1000
var direction: Vector2
var attack_direction: Vector2
var move_input = Vector2()
var dodges = 2
const MAX_DODGES = 2
const DODGE_COOLDOWN_TIME = 1.0
const DODGE_RECOVERY_TIME = 2.0

# Reference variables
@onready var dodge_timer = $DodgeTimer
@onready var dodge_recovery = $DodgeRecovery
@onready var dodge_cooldown = $DodgeCooldown
@onready var dodge_label = $DashCount
@onready var sword = $sword
@onready var sword_sprite = $sword/swordsprite
@onready var hitbox = $sword/hitbox
@onready var attackcd = $sword/hitbox/attackcd
@onready var projectiles = $Projectiles
@onready var respawn_timer: Timer = $RespawnTimer
@onready var healthbar: TextureProgressBar = $HealthBar

# Called when the node enters the scene tree for the first time.
func _ready():
	add_to_group("Player") # Add player to Player group
	shoot_fireball()
	randomize() # Seed the random number generator
	if not respawn_timer:
		respawn_timer = Timer.new()
		add_child(respawn_timer)
	respawn_timer.wait_time = 5.0
	respawn_timer.one_shot = true
	respawn_timer.timeout.connect(_on_respawn_timer_timeout)
	
	# Initialize health and healthbar
	health = max_health
	if healthbar:
		healthbar.max_value = max_health
		healthbar.value = health
		healthbar.show()
		print("Player healthbar initialized. Max health: ", max_health)
	
	# Make sure sword is in Effects group
	$sword.add_to_group("Effects")
	hitbox.disabled = true  # Disable the sword's hitbox by default
	sword_sprite.visible = true  # Ensure the sword_sprite remains visible
	
	# Initialize dodge timer settings
	dodge_timer.wait_time = 0.3  # Dash duration
	dodge_recovery.wait_time = DODGE_RECOVERY_TIME
	dodge_cooldown.wait_time = DODGE_COOLDOWN_TIME

	# Update timer settings
	dodge_timer.wait_time = 0.1  # Shorter dash duration
	dodge_recovery.wait_time = 0.5  # Faster recovery
	dodge_cooldown.wait_time = 0.1  # Short cooldown between dashes
	
	# Connect all signals
	dodge_timer.timeout.connect(_on_dodge_timer_timeout)
	dodge_recovery.timeout.connect(_on_dodge_recovery_timeout)
	dodge_cooldown.timeout.connect(_on_dodge_cooldown_timeout)

func calculate_damage(base_damage: float = attack_power) -> Dictionary:
	var roll = randf()  # Get the random roll
	var is_crit = roll < crit_chance
	var final_damage = base_damage * (crit_damage if is_crit else 1.0)
	print("DAMAGE CALC - Roll: ", roll, " Needed: ", crit_chance)
	print("Base damage: ", base_damage, " Final: ", final_damage, " Is crit: ", is_crit)
	return {"damage": final_damage, "is_crit": is_crit}

func apply_damage_to_enemy(enemy, base_damage: float) -> void:
	if enemy.has_method("take_damage"):
		# Calculate crit for each hit
		var is_crit = randf() < crit_chance
		var final_damage = base_damage * (crit_damage if is_crit else 1.0)
		print("Attack damage: ", final_damage, " (Critical: ", is_crit, ")")
		enemy.take_damage(final_damage, is_crit)

func get_damage() -> float:
	# Don't calculate crits here, just return base damage
	return attack_power

func _physics_process(delta) :
	attack_direction = (get_global_mouse_position() - global_position).normalized()
	handle_movement()
	thrust_attack(delta)
	sweep_process(delta)
	move_and_slide()
	shoot_fireball()
	point_sword_to_mouse()
	handle_health()

func get_dodges() -> int:
	return dodges

func handle_health():
	if health <= 0:
		alive = false
		die()

func take_damage(amount):
	if not dodging and alive:
		print("Player taking damage: ", amount)
		health -= amount
		print("Player health now: ", health)  # Debug print
		
		if healthbar:
			print("Updating player healthbar to: ", health)
			healthbar.value = health
			
		if health <= 0:
			die()

func thrust_attack(_delta):
	if Input.is_action_pressed("left_click") and not attacking:
		var current_time = Time.get_ticks_msec() / 1000.0

		if current_time - last_attack_time >= attack_cooldown:
			last_attack_time = current_time
			hitbox.disabled = false
			attacking = true

			# Process damage once at the start of the thrust
			process_melee_damage(sword.get_overlapping_areas(), attack_power * thrust_modifier)
			process_melee_damage(sword.get_overlapping_bodies(), attack_power * thrust_modifier)

			var tween = create_tween()
			tween.set_trans(Tween.TRANS_EXPO)
			tween.set_ease(Tween.EASE_OUT)

			var start_offset = 100
			var thrust_offset = 150

			tween.tween_method(
				func(progress: float):
					var current_offset = lerp(start_offset, thrust_offset, progress)
					sword.position = attack_direction * current_offset
					# Update sword orientation during thrust
					var mouse_position = get_global_mouse_position()
					var direction_to_mouse = (mouse_position - global_position).normalized()
					sword_sprite.rotation = direction_to_mouse.angle() + PI/2,
				0.0, 1.0, 0.15
			)

			tween.tween_method(
				func(progress: float):
					var current_offset = lerp(thrust_offset, start_offset, progress)
					sword.position = attack_direction * current_offset
					# Update sword orientation during return
					var mouse_position = get_global_mouse_position()
					var direction_to_mouse = (mouse_position - global_position).normalized()
					sword_sprite.rotation = direction_to_mouse.angle() + PI/2,
				0.0, 1.0, 0.25
			)

			tween.tween_callback(func(): attacking = false)
			tween.tween_callback(func(): hitbox.disabled = true)
			tween.tween_callback(func(): sword_sprite.visible = true)
			attackcd.start()
		pass

func process_melee_damage(overlapping_objects, base_damage: float):
	randomize()  # Ensure random is seeded for each attack
	for obj in overlapping_objects:
		print("Checking collision with: ", obj.name)
		var target = obj.get_parent() if obj is Area2D else obj
		if target.is_in_group("Enemy"):
			var damage_info = calculate_damage(base_damage)
			print("Processing melee hit - Roll: ", randf(), " < ", crit_chance, "?")
			print("Attack Power: ", base_damage, " Final Damage: ", damage_info["damage"], " Crit: ", damage_info["is_crit"])
			if target.has_method("take_damage"):
				target.take_damage(damage_info["damage"], damage_info["is_crit"])

func sweep_process(_delta):
	# Start sweeping when right mouse button is pressed
	if Input.is_action_pressed("right_click"):
		if not swinging:
			start_sweep()
	else:
		# Stop sweeping when right mouse button is released
		if swinging:
			stop_sweep()

func start_sweep():
	swinging = true
	attacking = true
	hitbox.disabled = false  # Enable hitbox during sweep
	perform_sweep()

func stop_sweep():
	swinging = false
	attacking = false
	hitbox.disabled = true  # Disable hitbox after sweep
	if current_tween:
		current_tween.kill()
	
	# Create a tween for smooth return animation
	current_tween = create_tween()
	current_tween.set_trans(Tween.TRANS_SINE)
	current_tween.set_ease(Tween.EASE_OUT)
	
	# Get the target position and rotation
	var mouse_position = get_global_mouse_position()
	var direction_to_mouse = (mouse_position - global_position).normalized()
	var target_rotation = direction_to_mouse.angle() + PI/2
	var target_position = global_position + direction_to_mouse * 40
	
	# Animate both rotation and position
	current_tween.tween_property(sword_sprite, "rotation", target_rotation, 0.2)
	current_tween.parallel().tween_property(sword, "global_position", target_position, 0.2)
	
	# After the tween completes, clear it and enable normal mouse tracking
	current_tween.tween_callback(func():
		current_tween = null
		point_sword_to_mouse()
	)

func perform_sweep():
	if not swinging:
		return
		
	# Create a tween for smooth animation
	current_tween = create_tween()
	current_tween.set_trans(Tween.TRANS_EXPO)
	current_tween.set_ease(Tween.EASE_IN_OUT)
	
	current_tween.tween_method(func(progress: float):
		# Calculate the direction to the mouse position
		var mouse_position = get_global_mouse_position()
		var direction_to_mouse = (mouse_position - global_position).normalized()
		var swing_base_angle = direction_to_mouse.angle()
		
		# Calculate the sweep angles based on the current direction
		var start_angle = swing_base_angle - PI/4 if swinging_left else swing_base_angle + PI/4
		var end_angle = swing_base_angle + PI/4 if swinging_left else swing_base_angle - PI/4
		
		var current_angle = lerp_angle(start_angle, end_angle, progress)
		var sweep_direction = Vector2(cos(current_angle), sin(current_angle))
		sword.global_position = global_position + sweep_direction * 40
		sword_sprite.rotation = current_angle + PI/2
		
		# Process damage only when entering the collision area
		if progress == 0.0:
			process_melee_damage(sword.get_overlapping_areas(), attack_power * sweep_modifier)
			process_melee_damage(sword.get_overlapping_bodies(), attack_power * sweep_modifier)
	
	, 0.0, 1.0, 0.2)  # 0.2 seconds duration for faster swings
	
	# Chain the next sweep with opposite direction
	current_tween.tween_callback(func():
		if swinging:  # Only continue if still swinging
			swinging_left = !swinging_left  # Toggle direction
			perform_sweep()  # Start the next sweep
	)

func point_sword_to_mouse():
	if not attacking and current_tween == null:  # Only update if not attacking and not tweening
		var mouse_position = get_global_mouse_position()
		var direction_to_mouse = (mouse_position - global_position).normalized()
		sword_sprite.rotation = direction_to_mouse.angle() + PI/2
		sword.global_position = global_position + direction_to_mouse * 40

func sweep_attack():
	var mouse_pos = get_global_mouse_position()
	var angle = position.direction_to(mouse_pos).angle()
	
	# Rotate the sword towards the mouse position
	sword.rotation = angle + PI/2  # PI/2 is added because the sword is initially rotated by 90 degrees
	
	# Implement a sweeping motion (example: 45 degrees sweep)
	var sweep_angle = PI/4
	
	# Animate the rotation
	var tween = create_tween()
	tween.tween_property(sword, "rotation", angle + PI/2 + sweep_angle, 0.1).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sword, "rotation", angle + PI/2 - sweep_angle, 0.1).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE).set_delay(0.1)
	tween.tween_property(sword, "rotation", angle + PI/2, 0.1).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE).set_delay(0.2)

func shoot_fireball():
	if Input.is_action_just_pressed("ui_e"):
		if is_instance_valid(current_target) and current_target.is_in_group("Targetable"):
			print("Shooting fireball at target: ", current_target.name)
			var fireball = fire_ball.instantiate()
			get_tree().root.add_child(fireball)
			fireball.global_position = global_position
			fireball.initialize(attack_direction, current_target)
		else:
			print("No valid target selected!")
			current_target = null  # Clear invalid target

func apply_damage(target, damage):
	target.health -= damage
	if target.health <= 0:
		target.queue_free()

func _on_area_entered(area):
	if area.is_in_group("Enemy"):
		var is_crit = randf() < crit_chance
		var final_damage = attack_power * (crit_damage if is_crit else 1.0)
		if area.has_method("take_damage"):
			area.take_damage(final_damage, is_crit)

# This function handles the player's movement input.
# It checks for the direction keys and applies movement accordingly.
func handle_movement():
	# Check if the player is not currently dodging
	if not dodging:
		# Get the movement input from the direction keys
		move_input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	# Determine the movement speed based on whether the player is dodging or not
	var SPEED = run_speed if not dodging else dodge_speed
	# Calculate the movement direction by multiplying the input vector with the speed
	var movedirection = move_input * SPEED
	# Apply the movement to the player's velocity
	velocity = movedirection
	# Check if the player can dodge and if the dodge button is pressed
	if can_dodge:
		if Input.is_action_just_pressed("dash") and not dodging and dodges > 0:
			# Handle the dodge movement
			handle_dodge()

# This function handles the player's dodge movement.
# It reduces the number of available dodges, starts the dodge recovery timer, and sets the dodging flag to true.
func handle_dodge():
	# Only process dodge if we have dodges available
	if dodges > 0:
		dodges -= 1 
		print("Dodge started! Remaining dashes: " + str(dodges))
		dodge_label.text = str(dodges)  # Update display immediately
		dodging = true
		can_dodge = false
		dodge_timer.start()

# Modified timeout handler
func _on_dodge_timer_timeout():
	dodging = false
	dodge_cooldown.start()
	print("Dodge ended, starting cooldown")

	if dodges < MAX_DODGES and not dodge_recovering:
		dodge_recovering = true
		dodge_recovery.start()
		print("Starting dodge recovery")

func _on_dodge_recovery_timeout():
	if dodges < MAX_DODGES:
		dodges += 1
		print("Recovered a dodge. Current dodges: " + str(dodges))
		dodge_label.text = str(dodges)
				
		if dodges < MAX_DODGES:
			dodge_recovery.start()
		else:
			dodge_recovering = false

func _on_dodge_cooldown_timeout():
	can_dodge = true
	print("Can dodge again")

func _on_attackcd_timeout():
	attacking = false
	print("Player attacked with power: ", attack_power)
	hitbox.disabled = true  # Disable hitbox after attack
	pass

func remove_and_respawn():
	# Remove the node
	queue_free()
	# Start the timer
	respawn_timer.start()

func die():
	if not alive:
		return
		
	print("Player died!")  # Debug print
	alive = false
	visible = false  # Hide the player
	respawn_timer.start()  # Start the 5-second timer

func _on_respawn_timer_timeout():
	# Reset player state
	health = max_health
	alive = true
	visible = true
	position = Vector2(100, 100)  # Reset to a starting position
	if healthbar:
		healthbar.value = health
	print("Player respawned!")  # Debug print

func set_current_target(target: Node2D) -> void:
	current_target = target
	print("Target set: ", target.name)

func clear_current_target() -> void:
	current_target = null
	print("Target cleared")
