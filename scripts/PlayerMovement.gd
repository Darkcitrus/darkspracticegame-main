extends Node

var player: Node = null
var dodge_timer: Timer = null
var dodge_recovery: Timer = null
var dodge_cooldown: Timer = null

# Ice spot functionality
var ice_spot_spawning_enabled: bool = false
var ice_spot_scene_path: String = "res://scenes/ice_spot.tscn"
var ice_spot_scene = null
var spawn_interval: float = 0.01  # Much more frequent spawning (was 0.5)
var last_spawn_time: float = 0.0

# Sneaking functionality
var is_sneaking: bool = false
var normal_speed_multiplier: float = 1.0
var sneak_speed_multiplier: float = 0.75

func initialize(player_node: Node):
	player = player_node
	dodge_timer = player.get_node("DodgeTimer")
	dodge_recovery = player.get_node("DodgeRecovery")
	dodge_cooldown = player.get_node("DodgeCooldown")

	# Connect all signals
	dodge_timer.timeout.connect(_on_dodge_timer_timeout)
	dodge_recovery.timeout.connect(_on_dodge_recovery_timeout)
	dodge_cooldown.timeout.connect(_on_dodge_cooldown_timeout)
	
	# Load the ice spot scene for later instantiation
	ice_spot_scene = load(ice_spot_scene_path)
	if ice_spot_scene:
		print("Ice spot scene loaded successfully")
	else:
		push_error("Failed to load ice spot scene")

func _physics_process(delta):
	# Skip movement if player can't take actions
	if not player or not player.can_take_actions():
		return

	# Handle sneaking
	handle_sneaking()

	# Normal movement code
	handle_movement()
	
	# Handle ice spot spawning
	handle_ice_spots(delta)	# Toggle ice spot spawning with the 4 key
	if Input.is_physical_key_pressed(KEY_4):
		if not player.has_meta("key4_pressed"):
			player.set_meta("key4_pressed", true)
			toggle_ice_spot_spawning()
	else:
		if player.has_meta("key4_pressed"):
			player.remove_meta("key4_pressed")

# Handle sneaking logic
func handle_sneaking():
	if not player:
		return
		
	var was_sneaking = is_sneaking
	is_sneaking = Input.is_action_pressed("sneak")
	
	# If sneaking state changed
	if was_sneaking != is_sneaking:
		if is_sneaking:
			# Started sneaking
			apply_sneak_effects()
		else:
			# Stopped sneaking
			remove_sneak_effects()

# Apply effects when player starts sneaking
func apply_sneak_effects():
	# Make player partially transparent
	if player.has_node("PlayerSprite"):
		player.get_node("PlayerSprite").modulate.a = 0.5
	
	# Store original speed if not already stored
	if not player.has_meta("original_run_speed_before_sneak"):
		player.set_meta("original_run_speed_before_sneak", player.run_speed)
	
	# Apply reduced speed (75% of original)
	player.run_speed = player.get_meta("original_run_speed_before_sneak") * sneak_speed_multiplier
	
	# Set undetectable flag for dummies to check
	player.set_meta("is_undetectable", true)
	
	print("Started sneaking. Speed reduced to: " + str(player.run_speed))

# Remove effects when player stops sneaking
func remove_sneak_effects():
	# Restore normal transparency
	if player.has_node("PlayerSprite"):
		player.get_node("PlayerSprite").modulate.a = 1.0
	
	# Restore original speed
	if player.has_meta("original_run_speed_before_sneak"):
		player.run_speed = player.get_meta("original_run_speed_before_sneak")
		player.remove_meta("original_run_speed_before_sneak")
	
	# Remove undetectable flag
	if player.has_meta("is_undetectable"):
		player.remove_meta("is_undetectable")
	
	print("Stopped sneaking. Speed restored to: " + str(player.run_speed))

func handle_movement():
	# Check again if the player can take actions (in case this is called directly)
	if not player.can_take_actions():
		return
		
	if not player.dodging:
		player.move_input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var SPEED = player.run_speed if not player.dodging else player.dodge_speed
	var movedirection = player.move_input * SPEED
	player.velocity = movedirection
	if player.can_dodge:
		if Input.is_action_just_pressed("dash") and not player.dodging and player.dodges > 0:
			# Check if player is on ice - prevent dodging if they are
			if player.has_meta("on_ice"):
				print("Cannot dodge while on ice!")
			else:
				handle_dodge()

