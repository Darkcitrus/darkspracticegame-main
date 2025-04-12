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
func handle_ice_spots(delta):
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
