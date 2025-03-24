extends CharacterBody2D 

# Current state variables
var can_dodge: bool = true
var dodging: bool = false
var attacking: bool = false
var dodge_recovering: bool = false
var attack_power = 20
var thrust_distance = 80
var thrust_modifier: float = 1.5  # Modifier for thrust attack
var sweep_modifier: float = 0.8  # Modifier for sweep attack
var swinging_left: bool = true  # Track the current direction of the swing
var swinging: bool = false  # Track if the sword is currently swinging
var current_tween: Tween = null  # Store the current tween
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

# Reference variables
@onready var dodge_timer = $DodgeTimer
@onready var dodge_recovery = $DodgeRecovery
@onready var dodge_cooldown = $DodgeCooldown
@onready var dodge_label = $DashCount
@onready var sword = $sword
@onready var sword_sprite = $sword/swordsprite
@onready var hitbox = $sword/hitbox
@onready var attackcd = $sword/hitbox/attackcd
@onready var projectiles = $Projectiles
@onready var respawn_timer: Timer = $RespawnTimer
@onready var healthbar: TextureProgressBar = $HealthBar

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
	
	# Make sure sword is in Effects group
	$sword.add_to_group("Effects")
	hitbox.disabled = true  # Disable the sword's hitbox by default
	sword_sprite.visible = true  # Ensure the sword_sprite remains visible
	
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
	
	# Initialize target references
	target = null
	current_target = null

	# Ensure the player's position is not reset
	print("Player initial position:", global_position)

	# Log the player's position after initialization
	print("Player initial position after GameManager positioning:", global_position)

	# Add a deferred call to verify the position after all initialization
	call_deferred("_verify_position")

	print("Player: _ready called. Initial position:", global_position)

func _verify_position():
	print("Player position verified after deferred call:", global_position)
	print("Player: Position verified after deferred call:", global_position)

# Override the default _physics_process to handle knockback
func _physics_process(delta):
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
			move_and_slide()
			return  # Skip normal movement processing
	
	# Normal movement processing if no knockback
	$PlayerMovement._physics_process(delta)
	$PlayerAttack._physics_process(delta)
	$PlayerHealth._physics_process(delta)
	move_and_slide()

	print("Player: _physics_process called. Current position:", global_position)

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
func take_damage(amount: float, is_crit: bool = false):
	if not alive:
		return
	
	print("Player taking damage: ", amount, " Critical: ", is_crit)
	health -= amount
	
	# Update healthbar if it exists
	if healthbar:
		healthbar.value = health
		print("Player health now: ", health)
	
	# Check for player death
	if health <= 0 and alive:
		alive = false
		print("Player died!")
		visible = false
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