func handle_dodge():
	# One more check to ensure player can take actions
	if not player.can_take_actions():
		return
		
	if player.dodges > 0:
		player.dodges -= 1 
		print("Dodge started! Remaining dashes: " + str(player.dodges))
		player.dodge_label.text = str(player.dodges)
		player.dodging = true
		player.can_dodge = false
		player.dodge_timer.start()

# Toggle ice spot spawning feature
func toggle_ice_spot_spawning():
	ice_spot_spawning_enabled = !ice_spot_spawning_enabled
	print("Ice spot spawning: " + ("ON" if ice_spot_spawning_enabled else "OFF"))
	
	# Apply or remove ice effects directly when toggling
	if ice_spot_spawning_enabled:
		# Apply ice effects to player immediately when toggled on
		apply_ice_effects_to_player()
		# Also spawn one ice spot immediately
		spawn_ice_spot()
	else:
		# Remove ice effects when toggled off
		remove_ice_effects_from_player()

# Handle spawning ice spots at regular intervals when enabled
func handle_ice_spots(_delta):
	if ice_spot_spawning_enabled and ice_spot_scene:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_spawn_time >= spawn_interval:
			spawn_ice_spot()
			last_spawn_time = current_time

# Spawn an ice spot at the player's current position
func spawn_ice_spot():
	if not player or not is_instance_valid(player):
		return
		
	var new_ice_spot = ice_spot_scene.instantiate()
	if new_ice_spot:
		# Add the ice spot to the game world at player's position
		player.get_parent().add_child(new_ice_spot)
		new_ice_spot.global_position = player.global_position
		print("Spawned ice spot at: ", player.global_position)

func _on_dodge_timer_timeout():
	player.dodging = false
	player.dodge_cooldown.start()
	print("Dodge ended, starting cooldown")

	if player.dodges < player.MAX_DODGES and not player.dodge_recovering:
		player.dodge_recovering = true
		player.dodge_recovery.start()
		print("Starting dodge recovery")

func _on_dodge_recovery_timeout():
	if player.dodges < player.MAX_DODGES:
		player.dodges += 1
		print("Recovered a dodge. Current dodges: " + str(player.dodges))
		player.dodge_label.text = str(player.dodges)
				
		if player.dodges < player.MAX_DODGES:
			player.dodge_recovery.start()
		else:
			player.dodge_recovering = false

func _on_dodge_cooldown_timeout():
	player.can_dodge = true
	print("Can dodge again")

# Apply ice effects to the player directly from movement script
func apply_ice_effects_to_player():
	if player:
		# Store original friction value if it doesn't exist yet
		if not player.has_meta("original_friction"):
			player.set_meta("original_friction", player.friction if "friction" in player else 1.0)
		
		# Store original speed if it doesn't exist yet
		if not player.has_meta("original_run_speed"):
			player.set_meta("original_run_speed", player.run_speed)
			player.set_meta("current_speed_multiplier", 1.0)
			print("Starting gradual speed acceleration on ice from base speed: " + str(player.get_meta("original_run_speed")))
			
			# Set up acceleration timer if it doesn't exist yet
			if not player.has_node("IceAccelerationTimer"):
				var acceleration_timer = Timer.new()
				acceleration_timer.name = "IceAccelerationTimer"
				acceleration_timer.wait_time = 0.05  # Update speed 20 times per second for smooth acceleration
				acceleration_timer.connect("timeout", _on_acceleration_timeout)
				player.add_child(acceleration_timer)
				acceleration_timer.start()
		
		# Apply slippery effect by reducing friction
		player.friction = 0.2  # Same slippery factor as in ice_spot.gd
		print("Applied slippery effect, friction reduced to: ", player.friction)
		
		# Set the on_ice flag to prevent dodging
		player.set_meta("on_ice", true)

