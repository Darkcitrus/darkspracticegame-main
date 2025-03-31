extends Area2D

# Node References
var initial_position: Vector2
var current_base_position: Vector2
var oscillation_start_time: float = 0.0
var heal_amount: float = 25.0
var oscillation_intensity: float = 5.0
var oscillation_speed: float = 5.0

# Player attraction variables
var attraction_range: float = 150.0
var attraction_speed: float = 600.0
var player_node: Node2D = null
var was_in_attraction_range: bool = false

# Glow effect properties
var glow_enabled: bool = true
var glow_intensity: float = 1.0
@export var glow_color: Color = Color(0.2, 0.2, 0.4, 0.8) # Warm orange/yellow for burger
var glow_pulse_speed: float = 2.0
var glow_size: float = 2.2 # Slightly larger than default
var max_glow_intensity_multiplier: float = 3.0 # Stronger intensity increase for burger
var glow_radius: float = 40.0
var sprite_node: Sprite2D
var glow_node: Sprite2D

# Respawn variables
var respawn_time: float = 5.0
var respawn_timer: Timer

func _ready():
	initial_position = position
	current_base_position = initial_position  # Initialize current base position
	oscillation_start_time = Time.get_ticks_msec() / 1000.0
	
	# Connect signals
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	
	# Create respawn timer
	respawn_timer = Timer.new()
	respawn_timer.one_shot = true
	respawn_timer.wait_time = respawn_time
	respawn_timer.connect("timeout", _on_respawn_timer_timeout)
	add_child(respawn_timer)
	
	# Force it to check for any player in range on start
	call_deferred("_check_for_player")
	
	# Setup glow effect with a slight delay to ensure all nodes are ready
	call_deferred("setup_glow_effect")

func setup_glow_effect():
	# Find the sprite node
	if has_node("burgersprite"):
		sprite_node = $burgersprite
	else:
		for child in get_children():
			if child is Sprite2D:
				sprite_node = child
				break
	
	if sprite_node and glow_enabled:
		print("Setting up filled circular glow effect for burger")
		
		# Create a custom filled circular texture
		var img = Image.create(256, 256, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0)) # Start with fully transparent image
		
		# Draw a filled circle with soft edges
		var center_x = 128
		var center_y = 128
		var max_radius = 100  # Smaller radius for the filled glow
		
		# Draw each pixel manually to ensure perfect transparency
		for x in range(256):
			for y in range(256):
				var dist = sqrt(pow(x - center_x, 2) + pow(y - center_y, 2))
				
				 # Create a filled glow that fades at the edges
				if dist <= max_radius:
					# Calculate opacity - full in the center, fading toward edges
					var opacity = 1.0 - (dist / max_radius)
					opacity = pow(opacity, 1.5)  # Add a curve to make fade more pronounced
					opacity *= 0.8  # Slightly higher opacity for burger
					
					# Set the pixel color with the calculated opacity
					img.set_pixel(x, y, Color(1, 1, 1, opacity))
		
		# Create texture from image
		var texture = ImageTexture.create_from_image(img)
		
		# Create a separate node for the glow
		glow_node = Sprite2D.new()
		glow_node.name = "BurgerGlowSprite"
		glow_node.texture = texture
		glow_node.position = Vector2.ZERO
		glow_node.scale = Vector2.ONE * (sprite_node.texture.get_width() / 256.0 * glow_size)
		glow_node.z_index = sprite_node.z_index - 1
		glow_node.modulate = glow_color
		
		# Create material with additive blend mode
		var material = CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow_node.material = material
		
		# Add the glow node to the scene
		add_child(glow_node)
		
		# Log success
		print("Burger glow effect applied successfully")

func _check_for_player():
	# Find any player in the scene
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		player_node = players[0]
		print("Found player at start: ", player_node.position)

