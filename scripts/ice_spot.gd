extends Area2D

# Ice spot properties
var slippery_factor = 0.2  # Lower friction = more slippery (0.0 would be no friction)
var current_player = null
var lifetime = 2.0  # Time in seconds before disappearing

# Speed acceleration properties
var speed_increase_rate = 0.8  # How quickly speed increases per second
var max_speed_multiplier = 3  # Maximum speed cap (1.8 = 180% of normal speed)
var acceleration_timer = null

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
	# Restore original friction if we have it stored
	if player.has_meta("original_friction"):
		player.friction = player.get_meta("original_friction")
		print("Removed slippery effect, friction restored to: ", player.get_meta("original_friction"))
	
	# Restore original speed if we increased it
	if player.has_meta("original_run_speed"):
		player.run_speed = player.get_meta("original_run_speed")
		print("Restored player speed from ice to: ", player.run_speed)
		player.remove_meta("original_run_speed")
		player.remove_meta("current_speed_multiplier")
		
		# Stop and remove the acceleration timer
		if player.has_node("IceAccelerationTimer"):
			var timer = player.get_node("IceAccelerationTimer")
			timer.stop()
			timer.queue_free()
			print("Stopped speed acceleration timer")
	
	# Remove the on_ice flag
	if player.has_meta("on_ice"):
		player.remove_meta("on_ice")

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
