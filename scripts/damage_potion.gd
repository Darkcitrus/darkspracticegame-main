extends ItemPickup
class_name DamagePotion

# Damage boost properties
@export var damage_multiplier: float = 1.3  # 30% increase per stack
@export var effect_duration: float = 5.0  # Each stack lasts 5 seconds
@export var apply_to_melee: bool = true
@export var apply_to_fireball: bool = true
@export var apply_to_auto_attack: bool = true

# Store original values to restore when effect ends
var player_ref: Node = null
var original_attack_power: float = 0.0
var original_fireball_damage: float = 0.0
var original_auto_attack_damage: float = 0.0
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
	
	# Set the glow color to a red color for damage
	glow_color = Color(1.0, 0.2, 0.2, 1.0)  # Red color
	glow_intensity = 1.5  # Slightly higher intensity
	glow_size = 2.0  # Default size
	glow_radius = 32.0  # Default radius
	glow_pulse_speed = 2.0  # Default pulse speed
	# Set the oscillation speed and intensity
	oscillation_speed = 5.0  # Default speed
	oscillation_intensity = 5.0  # Default intensity
	
	print("Damage Potion initialized")

# Override can_be_picked_up_by to always allow pickup
func can_be_picked_up_by(player) -> bool:
	return true

# Override apply_pickup_effect to apply the damage boost
func apply_pickup_effect(player):
	print("Applying damage boost effect to player")
	
	# Store reference to player
	player_ref = player
	
	# If this is the first stack, store original values
	if not effect_active:
		effect_active = true
		original_attack_power = player.attack_power
		
		# Find PlayerAttack node and store original values
		var player_attack = player.get_node_or_null("PlayerAttack")
		if player_attack:
			original_auto_attack_damage = player_attack.AUTO_ATTACK_DAMAGE
			# Fireball damage is calculated based on player's attack_power, so we don't store it separately
	
	# Increment stack count
	effect_stack_count += 1
	if effect_stack_count > max_stacks:
		effect_stack_count = max_stacks
		print("Maximum damage stacks reached: ", max_stacks)
	
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

# Apply the damage boost based on current stack count
func apply_stacked_effect():
	if not is_instance_valid(player_ref):
		return
		
	# Calculate total multiplier based on stacks: each stack gives damage_multiplier - 1 boost
	# For example, with damage_multiplier = 1.3, each stack gives 0.3 (30%) boost
	var total_multiplier = 1.0 + (effect_stack_count * (damage_multiplier - 1.0))
	print("Damage boost stacks: ", effect_stack_count, " - Total multiplier: ", total_multiplier)
	
	# Apply melee attack damage boost
	if apply_to_melee:
		player_ref.attack_power = original_attack_power * total_multiplier
		print("Attack power increased to", player_ref.attack_power)
	
	# Apply auto-attack damage
	var player_attack = player_ref.get_node_or_null("PlayerAttack")
	if player_attack and apply_to_auto_attack:
		player_attack.AUTO_ATTACK_DAMAGE = original_auto_attack_damage * total_multiplier
		print("Auto-attack damage increased to", player_attack.AUTO_ATTACK_DAMAGE)
	
	# Fireball uses player's attack_power, so it's already boosted by the change to attack_power

# Function to handle when a stack timer expires
func _on_stack_timer_timeout(timer):
	if timer in effect_timers:
		effect_timers.erase(timer)
		timer.queue_free()
		
		# Decrement stack count
		effect_stack_count -= 1
		print("Damage stack expired. Remaining stacks: ", effect_stack_count)
		
		# If stacks remain, reapply effect with reduced stacks
		if effect_stack_count > 0:
			apply_stacked_effect()
		else:
			# No stacks remain, return to normal values
			reset_damage_values()
			effect_active = false
			print("All damage stacks expired")

# Reset all damage values to original values
func reset_damage_values():
	if is_instance_valid(player_ref):
		# Reset melee damage
		if apply_to_melee:
			player_ref.attack_power = original_attack_power
			print("Attack power restored to", original_attack_power)
		
		# Reset auto-attack damage
		var player_attack = player_ref.get_node_or_null("PlayerAttack")
		if player_attack and apply_to_auto_attack:
			player_attack.AUTO_ATTACK_DAMAGE = original_auto_attack_damage
			print("Auto-attack damage restored to", original_auto_attack_damage)
	
	# Fireball uses player's attack_power, so it's already restored by resetting attack_power

# Helper function to display floating text
func spawn_floating_effect_text(player):
	# Try to use the floating number scene if available
	var floating_number_scene = load("res://scenes/floating_number.tscn")
	if floating_number_scene:
		var floating_text = floating_number_scene.instantiate()
		get_tree().get_root().add_child(floating_text)
		
		# Calculate bonus percentage based on current stacks
		var stack_bonus = int(effect_stack_count * (damage_multiplier - 1.0) * 100)
		
		# Display stack percentage - using setup_damage instead of setup_heal to show different color
		if floating_text.has_method("setup_damage"):
			floating_text.setup_damage(stack_bonus, player.global_position)
		elif floating_text.has_method("setup_heal"):  # Fallback if setup_damage doesn't exist
			floating_text.setup_heal(stack_bonus, player.global_position)
		else:
			print("Could not display floating text - required methods not found")
