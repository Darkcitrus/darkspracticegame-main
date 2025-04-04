extends Node

var player: Node = null
var sprite: AnimatedSprite2D = null
var base_run_speed: float = 250.0 # Store the default player run speed for comparison
var last_direction_x: float = 1.0 # Keep track of last horizontal movement direction
var hurt_animation_played: bool = false # Track if the hurt animation has been played while trapped
var hurt_animation_finished: bool = false # Track if the hurt animation has completed
var is_dying: bool = false # Track if the death animation is currently playing

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
		if not is_dying:
			is_dying = true # Set the dying flag when death animation starts
			print("Death animation started - disabling player input")
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
		# If player is trapped, only play hurt animation once
		if player.is_trapped:
			if not hurt_animation_played:
				play_animation("Hurt") 
				hurt_animation_played = true
				hurt_animation_finished = false
		else:
			# Normal hurt behavior when not trapped
			if not sprite.animation == "Hurt" or not sprite.is_playing():
				play_animation("Hurt")
				hurt_animation_played = false
		return
	
	# If we're here, we're not hurt anymore, reset the flags
	hurt_animation_played = false
	
	# If trapped but not hurt, show idle animation
	# Also show idle if hurt animation finished while trapped
	if player.is_trapped:
		if hurt_animation_finished or not sprite.animation == "Idle" or not sprite.is_playing():
			play_animation("Idle")
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
		# If the player is trapped, don't loop hurt animation
		if player.is_trapped:
			hurt_animation_finished = true
			play_animation("Idle")
		else:
			update_animation()
	elif sprite.animation == "Death":
			# Reset dying flag when animation finishes (although player remains dead)
			is_dying = false
			print("Death animation finished")
			# When death animation is finished, notify the PlayerHealth script
			if player.has_node("PlayerHealth"):
				player.get_node("PlayerHealth").on_death_animation_finished()
			# Keep the last frame visible
			sprite.stop()

# Public function to check if death animation is playing
func is_death_animation_playing() -> bool:
	return is_dying