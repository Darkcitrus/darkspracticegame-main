extends CharacterBody2D 

# Current state variables
var can_dodge: bool = true
var dodging: bool = false
var attacking: bool = false
var dodge_recovering: bool = false
var is_trapped: bool = false  # New state to handle bear trap interaction
var teleporting: bool = false # State to track teleportation
var attack_power = 20
var attack_cooldown = 0.3  # attack cooldown in seconds
var last_attack_time = 0
var fire_ball: PackedScene = null  # Use safer resource loading with error checking
var health = 100
var max_health = 100
var crit_chance: float = 0.25
var crit_damage: float = 2.0
var alive: bool = true
var target: Node2D = null  # For compatibility with scripts that might use 'target' directly
var current_target: Node2D = null  # Add this near the other state variables

# Damage resistance variables
var armor: float = 0.0  # Physical damage reduction (0.0 to 0.95 or 0% to 95%)
var magic_resist: float = 0.0  # Magical damage reduction (0.0 to 0.95 or 0% to 95%)
const MAX_RESIST: float = 0.95  # Maximum resistance cap (95%)
var damage_resist_while_dodging: float = 0.95  # 95% damage resistance when dodging

# Knockback properties
var knockback_active = false
var knockback_direction = Vector2.ZERO
var knockback_strength = 150.0  # Base knockback strength
var knockback_recovery_speed = 60.0  # How fast the player recovers from knockback
var knockback_remaining_time = 0.0
var knockback_max_time = 0.15  # Knockback duration in seconds

# Movement variables
var run_speed = 250
var dodge_speed: int = 1000
var direction: Vector2
var attack_direction: Vector2
var move_input = Vector2()
var dodges = 2
const MAX_DODGES = 2
const DODGE_COOLDOWN_TIME = 1.0
const DODGE_RECOVERY_TIME = 2.0
var friction: float = 1.0  # Default friction (1.0 = full control, lower values = slippery)

# Reference variables
@onready var dodge_timer = $DodgeTimer
@onready var dodge_recovery = $DodgeRecovery
@onready var dodge_cooldown = $DodgeCooldown
@onready var dodge_label = $DashCount
@onready var attack_area = $AttackArea # Area2D container for the hurtbox
@onready var attack_hurtbox = $AttackArea/AttackHurtbox # The actual CollisionShape2D
@onready var attackcd = $attackcd # Attack cooldown timer
@onready var projectiles = $Projectiles
@onready var respawn_timer: Timer = $RespawnTimer
@onready var healthbar: TextureProgressBar = $HealthBar
@onready var player_sprite = $PlayerSprite # Reference to the sprite for access by other scripts

# Called when the node enters the scene tree for the first time.
func _ready():
	add_to_group("Player") # Add player to Player group
	add_to_group("Targetable") # Add player to Targetable group so fireballs can target
	randomize() # Seed the random number generator
	
	# Safely load the fireball resource
	if ResourceLoader.exists("res://scenes/fire_ball.tscn"):
		fire_ball = load("res://scenes/fire_ball.tscn")
	else:
		push_error("Could not load fireball resource!")
	
	# Safer timer setup
	if not respawn_timer:
		respawn_timer = Timer.new()
		add_child(respawn_timer)
	
	respawn_timer.wait_time = 5.0
	respawn_timer.one_shot = true
	if not respawn_timer.is_connected("timeout", _on_respawn_timer_timeout):
		respawn_timer.connect("timeout", _on_respawn_timer_timeout)
	
	# Initialize health and healthbar
	health = max_health
	if healthbar:
		healthbar.max_value = max_health
		healthbar.value = health
		healthbar.show()
		print("Player healthbar initialized. Max health: ", max_health)
	
	# Disable attack hurtbox by default
	if attack_hurtbox:
		attack_hurtbox.disabled = true
	else:
		push_error("AttackHurtbox not found. Melee attacks will not work.")
		
	# Make sure the attackcd timer exists
	if not attackcd:
		attackcd = Timer.new()
		add_child(attackcd)
		attackcd.wait_time = 0.3
		attackcd.one_shot = true
		attackcd.connect("timeout", _on_attackcd_timeout)
	
	# Initialize dodge timer settings
	dodge_timer.wait_time = 0.3  # Dash duration
	dodge_recovery.wait_time = DODGE_RECOVERY_TIME
	dodge_cooldown.wait_time = DODGE_COOLDOWN_TIME

	# Update timer settings
	dodge_timer.wait_time = 0.1  # Shorter dash duration
	dodge_recovery.wait_time = 0.5  # Faster recovery
	dodge_cooldown.wait_time = 0.1  # Short cooldown between dashes
	
	# Only initialize sub-scripts if they exist
	if has_node("PlayerMovement"):
		$PlayerMovement.initialize(self)
	if has_node("PlayerAttack"):
		$PlayerAttack.initialize(self)
	if has_node("PlayerHealth"):
		$PlayerHealth.initialize(self)
	if has_node("PlayerAnimation"):
		$PlayerAnimation.initialize(self)
	if has_node("PlayerTeleport"):
		$PlayerTeleport.initialize(self)
	if has_node("PlayerGrappling"):
		$PlayerGrappling.initialize(self)
	
	# Initialize target references
	target = null
	current_target = null

	# Ensure the player's position is not reset
	print("Player initial position:", global_position)

	# Log the player's initial position
	print("Player: Initial position in _ready:", global_position)

	# Log the player's position after initialization
	print("Player initial position after GameManager positioning:", global_position)

	# Add a deferred call to verify the position after all initialization
	call_deferred("_verify_position")

	print("Player: _ready called. Initial position:", global_position)

