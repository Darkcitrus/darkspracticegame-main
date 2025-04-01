extends ItemPickup
class_name AttackSpeedCrystal

# Speed boost properties
@export var attack_speed_multiplier: float = 1.25  # 25% increase per stack
@export var effect_duration: float = 5.0  # Each stack lasts 5 seconds
@export var apply_to_melee: bool = true
@export var apply_to_fireball: bool = true
@export var apply_to_auto_attack: bool = true

# Store original values to restore when effect ends
var player_ref: Node = null
var original_melee_cooldown: float = 0.0
var original_fireball_cooldown: float = 0.0
var original_auto_cooldown: float = 0.0
var effect_timer: Timer
var effect_active: bool = false  # Track if any effect is active

# Stacking variables
var effect_stack_count: int = 0
var effect_timers: Array = []
var max_stacks: int = 5  # Optional limit to maximum stacks

func _ready():
	# Call parent _ready
	super()
	
	# Create a timer for the effect duration (this will be a template)
	effect_timer = Timer.new()
	effect_timer.one_shot = true
	effect_timer.wait_time = effect_duration
	add_child(effect_timer)
	
	# Set the glow color to a cyan/blue color for speed
	glow_color = Color(0.0, 0.3, 8.0, 1.0)  # Cyan/blue color
	glow_intensity = 1.5  # Slightly higher intensity for speed
	glow_size = 2.0  # Default size for speed
	glow_radius = 32.0  # Default radius for speed
	glow_pulse_speed = 2.0  # Default pulse speed for speed
	# Set the oscillation speed and intensity for the crystal
	oscillation_speed = 5.0  # Default speed for speed
	oscillation_intensity = 5.0  # Default intensity for speed
	
	print("Attack Speed Crystal initialized")

# Override can_be_picked_up_by to always allow pickup
func can_be_picked_up_by(player) -> bool:
	return true

# Override apply_pickup_effect to apply the speed boost
func apply_pickup_effect(player):
	print("Applying attack speed boost effect to player")
	
	# Store reference to player
	player_ref = player
	
	# If this is the first stack, store original cooldowns
	if not effect_active:
		effect_active = true
		original_melee_cooldown = player.attack_cooldown
		
		# Find PlayerAttack node and store original cooldowns
		var player_attack = player.get_node_or_null("PlayerAttack")
		if player_attack:
			original_fireball_cooldown = player_attack.FIREBALL_COOLDOWN
			original_auto_cooldown = player_attack.AUTO_ATTACK_COOLDOWN
	
	# Increment stack count
	effect_stack_count += 1
	if effect_stack_count > max_stacks:
		effect_stack_count = max_stacks
		print("Maximum attack speed stacks reached: ", max_stacks)
	
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
		
	# Calculate total multiplier based on stacks: each stack gives attack_speed_multiplier - 1 boost
	# For example, with attack_speed_multiplier = 1.25, each stack gives 0.25 (25%) boost
	var total_multiplier = 1.0 + (effect_stack_count * (attack_speed_multiplier - 1.0))
	print("Attack speed boost stacks: ", effect_stack_count, " - Total multiplier: ", total_multiplier)
	
	# Apply melee attack speed boost
	if apply_to_melee:
		player_ref.attack_cooldown = original_melee_cooldown / total_multiplier
		print("Melee cooldown reduced to", player_ref.attack_cooldown)
	
	# Apply fireball and auto-attack cooldowns
	var player_attack = player_ref.get_node_or_null("PlayerAttack")
	if player_attack:
		if apply_to_fireball:
			player_attack.FIREBALL_COOLDOWN = original_fireball_cooldown / total_multiplier
			print("Fireball cooldown reduced to", player_attack.FIREBALL_COOLDOWN)
		
		if apply_to_auto_attack:
			player_attack.AUTO_ATTACK_COOLDOWN = original_auto_cooldown / total_multiplier
			print("Auto-attack cooldown reduced to", player_attack.AUTO_ATTACK_COOLDOWN)

# Function to handle when a stack timer expires
func _on_stack_timer_timeout(timer):
	if timer in effect_timers:
		effect_timers.erase(timer)
		timer.queue_free()
		
		# Decrement stack count
		effect_stack_count -= 1
		print("Attack speed stack expired. Remaining stacks: ", effect_stack_count)
		
		# If stacks remain, reapply effect with reduced stacks
		if effect_stack_count > 0:
			apply_stacked_effect()
		else:
			# No stacks remain, return to normal values
			reset_cooldowns()
			effect_active = false
			print("All attack speed stacks expired")

# Reset all cooldowns to original values
func reset_cooldowns():
	if is_instance_valid(player_ref):
		# Reset melee cooldown
		if apply_to_melee:
			player_ref.attack_cooldown = original_melee_cooldown
			print("Melee cooldown restored to", original_melee_cooldown)
		
		# Reset fireball and auto-attack cooldowns
		var player_attack = player_ref.get_node_or_null("PlayerAttack")
		if player_attack:
			if apply_to_fireball:
				player_attack.FIREBALL_COOLDOWN = original_fireball_cooldown
				print("Fireball cooldown restored to", original_fireball_cooldown)
			
			if apply_to_auto_attack:
				player_attack.AUTO_ATTACK_COOLDOWN = original_auto_cooldown
				print("Auto-attack cooldown restored to", original_auto_cooldown)

# Helper function to display floating text
func spawn_floating_effect_text(player):
	# Try to use the floating number scene if available
	var floating_number_scene = load("res://scenes/floating_number.tscn")
	if floating_number_scene:
		var floating_text = floating_number_scene.instantiate()
		get_tree().get_root().add_child(floating_text)
		
		# Calculate bonus percentage based on current stacks
		var stack_bonus = int(effect_stack_count * (attack_speed_multiplier - 1.0) * 100)
		
		# Display stack percentage
		if floating_text.has_method("setup_heal"):
			floating_text.setup_heal(stack_bonus, player.global_position)
		else:
			print("Could not display floating text - setup_heal method not found")
