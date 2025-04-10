extends Area2D

# Damage settings
@export var damage: int = 30  # Damage dealt to player
@export var cooldown: float = 0.5  # Cooldown in seconds
@export var knockback_strength: float = 100.0  # Strength of knockback to apply

# Cooldown tracking
var can_damage: bool = true
var player_in_area: bool = false
var current_player = null

# Reference to cooldown timer
var damage_cooldown_timer: Timer

func _ready():
	# Connect signals for player detection
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	
	# Create cooldown timer
	damage_cooldown_timer = Timer.new()
	damage_cooldown_timer.one_shot = true
	damage_cooldown_timer.wait_time = cooldown
	damage_cooldown_timer.timeout.connect(_on_damage_cooldown_timeout)
	add_child(damage_cooldown_timer)
	
	# Set collision to detect player
	collision_mask = 1  # Assuming player is on layer 1
	collision_layer = 4  # Using layer 4 for traps/hazards

func _physics_process(_delta):
	# Apply damage if player is in the area and cooldown has passed
	if player_in_area and can_damage and current_player != null:
		apply_damage()

func apply_damage():
	# Check if player is valid and has take_damage method
	if is_instance_valid(current_player) and current_player.has_method("take_damage"):
		print("Spike pad dealing " + str(damage) + " physical damage to player")
		current_player.take_damage(damage, false, "physical")  # Apply physical damage (not a critical hit)
		
		 # Apply knockback to trigger hurt animation
		apply_knockback_to_player(current_player)
		
		# Start cooldown
		can_damage = false
		damage_cooldown_timer.start()

# Apply knockback to trigger the hurt animation
func apply_knockback_to_player(player):
	if player.has_method("apply_knockback_from_fireball"):
		# Use the existing knockback method to trigger hurt animation
		# Calculate direction from spike pad to player
		var knockback_direction = (player.global_position - global_position).normalized()
		player.knockback_direction = knockback_direction
		player.knockback_active = true
		player.knockback_remaining_time = player.knockback_max_time
		player.knockback_strength = knockback_strength
		print("Player knocked back from spike pad in direction: ", knockback_direction)

func _on_damage_cooldown_timeout():
	can_damage = true
	# If player is still in the area, damage them again
	if player_in_area and current_player != null:
		apply_damage()

func _on_body_entered(body):
	if body.is_in_group("Player"):
		player_in_area = true
		current_player = body
		
		# Apply immediate damage when player first enters
		if can_damage:
			apply_damage()

func _on_body_exited(body):
	if body.is_in_group("Player"):
		player_in_area = false
		current_player = null

# For cases where the player is an Area2D instead of a body
func _on_area_entered(area):
	var parent = area.get_parent()
	if parent and parent.is_in_group("Player"):
		player_in_area = true
		current_player = parent
		
		# Apply immediate damage when player first enters
		if can_damage:
			apply_damage()

func _on_area_exited(area):
	var parent = area.get_parent()
	if parent and parent.is_in_group("Player"):
		player_in_area = false
		current_player = null