func _verify_position():
	print("Player position verified after deferred call:", global_position)
	print("Player: Position verified after deferred call:", global_position)

# Check if the player can take actions (not dying, trapped, etc.)
func can_take_actions() -> bool:
	# Check if the death animation is playing
	if has_node("PlayerAnimation") and $PlayerAnimation.is_death_animation_playing():
		return false
	
	# Check if teleport animation is playing
	if has_node("PlayerAnimation") and $PlayerAnimation.is_teleport_animation_playing():
		return false
	
	# Check other conditions that prevent actions
	if not alive or knockback_active or teleporting:
		return false
		
	# For general actions, is_trapped is considered a blocker
	# For combat actions specifically, use can_take_combat_actions() instead
	if is_trapped:
		return false
		
	return true

# Check if the player can take combat actions (attack, ranged attack, fireball)
# This allows attacking even when trapped
func can_take_combat_actions() -> bool:
	# Check if the death animation is playing
	if has_node("PlayerAnimation") and $PlayerAnimation.is_death_animation_playing():
		return false
	
	# Check if teleport animation is playing
	if has_node("PlayerAnimation") and $PlayerAnimation.is_teleport_animation_playing():
		return false
	
	# Check conditions that prevent combat actions
	if not alive or knockback_active or teleporting:
		return false
		
	# Note: is_trapped is NOT checked here, allowing combat while trapped
	return true

# Override the default _physics_process to handle knockback
func _physics_process(delta):
	# Check if the player can take actions
	if not alive:
		# Still process animation for death, but don't allow any movement or actions
		if has_node("PlayerAnimation"):
			$PlayerAnimation._physics_process(delta)
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	# Skip movement if trapped by a bear trap
	if is_trapped:
		velocity = Vector2.ZERO
		if has_node("PlayerAnimation"):
			$PlayerAnimation._physics_process(delta)
		move_and_slide()
		return
		
	# Handle knockback if active
	if knockback_active:
		# Apply knockback force
		knockback_remaining_time -= delta
		if knockback_remaining_time <= 0:
			knockback_active = false
			velocity = Vector2.ZERO  # Reset velocity after knockback
			print("Player knockback ended")
		else:
			# Apply knockback movement
			velocity = knockback_direction * knockback_strength
			if has_node("PlayerAnimation"):
				$PlayerAnimation._physics_process(delta)
			move_and_slide()
			return  # Skip normal movement processing
	
	# Check if the death animation is playing
	if has_node("PlayerAnimation") and $PlayerAnimation.is_death_animation_playing():
		# If death animation is playing, don't allow any actions
		velocity = Vector2.ZERO
		$PlayerAnimation._physics_process(delta) # Still process animation
		move_and_slide()
		return
	
	# Check if the teleport animation is playing
	if teleporting:
		# If teleport animation is playing, don't allow any actions
		if has_node("PlayerAnimation"):
			$PlayerAnimation._physics_process(delta) # Still process animation
		move_and_slide()
		return
	
	# Normal movement processing if no knockback
	$PlayerMovement._physics_process(delta)
	$PlayerAttack._physics_process(delta)
	$PlayerHealth._physics_process(delta)
	$PlayerAnimation._physics_process(delta)
	if has_node("PlayerTeleport"):
		$PlayerTeleport._physics_process(delta)
	if has_node("PlayerGrappling"):
		$PlayerGrappling._physics_process(delta)
		
	# Apply friction to movement before calling move_and_slide
	# Lower friction (caused by ice spots) makes player continue moving in their current direction
	if friction < 1.0:
		# Store the previous velocity for momentum
		if not has_meta("prev_velocity"):
			set_meta("prev_velocity", velocity)
			
		var prev_velocity = get_meta("prev_velocity")
		
		# On ice, we want to maintain previous momentum, making it hard to change direction
		if move_input.length() > 0:
			# When trying to move on ice, only a small portion of input affects movement
			# Most of the movement comes from previous momentum (sliding)
			velocity = prev_velocity.lerp(move_input * run_speed, friction)
		else:
			# When not pressing movement keys on ice, continue sliding with minimal slowdown
			velocity = prev_velocity * 0.99  # Very slow deceleration on ice
		
		# Debug print to verify sliding effect is working
		if velocity.length() > 10:
			print("Sliding on ice! Speed: " + str(velocity.length()))
			
		# Update previous velocity for next frame
		set_meta("prev_velocity", velocity)
	else:
		# Reset previous velocity when not on ice
		if has_meta("prev_velocity"):
			remove_meta("prev_velocity")
			
	move_and_slide()

