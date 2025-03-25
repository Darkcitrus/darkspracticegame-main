extends Node  # Changed from Node2D to Node to match the node type

# Variables for player positioning
var center_position = Vector2.ZERO
var player_offset = Vector2(100, 0)  # Example offset, adjust as needed
var expected_position = Vector2.ZERO
var position_history = []  # Track recent positions
var is_tracking = true

func _ready():
	# Remove camera control, let the editor handle it
	
	# Add position tracking timer
	var tracking_timer = Timer.new()
	tracking_timer.name = "PositionTrackingTimer"
	add_child(tracking_timer)
	tracking_timer.wait_time = 0.2
	tracking_timer.timeout.connect(track_player_position)
	tracking_timer.start()
	
	# Schedule debug info
	get_tree().create_timer(0.3).timeout.connect(debug_player_initial)
	get_tree().create_timer(1.0).timeout.connect(debug_player_delayed)

func track_player_position():
	var player = get_parent()
	if player:
		# Log the player's position for debugging
		print("PlayerDebug: Tracking player position. Current global position:", player.global_position)

		# Log the dummy's position without modifying it
		var dummy = player.get_node_or_null("../Dummy Manager/Dummy")
		if dummy:
			print("PlayerDebug: Dummy position tracking only. Current global position:", dummy.global_position)

func enforce_camera_and_positions():
	# Let the editor handle camera settings
	
	# Check positions periodically
	debug_player_periodic()

func debug_player_initial():
	var player = get_parent()
	
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
	print("Project window size:", DisplayServer.window_get_size())
	print("=========================================")

func debug_player_delayed():
	var player = get_parent()
	print("========== PLAYER AND DUMMY DELAYED DEBUG ==========")
	print("Player name:", player.name)
	print("Player current global position:", player.global_position)

	# Get the dummy and verify its position
	var dummy = player.get_node_or_null("../Dummy Manager/Dummy")
	if dummy:
		print("Dummy name:", dummy.name)
		print("Dummy current position:", dummy.position)
		print("Dummy current global position:", dummy.global_position)
	print("=========================================")

func debug_player_periodic():
	var player = get_parent()
	print("Player periodic check - Position:", player.position, "Global:", player.global_position)

# Add this new function to toggle position tracking
func toggle_tracking():
	is_tracking = !is_tracking
	print("Position tracking: " + ("ON" if is_tracking else "OFF"))
