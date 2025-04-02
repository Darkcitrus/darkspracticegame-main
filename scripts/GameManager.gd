extends Node

# Debug settings
var debug_mode = false
@onready var debug_overlay = null

# Spawn position settings
var center_position = Vector2.ZERO
var player_offset = Vector2(-250, 0)  # Player spawns 250px left of center

# Fullscreen settings
var is_fullscreen = false
var last_f11_state = false

func _ready():
	# Calculate center position based on viewport size
	_update_center_position()
	
	# Connect to window resize signal to update positions if window changes
	get_tree().get_root().size_changed.connect(_update_center_position)

	# If we need autoloading of the debug logger
	if not has_node("/root/DebugLogger"):
		var logger_script = load("res://scripts/debug/DebugLogger.gd")
		var logger = Node.new()
		logger.set_script(logger_script)
		logger.name = "DebugLogger"
		get_tree().root.call_deferred("add_child", logger)
	
	# Defer the call to _position_entities to ensure all nodes are ready
	call_deferred("_position_entities")
	
	# Initialize fullscreen state - use the actual current window mode
	is_fullscreen = DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED
	print("Initial window mode: ", DisplayServer.window_get_mode(), " - Fullscreen: ", is_fullscreen)

func _input(event):
	# Handle F11 key specifically for fullscreen toggle
	if event is InputEventKey and event.keycode == KEY_F11 and event.pressed and not event.echo:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()  # Prevent the event from propagating

func _process(_delta):
	# Alternative F11 detection method as backup
	if Input.is_action_just_pressed("ui_fullscreen"):
		toggle_fullscreen()

func toggle_fullscreen():
	is_fullscreen = !is_fullscreen
	
	if is_fullscreen:
		# Go to fullscreen borderless mode
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		print("Entered fullscreen mode: ", DisplayServer.window_get_mode())
	else:
		# Go back to windowed mode
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		print("Exited fullscreen mode: ", DisplayServer.window_get_mode())
	
	# Ensure entities maintain their relative positions
	call_deferred("_update_center_position")
	call_deferred("_position_entities")

func _update_center_position():
	# Calculate the center of the viewport
	var viewport = get_viewport()
	if viewport:
		center_position = viewport.get_visible_rect().size / 2
		info_log("Center position updated: " + str(center_position))

func _position_entities():
	# Check for Dummy Manager
	var dummy_manager = get_node_or_null("Dummy Manager")
	if dummy_manager:
		var dummy = _find_first_dummy(dummy_manager)
		if dummy:
			position_dummy(dummy)
	
	# Check for Player
	var player = get_node_or_null("Player")
	if player:
		player.scale = Vector2(1, 1)  # Reset scale to avoid affecting position
		
		# Explicitly set the player's spawn position to the center of the viewport
		var target_pos = center_position + player_offset
		player.global_position = target_pos
		
		# Add a deferred call to verify the player's position
		call_deferred("_verify_player_position", player)

func position_dummy(dummy):
	if dummy:
		# Ensure the Dummy Manager is positioned at the center of the viewport
		var dummy_manager = dummy.get_parent()
		if dummy_manager:
			dummy_manager.global_position = center_position

		# Delegate dummy positioning to the Dummy Manager
		dummy_manager.call("reset_dummy_position", center_position)

func _enforce_dummy_position(dummy):
	if dummy and is_instance_valid(dummy):
		# Reapply the dummy's position to ensure no drift
		dummy.position = Vector2.ZERO

func position_player(player):
	if player:
		# Get the dummy's position to place the player relative to it
		var dummy = get_tree().get_first_node_in_group("Enemy")
		var target_pos = Vector2.ZERO
		
		if dummy:
			# Position player 250 pixels to the left of the dummy
			target_pos = dummy.global_position + Vector2(-250, 0)
		else:
			# Fallback to viewport center if no dummy
			target_pos = get_viewport().get_visible_rect().size / 2 + Vector2(-250, 0)
		
		# Reset transform and set position
		player.global_transform = Transform2D.IDENTITY
		player.global_position = target_pos
		
		# Force position again after a short delay
		get_tree().create_timer(0.1).timeout.connect(func(): _enforce_player_position(player, target_pos))
		get_tree().create_timer(0.5).timeout.connect(func(): _enforce_player_position(player, target_pos))

# New function specifically for enforcing position
func _enforce_player_position(player, target_pos):
	if player and is_instance_valid(player):
		player.global_position = target_pos

# Force player position regardless of other influences
func _force_player_position(player, target_pos):
	if player and is_instance_valid(player):
		var current_pos = player.global_position
		var distance = (current_pos - target_pos).length()
		
		if distance > 5.0:
			player.global_position = target_pos

# Helper function to get the full node path
func _get_node_path_to_root(node):
	var path = []
	var current = node
	
	while current:
		path.append({
			"name": current.name,
			"global_pos": current.global_position,
			"scale": current.scale
		})
		current = current.get_parent()
	
	return path

func _verify_player_position(player):
	if player:
		var viewport_center = get_viewport().get_visible_rect().size / 2
		var expected_pos = viewport_center + player_offset
		
		# Reapply if needed
		if (player.global_position - expected_pos).length() > 5.0:
			player.global_position = expected_pos

func _find_first_dummy(dummy_manager):
	for child in dummy_manager.get_children():
		if child.is_in_group("dummy"):
			return child
	return null

# Call this from Player, Dummy, etc. to log position data
func log_entity_position(entity):
	if not debug_mode or not has_node("/root/DebugLogger"):
		return
		
	var logger = get_node("/root/DebugLogger")
	var entity_type = "unknown"
	
	if entity.is_in_group("player"):
		entity_type = "player"
	elif entity.is_in_group("dummy"):
		entity_type = "dummy"
	elif entity is Camera2D:
		entity_type = "camera"
	
	logger.log_position(entity_type, entity.name, entity.position, entity.global_position)

# Helper function for consistent logging
func info_log(message):
	if has_node("/root/DebugLogger"):
		get_node("/root/DebugLogger").info(message, "GameManager")
