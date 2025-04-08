extends Node2D

var player: CharacterBody2D = null
var grappling: bool = false
var hook_in_flight: bool = false  # New variable to track hook in flight
var grapple_point: Vector2 = Vector2.ZERO
var grapple_range: float = 500.0  # Maximum distance the grapple can travel
var swing_speed: float = 4.0  # Speed of the swing rotation
var swing_direction: int = 1  # 1 for clockwise, -1 for counter-clockwise
var swing_radius: float = 0.0  # Distance between player and grapple point
var grapple_projectile_scene: PackedScene = null
var current_grapple_projectile = null
var angle: float = 0.0

# Reference to the grapple rope for visualization
var grapple_rope: Node2D = null

func initialize(player_node: Node):
	player = player_node
	# Attempt to load the grapple hook scene
	if ResourceLoader.exists("res://scenes/grapple_hook.tscn"):
		grapple_projectile_scene = load("res://scenes/grapple_hook.tscn")
	else:
		push_error("Could not load grapple hook scene!")
	
	# Load the rope scene
	if ResourceLoader.exists("res://scenes/grapple_rope.tscn"):
		var rope_scene = load("res://scenes/grapple_rope.tscn")
		grapple_rope = rope_scene.instantiate()
		add_child(grapple_rope)
		grapple_rope.visible = false
	else:
		push_error("Could not load grapple rope scene!")

func _physics_process(delta):
	# Skip if player can't take actions
	if not player or not player.can_take_actions():
		if grappling or hook_in_flight:
			release_grapple()
		return
		
	# Debug output to check if R is detected
	if Input.is_action_just_pressed("grapple"):
		print("R key pressed! Trying to shoot grapple...")
		
	# Handle grapple input - Only allow shooting if no hook is in flight or attached
	if Input.is_action_just_pressed("grapple") and not grappling and not hook_in_flight:
		print("Shooting grapple hook!")
		shoot_grapple()
	
	# Handle release input
	if Input.is_action_just_released("grapple") and (grappling or hook_in_flight):
		release_grapple()
	
	# Process swing mechanics if grappling
	if grappling:
		process_swing(delta)
		
		# Control swing direction with left/right input
		if Input.is_action_pressed("ui_left"):
			swing_direction = -1
		elif Input.is_action_pressed("ui_right"):
			swing_direction = 1

func shoot_grapple():
	# First ensure any existing hooks are cleaned up
	if current_grapple_projectile and is_instance_valid(current_grapple_projectile):
		current_grapple_projectile.queue_free()
		current_grapple_projectile = null
	
	if not grapple_projectile_scene:
		print("No grapple hook scene available!")
		return
		
	# Set hook_in_flight flag
	hook_in_flight = true
	
	# Get the mouse position for aiming
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - player.global_position).normalized()
	
	# Create the grapple projectile
	current_grapple_projectile = grapple_projectile_scene.instantiate()
	get_tree().get_root().add_child(current_grapple_projectile)
	
	# Set initial position slightly away from player in the direction of throw
	# This helps prevent colliding with the player immediately
	var offset_distance = 30.0  # pixels
	var starting_position = player.global_position + (direction * offset_distance)
	
	# Setup the grapple projectile
	current_grapple_projectile.global_position = starting_position
	current_grapple_projectile.direction = direction
	current_grapple_projectile.max_distance = grapple_range
	current_grapple_projectile.owner_node = self
	current_grapple_projectile.initial_position = starting_position  # Update the initial position
	
	# Connect the hit signal
	if current_grapple_projectile.has_signal("grapple_hit"):
		current_grapple_projectile.connect("grapple_hit", on_grapple_hit)
	else:
		push_error("Grapple projectile does not have grapple_hit signal!")

func on_grapple_hit(target_position):
	grapple_point = target_position
	grappling = true
	hook_in_flight = false  # No longer in flight, now attached
	
	# Calculate the initial swing radius (distance from player to grapple point)
	swing_radius = player.global_position.distance_to(grapple_point)
	
	# Calculate initial angle
	angle = (player.global_position - grapple_point).angle()
	
	# Show and position the rope
	if grapple_rope:
		grapple_rope.visible = true
		update_rope_position()
	
	print("Hook attached at position: ", target_position)
	
	# The hook itself will stop moving due to the 'attached' flag we added

func process_swing(delta):
	# Update angle based on swing speed and direction
	angle += swing_direction * swing_speed * delta
	
	# Calculate new position based on angle and radius
	var new_pos = grapple_point + Vector2(cos(angle), sin(angle)) * swing_radius
	
	# Move the player to the new position
	player.velocity = (new_pos - player.global_position) / delta
	
	# Update rope position
	update_rope_position()

func update_rope_position():
	if grapple_rope:
		# Update rope start and end points
		grapple_rope.set_points(player.global_position, grapple_point)

func release_grapple():
	grappling = false
	hook_in_flight = false
	
	# Remove the grapple projectile if it exists
	if current_grapple_projectile and is_instance_valid(current_grapple_projectile):
		print("Deleting grapple hook")
		current_grapple_projectile.queue_free()
	current_grapple_projectile = null
	
	# Hide the rope
	if grapple_rope:
		grapple_rope.visible = false
	
	# Preserve momentum when releasing
	player.velocity = player.velocity.normalized() * player.run_speed * 1.5
