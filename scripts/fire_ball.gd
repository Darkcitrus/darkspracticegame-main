# This script controls a fireball projectile in the game
# The fireball is an Area2D node that moves in a specified direction and destroys itself upon collision or timeout
extends Area2D

const ExplosionEffect = preload("res://scenes/explosion_effect.tscn")
# Node References
# Timer that controls how long the fireball exists before self-destructing
@onready var fire_ball_vanish: Timer = $FireBallVanish

# Movement Properties
# Direction vector that determines where the fireball will travel
var direction: Vector2 = Vector2.ZERO  # Initialize to zero vector
# Initial speed at which the fireball moves (in pixels per second)
var current_speed: float = 100  
# Maximum speed the fireball can reach (in pixels per second)
const MAX_SPEED: float = 12000   
# Speed multiplier per second (greater than 1 for exponential growth)
const SPEED_MULTIPLIER: float = 20

# Damage Properties
# Base damage for fireball
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
	# Set a smaller scale for the fireball
	scale = Vector2(0.5, 0.5)  # Adjust this value to get the desired size

func _ready():
	print("Fireball created with damage: ", damage)
	add_to_group("Effects")
	
	# Set up collision properties
	monitoring = true
	monitorable = true
	
	# Connect collision signals
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
		
	fire_ball_vanish.start()

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
	pass

# Signal Handlers
# Called when the fireball collides with another body
func _on_body_entered(body: Node2D) -> void:
	print("Fireball hit body: ", body.name, " in groups: ", body.get_groups())
	# Check self-destruction if body or its parent is in Enemy or if body is in World
	var hit_enemy = body.is_in_group("Enemy") or (body.get_parent() and body.get_parent().is_in_group("Enemy"))
	if hit_enemy or body.is_in_group("World"):
		if body.has_method("take_damage"):
			var damage_info = calculate_damage()
			body.take_damage(damage_info["damage"], damage_info["is_crit"])
		spawn_explosion_effect()
		queue_free()  # Self-delete upon contact

# Called when the fireball enters another area
func _on_area_entered(area: Area2D) -> void:
	print("Fireball hit area: ", area.name, " in groups: ", area.get_groups())
	# Check self-destruction if area or its parent is in Enemy or if area is in World
	var hit_enemy = area.is_in_group("Enemy") or (area.get_parent() and area.get_parent().is_in_group("Enemy"))
	if hit_enemy or area.is_in_group("World"):
		if area.has_method("take_damage"):
			var damage_info = calculate_damage()
			area.take_damage(damage_info["damage"], damage_info["is_crit"])
		spawn_explosion_effect()
		queue_free()  # Self-delete upon contact

# Timer callback
# Called when the fireball's lifetime expires
func _on_fire_ball_vanish_timeout():
	spawn_explosion_effect()
	queue_free()

func get_damage() -> float:
	print("Fireball damage requested: ", damage)
	return damage

func spawn_explosion_effect():
	if not is_instance_valid(self):
		return
	var explosion = ExplosionEffect.instantiate()
	explosion.global_position = global_position
	get_tree().get_root().add_child(explosion)

func calculate_damage() -> Dictionary:
	var is_crit = randf() < crit_chance
	var final_damage = damage * (crit_multiplier if is_crit else 1.0)
	print("Fireball damage: ", final_damage, " (Critical: ", is_crit, ")")
	return {"damage": final_damage, "is_crit": is_crit}
