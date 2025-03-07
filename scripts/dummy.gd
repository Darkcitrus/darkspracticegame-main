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

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	# Update vertical position with a sine wave oscillation
	# Use relative time from spawn to keep oscillation consistent
	var time = Time.get_ticks_msec() / 1000.0 - oscillation_start_time
	position.y = initial_position.y + sin(time * frequency * PI * 2) * amplitude
	pass

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
	elif area.has_method("calculate_damage"):
		var damage_info = area.calculate_damage()
		take_damage(damage_info["damage"], damage_info["is_crit"])
		print("Took effect damage: ", damage_info["damage"], " Critical: ", damage_info["is_crit"])

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
