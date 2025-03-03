extends AnimatedSprite2D

var frame_time: float = 0.05  # Time per frame in seconds
var current_time: float = 0.0
var total_frames: int = 0

func _ready():
	# Stop auto animation
	stop()
	frame = 0
	
	# Basic error checking
	if not sprite_frames or sprite_frames.get_frame_count("default") == 0:
		push_error("Invalid sprite frames!")
		queue_free()
		return
	
	total_frames = sprite_frames.get_frame_count("default")
	
	
	# Backup cleanup timer
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = frame_time * (total_frames + 1)  # Extra time for safety
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(func(): queue_free())
	add_child(cleanup_timer)
	cleanup_timer.start()

func _process(delta: float) -> void:
	current_time += delta
	
	if current_time >= frame_time:
		current_time = 0.0
		frame += 1
		
		
		# If we've shown all frames, remove the effect
		if frame >= (total_frames - 1):  # -1 because frames are 0-based
			
			queue_free()
