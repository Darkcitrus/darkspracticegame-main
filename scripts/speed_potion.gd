extends ItemPickup
class_name SpeedPotion

# Speed boost properties
@export var speed_multiplier: float = 1.5  # 50% increase per stack
@export var effect_duration: float = 5.0  # Each stack lasts 5 seconds
@export var max_stacks: int = 5  # Maximum number of speed boost stacks

# Store original values to restore when effect ends
var player_ref: Node = null
var original_move_speed: float = 0.0
var effect_timer: Timer
var effect_active: bool = false  # Track if any effect is active

# Stacking variables
var effect_stack_count: int = 0
var effect_timers: Array = []

func _ready():
	# Call parent _ready
	super()
	
	# Create a timer for the effect duration (this will be a template)
	effect_timer = Timer.new()
	effect_timer.one_shot = true
	effect_timer.wait_time = effect_duration
	add_child(effect_timer)
	
	# Set the glow color to a vibrant green color for speed
	glow_color = Color(0.0, 0.8, 0.2, 0.7)  # Green color
	glow_intensity = 1.2  # Slightly higher intensity
	glow_size = 2.0  # Default size
	
	# Set the oscillation speed and intensity
	oscillation_speed = 5.0  # Default speed
	oscillation_intensity = 5.0  # Default intensity
	
	print("Speed Potion initialized")

# Override can_be_picked_up_by to always allow pickup
func can_be_picked_up_by(player) -> bool:
	return true

# Override should_attract_to_player to always attract
func can_be_attracted_to_player() -> bool:
	return true

# Override apply_pickup_effect to apply the speed boost
func apply_pickup_effect(player):
	print("Applying speed boost effect to player")
	
	# Store reference to player
	player_ref = player
	
	# If this is the first stack, store original speed
	if not effect_active:
		effect_active = true
		original_move_speed = player.run_speed
		print("Original move speed:", original_move_speed)
	
	# Increment stack count
	effect_stack_count += 1
	if effect_stack_count > max_stacks:
		effect_stack_count = max_stacks
		print("Maximum speed stacks reached: ", max_stacks)
	
	# Create a new timer for this stack
	var stack_timer = Timer.new()
	stack_timer.one_shot = true
	stack_timer.wait_time = effect_duration
	player_ref.add_child(stack_timer)
	stack_timer.connect("timeout", _on_stack_timer_timeout.bind(stack_timer))
	stack_timer.start()
	effect_timers.append(stack_timer)
	
	# Apply updated effect based on current stack count
	apply_stacked_effect()
	
	# Show floating text to indicate the effect
	spawn_floating_effect_text(player)

# Apply the speed boost based on current stack count
func apply_stacked_effect():
	if not is_instance_valid(player_ref):
		return
		
	# Calculate total multiplier based on stacks
	# For example, with speed_multiplier = 1.5, each stack gives 0.5 (50%) boost
	var total_multiplier = 1.0 + (effect_stack_count * (speed_multiplier - 1.0))
	print("Speed boost stacks: ", effect_stack_count, " - Total multiplier: ", total_multiplier)
	
	# Apply movement speed boost
	player_ref.run_speed = original_move_speed * total_multiplier
	print("Move speed increased to:", player_ref.run_speed)

# Function to handle when a stack timer expires
func _on_stack_timer_timeout(timer):
	if timer in effect_timers:
		effect_timers.erase(timer)
		timer.queue_free()
		
		# Decrement stack count
		effect_stack_count -= 1
		print("Speed boost stack expired. Remaining stacks: ", effect_stack_count)
		
		# If stacks remain, reapply effect with reduced stacks
		if effect_stack_count > 0:
			apply_stacked_effect()
		else:
			# No stacks remain, return to normal values
			reset_speed()
			effect_active = false
			print("All speed boost stacks expired")

# Reset speed to original value
func reset_speed():
	if is_instance_valid(player_ref):
		player_ref.run_speed = original_move_speed
		print("Move speed restored to:", original_move_speed)

# Helper function to display floating text
func spawn_floating_effect_text(player):
	# Try to use the floating number scene if available
	var floating_number_scene = load("res://scenes/floating_number.tscn")
	if floating_number_scene:
		var floating_text = floating_number_scene.instantiate()
		get_tree().get_root().add_child(floating_text)
		
		# Calculate bonus percentage based on current stacks
		var stack_bonus = int(effect_stack_count * (speed_multiplier - 1.0) * 100)
		
		# Display stack percentage
		if floating_text.has_method("setup_heal"):
			floating_text.setup_heal(stack_bonus, player.global_position)
		else:
			print("Could not display floating text - setup_heal method not found")
