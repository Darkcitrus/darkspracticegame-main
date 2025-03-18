extends Node

func _ready():
	# Wait a fraction of a second to let the scene initialize
	await get_tree().create_timer(0.1).timeout
	
	# Find and configure camera
	var camera = get_viewport().get_camera_2d()
	if camera:
		print("CameraEnforcer: Found camera, enforcing settings")
		enforce_camera_settings(camera)
	else:
		print("CameraEnforcer: No existing camera found, creating one")
		create_and_configure_camera()

func _process(_delta):
	# Continuously ensure camera settings (run a few times then disable)
	if Engine.get_frames_drawn() < 10 or Engine.get_frames_drawn() % 30 == 0:
		var camera = get_viewport().get_camera_2d()
		if camera:
			enforce_camera_settings(camera)

func enforce_camera_settings(camera):
	camera.position = Vector2.ZERO
	camera.enabled = true
	camera.anchor_mode = 1  # Drag center mode (0,0) at center
	
	# These settings help ensure stability
	camera.position_smoothing_enabled = false
	camera.drag_horizontal_enabled = false
	camera.drag_vertical_enabled = false
	
	# Make it current and reset any smoothing
	camera.make_current()
	camera.reset_smoothing()

func create_and_configure_camera():
	var new_camera = Camera2D.new()
	new_camera.name = "EnforcedCamera2D"
	new_camera.position = Vector2.ZERO
	new_camera.enabled = true
	new_camera.anchor_mode = 1
	add_child(new_camera)
	new_camera.make_current()
	print("CameraEnforcer: Created and configured new camera")
