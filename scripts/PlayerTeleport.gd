extends Node

# Teleport mechanic for the player

@export var teleport_distance: float = 200.0  # Distance of teleport in pixels, can be adjusted in inspector
@export var teleport_cooldown: float = 2.0  # Cooldown time in seconds, can be adjusted in inspector
@export var teleport_visual_indicator: bool = false  # Whether to show a visual indicator of teleport destination
@export var teleport_animation_speed: float = 1.0  # Custom animation speed for teleport animations

var player: Node = null
var sprite: AnimatedSprite2D = null
var is_teleporting: bool = false
var teleport_cooldown_timer: Timer
var can_teleport: bool = true
var left_click_pressed: bool = false  # Track left click for better attack vs teleport handling

# Add a visual indicator for teleport destination
var teleport_indicator: Node2D = null

func _ready():
	# Create cooldown timer
	teleport_cooldown_timer = Timer.new()
	teleport_cooldown_timer.one_shot = true
	teleport_cooldown_timer.wait_time = teleport_cooldown
	teleport_cooldown_timer.timeout.connect(_on_teleport_cooldown_timeout)
	add_child(teleport_cooldown_timer)
	
	# Create a simple visual indicator for teleport destination if enabled
	if teleport_visual_indicator:
		teleport_indicator = Node2D.new()
		var indicator_sprite = Sprite2D.new()
		# You can replace this with your own teleport indicator texture
		if ResourceLoader.exists("res://assets/arrow.png"):
			indicator_sprite.texture = load("res://assets/arrow.png")
		indicator_sprite.scale = Vector2(0.5, 0.5)
		teleport_indicator.add_child(indicator_sprite)
		teleport_indicator.visible = false
		add_child(teleport_indicator)

func initialize(player_node: Node):
	player = player_node
	
	# Get the AnimatedSprite2D
	if player.has_node("PlayerSprite"):
		sprite = player.get_node("PlayerSprite")
		print("Teleport controller initialized with player sprite")
	else:
		push_error("PlayerSprite not found. Teleport animations will not work.")

func _unhandled_input(event):
	# Track mouse button state for better input handling with attack system
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			left_click_pressed = event.pressed
			
			# If pressed and can teleport but player is attacking, don't teleport
			if event.pressed and can_teleport and player.can_take_actions():
				# Only teleport if the player isn't currently attacking
				if not player.attacking:
					teleport()
					# Prevent this click from also triggering an attack
					get_viewport().set_input_as_handled()
	# Check specifically for the "teleport" action
	if event.is_action_pressed("teleport") and can_teleport and player.can_take_actions():
		teleport()
		get_viewport().set_input_as_handled()

func _physics_process(_delta):
	if not player or not sprite:
		return
		
	# Update teleport indicator position if it exists and is visible
	if teleport_indicator and teleport_indicator.visible and can_teleport:
		var mouse_pos = get_viewport().get_mouse_position()
		var world_pos = get_viewport().get_canvas_transform().affine_inverse() * mouse_pos
		var direction = (world_pos - player.global_position).normalized()
		var indicator_position = player.global_position + (direction * teleport_distance)
		teleport_indicator.global_position = indicator_position
		
		# Rotate indicator to face the teleport direction
		teleport_indicator.rotation = direction.angle() + PI/2

# Show teleport indicator when player is holding the teleport key/button
func _input(event):
	if teleport_indicator and can_teleport and player and player.can_take_actions():
		if event.is_action("teleport"):
			teleport_indicator.visible = event.is_pressed()

func teleport():
	if is_teleporting:
		return
		
	# Start teleport sequence
	is_teleporting = true
	can_teleport = false
	player.teleporting = true
	
	# Hide teleport indicator during teleport
	if teleport_indicator:
		teleport_indicator.visible = false
	
	# Disable player movement and actions
	player.set_physics_process(false)
	
	# Save original speed scale to restore later
	var original_speed_scale = sprite.speed_scale
	
	# Set consistent animation speed for teleport animations
	sprite.speed_scale = teleport_animation_speed
	
	# Play teleport start animation
	sprite.animation_finished.connect(_on_teleport_start_animation_finished, CONNECT_ONE_SHOT)
	sprite.play("Teleport Start")
	
	print("Starting teleport sequence")

func _on_teleport_start_animation_finished():
	# Calculate teleport destination
	var mouse_pos = get_viewport().get_mouse_position()
	var world_pos = get_viewport().get_canvas_transform().affine_inverse() * mouse_pos
	
	# Get direction from player to mouse in world coordinates
	var direction = (world_pos - player.global_position).normalized()
	
	# Calculate new position
	var new_position = player.global_position + (direction * teleport_distance)
	
	# Store current position for reference if needed
	var old_position = player.global_position
	
	# Teleport the player
	player.global_position = new_position
	print("Teleported from " + str(old_position) + " to " + str(new_position))
	
	# Play teleport end animation (maintaining our custom speed)
	sprite.animation_finished.connect(_on_teleport_end_animation_finished, CONNECT_ONE_SHOT)
	sprite.play("Teleport End")

func _on_teleport_end_animation_finished():
	# Re-enable player movement and actions
	player.set_physics_process(true)
	
	# End teleport sequence
	is_teleporting = false
	player.teleporting = false
	
	# Let the animation system handle the speed scale from now on
	# It will be reset based on movement state in the next frame
	
	# Start cooldown
	teleport_cooldown_timer.start()
	print("Teleport completed, starting cooldown")

func _on_teleport_cooldown_timeout():
	can_teleport = true
	print("Teleport ready")

# Public function to check if teleport animation is playing
func is_teleport_animation_playing() -> bool:
	return is_teleporting
