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
	add_to_group("Enemy")  # Add dummy to Enemy group
	add_to_group("Targetable")  # Add to Targetable group for fireball targeting
	
	# Store initial position and oscillation time
	initial_position = position
	oscillation_start_time = Time.get_ticks_msec() / 1000.0
	
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
		print("Dummy healthbar initialized. Max health: ", max_health)
	
	# Ensure selector is properly set up
	if selector:
		selector.visible = false  # Hide selector initially
		print("Selector initialized and hidden")
	else:
		print("Selector node not found!")
		
	# Load fireball scene with error checking
	if ResourceLoader.exists("res://scenes/fire_ball.tscn"):
		fireball_scene = load("res://scenes/fire_ball.tscn")
		print("Fireball scene loaded successfully")
	else:
		push_error("Could not load fireball scene!")
		print("ERROR: Failed to load fireball scene")
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
		print("Fireball timer initialized with frequency: ", fireball_frequency)
	
	# Find spawner/manager parent to record original scale
	var parent = get_parent()
	if parent and parent.has_method("record_original_dummy_scale"):
		parent.record_original_dummy_scale(self)
		print("Dummy: Registered original scale with parent: ", scale)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	# Update vertical position with a sine wave oscillation
	# Use relative time from spawn to keep oscillation consistent
	var time = Time.get_ticks_msec() / 1000.0 - oscillation_start_time
	position.y = initial_position.y + sin(time * frequency * PI * 2) * amplitude
	
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
	print("Dummy detected hit from: ", area.name, " Parent: ", parent_name)
	
	# Updated condition: check directly for "hitbox" OR "sword"
	if area.name == "hitbox" or area.name == "sword":
		var player = get_tree().get_first_node_in_group("Player")
		if player:
			var damage_info = player.get_node("PlayerAttack").calculate_damage()
			take_damage(damage_info["damage"], damage_info["is_crit"])
			print("Took melee damage: ", damage_info["damage"], " Critical: ", damage_info["is_crit"])
	# Check for fireball damage and make sure it's not from self
	elif area.has_method("calculate_damage"):
		# Make sure this fireball wasn't fired by this dummy
		if area.has_method("get_source") and area.get_source() != self:
			var damage_info = area.calculate_damage()
			take_damage(damage_info["damage"], damage_info["is_crit"])
			print("Took effect damage: ", damage_info["damage"], " Critical: ", damage_info["is_crit"])
		else:
			print("Dummy ignoring its own projectile")

func take_damage(amount, is_crit: bool = false):
	if not alive:
		print("Dummy is already dead, ignoring damage")
		return
		
	print("DUMMY DAMAGE - Amount: ", amount, " Is Crit: ", is_crit)
	health -= amount
	
	# Spawn floating number with adjusted position
	if alive:  # Ensure the dummy is still alive before accessing global_position
		var floating_num = FloatingNumber.instantiate() as Label
		if floating_num:
			get_tree().get_root().add_child(floating_num)
			print("Spawning damage number: ", amount, " Crit: ", is_crit)
			floating_num.setup(amount, is_crit, global_position)
	
	print("Dummy health now: ", health)
	
	if healthbar:
		print("Updating dummy healthbar to: ", health)
		healthbar.value = health
	
	if health <= 0:
		die()

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
func reset_position(pos: Vector2):
	initial_position = pos
	position = pos
	oscillation_start_time = Time.get_ticks_msec() / 1000.0
	print("Dummy reset to position: ", pos)

func shoot_fireball():
	if !alive or !shoots_fireballs:
		print("Skipping fireball: alive=", alive, ", shoots_fireballs=", shoots_fireballs)
		return
		
	print("Attempting to shoot fireball")
	var player = get_tree().get_first_node_in_group("Player")
	# Only shoot if player exists and is alive
	if player and player.alive and fireball_scene:
		print("Dummy shooting fireball at player")
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
		print("Fireball fired with damage: ", fireball_damage, " speed: ", adjusted_speed, " homing: ", adjusted_homing)
	else:
		print("Cannot shoot fireball: player exists=", is_instance_valid(player), ", player alive=", player and player.alive, ", fireball_scene exists=", fireball_scene != null)
