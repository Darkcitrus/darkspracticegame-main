extends Node

var player: Node = null
var last_fireball_time: float = 0.0  # Track when the last fireball was fired
@export var FIREBALL_COOLDOWN: float = 0.2  # Cooldown between fireballs

# Auto-attack parameters
var last_auto_attack_time: float = 0.0  # Track when the last auto-attack was fired
@export var AUTO_ATTACK_COOLDOWN: float = 0.5  # Cooldown between auto-attacks (adjust for fire rate)
@export var AUTO_ATTACK_DAMAGE: float = 5.0  # Base damage for auto-attacks
@export var AUTO_ATTACK_CRIT_CHANCE: float = 0.15  # Separate crit chance for auto-attacks
var auto_attack_resource = preload("res://scenes/auto_attack.tscn")  # Path to the auto_attack scene

func initialize(player_node: Node):
	player = player_node
	# Print the actual cooldown value being used to validate it was set correctly
	print("Fireball cooldown initialized to: ", FIREBALL_COOLDOWN)
	print("Auto-attack cooldown initialized to: ", AUTO_ATTACK_COOLDOWN)

func _physics_process(delta):
	if player:
		player.attack_direction = (player.get_global_mouse_position() - player.global_position).normalized()
		thrust_attack(delta)
		sweep_process(delta)
		shoot_fireball()
		shoot_auto_attack()  # Add auto-attack functionality
		point_sword_to_mouse()

func thrust_attack(_delta):
	if Input.is_action_pressed("left_click") and not player.attacking:
		var current_time = Time.get_ticks_msec() / 1000.0

		if current_time - player.last_attack_time >= player.attack_cooldown:
			player.last_attack_time = current_time
			player.hitbox.disabled = false
			player.attacking = true

			process_melee_damage(player.sword.get_overlapping_areas(), player.attack_power * player.thrust_modifier)
			process_melee_damage(player.sword.get_overlapping_bodies(), player.attack_power * player.thrust_modifier)

			var tween = player.create_tween()
			tween.set_trans(Tween.TRANS_EXPO)
			tween.set_ease(Tween.EASE_OUT)

			var start_offset = 100
			var thrust_offset = 150

			tween.tween_method(
				func(progress: float):
					var current_offset = lerp(start_offset, thrust_offset, progress)
					player.sword.position = player.attack_direction * current_offset
					var mouse_position = player.get_global_mouse_position()
					var direction_to_mouse = (mouse_position - player.global_position).normalized()
					player.sword_sprite.rotation = direction_to_mouse.angle() + PI/2,
				0.0, 1.0, 0.15
			)

			tween.tween_method(
				func(progress: float):
					var current_offset = lerp(thrust_offset, start_offset, progress)
					player.sword.position = player.attack_direction * current_offset
					var mouse_position = player.get_global_mouse_position()
					var direction_to_mouse = (mouse_position - player.global_position).normalized()
					player.sword_sprite.rotation = direction_to_mouse.angle() + PI/2,
				0.0, 1.0, 0.25
			)

			tween.tween_callback(func(): player.attacking = false)
			tween.tween_callback(func(): player.hitbox.disabled = true)
			tween.tween_callback(func(): player.sword_sprite.visible = true)
			player.attackcd.start()
		pass

func process_melee_damage(overlapping_objects, base_damage: float):
	randomize()
	for obj in overlapping_objects:
		print("Checking collision with: ", obj.name)
		var target = obj.get_parent() if obj is Area2D else obj
		if target.is_in_group("Enemy"):
			var damage_info = calculate_damage(base_damage)
			print("Processing melee hit - Roll: ", randf(), " < ", player.crit_chance, "?")
			print("Attack Power: ", base_damage, " Final Damage: ", damage_info["damage"], " Crit: ", damage_info["is_crit"])
			if target.has_method("take_damage"):
				target.take_damage(damage_info["damage"], damage_info["is_crit"])

func sweep_process(_delta):
	if Input.is_action_pressed("right_click"):
		if not player.swinging:
			start_sweep()
	else:
		if player.swinging:
			stop_sweep()

func start_sweep():
	player.swinging = true
	player.attacking = true
	player.hitbox.disabled = false
	perform_sweep()

func stop_sweep():
	player.swinging = false
	player.attacking = false
	player.hitbox.disabled = true
	if player.current_tween:
		player.current_tween.kill()
	
	player.current_tween = player.create_tween()
	player.current_tween.set_trans(Tween.TRANS_SINE)
	player.current_tween.set_ease(Tween.EASE_OUT)
	
	var mouse_position = player.get_global_mouse_position()
	var direction_to_mouse = (mouse_position - player.global_position).normalized()
	var target_rotation = direction_to_mouse.angle() + PI/2
	var target_position = player.global_position + direction_to_mouse * 40
	
	player.current_tween.tween_property(player.sword_sprite, "rotation", target_rotation, 0.2)
	player.current_tween.parallel().tween_property(player.sword, "global_position", target_position, 0.2)
	
	player.current_tween.tween_callback(func():
		player.current_tween = null
		point_sword_to_mouse()
	)

