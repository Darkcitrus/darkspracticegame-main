# This script controls a homing missile projectile that only targets a specific entity
# The missile is an Area2D node that tracks its target with enhanced homing capabilities
extends Area2D

# Use safer resource loading with error checking
var ExplosionEffect = null

# Node References
@onready var missile_vanish: Timer = $MissileVanish

# Movement Properties
var direction: Vector2 = Vector2.ZERO  # Initialize to zero vector
var speed: float = 200  # Constant speed (no acceleration)

# Damage Properties
var damage: float = 15
var crit_chance: float = 0.2
var crit_multiplier: float = 1.5
var can_crit: bool = true

# Source tracking
var source: Node = null

# Target for homing - required for this projectile
var target: Node2D = null
var homing_strength: float = 15.0  # Much stronger homing than fireball

# Called when the missile is instantiated
func initialize(new_direction: Vector2, new_target = null, new_damage: float = -1, new_speed: float = -1, new_homing: float = -1, allow_crits: bool = true, firing_source: Node = null):
	direction = new_direction.normalized()
	can_crit = allow_crits
	source = firing_source
	
	# Set custom parameters if provided
	if new_damage > 0:
		damage = new_damage
	if new_speed > 0:
		speed = new_speed
	if new_homing > 0:
		homing_strength = new_homing
		
	# Target is required for this projectile
	if is_instance_valid(new_target):
		target = new_target
	else:
		# No valid target, destroy self
		queue_free()
	
func _ready():
	# Load the explosion effect with error checking
	if ResourceLoader.exists("res://scenes/explosion_effect.tscn"):
		ExplosionEffect = load("res://scenes/explosion_effect.tscn")
	else:
		push_error("Could not load explosion effect resource!")
		
	add_to_group("Effects")
	
	# Set up collision properties
	monitoring = true
	monitorable = true
	
	# Connect collision signals
	if not is_connected("area_entered", _on_area_entered):
		connect("area_entered", _on_area_entered)
	if not is_connected("body_entered", _on_body_entered):
		connect("body_entered", _on_body_entered)
	
	# Make sure the timer exists before starting it
	if missile_vanish:
		missile_vanish.start()
	else:
		push_error("MissileVanish timer not found!")

# Called every frame to update the missile's position
func _process(delta):
	if not is_instance_valid(self):
		return
	
	# Check if target is still valid
	if not is_instance_valid(target):
		queue_free()
		return
		
	# Calculate direction to target with stronger homing
	var desired_direction = (target.global_position - global_position).normalized()
	# Smoothly interpolate current direction towards desired direction
	direction = direction.lerp(desired_direction, homing_strength * delta).normalized()
	
	# Move with constant speed (no acceleration)
	global_position += direction * speed * delta
	
	# Check for direct collision with target
	var distance_to_target = global_position.distance_to(target.global_position)
	if distance_to_target < 30:  # Close enough to count as a hit
		_handle_hit(target)
		
	# Rotate to face movement direction
	rotation = direction.angle()

# Signal Handlers - Only handle the specific target
func _on_body_entered(body: Node2D) -> void:
	# Only collide with the specific target
	if body == target or body.get_parent() == target:
		_handle_hit(target)

func _on_area_entered(area: Area2D) -> void:
	# Only collide with the specific target
	if area == target or area.get_parent() == target:
		_handle_hit(target)

# Centralized hit handling
func _handle_hit(object):
	if object == source:
		return
	
	# Try to apply damage if possible
	if object.has_method("take_damage"):
		var damage_info = calculate_damage()
		object.take_damage(damage_info["damage"], damage_info["is_crit"])
		
		# Apply knockback based on object type
		if object.has_method("apply_knockback_from_fireball"):
			object.apply_knockback_from_fireball(global_position, damage_info["is_crit"])
	
	# Spawn effect and destroy
	spawn_explosion_effect()
	queue_free()

# Timer callback
func _on_missile_vanish_timeout():
	spawn_explosion_effect()
	queue_free()

func get_damage() -> float:
	return damage

func get_source() -> Node:
	return source

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
	var is_crit = can_crit && randf() < crit_chance
	var final_damage = damage * (crit_multiplier if is_crit else 1.0)
	return {"damage": final_damage, "is_crit": is_crit}
