extends Area2D  # Changed from CharacterBody2D

@warning_ignore("unused_signal")
signal dummy_died(pos: Vector2)  # Declare the signal
const FloatingNumber = preload("res://scenes/floating_number.tscn")

# Enemy properties
var health = 100
var max_health = 100
var damage = 15
var alive = true
var initial_position: Vector2
var oscillation_start_time: float = 0.0

# Add exported variables for oscillation
@export var amplitude: float = 20
@export var frequency: float = 1.0

# Knockback properties
var knockback_active = false
var knockback_direction = Vector2.ZERO
var knockback_strength = 100.0  # Base knockback strength
var knockback_recovery_speed = 40.0  # How fast the dummy returns to original position
var knockback_remaining_time = 0.0
var knockback_max_time = 0.2  # Knockback duration in seconds
var knockback_position_offset = Vector2.ZERO
var knockback_return_active = false

# Fireball properties
@export var shoots_fireballs: bool = true
@export var fireball_frequency: float = 2.0  # How often to shoot fireballs (in seconds)
@export var fireball_damage: float = 10.0
@export var fireball_speed: float = 100.0
@export var fireball_homing_strength: float = 3.0
var fireball_scene = null
@onready var fireball_timer: Timer

@onready var healthbar: TextureProgressBar = $HealthBar
@onready var selector = $Selector  # Remove the Label cast, let it be whatever node type it is

# Called when the node enters the scene tree for the first time.
func _ready():
	# DEBUGGING CODE - Print position information
	print("========== DUMMY POSITION DEBUG ==========")
	print("Dummy name:", name)
	print("Initial position:", position)
	print("Initial global position:", global_position)
	var parent = get_parent()
	print("Parent:", parent.name if parent != null else "none") 
	print("Viewport size:", get_viewport_rect().size)
	print("Scale:", scale)
	print("========================================")
	
	# Schedule position check after a delay
	get_tree().create_timer(1.0).timeout.connect(print_delayed_position)
	add_to_group("Enemy")  # Add dummy to Enemy group
	add_to_group("Targetable")  # Add to Targetable group for fireball targeting
	
	# Store initial position but don't apply oscillation immediately
	initial_position = position
	oscillation_start_time = Time.get_ticks_msec() / 1000.0
	
	# Add a short delay before starting oscillation
	await get_tree().create_timer(0.1).timeout
	
	# Set up collisions - REMOVED mouse detection settings
	monitoring = true
	monitorable = true
	
	# Connect area signals - REMOVED mouse signals
	area_entered.connect(_on_area_entered)
	
	# Initialize health and healthbar
	health = max_health
	if healthbar:
		healthbar.max_value = max_health
		healthbar.value = health
		healthbar.show()
	
	# Ensure selector is properly set up
	if selector:
		selector.visible = false  # Hide selector initially
	
	# Load fireball scene with error checking
	if ResourceLoader.exists("res://scenes/fire_ball.tscn"):
		fireball_scene = load("res://scenes/fire_ball.tscn")
	else:
		push_error("Could not load fireball scene!")
		shoots_fireballs = false
	
	# Set up fireball timer
	if shoots_fireballs:
		fireball_timer = Timer.new()
		fireball_timer.name = "FireballTimer"
		add_child(fireball_timer)
		fireball_timer.wait_time = fireball_frequency
		fireball_timer.one_shot = false
		# Make sure to connect timeout signal before starting
		if not fireball_timer.timeout.is_connected(shoot_fireball):
			fireball_timer.timeout.connect(shoot_fireball)
		fireball_timer.start()  # Start the timer explicitly
	
	# Find spawner/manager parent to record original scale
	var spawner_parent = get_parent()
	if spawner_parent and spawner_parent.has_method("record_original_dummy_scale"):
		spawner_parent.record_original_dummy_scale(self)
	
	# Print more details about node hierarchy
	print("Dummy full path:", get_path())
	if parent:
		print("Parent full path:", parent.get_path())
		print("Parent global position:", parent.global_position)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Handle knockback movement
	if knockback_active:
		# Move in knockback direction
		knockback_remaining_time -= delta
		if knockback_remaining_time <= 0:
			knockback_active = false
			knockback_return_active = true
		else:
			# Apply knockback movement
			knockback_position_offset += knockback_direction * knockback_strength * delta
	
	# Handle returning after knockback
	if knockback_return_active and not knockback_active:
		# Return to original position
		var return_direction = -knockback_position_offset.normalized()
		var return_distance = knockback_recovery_speed * delta
		if knockback_position_offset.length() <= return_distance:
			# We're close enough - snap back to exact position
			knockback_position_offset = Vector2.ZERO
			knockback_return_active = false
		else:
			# Move towards original position
			knockback_position_offset += return_direction * return_distance
	
	# Only apply oscillation if we're past the initial delay
	if Time.get_ticks_msec() / 1000.0 > oscillation_start_time + 0.1:
		# Calculate oscillation offset
		var time_elapsed = Time.get_ticks_msec() / 1000.0 - oscillation_start_time
		var oscillation_offset = Vector2.UP * amplitude * sin(time_elapsed * frequency * 2 * PI)
		
		# Apply to position
		position = initial_position + oscillation_offset + knockback_position_offset
	else:
		# Keep exactly at initial position during the initial delay
		position = initial_position + knockback_position_offset
	
	# Always check for player as potential target
	if shoots_fireballs and alive:
		var player = get_tree().get_first_node_in_group("Player")
		if player and player.alive:
				# For debugging: periodically check if we can see the player
			if Engine.get_frames_drawn() % 60 == 0:  # Check roughly once per second
				print("Dummy tracking player at position: ", player.global_position)