func perform_sweep():
	if not player.swinging:
		return
		
	player.current_tween = player.create_tween()
	player.current_tween.set_trans(Tween.TRANS_EXPO)
	player.current_tween.set_ease(Tween.EASE_IN_OUT)
	
	player.current_tween.tween_method(func(progress: float):
		var mouse_position = player.get_global_mouse_position()
		var direction_to_mouse = (mouse_position - player.global_position).normalized()
		var swing_base_angle = direction_to_mouse.angle()
		
		var start_angle = swing_base_angle - PI/4 if player.swinging_left else swing_base_angle + PI/4
		var end_angle = swing_base_angle + PI/4 if player.swinging_left else swing_base_angle - PI/4
		
		var current_angle = lerp_angle(start_angle, end_angle, progress)
		var sweep_direction = Vector2(cos(current_angle), sin(current_angle))
		player.sword.global_position = player.global_position + sweep_direction * 40
		player.sword_sprite.rotation = current_angle + PI/2
		
		if progress == 0.0:
			process_melee_damage(player.sword.get_overlapping_areas(), player.attack_power * player.sweep_modifier)
			process_melee_damage(player.sword.get_overlapping_bodies(), player.attack_power * player.sweep_modifier)
	
	, 0.0, 1.0, 0.2)
	
	player.current_tween.tween_callback(func():
		if player.swinging:
			player.swinging_left = !player.swinging_left
			perform_sweep()
	)

func point_sword_to_mouse():
	if not player.attacking and player.current_tween == null:
		var mouse_position = player.get_global_mouse_position()
		var direction_to_mouse = (mouse_position - player.global_position).normalized()
		player.sword_sprite.rotation = direction_to_mouse.angle() + PI/2
		player.sword.global_position = player.global_position + direction_to_mouse * 40

func shoot_fireball():
	if Input.is_action_pressed("ui_e"):  # Changed from is_action_just_pressed to is_action_pressed
		# Get current time
		var current_time = Time.get_ticks_msec() / 1000.0
						
		# Check if cooldown has passed
		if current_time - last_fireball_time >= FIREBALL_COOLDOWN:
			# Make sure player exists
			if not is_instance_valid(player):
				return
				
			# Make sure player has a valid target
			if is_instance_valid(player.current_target) and player.current_target.is_in_group("Targetable"):
				# Make sure fireball resource exists
				if player.fire_ball != null:
					print("Shooting fireball at target: ", player.current_target.name)
					
					# Safer instantiation
					var fireball = player.fire_ball.instantiate()
					if fireball:
						# Use safer scene tree access
						var scene_root = player.get_tree().get_root()
						if scene_root:
							scene_root.add_child(fireball)
							fireball.global_position = player.global_position
							# Pass the player as the source of the fireball
							fireball.initialize(player.attack_direction, player.current_target, -1, -1, -1, true, player)
							
							# Update the last fireball time
							last_fireball_time = current_time
					else:
						push_error("Failed to instantiate fireball!")
				else:
					push_error("Fireball resource is null!")
			else:
				print("No valid target selected!")
				player.current_target = null

func shoot_auto_attack():
	if Input.is_action_pressed("ui_q"):  # Hold Q for auto-attack
		# Get current time
		var current_time = Time.get_ticks_msec() / 1000.0
						
		# Check if cooldown has passed
		if current_time - last_auto_attack_time >= AUTO_ATTACK_COOLDOWN:
			# Make sure player exists
			if not is_instance_valid(player):
				return
				
			# Make sure player has a valid target
			if is_instance_valid(player.current_target) and player.current_target.is_in_group("Targetable"):
				# Make sure auto-attack resource exists
				if auto_attack_resource != null:
					print("Firing auto-attack at target: ", player.current_target.name)
					
					# Safer instantiation
					var auto_attack = auto_attack_resource.instantiate()
					if auto_attack:
						# Use safer scene tree access
						var scene_root = player.get_tree().get_root()
						if scene_root:
							scene_root.add_child(auto_attack)
							auto_attack.global_position = player.global_position
							
							# Initialize with custom parameters
							auto_attack.initialize(
								player.attack_direction, 
								player.current_target,
								AUTO_ATTACK_DAMAGE,  # Custom damage
								-1,  # Use default speed
								-1,  # Use default homing
								true,
								player
							)
							
							# Set specific crit chance for auto-attacks
							auto_attack.crit_chance = AUTO_ATTACK_CRIT_CHANCE
							
							# Update the last auto-attack time
							last_auto_attack_time = current_time
					else:
						push_error("Failed to instantiate auto-attack!")
				else:
					push_error("Auto-attack resource could not be loaded!")
			else:
				print("No valid target selected for auto-attack!")
				player.current_target = null

func calculate_damage(base_damage: float = player.attack_power) -> Dictionary:
	var roll = randf()  # Get the random roll
	var is_crit = roll < player.crit_chance
	var final_damage = base_damage * (player.crit_damage if is_crit else 1.0)
	print("DAMAGE CALC - Roll: ", roll, " Needed: ", player.crit_chance)
	print("Base damage: ", base_damage, " Final: ", final_damage, " Is crit: ", is_crit)
	return {"damage": final_damage, "is_crit": is_crit}
