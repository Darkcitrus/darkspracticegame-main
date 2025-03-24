extends Node  # Changed from Node2D to Node to match the node type

# Variables for player positioning
var center_position = Vector2.ZERO
var player_offset = Vector2(100, 0)  # Example offset, adjust as needed
var expected_position = Vector2.ZERO
var position_history = []  # Track recent positions
var is_tracking = true

func _ready():
	# Let GameManager handle initial positioning
	# Just set up tracking
	call_deferred("force_camera_settings")
	get_tree().create_timer(0.05).timeout.connect(force_camera_settings)
	get_tree().create_timer(0.2).timeout.connect(force_camera_settings)
	
	# Add position tracking timer
	var tracking_timer = Timer.new()
	tracking_timer.name = "PositionTrackingTimer"
	add_child(tracking_timer)
	tracking_timer.wait_time = 0.2
	tracking_timer.timeout.connect(track_player_position)
	tracking_timer.start()
	
	# Add camera check timer
	var camera_timer = Timer.new()
	camera_timer.name = "CameraCheckTimer"
	add_child(camera_timer)
	camera_timer.wait_time = 1.0
	camera_timer.timeout.connect(force_camera_settings)
	camera_timer.start()
	
	# Schedule debug info
	get_tree().create_timer(0.3).timeout.connect(debug_player_initial)
	get_tree().create_timer(1.0).timeout.connect(debug_player_delayed)

func track_player_position():
	var player = get_parent()
	if player:
		# Log the player's position for debugging
		print("PlayerDebug: Tracking player position. Current global position:", player.global_position)
		print("PlayerDebug: Expected position:", expected_position)
		print("PlayerDebug: Distance from expected position:", (player.global_position - expected_position).length())

		# Ensure this script does not modify the player's position
		print("PlayerDebug: Position tracking only, no corrections applied.")

func enforce_camera_and_positions():
	# Enforce camera settings
	force_camera_settings()
	
	# IMPORTANT: Remove any code that forces player position
	# Let the GameManager handle positioning
	
	# Check positions periodically
	debug_player_periodic()

func force_camera_settings():
	var camera = player_find_camera()
	if camera:
		camera.position = Vector2.ZERO
		camera.enabled = true
		camera.anchor_mode = 1  # Drag center mode (0,0) at center
		camera.make_current()
		camera.reset_smoothing()
		print("Camera settings enforced: pos=", camera.position, ", enabled=", camera.enabled, 
			  ", mode=", camera.anchor_mode)
	else:
		print("WARNING: No camera found to configure!")

func debug_player_initial():
	var player = get_parent()
	
	# IMPORTANT: Don't set player position here at all
	# This conflicts with GameManager's positioning
	
	# Just print debug info
	print("Player full path:", player.get_path())
	print("========== PLAYER INITIAL DEBUG ==========")
	print("Player name:", player.name)
	print("Initial position:", player.position)
	print("Initial global position:", player.global_position)
	var parent = player.get_parent()
	print("Parent:", parent.name if parent else "none")
	print("Parent transform:", parent.global_transform if parent else "none")
	print("Viewport size:", player.get_viewport_rect().size)
	print("Scale:", player.scale)
	print("Camera position:", find_camera_position())
	print("Project window size:", DisplayServer.window_get_size())
	print("=========================================")

func debug_player_delayed():
	var player = get_parent()
	print("========== PLAYER DELAYED DEBUG ==========")
	print("Player name:", player.name)
	print("Current position:", player.position)
	print("Current global position:", player.global_position)
	print("Camera position:", find_camera_position())
	
	# Get the camera and check its properties
	var camera = player_find_camera()
	if camera:
		print("Camera enabled:", camera.enabled)
		print("Camera anchor mode:", camera.anchor_mode)
		print("Camera zoom:", camera.zoom)
		
		# Force camera settings
		camera.enabled = true
		camera.anchor_mode = 1  # Drag center mode (0,0) at center
		print("Camera settings enforced: enabled=true, anchor_mode=1")
	
	print("=========================================")

func debug_player_periodic():
	var player = get_parent()
	print("Player periodic check - Position:", player.position, "Global:", player.global_position)
	
	# Check camera is still correct
	var camera = player_find_camera()
	if camera and camera.anchor_mode != 1:
		print("WARNING: Camera anchor mode changed to", camera.anchor_mode, "- resetting to 1")
		camera.anchor_mode = 1
		camera.make_current()

func find_camera_position():
	var camera = player_find_camera()
	if camera:
		return "Pos: " + str(camera.position) + ", Global: " + str(camera.global_position) + ", Mode: " + str(camera.anchor_mode)
	else:
		return "No camera found"
		
func player_find_camera():
	# Try to find camera in different ways
	var camera = get_viewport().get_camera_2d()
	if camera:
		return camera
		
	# Try to find in scene
	var root = get_tree().root
	return root.find_child("Camera2D", true, false)

# Add this new function to toggle position tracking
func toggle_tracking():
	is_tracking = !is_tracking
	print("Position tracking: " + ("ON" if is_tracking else "OFF"))
