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
	
	# Call deferred to ensure the scene is fully loaded
	call_deferred("_position_entities")

func _update_center_position():
	# Calculate the center of the viewport
	var viewport = get_viewport()
	if viewport:
		center_position = viewport.get_visible_rect().size / 2
		info_log("Center position updated: " + str(center_position))

func _position_entities():
	# Position the dummy at center
	var dummy_manager = get_node_or_null("/root/GameWorld/Dummy Manager")
	if dummy_manager:
		var dummy = _find_first_dummy(dummy_manager)
		if dummy:
			position_dummy(dummy)
	
	# Position the player left of center
	var player = get_node_or_null("/root/GameWorld/Player")
	if player:
		position_player(player)
	
	# Ensure camera is properly positioned
	var camera = get_node_or_null("/root/GameWorld/Camera2D")
	if camera:
		# Set camera to follow the player if that's the desired behavior
		# Or set it to a fixed position if needed
		camera.position = Vector2.ZERO
		info_log("Camera position set to: " + str(camera.position))

func position_dummy(dummy):
	if dummy:
		# Center the dummy relative to the DummyManager
		var dummy_manager = dummy.get_parent()
		if dummy_manager:
			var manager_scale = dummy_manager.scale
			dummy.position = Vector2(
				(center_position.x - dummy_manager.position.x) / manager_scale.x,
				(center_position.y - dummy_manager.position.y) / manager_scale.y
			)
			print("Positioned dummy manager at:", center_position)
			print("Dummy global position:", dummy.global_position)

func position_player(player):
	if player:
		# Center the player relative to the viewport with an offset
		player.position = center_position + player_offset
		print("Positioned player at:", player.position)
		
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