func _on_area_entered(area: Area2D) -> void:
	if not alive:
		return
		
	var parent_name = ""
	if area.get_parent():
		parent_name = area.get_parent().name
	
	# Updated condition: check directly for "hitbox" OR "sword"
	if area.name == "hitbox" or area.name == "sword":
		var player = get_tree().get_first_node_in_group("Player")
		if player:
			var damage_info = player.get_node("PlayerAttack").calculate_damage()
			take_damage(damage_info["damage"], damage_info["is_crit"])
	# Check for fireball damage and make sure it's not from self
	elif area.has_method("calculate_damage"):
		# Make sure this fireball wasn't fired by this dummy
		if area.has_method("get_source") and area.get_source() != self:
			var damage_info = area.calculate_damage()
			take_damage(damage_info["damage"], damage_info["is_crit"])

func take_damage(amount, is_crit: bool = false, damage_type: String = "physical"):
	if not alive:
		return
	
	# Dummy has 0 resistances as requested, so we use the raw damage amount
	# No need to calculate resistances like for the player
	health -= amount
	
	# Apply knockback
	apply_knockback_from_hit()
	
	# Spawn floating number with adjusted position and damage type
	if alive:  # Ensure the dummy is still alive before accessing global_position
		var floating_num = FloatingNumber.instantiate() as Label
		if floating_num:
			get_tree().get_root().add_child(floating_num)
			floating_num.setup_with_type(amount, is_crit, damage_type, global_position)
	
	if healthbar:
		healthbar.value = health
	
	if health <= 0:
		die()

func apply_knockback_from_hit():
	# Get player position to determine knockback direction
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		# Calculate knockback direction away from player
		knockback_direction = (global_position - player.global_position).normalized()
		
		# Increase knockback for crits
		knockback_strength = 150.0  # Base knockback strength
		
		# Start knockback
		knockback_active = true
		knockback_return_active = false
		knockback_remaining_time = knockback_max_time

# Function to handle knockback from fireballs specifically
func apply_knockback_from_fireball(fireball_position: Vector2, is_crit: bool = false):
	# Calculate knockback direction away from fireball
	knockback_direction = (global_position - fireball_position).normalized()
	
	# Increase knockback for crits
	knockback_strength = 100.0 * (1.5 if is_crit else 1.0)
	
	# Start knockback
	knockback_active = true
	knockback_return_active = false
	knockback_remaining_time = knockback_max_time

func die():
	if not alive:
		return
	alive = false
	print("Dummy died at position: ", position, " Initial position was: ", initial_position)
	visible = false
	remove_from_group("Targetable")  # Remove from targetable group
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	# Pass the INITIAL position for respawning, not the current oscillated position
	emit_signal("dummy_died", initial_position)  # Emit signal with initial position
	# Don't queue_free immediately, let the signal propagate first
	await get_tree().create_timer(0.1).timeout
	queue_free()

# Ensure initial position is reset correctly on respawn
func reset_position(pos = null):
	if pos:
		global_position = pos
	
	# Store the current position for oscillation
	initial_position = position
	knockback_position_offset = Vector2.ZERO
	
	print("Dummy reset - Position:", position)
	print("Dummy reset - Global position:", global_position)
	
	# Reset oscillation time
	oscillation_start_time = Time.get_ticks_msec() / 1000.0
	
	# Cancel any active effects
	knockback_active = false
	knockback_return_active = false

func shoot_fireball():
	if !alive or !shoots_fireballs:
		return
		
	var player = get_tree().get_first_node_in_group("Player")
	# Only shoot if player exists and is alive
	if player and player.alive and fireball_scene:
		var fireball = fireball_scene.instantiate()
		get_tree().get_root().add_child(fireball)
		fireball.global_position = global_position
		
		# Direction to player
		var direction = (player.global_position - global_position).normalized()
		
		# Make fireballs faster, and more aggressive with homing
		# Scale is set in initialize method
		var adjusted_speed = fireball_speed * 1.2  # A bit faster
		var adjusted_homing = fireball_homing_strength * 1.5  # More aggressive homing
		
		# Initialize with custom properties, disable crits, and set self as source
		fireball.initialize(direction, player, fireball_damage, adjusted_speed, adjusted_homing, false, self)

func print_delayed_position():
	print("========== DUMMY DELAYED POSITION CHECK ==========")
	print("Dummy name:", name)
	print("Current position:", position)
	print("Current global position:", global_position)
	print("Initial position stored:", initial_position)
	print("Oscillation offset:", Vector2.UP * amplitude * sin((Time.get_ticks_msec() / 1000.0 - oscillation_start_time) * frequency * 2 * PI))
	print("Knockback offset:", knockback_position_offset)
	print("==========================================")
