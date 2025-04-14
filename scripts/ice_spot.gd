extends Area2D

# Ice spot properties
var slippery_factor = 0.2  # Lower friction = more slippery (0.0 would be no friction)
var current_player = null
var lifetime = 2.0  # Time in seconds before disappearing

# Speed acceleration properties
var speed_increase_rate = 0.8  # How quickly speed increases per second
var max_speed_multiplier = 3  # Maximum speed cap (1.8 = 180% of normal speed)
var acceleration_timer = null

# Sliding momentum properties
var sliding_deceleration_rate = 0.90  # Rate at which speed decreases (0.90 = 90% of previous speed each step)
var min_sliding_speed_percentage = 0.25  # Stop sliding when reaching 25% of original speed

func _ready():
	# Connect signals for when bodies enter/exit the ice spot with proper Godot 4 syntax
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Set up proper collision layer/mask
	collision_layer = 4  # Using layer 4 for hazards/effects
	collision_mask = 1   # Assuming player is on layer 1
	
	# Set z_index to be below the player (-1 means rendered below)
	z_index = -1
	
	# Set up a timer to make the ice spot disappear after the lifetime
	var disappear_timer = Timer.new()
	disappear_timer.wait_time = lifetime
	disappear_timer.one_shot = true
	disappear_timer.connect("timeout", _on_disappear_timeout)
	add_child(disappear_timer)
	disappear_timer.start()

func _on_disappear_timeout():
	# Fade out effect before removing the ice spot
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
	print("Ice spot disappearing")

func _on_body_entered(body):
	if body.is_in_group("Player"):
		print("Player stepped on ice spot!")
		current_player = body
		
		# Use a counter to track how many ice spots the player is on
		if not body.has_meta("ice_spot_count"):
			body.set_meta("ice_spot_count", 0)
			
		# Increment the counter
		var count = body.get_meta("ice_spot_count") + 1
		body.set_meta("ice_spot_count", count)
		print("Player now on " + str(count) + " ice spot(s)")
		
		# Apply slippery effect to player (only need to do this once)
		apply_slippery_effect(body)

func _on_body_exited(body):
	if body.is_in_group("Player") and current_player == body:
		# Decrement the counter
		if body.has_meta("ice_spot_count"):
			var count = body.get_meta("ice_spot_count") - 1
			body.set_meta("ice_spot_count", count)
			print("Player now on " + str(count) + " ice spot(s)")
			
			# Only remove effect when all ice spots are exited
			if count <= 0:
				print("Player left all ice spots")
				remove_slippery_effect(body)
				body.remove_meta("ice_spot_count")

func apply_slippery_effect(player):
	# Store original friction value if it exists
	if not player.has_meta("original_friction"):
		player.set_meta("original_friction", player.friction if "friction" in player else 1.0)
	
	# Store original speed if this is the first ice spot
	if not player.has_meta("original_run_speed"):
		player.set_meta("original_run_speed", player.run_speed)
		player.set_meta("current_speed_multiplier", 1.0)
		print("Starting gradual speed acceleration on ice from base speed: " + str(player.get_meta("original_run_speed")))
		
		# Set up acceleration timer if this is the first ice spot
		if not player.has_node("IceAccelerationTimer"):
			acceleration_timer = Timer.new()
			acceleration_timer.name = "IceAccelerationTimer"
			acceleration_timer.wait_time = 0.05  # Update speed 20 times per second for smooth acceleration
			acceleration_timer.connect("timeout", _on_acceleration_timeout.bind(player))
			player.add_child(acceleration_timer)
			acceleration_timer.start()
	
	# Apply slippery effect by reducing friction (make it even more slippery)
	player.friction = slippery_factor
	print("Applied slippery effect, friction reduced to: ", slippery_factor)
	
	# Also store that player is on ice for better sliding mechanics
	player.set_meta("on_ice", true)

func remove_slippery_effect(player):
	# When leaving ice, don't immediately reset friction - enter sliding state
	if player.has_meta("original_friction"):
		# Set a medium friction value for sliding (between ice and normal)
		player.friction = lerp(slippery_factor, player.get_meta("original_friction"), 0.3)
		print("Entered sliding state with friction: ", player.friction)
	
	# Don't restore original speed yet - maintain momentum
	if player.has_meta("original_run_speed") and player.has_meta("current_speed_multiplier"):
		# Keep current speed for sliding
		var current_speed = player.run_speed
		print("Maintaining momentum with speed: ", current_speed)
		
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
			sliding_timer.connect("timeout", _on_sliding_momentum_timeout.bind(player))
			player.add_child(sliding_timer)
			sliding_timer.start()
			print("Started sliding momentum timer")
	
	# Change on_ice flag to sliding flag
	if player.has_meta("on_ice"):
		player.remove_meta("on_ice")
		player.set_meta("is_sliding", true)
		print("Player is now sliding")

# Function to gradually increase player speed while on ice
func _on_acceleration_timeout(player):
	if player and is_instance_valid(player) and player.has_meta("on_ice"):
		var original_speed = player.get_meta("original_run_speed")
		var current_multiplier = player.get_meta("current_speed_multiplier")
		
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
func _on_sliding_momentum_timeout(player):
	if player and is_instance_valid(player) and player.has_meta("is_sliding"):
		var original_speed = player.get_meta("original_run_speed")
		
		# Gradually decrease speed (multiply by sliding_deceleration_rate)
		var new_speed = player.run_speed * sliding_deceleration_rate
		
		# Calculate percentage of original speed
		var percentage_of_original = new_speed / original_speed
		
		# If speed is low enough, stop sliding
		if percentage_of_original <= min_sliding_speed_percentage:
			stop_sliding(player)
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
func stop_sliding(player):
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
