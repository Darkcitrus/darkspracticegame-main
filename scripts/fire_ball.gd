# This script controls a fireball projectile in the game
# The fireball is an Area2D node that moves in a specified direction and destroys itself upon collision or timeout
extends Area2D

# Use safer resource loading with error checking
var ExplosionEffect = null

# Node References
@onready var fire_ball_vanish: Timer = $FireBallVanish

# Movement Properties
var direction: Vector2 = Vector2.ZERO  # Initialize to zero vector
var current_speed: float = 100  
const MAX_SPEED: float = 12000   
const SPEED_MULTIPLIER: float = 20

# Damage Properties
var damage: float = 15  
var crit_chance: float = 0.2  # 20% chance to crit
var crit_multiplier: float = 1.5  # 50% more damage on crit

# Target for homing
var target: Node2D = null
var homing_strength: float = 5.0  # Controls how quickly the fireball turns towards target

# Called when the fireball is instantiated
func initialize(new_direction: Vector2, new_target = null):
	direction = new_direction.normalized()
	if is_instance_valid(new_target) and new_target.is_in_group("Targetable"):
		target = new_target
		print("Fireball targeting: ", target.name)
	# Set a smaller scale for the fireball
	scale = Vector2(0.5, 0.5)  # Adjust this value to get the desired size

func _ready():
	# Load the explosion effect with error checking
	if ResourceLoader.exists("res://scenes/explosion_effect.tscn"):
		ExplosionEffect = load("res://scenes/explosion_effect.tscn")
	else:
		push_error("Could not load explosion effect resource!")
		
	print("Fireball created with damage: ", damage)
	add_to_group("Effects")
	
	# Set up collision properties
	monitoring = true
	monitorable = true
	
	# Connect collision signals with better error handling and protection
	if not is_connected("area_entered", _on_area_entered):
		connect("area_entered", _on_area_entered)
	if not is_connected("body_entered", _on_body_entered):
		connect("body_entered", _on_body_entered)
	
	# Make sure the timer exists before starting it
	if fire_ball_vanish:
		fire_ball_vanish.start()
	else:
		push_error("FireBallVanish timer not found!")
	
	print("Fireball ready with signals connected")

# Called every frame to update the fireball's position
func _process(delta):
	if not is_instance_valid(self):
		return
		
	if is_instance_valid(target) and target.is_in_group("Targetable"):
		# Calculate direction to target
		var desired_direction = (target.global_position - global_position).normalized()
		# Smoothly interpolate current direction towards desired direction
		direction = direction.lerp(desired_direction, homing_strength * delta).normalized()
	# Increase speed exponentially over time, but don't exceed max speed
	current_speed = min(current_speed * pow(SPEED_MULTIPLIER, delta), MAX_SPEED)
	# Move the fireball with the current speed using global_position
	global_position += direction * current_speed * delta
	
	# Check for direct collision with target
	if is_instance_valid(target):
		var distance_to_target = global_position.distance_to(target.global_position)
		if distance_to_target < 30:  # Close enough to count as a hit
			print("FIREBALL: Direct hit on target detected by proximity")
			_handle_hit(target)

# Signal Handlers
func _on_body_entered(body: Node2D) -> void:
	print("FIREBALL: Hit body: ", body.name, " Groups: ", body.get_groups())
	
	# Enhanced detection
	if body.is_in_group("Enemy"):
		print("FIREBALL: Valid enemy body hit!")
		_handle_hit(body)
	elif body.is_in_group("World"):
		print("FIREBALL: World body hit!")
		_handle_hit(body)
	# Special case for targeting
	elif is_instance_valid(target) and body == target:
		print("FIREBALL: Direct target body hit!")
		_handle_hit(target)
	else:
		print("FIREBALL: Non-target collision with: ", body.name)

func _on_area_entered(area: Area2D) -> void:
	print("FIREBALL: Hit area: ", area.name, " Groups: ", area.get_groups())
	
	# Enhanced detection
	if area.is_in_group("Enemy"):
		print("FIREBALL: Valid enemy area hit!")
		_handle_hit(area)
	elif area.is_in_group("World"):
		print("FIREBALL: World area hit!")
		_handle_hit(area)
	# Special case for targeting
	elif is_instance_valid(target) and area == target:
		print("FIREBALL: Direct target area hit!")
		_handle_hit(target)
	else:
		print("FIREBALL: Non-target collision with: ", area.name)

# Centralized hit handling to ensure proper destruction
func _handle_hit(object):
	# Try to apply damage if possible
	if object.has_method("take_damage"):
		var damage_info = calculate_damage()
		object.take_damage(damage_info["damage"], damage_info["is_crit"])
		print("FIREBALL: Damage applied: ", damage_info["damage"])
	
	# Spawn effect and destroy - using immediate destruction for reliability
	spawn_explosion_effect()
	print("FIREBALL: Destroying fireball NOW")
	queue_free()  # Immediate destruction

# Timer callback
func _on_fire_ball_vanish_timeout():
	print("FIREBALL: Timeout reached, self-destructing")
	spawn_explosion_effect()
	queue_free()

func get_damage() -> float:
	return damage

func spawn_explosion_effect():
	if not is_instance_valid(self):
		return
		
	if ExplosionEffect:
		var explosion = ExplosionEffect.instantiate()
		if explosion:
			explosion.global_position = global_position
			# Use safe way to add to scene
			var root = get_tree().get_root()
			if root:
				root.add_child(explosion)
	else:
		print("WARNING: ExplosionEffect resource not available")

func calculate_damage() -> Dictionary:
	var is_crit = randf() < crit_chance
	var final_damage = damage * (crit_multiplier if is_crit else 1.0)
	print("Fireball damage: ", final_damage, " (Critical: ", is_crit, ")")
	return {"damage": final_damage, "is_crit": is_crit}
