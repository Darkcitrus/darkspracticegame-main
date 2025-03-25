extends Node

# Debug settings
var debug_mode = false
@onready var debug_overlay = null

# Spawn position settings
var center_position = Vector2.ZERO
var player_offset = Vector2(-250, 0)  # Player spawns 250px left of center

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
	print("GameManager: _ready called. Initialization deferred until all nodes are ready.")

func _update_center_position():
	# Calculate the center of the viewport
	var viewport = get_viewport()
	if viewport:
		center_position = viewport.get_visible_rect().size / 2
		info_log("Center position updated: " + str(center_position))
		print("GameManager: Center position updated to:", center_position)

func _position_entities():
	print("GameManager: _position_entities called. Repositioning entities.")

	# Check for Dummy Manager
	var dummy_manager = get_node_or_null("Dummy Manager")
	if dummy_manager:
		print("GameManager: Found Dummy Manager.")
		var dummy = _find_first_dummy(dummy_manager)
		if dummy:
			print("GameManager: Found first dummy. Positioning dummy.")
			position_dummy(dummy)
		else:
			print("GameManager: No dummy found in Dummy Manager.")
	else:
		print("GameManager: Dummy Manager not found.")

	# Check for Player
	var player = get_node_or_null("Player")
	if player:
		print("GameManager: Found Player node. Positioning player.")
		player.scale = Vector2(1, 1)  # Reset scale to avoid affecting position
		
		# Explicitly set the player's spawn position to the center of the viewport
		var target_pos = center_position + player_offset
		player.global_position = target_pos
		print("GameManager: Player positioned at:", target_pos, "with scale reset to:", player.scale)
		print("GameManager: Player global position after positioning:", player.global_position)
		
		# Add a deferred call to verify the player's position
		call_deferred("_verify_player_position", player)
	else:
		print("GameManager: Player node not found.")

	# No longer controlling Camera2D, letting editor handle it
	print("GameManager: Camera2D control removed, editor has full control.")

	# Log final positions for debugging
	print("GameManager: Final player position:", player.global_position if player else "Player not found.")

func position_dummy(dummy):
	if dummy:
		# Ensure the Dummy Manager is positioned at the center of the viewport
		var dummy_manager = dummy.get_parent()
		if dummy_manager:
			dummy_manager.global_position = center_position
			print("GameManager: Positioned Dummy Manager at center:", center_position)

		# Delegate dummy positioning to the Dummy Manager
		dummy_manager.call("reset_dummy_position", center_position)
		print("GameManager: Delegated dummy positioning to Dummy Manager.")

func _enforce_dummy_position(dummy):
	if dummy and is_instance_valid(dummy):
		# Reapply the dummy's position to ensure no drift
		dummy.position = Vector2.ZERO
		print("GameManager: Enforced dummy position during deferred call. Current position:", dummy.position)
		print("GameManager: Dummy global position after enforcement:", dummy.global_position)

func position_player(player):
	if player:
		# Get the dummy's position to place the player relative to it
		var dummy = get_tree().get_first_node_in_group("Enemy")
		var target_pos = Vector2.ZERO
		
		if dummy:
			# Position player 250 pixels to the left of the dummy
			target_pos = dummy.global_position + Vector2(-250, 0)
			print("POSITIONING: Player will be placed relative to dummy at:", dummy.global_position)
		else:
			# Fallback to viewport center if no dummy
			target_pos = get_viewport().get_visible_rect().size / 2 + Vector2(-250, 0)
			print("POSITIONING: No dummy found, using viewport center")
		
		# Reset transform and set position
		player.global_transform = Transform2D.IDENTITY
		player.global_position = target_pos
		
		# Force position again after a short delay
		get_tree().create_timer(0.1).timeout.connect(func(): _enforce_player_position(player, target_pos))
		get_tree().create_timer(0.5).timeout.connect(func(): _enforce_player_position(player, target_pos))
		
		print("POSITIONING: Set player global_position to:", target_pos)
		print("POSITIONING: Player actual global_position:", player.global_position)

# New function specifically for enforcing position
func _enforce_player_position(player, target_pos):
	if player and is_instance_valid(player):
		player.global_position = target_pos
		print("ENFORCED Player position to:", target_pos)

# Force player position regardless of other influences
func _force_player_position(player, target_pos):
	if player and is_instance_valid(player):
		var current_pos = player.global_position
		var distance = (current_pos - target_pos).length()
		
		if distance > 5.0:
			print("CORRECTING PLAYER: Current global:", current_pos, ", Target:", target_pos)
			player.global_position = target_pos
			
			# Debug various properties
			print("Player global_transform:", player.global_transform)
			print("Player transform:", player.transform)
			print("Player position:", player.position)

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
		print("GameManager: Verifying player position after deferred call. Current position:", player.global_position)
		var viewport_center = get_viewport().get_visible_rect().size / 2
		var expected_pos = viewport_center + player_offset
		
		print("VERIFY - Player position expected:", expected_pos)
		print("VERIFY - Player global position actual:", player.global_position)
		
		# Reapply if needed
		if (player.global_position - expected_pos).length() > 5.0:
			print("CORRECTING player position")
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
	print(message)
	if has_node("/root/DebugLogger"):
		get_node("/root/DebugLogger").info(message, "GameManager")