func _on_respawn_timer_timeout():
	$PlayerHealth._on_respawn_timer_timeout()

func set_current_target(target_node: Node2D) -> void:
	target = target_node  # Set both target variables for compatibility
	current_target = target_node
	print("Target set: ", target_node.name)

func clear_current_target() -> void:
	target = null  # Clear both target variables
	current_target = null
	print("Target cleared")

# Add this function to handle damage from fireballs and other sources
func take_damage(amount: float, is_crit: bool = false, damage_type: String = "physical"):
	if not alive:
		return
	
	# Apply dodge damage resistance if player is dodging
	var final_amount = amount
	if dodging:
		# True damage ignores dodge resistance
		if damage_type.to_lower() == "true":
			final_amount = amount
			print("True damage ignores dodge resistance: ", amount)
		else:
			final_amount = amount * (1.0 - damage_resist_while_dodging)
			print("Dodge damage reduction applied: ", amount, " -> ", final_amount)
	# Apply armor or magic resistance based on damage type
	elif damage_type.to_lower() == "physical":
		final_amount = amount * (1.0 - min(armor, MAX_RESIST))
		print("Physical damage reduced by armor: ", amount, " -> ", final_amount)
	elif damage_type.to_lower() == "magical":
		final_amount = amount * (1.0 - min(magic_resist, MAX_RESIST))
		print("Magical damage reduced by magic resist: ", amount, " -> ", final_amount)
	elif damage_type.to_lower() == "true":
		# True damage ignores all resistances
		final_amount = amount
		print("True damage ignores resistances: ", amount)
	
	print("Player taking damage: ", final_amount, " (Original: ", amount, ") Critical: ", is_crit, " Type: ", damage_type)
	health -= final_amount
	
	# Show floating damage number with appropriate color based on damage type
	spawn_floating_damage_number(final_amount, is_crit, damage_type)
	
	# Update healthbar if it exists
	if healthbar:
		healthbar.value = health
		print("Player health now: ", health)
	
	# Check for player death
	if health <= 0 and alive:
		alive = false
		print("Player died!")
		# Don't hide the player immediately - let the animation system handle it
		
		# Start respawn timer
		if respawn_timer:
			respawn_timer.start()

# Function to apply knockback from fireballs
func apply_knockback_from_fireball(fireball_position: Vector2, is_crit: bool = false):
	# Calculate knockback direction away from fireball
	knockback_direction = (global_position - fireball_position).normalized()
	
	# Modify knockback strength for crits
	var actual_strength = knockback_strength * (1.5 if is_crit else 1.0)
	
	# Start knockback
	knockback_active = true
	knockback_remaining_time = knockback_max_time
	knockback_strength = actual_strength
	print("Player knocked back from fireball in direction: ", knockback_direction)

# Add a heal function to be called by healing items
func heal(amount: float):
	print("Player healed for: ", amount)
	health = min(health + amount, max_health)
	
	# Update healthbar if it exists
	if healthbar:
		healthbar.value = health
		print("Player health now: ", health)
	
	# Show floating heal number
	spawn_floating_heal_number(amount)

# Function to display healing numbers
func spawn_floating_heal_number(heal_amount: float):
	var floating_number_scene = load("res://scenes/floating_number.tscn")
	if floating_number_scene:
		var floating_number = floating_number_scene.instantiate()
		get_tree().get_root().add_child(floating_number)
		floating_number.setup_heal(int(heal_amount), global_position)

# Function to display damage numbers with appropriate color based on damage type
func spawn_floating_damage_number(damage_amount: float, is_crit: bool, damage_type: String):
	var floating_number_scene = load("res://scenes/floating_number.tscn")
	if floating_number_scene:
		var floating_number = floating_number_scene.instantiate()
		get_tree().get_root().add_child(floating_number)
		floating_number.setup_with_type(int(damage_amount), is_crit, damage_type, global_position)

func _on_attackcd_timeout():
	attacking = false
	print("Attack cooldown ended")

# Functions for bear trap interaction
func trap_player():
	is_trapped = true
	velocity = Vector2.ZERO

func release_player():
	is_trapped = false
