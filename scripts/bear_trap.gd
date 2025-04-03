extends Area2D

# Node references
@onready var sprite = $BearTrapSprite
@onready var collision_shape = $BearTrapHitbox

# State variables
var is_active = true
var trapped_player = null
var release_timer = null

# Called when the node enters the scene tree for the first time.
func _ready():
	# Connect signals
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	# Set up release timer
	release_timer = Timer.new()
	release_timer.one_shot = true
	release_timer.wait_time = 3.0
	release_timer.connect("timeout", _on_release_timer_timeout)
	add_child(release_timer)
	
	# Start with the open animation
	sprite.play("Open")
	
	# Make sure we only detect players
	collision_layer = 0
	collision_mask = 0
	
	# Set collision to only detect the Player group (assuming Player is on layer 1)
	set_collision_mask_value(1, true)

# Process physics for holding the player in place
func _physics_process(_delta):
	if trapped_player and is_instance_valid(trapped_player):
		# Hold the player still by zeroing their velocity
		# This functionality is now handled by the player's trap_player method
		pass

# Called when a body enters the bear trap
func _on_body_entered(body):
	if not is_active or trapped_player:
		return
		
	# Check if it's a player
	if body.is_in_group("Player"):
		print("Bear trap caught player!")
		trapped_player = body
		
		 # Call the player's trap function
		if trapped_player.has_method("trap_player"):
			trapped_player.trap_player()
		
		# Play closed animation
		sprite.play("Closed")
		
		# Start the release timer
		release_timer.start()
		
		# Set state to inactive while trapping player
		is_active = false

# Called when the release timer expires
func _on_release_timer_timeout():
	if trapped_player and is_instance_valid(trapped_player):
		print("Bear trap releasing player!")
		
		 # Release the player
		if trapped_player.has_method("release_player"):
			trapped_player.release_player()
		
		# Play open animation
		sprite.play("Open")
		
		# Reset trapped player reference
		trapped_player = null
		
		# Disable collision with the player temporarily
		# We'll use deferred call to ensure physics state is safe to change
		collision_shape.set_deferred("disabled", true)
		
		# Create a timer to reactivate the trap after a short delay
		var reactivate_timer = Timer.new()
		reactivate_timer.one_shot = true
		reactivate_timer.wait_time = 0.5
		reactivate_timer.connect("timeout", _on_reactivate_timer_timeout)
		add_child(reactivate_timer)
		reactivate_timer.start()

# Called when the trap should become active again
func _on_reactivate_timer_timeout():
	collision_shape.set_deferred("disabled", false)
	is_active = true
	print("Bear trap active again!")
