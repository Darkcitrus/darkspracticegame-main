extends Node

# Variables for player positioning
var center_position = Vector2.ZERO
var player_offset = Vector2(100, 0)  # Example offset, adjust as needed

func _ready():
	# Force camera settings immediately and after a short delay
	call_deferred("force_camera_settings")
	get_tree().create_timer(0.05).timeout.connect(force_camera_settings)
	get_tree().create_timer(0.2).timeout.connect(force_camera_settings)
	
	# Give time for the scene to initialize
	get_tree().create_timer(0.1).timeout.connect(debug_player_initial)
	get_tree().create_timer(1.0).timeout.connect(debug_player_delayed)
	
	# Add a periodic position check and camera enforcement
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.5
	timer.timeout.connect(enforce_camera_and_positions)
	timer.start()

func enforce_camera_and_positions():
	# Enforce camera settings
	force_camera_settings()
	
	# Keep player at origin for testing
	var player = get_parent()
	player.position = Vector2.ZERO
	
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
	player.position = center_position + player_offset
	print("Player initial position set to:", player.position)
	print("========== PLAYER INITIAL DEBUG ==========")
	print("Player name:", player.name)
	print("Initial position:", player.position)
	print("Initial global position:", player.global_position)
	var parent = player.get_parent()
	print("Parent:", parent.name if parent else "none")
	print("Viewport size:", player.get_viewport_rect().size)
	print("Viewport position:", player.get_viewport_rect().position)
	print("Scale:", player.scale)
	print("Camera position:", find_camera_position())
	
	# Check project settings
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
	
	# Force position to center for testing
	player.position = Vector2.ZERO
	print("RESET player position to (0,0)")
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
