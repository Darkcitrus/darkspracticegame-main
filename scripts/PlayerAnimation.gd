extends Node

var player: Node = null
var sprite: AnimatedSprite2D = null
var base_run_speed: float = 250.0 # Store the default player run speed for comparison
var last_direction_x: float = 1.0 # Keep track of last horizontal movement direction

func initialize(player_node: Node):
	player = player_node
	
	# Get the AnimatedSprite2D
	if player.has_node("PlayerSprite"):
		sprite = player.get_node("PlayerSprite")
		print("Animation controller initialized with player sprite")
		# Store the base run speed for speed comparisons
		base_run_speed = player.run_speed
	else:
		push_error("PlayerSprite not found. Animations will not work.")

func _physics_process(delta):
	if not player or not sprite:
		return
		
	update_animation()
	update_sprite_direction()

func update_animation():
	# Handle death animation as highest priority
	if not player.alive:
		play_animation("Death")
		return
		
	# Handle attack animation
	if player.attacking:
		# Attacking takes priority over movement
		if not sprite.animation == "Attack" or not sprite.is_playing():
			play_animation("Attack")
		return
		
	# Handle dodge/dash animation - only for actual dodging
	if player.dodging:
		if not sprite.animation == "Slide" or not sprite.is_playing():
			play_animation("Slide")
		return
		
	# Handle hurt animation (if you have a hurt state)
	if player.knockback_active:
		if not sprite.animation == "Hurt" or not sprite.is_playing():
			play_animation("Hurt")
		return
	
	# Handle movement animations based on speed
	if player.velocity.length() > 10:
		# For regular movement, always use Run animation but adjust the speed based on player speed
		var speed_ratio = player.velocity.length() / base_run_speed
		
		# Use Run animation and adjust its speed
		if not sprite.animation == "Run":
			play_animation("Run")
		
		# Adjust animation speed based on movement speed, with limits to prevent too slow/fast animations
		var anim_speed = clamp(speed_ratio * 1.0, 0.7, 2.0)
		sprite.speed_scale = anim_speed
	else:
		# Player is idle
		if not sprite.animation == "Idle" or not sprite.is_playing():
			play_animation("Idle")
			sprite.speed_scale = 1.0  # Reset speed scale when idle

func update_sprite_direction():
	# Update the sprite direction based on movement or last direction
	if player.velocity.x != 0:
		# Update last direction if we're actively moving horizontally
		last_direction_x = player.velocity.x
		sprite.flip_h = player.velocity.x < 0
	else:
		# Use the last direction when not actively moving horizontally
		sprite.flip_h = last_direction_x < 0
	
	# When attacking, consider the attack direction rather than movement
	if player.attacking:
		sprite.flip_h = player.attack_direction.x < 0

func play_animation(anim_name: String):
	# If the animation doesn't exist in the sprite frames, use a fallback
	if !sprite.sprite_frames.has_animation(anim_name):
		match anim_name:
			"Run":
				# Fallback to "Slide" if "Run" doesn't exist
				anim_name = "Slide" if sprite.sprite_frames.has_animation("Slide") else "Walk"
	
	# Only proceed if we have a valid animation after fallback checks
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
		
		# Connect to animation finished signal for non-looping animations
		if not sprite.sprite_frames.get_animation_loop(anim_name) and not sprite.animation_finished.is_connected(_on_animation_finished):
			sprite.animation_finished.connect(_on_animation_finished)
	else:
		push_error("Animation '" + anim_name + "' not found in sprite frames")

func _on_animation_finished():
	# Handle animation transitions once non-looping animations finish
	if sprite.animation == "Attack":
		player.attacking = false
		update_animation()
	elif sprite.animation == "Dash":
		# Dash might be handled by a timer instead, but this is a backup
		if not player.dodging:
			update_animation()
	elif sprite.animation == "Hurt":
		update_animation()
	elif sprite.animation == "Death":
		# Stop at last frame of death animation
		sprite.stop()