# Remove ice effects from the player directly from movement script
func remove_ice_effects_from_player():
	if player:
		# When toggling off ice, use sliding momentum instead of instantly stopping
		if player.has_meta("on_ice") and ice_spot_spawning_enabled == false:
			# Set medium friction for sliding (between ice and normal)
			if player.has_meta("original_friction"):
				player.friction = lerp(0.2, player.get_meta("original_friction"), 0.3)  
				print("Entered sliding state with friction: ", player.friction)
			
			# Keep current speed for sliding momentum
			if player.has_meta("original_run_speed") and player.has_meta("current_speed_multiplier"):
				var current_speed = player.run_speed
				print("Maintaining momentum at speed: ", current_speed)
				
				# Stop acceleration timer
				if player.has_node("IceAccelerationTimer"):
					var accel_timer = player.get_node("IceAccelerationTimer")
					accel_timer.stop()
					accel_timer.queue_free()
					print("Stopped acceleration timer")
				
				# Create sliding timer to gradually reduce speed
				if not player.has_node("SlidingMomentumTimer"):
					var sliding_timer = Timer.new()
					sliding_timer.name = "SlidingMomentumTimer"
					sliding_timer.wait_time = 0.05  # Update speed reduction 20 times per second
					sliding_timer.connect("timeout", _on_sliding_momentum_timeout)
					player.add_child(sliding_timer)
					sliding_timer.start()
					print("Started sliding momentum timer")
			
			# Change on_ice flag to sliding flag
			player.remove_meta("on_ice")
			player.set_meta("is_sliding", true)
			print("Player is now sliding")
		else:
			# Complete reset (for direct calls that aren't toggle-related)
			stop_sliding()

# Function to gradually increase player speed while on ice
func _on_acceleration_timeout():
	if player and is_instance_valid(player) and player.has_meta("on_ice"):
		var original_speed = player.get_meta("original_run_speed")
		var current_multiplier = player.get_meta("current_speed_multiplier")
		
		# Define speed increase properties here in PlayerMovement
		var speed_increase_rate = 0.8  # How quickly speed increases per second
		var max_speed_multiplier = 1.8  # Maximum speed cap (1.8 = 180% of normal speed)
		
		# Calculate new multiplier with gradual increase
		var new_multiplier = min(current_multiplier + (speed_increase_rate * 0.05), max_speed_multiplier)
		player.set_meta("current_speed_multiplier", new_multiplier)
		
		# Apply the new speed
		var new_speed = original_speed * new_multiplier
		player.run_speed = new_speed
		
		# Debug output every 0.2 seconds to avoid spamming the console
		if int(Time.get_ticks_msec() / 200) % 5 == 0:
			print("Gradually increasing speed: " + str(int(new_multiplier * 100)) + "% of original speed")

# Function to gradually decrease player speed during sliding
func _on_sliding_momentum_timeout():
	if player and is_instance_valid(player) and player.has_meta("is_sliding"):
		var original_speed = player.get_meta("original_run_speed")
		
		# Define sliding properties
		var sliding_deceleration_rate = 0.5		# Rate at which speed decreases (0.5 = 50% of previous speed each step)
		var min_sliding_speed_percentage = 0.10  # Stop sliding when reaching 10% of original speed
		
		# Gradually decrease speed
		var new_speed = player.run_speed * sliding_deceleration_rate
		
		# Calculate percentage of original speed
		var percentage_of_original = new_speed / original_speed
		
		# If speed is low enough, stop sliding
		if percentage_of_original <= min_sliding_speed_percentage:
			stop_sliding()
		else:
			# Apply gradually decreasing speed
			player.run_speed = new_speed
			
			# Gradually increase friction back to normal
			if player.has_meta("original_friction"):
				var target_friction = player.get_meta("original_friction")
				player.friction = lerp(player.friction, target_friction, 0.05)
			
			# Debug output every few updates
			if int(Time.get_ticks_msec() / 200) % 5 == 0:
				print("Sliding momentum: " + str(int(percentage_of_original * 100)) + "% of original speed")

# Function to finalize stopping sliding
func stop_sliding():
	if player:
		print("Player stopped sliding")
		
		# Restore original speed
		if player.has_meta("original_run_speed"):
			player.run_speed = player.get_meta("original_run_speed")
			player.remove_meta("original_run_speed")
		
		# Restore original friction
		if player.has_meta("original_friction"):
			player.friction = player.get_meta("original_friction")
			player.remove_meta("original_friction")
		
		# Stop and remove the sliding timer
		if player.has_node("SlidingMomentumTimer"):
			var sliding_timer = player.get_node("SlidingMomentumTimer")
			sliding_timer.stop()
			sliding_timer.queue_free()
			print("Removed sliding momentum timer")
		
		# Remove sliding flag
		if player.has_meta("is_sliding"):
			player.remove_meta("is_sliding")
		
		# Remove any other related metadata
		if player.has_meta("current_speed_multiplier"):
			player.remove_meta("current_speed_multiplier")
