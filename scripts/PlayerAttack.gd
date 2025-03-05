extends Node

var player: Node = null

func initialize(player_node: Node):
	player = player_node

func _physics_process(delta):
	if player:
		player.attack_direction = (player.get_global_mouse_position() - player.global_position).normalized()
		thrust_attack(delta)
		sweep_process(delta)
		shoot_fireball()
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
	if Input.is_action_just_pressed("ui_e"):
		if is_instance_valid(player.current_target) and player.current_target.is_in_group("Targetable"):
			print("Shooting fireball at target: ", player.current_target.name)
			var fireball = player.fire_ball.instantiate()
			player.get_tree().root.add_child(fireball)
			fireball.global_position = player.global_position
			fireball.initialize(player.attack_direction, player.current_target)
		else:
			print("No valid target selected!")
			player.current_target = null

func calculate_damage(base_damage: float = player.attack_power) -> Dictionary:
	var roll = randf()  # Get the random roll
	var is_crit = roll < player.crit_chance
	var final_damage = base_damage * (player.crit_damage if is_crit else 1.0)
	print("DAMAGE CALC - Roll: ", roll, " Needed: ", player.crit_chance)
	print("Base damage: ", base_damage, " Final: ", final_damage, " Is crit: ", is_crit)
	return {"damage": final_damage, "is_crit": is_crit}
