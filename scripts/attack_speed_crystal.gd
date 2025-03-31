extends ItemPickup
class_name AttackSpeedCrystal

# Speed boost properties
@export var attack_speed_multiplier: float = 1.5  # How much faster attacks will be (1.5 = 50% faster)
@export var effect_duration: float = 10.0  # How long the effect lasts in seconds
@export var apply_to_melee: bool = true
@export var apply_to_fireball: bool = true
@export var apply_to_auto_attack: bool = true

# Store original values to restore when effect ends
var player_ref: Node = null
var original_melee_cooldown: float = 0.0
var original_fireball_cooldown: float = 0.0
var original_auto_cooldown: float = 0.0
var effect_timer: Timer

func _ready():
	# Call parent _ready
	super()
	
	# Create a timer for the effect duration
	effect_timer = Timer.new()
	effect_timer.one_shot = true
	effect_timer.wait_time = effect_duration
	effect_timer.connect("timeout", _on_effect_timer_timeout)
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
	
	# Store original cooldowns
	original_melee_cooldown = player.attack_cooldown
	
	# Find PlayerAttack node and apply effects to fireball and auto-attack
	var player_attack = player.get_node_or_null("PlayerAttack")
	if player_attack:
		original_fireball_cooldown = player_attack.FIREBALL_COOLDOWN
		original_auto_cooldown = player_attack.AUTO_ATTACK_COOLDOWN
		
		if apply_to_fireball:
			player_attack.FIREBALL_COOLDOWN /= attack_speed_multiplier
			print("Fireball cooldown reduced from", original_fireball_cooldown, "to", player_attack.FIREBALL_COOLDOWN)
		
		if apply_to_auto_attack:
			player_attack.AUTO_ATTACK_COOLDOWN /= attack_speed_multiplier
			print("Auto-attack cooldown reduced from", original_auto_cooldown, "to", player_attack.AUTO_ATTACK_COOLDOWN)
	
	# Apply melee attack speed boost
	if apply_to_melee:
		player.attack_cooldown /= attack_speed_multiplier
		print("Melee cooldown reduced from", original_melee_cooldown, "to", player.attack_cooldown)
	
	# Show floating text to indicate the effect
	spawn_floating_effect_text(player)
	
	# Start the effect timer
	effect_timer.start()

# Function to handle when the effect expires
func _on_effect_timer_timeout():
	if is_instance_valid(player_ref):
		print("Attack speed boost effect ending")
		
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
		
		# Display "ATK+" using an integer value for the first parameter
		if floating_text.has_method("setup_heal"):
			floating_text.setup_heal(int(attack_speed_multiplier * 100), player.global_position)
		else:
			# Fallback message if the method doesn't exist
			print("Could not display floating text - setup_heal method not found")
