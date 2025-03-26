# This script controls a fireball projectile in the game
# The fireball is an Area2D node that moves in a specified direction and destroys itself upon collision or timeout
extends Area2D

# Use safer resource loading with error checking
var ExplosionEffect = null

# Node References
@onready var fire_ball_vanish: Timer = $FireBallVanish

# Movement Properties
var direction: Vector2 = Vector2.ZERO  # Initialize to zero vector
var current_speed: float = 50  
const MAX_SPEED: float = 12000   
const SPEED_MULTIPLIER: float = 20

# Damage Properties
var damage: float = 15
var crit_chance: float = 0.2  # 20% chance to crit
var crit_multiplier: float = 1.5  # 50% more damage on crit
var can_crit: bool = true  # Can be disabled for enemy projectiles

# Source tracking
var source: Node = null  # Who fired this fireball

# Target for homing
var target: Node2D = null
var homing_strength: float = 5.0  # Controls how quickly the fireball turns towards target

# Called when the fireball is instantiated
func initialize(new_direction: Vector2, new_target = null, new_damage: float = -1, new_speed: float = -1, new_homing: float = -1, allow_crits: bool = true, firing_source: Node = null):
	direction = new_direction.normalized()
	can_crit = allow_crits
	source = firing_source  # Store who fired this fireball
	
	# Set custom parameters if provided
	if new_damage > 0:
		damage = new_damage
	if new_speed > 0:
		current_speed = new_speed
	if new_homing > 0:
		homing_strength = new_homing
		
	if is_instance_valid(new_target):
		target = new_target
	else:
		pass
	
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

# Called every frame to update the fireball's position
func _process(delta):
	if not is_instance_valid(self):
		return
		
	if is_instance_valid(target):
		# Check if the target is still valid for homing
		if target.is_in_group("Targetable") or target.is_in_group("Player"):
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
			_handle_hit(target)
			
	# Rotate the fireball to face its movement direction
	rotation = direction.angle()

# Signal Handlers
func _on_body_entered(body: Node2D) -> void:
	
	# Don't damage the source that fired this fireball
	if body == source:
		return
	
	# Enhanced detection for Player
	if body.is_in_group("Player") and source != body:
		_handle_hit(body)
	elif body.is_in_group("Enemy"):
		_handle_hit(body)
	elif body.is_in_group("World"):
		_handle_hit(body)
	# Special case for targeting
	elif is_instance_valid(target) and body == target:
		_handle_hit(target)

func _on_area_entered(area: Area2D) -> void:
	
	# Don't damage the source that fired this fireball
	if area == source:
		return
	
	# Get parent if it exists
	var parent = area.get_parent() if area.get_parent() else null
	
	# Enhanced detection for Player
	if (area.is_in_group("Player") or (parent and parent.is_in_group("Player"))) and source != area and source != parent:
		_handle_hit(parent if parent and parent.is_in_group("Player") else area)
	elif area.is_in_group("Enemy"):
		_handle_hit(area)
	elif area.is_in_group("World"):
		_handle_hit(area)
	# Special case for targeting
	elif is_instance_valid(target) and (area == target or parent == target):
		_handle_hit(target)

# Centralized hit handling to ensure proper destruction
func _handle_hit(object):
	# Don't damage the source that fired this fireball
	if object == source:
		return
		
	# Don't damage entities in the same group as the source (teammates)
	if source and source.is_in_group("Enemy") and object.is_in_group("Enemy"):
		return
	
	if source and source.is_in_group("Player") and object.is_in_group("Player"):
		return
		
	# Try to apply damage if possible
	if object.has_method("take_damage"):
		var damage_info = calculate_damage()
		object.take_damage(damage_info["damage"], damage_info["is_crit"])
		
 		# Apply knockback based on object type
		if object.has_method("apply_knockback_from_fireball"):
			object.apply_knockback_from_fireball(global_position, damage_info["is_crit"])
	
	# Spawn effect and destroy - using immediate destruction for reliability
	spawn_explosion_effect()
	queue_free()  # Immediate destruction

# Timer callback
func _on_fire_ball_vanish_timeout():
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
	var is_crit = can_crit && randf() < crit_chance  # Only check for crit if allowed
	var final_damage = damage * (crit_multiplier if is_crit else 1.0)
	return {"damage": final_damage, "is_crit": is_crit}
