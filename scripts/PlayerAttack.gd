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
	
	# Make sure the player's AttackArea collision mask is set properly
	if player.attack_area:
		print("Attack area exists")
		# Set the Area2D to collide with the Enemy group
		player.attack_area.collision_mask = 2  # Assuming enemies are on layer 2
		player.attack_area.monitoring = true
		player.attack_area.monitorable = true
		
		# Debug attack area position
		print("Attack area position: ", player.attack_area.position)
		print("AttackHurtbox position: ", player.attack_hurtbox.position)

func _physics_process(delta):
	if not player:
		return
		
	# Allow combat actions even when trapped by using can_take_combat_actions
	if not player.can_take_combat_actions():
		return
		
	player.attack_direction = (player.get_global_mouse_position() - player.global_position).normalized()
	basic_attack(delta)
	shoot_fireball()
	shoot_auto_attack()  # Add auto-attack functionality

func basic_attack(_delta):
	# Allow combat actions even when trapped
	if not player.can_take_combat_actions():
		return
		
	# Changed from ui_e to melee_attack
	if Input.is_action_pressed("melee_attack") and not player.attacking:
		var current_time = Time.get_ticks_msec() / 1000.0

		if current_time - player.last_attack_time >= player.attack_cooldown:
			player.last_attack_time = current_time
			player.attacking = true
			
			# Get direction to mouse
			var direction_to_mouse = player.attack_direction
			
			# Play attack animation using the correct sprite node name
			if player.has_node("PlayerSprite"):
				var sprite = player.get_node("PlayerSprite")
				sprite.play("Attack")
				
				# Let the animation play fully regardless of hits
				var animation_length = sprite.sprite_frames.get_frame_count("Attack") / sprite.sprite_frames.get_animation_speed("Attack")
				print("Attack animation length: ", animation_length, " seconds")
			
			# Activate hurtbox for attack
			if player.attack_hurtbox:
				# Position hurtbox in front of player in the attack direction (100 units forward)
				player.attack_area.position = direction_to_mouse * 100
				# Rotate hurtbox to face the attack direction
				player.attack_area.rotation = direction_to_mouse.angle()
				# Enable the hurtbox
				player.attack_hurtbox.disabled = false
				print("Attack hurtbox activated at position: ", player.attack_area.global_position)
			else:
				push_error("Attack hurtbox not found!")
				return
			
			# Wait a short time to let the attack animation start before checking for hits
			var tween = player.create_tween()
			tween.tween_callback(func():
				# Process damage for enemies in hurtbox area
				if player.attack_area and player.attack_area is Area2D:
					var overlapping_areas = player.attack_area.get_overlapping_areas()
					var overlapping_bodies = player.attack_area.get_overlapping_bodies()
					
					print("Overlapping areas: ", overlapping_areas.size())
					print("Overlapping bodies: ", overlapping_bodies.size())
					
					# Process damage even if arrays are empty (this will just print debug info)
					process_melee_damage(overlapping_areas, player.attack_power)
					process_melee_damage(overlapping_bodies, player.attack_power)
				else:
					push_error("AttackArea not found or not an Area2D. Damage detection will not work.")
			).set_delay(0.1)  # Wait 0.1 seconds to check for hits
			
			# Create timer to disable hurtbox after attack animation
			tween.tween_callback(func(): 
				player.attack_hurtbox.disabled = true
			).set_delay(0.3)  # Hurtbox active for ~0.4 seconds total
			
			# Let the animation complete before resetting attacking state
			# The PlayerAnimation script will handle resetting the attacking state when the animation finishes
			
			player.attackcd.start()

func process_melee_damage(overlapping_objects, base_damage: float):
	if overlapping_objects.size() == 0:
		print("No objects to damage")
		return
		
	randomize()
	for obj in overlapping_objects:
		print("Checking collision with: ", obj.name)
		var target = obj.get_parent() if obj is Area2D else obj
		if target.is_in_group("Enemy"):
			var damage_info = calculate_damage(base_damage)
			print("Processing melee hit on: ", target.name)
			print("Attack Power: ", base_damage, " Final Damage: ", damage_info["damage"], " Crit: ", damage_info["is_crit"])
			if target.has_method("take_damage"):
				target.take_damage(damage_info["damage"], damage_info["is_crit"])
				print("Damage applied to enemy")
			else:
				print("Target does not have take_damage method")
		else:
			print("Target is not in Enemy group: ", target.name)
			# Check what groups the target is in
			for group in target.get_groups():
				print("Target is in group: ", group)

func shoot_fireball():
	# Allow combat actions even when trapped
	if not player.can_take_combat_actions():
		return
		
	# Changed from ui_q to fireball action
	if Input.is_action_pressed("fireball"):
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
	# Allow combat actions even when trapped
	if not player.can_take_combat_actions():
		return
		
	# Changed from right_click to ranged_attack
	if Input.is_action_pressed("ranged_attack"):  # Use ranged_attack input for auto-attack
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