func _process(delta: float):
	# Skip processing if invisible (collected)
	if not visible:
		return
		
	# Calculate oscillation
	var elapsed_time = Time.get_ticks_msec() / 1000.0 - oscillation_start_time
	var oscillation_offset = sin(elapsed_time * oscillation_speed) * oscillation_intensity
	
	# Player detection - if we don't have a reference to the player, try to find one
	if not player_node:
		var players = get_tree().get_nodes_in_group("Player")
		if players.size() > 0:
			player_node = players[0]
	
	# Attraction logic - only if player needs healing
	if player_node and player_node.is_inside_tree() and player_needs_healing():
		var distance_to_player = position.distance_to(player_node.position)
	
		# Check if the player is within attraction range
		if distance_to_player <= attraction_range:
			was_in_attraction_range = true
			
			# Calculate direction vector to player (both X and Y)
			var direction_to_player = (player_node.position - position).normalized()
			
			# Stronger attraction force calculation
			var attraction_force = attraction_speed * pow(1.0 - (distance_to_player / attraction_range), 2.0)
			
			# Apply movement in both X and Y directions
			position += direction_to_player * attraction_force * delta
			
			# Update the current base position (without the oscillation)
			current_base_position = Vector2(position.x, position.y - oscillation_offset)
			
			# Intensify glow when approaching player
			if glow_enabled and glow_node:
				# Calculate how close we are to the player
				var proximity_factor = 1.0 - (distance_to_player / attraction_range)
				proximity_factor = pow(proximity_factor, 2.0)
				
				# Pulse effect
				var time_pulse = (sin(Time.get_ticks_msec() / 1000.0 * glow_pulse_speed) + 1.0) * 0.5
				
				# Combine proximity and pulse effects
				var final_intensity = glow_intensity * (1.0 + proximity_factor * (max_glow_intensity_multiplier - 1.0))
				final_intensity *= (0.8 + time_pulse * 0.4)
				
				# Apply the effects
				glow_node.modulate.a = final_intensity
				
				# Scale the glow based on proximity
				var base_scale = sprite_node.texture.get_width() / 256.0 * glow_size
				glow_node.scale = Vector2.ONE * base_scale * (1.0 + proximity_factor * 1.0)
				
				# Make color more intense when closer (shift toward brighter yellow)
				var base_color = glow_color
				var bright_color = Color(1.0, 0.8, 0.3, base_color.a)
				glow_node.modulate = base_color.lerp(bright_color, proximity_factor)
				glow_node.modulate.a = final_intensity
		else:
			# Not in range, just oscillate from current position
			position.y = current_base_position.y + oscillation_offset
			
			# Reset glow if we're not in attraction range
			if glow_enabled and glow_node and was_in_attraction_range:
				# Reset with pulse
				var time_pulse = (sin(Time.get_ticks_msec() / 1000.0 * glow_pulse_speed) + 1.0) * 0.5
				glow_node.modulate = glow_color
				glow_node.modulate.a = glow_intensity * (0.8 + time_pulse * 0.4)
				
				# Reset scale
				var base_scale = sprite_node.texture.get_width() / 256.0 * glow_size
				glow_node.scale = Vector2.ONE * base_scale
	else:
		# No player or player at full health, just oscillate from current position
		position.y = current_base_position.y + oscillation_offset
		
		# Maintain pulse effect even when not attracting
		if glow_enabled and glow_node:
			var time_pulse = (sin(Time.get_ticks_msec() / 1000.0 * glow_pulse_speed) + 1.0) * 0.5
			glow_node.modulate = glow_color
			glow_node.modulate.a = glow_intensity * (0.8 + time_pulse * 0.4)

# Check if player needs healing (health below max)
func player_needs_healing() -> bool:
	if player_node and "health" in player_node and "max_health" in player_node:
		return player_node.health < player_node.max_health
	return false

func _on_body_entered(body):
	if not visible:  # Skip if already collected
		return
		
	if body.is_in_group("Player") and player_needs_healing():
		player_node = body
		print("Player entered burger area")
		
		if body.has_method("heal"):
			body.heal(heal_amount)
			print("Healing player for: ", heal_amount)
			
			# Hide instead of destroying
			visible = false
			# Turn off collision - use the correct node name "burgerbox"
			if has_node("burgerbox"):
				$burgerbox.set_deferred("disabled", true)
			# Start respawn timer
			respawn_timer.start()

func _on_body_exited(body):
	if body == player_node:
		print("Player exited burger area")
		# Do NOT set player_node to null, we still want to track them for attraction

func _on_respawn_timer_timeout():
	# Reset position to initial position
	position = initial_position
	current_base_position = initial_position
	# Reset oscillation time
	oscillation_start_time = Time.get_ticks_msec() / 1000.0
	# Make visible again
	visible = true
	# Enable collision - use the correct node name "burgerbox"
	if has_node("burgerbox"):
		$burgerbox.set_deferred("disabled", false)
	print("Burger respawned at: ", position)
	
	# Reset glow when respawning
	if glow_enabled and glow_node:
		var base_scale = sprite_node.texture.get_width() / 256.0 * glow_size
		glow_node.scale = Vector2.ONE * base_scale
		glow_node.modulate = glow_color
		glow_node.modulate.a = glow_intensity
