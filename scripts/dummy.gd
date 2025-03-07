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

# Add exported variables for oscillation
@export var amplitude: float = 20
@export var frequency: float = 1.0

@onready var healthbar: TextureProgressBar = $HealthBar
@onready var selector = $Selector  # Remove the Label cast, let it be whatever node type it is

# Called when the node enters the scene tree for the first time.
func _ready():
	add_to_group("Enemy")  # Add dummy to Enemy group
	add_to_group("Targetable")  # Add to Targetable group for fireball targeting
	initial_position = position  # Store initial position for respawn
	
	# Set up collisions and mouse detection
	input_pickable = true
	monitoring = true
	monitorable = true
	
	# Connect area signals
	area_entered.connect(_on_area_entered)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Initialize health and healthbar
	health = max_health
	if healthbar:
		healthbar.max_value = max_health
		healthbar.value = health
		healthbar.show()
		print("Dummy healthbar initialized. Max health: ", max_health)
	
	set_process_input(true)  # Ensure the node processes input
	input_pickable = true  # Ensure the Area2D node can detect mouse input
	if selector:
		selector.visible = false  # Hide selector initially
		print("Selector initialized and hidden")
	else:
		print("Selector node not found!")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	# Update vertical position with a sine wave oscillation
	position.y = initial_position.y + sin(Time.get_ticks_msec() / 1000.0 * frequency * PI * 2) * amplitude
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
	print("Dummy died!")
	visible = false
	remove_from_group("Targetable")  # Remove from targetable group
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	emit_signal("dummy_died", initial_position)  # Emit signal with initial position
	# Don't queue_free immediately, let the signal propagate first
	await get_tree().create_timer(0.1).timeout
	queue_free()

func _on_mouse_entered() -> void:
	print("Mouse entered dummy area")
	if selector and alive:
		selector.show()  # Try using show() instead of visible
		print("Mouse entered dummy")
		# Also set the player's target
		var player = get_tree().get_first_node_in_group("Player")
		if player:
			player.set_current_target(self)

func _on_mouse_exited() -> void:
	print("Mouse exited dummy area")
	if selector and alive:
		selector.hide()  # Try using hide() instead of visible
		print("Mouse exited dummy")
		# Clear the player's target
		var player = get_tree().get_first_node_in_group("Player")
		if player:
			player.clear_current_target()

# Ensure initial position is reset correctly on respawn
func reset_position(pos: Vector2):
	initial_position = pos
	position = pos
