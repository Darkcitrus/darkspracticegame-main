extends Node

# Summoning variables
var player: Node = null
var minion_knight_scene: PackedScene = null
var minion_wizard_scene: PackedScene = null
var current_minions: Array = []
const MAX_MINIONS: int = 6  # Maximum number of minions allowed at once
const SUMMON_COUNT: int = 3  # Number of minions to summon per cast
const SUMMON_DELAY: float = 0.1  # Delay between consecutive summons in seconds

# Cooldown values
var summon_cooldown: float = 1.0  # Cooldown between summon actions
var last_knight_summon_time: float = 0.0
var last_wizard_summon_time: float = 0.0

# Visual effects
var summon_effect_scene: PackedScene = null

# Initialization
func initialize(player_node: Node):
	player = player_node
	
	# Load minion scenes
	minion_knight_scene = load("res://scenes/minion_knight.tscn")
	if not minion_knight_scene:
		push_error("Failed to load minion_knight scene!")
	
	minion_wizard_scene = load("res://scenes/minion_wizard.tscn")
	if not minion_wizard_scene:
		push_error("Failed to load minion_wizard scene!")
		
	# Optionally load a summon effect (you can create this later)
	if ResourceLoader.exists("res://scenes/summon.tscn"):
		summon_effect_scene = load("res://scenes/summon.tscn")
	
	print("PlayerSummon initialized with knights and wizards")

func _physics_process(_delta):
	if not player:
		return
		
	# Allow combat actions even when trapped
	if not player.can_take_combat_actions():
		return
		
	# Set up summon action using the existing summon_knight input (bound to 5 key)
	if Input.is_action_just_pressed("summon_knight"):
		attempt_knight_summon()
	
	# Set up summon action using the existing summon_wizard input (bound to 6 key)
	if Input.is_action_just_pressed("summon_wizard"):
		attempt_wizard_summon()
		
	# Clean up invalid minions from the array
	clean_invalid_minions()

func attempt_knight_summon():
	# Get current time
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Check cooldown
	if current_time - last_knight_summon_time < summon_cooldown:
		var remaining = last_knight_summon_time + summon_cooldown - current_time
		print("Knight summon on cooldown! Ready in: ", remaining, " seconds")
		return
		
	# Check if we have room for more minions
	if current_minions.size() >= MAX_MINIONS:
		print("Maximum number of minions reached!")
		return
		
	# Update cooldown time
	last_knight_summon_time = current_time
	
	# Calculate how many minions we can summon
	var minions_to_summon = min(SUMMON_COUNT, MAX_MINIONS - current_minions.size())
	
	if minions_to_summon <= 0:
		print("Cannot summon any more minions!")
		return
		
	print("Summoning ", minions_to_summon, " minion knights!")
	
	# Start the summoning sequence
	summon_knight_sequence(minions_to_summon)

func attempt_wizard_summon():
	# Get current time
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Check cooldown
	if current_time - last_wizard_summon_time < summon_cooldown:
		var remaining = last_wizard_summon_time + summon_cooldown - current_time
		print("Wizard summon on cooldown! Ready in: ", remaining, " seconds")
		return
		
	# Check if we have room for more minions
	if current_minions.size() >= MAX_MINIONS:
		print("Maximum number of minions reached!")
		return
		
	# Update cooldown time
	last_wizard_summon_time = current_time
	
	# Calculate how many minions we can summon
	var minions_to_summon = min(SUMMON_COUNT, MAX_MINIONS - current_minions.size())
	
	if minions_to_summon <= 0:
		print("Cannot summon any more minions!")
		return
		
	print("Summoning ", minions_to_summon, " minion wizards!")
	
	# Start the summoning sequence
	summon_wizard_sequence(minions_to_summon)

func summon_knight_sequence(count: int):
	# Summon one minion immediately
	summon_single_knight()
	
	# Schedule the rest with fixed (non-cumulative) delays
	if count > 1:
		# Create separate tweens for each minion to avoid cumulative delays
		for i in range(1, count):
			var tween = create_tween()
			# Each summon happens at a fixed interval after the first one
			tween.tween_callback(summon_single_knight).set_delay(SUMMON_DELAY)

func summon_wizard_sequence(count: int):
	# Summon one minion immediately
	summon_single_wizard()
	
	# Schedule the rest with fixed (non-cumulative) delays
	if count > 1:
		# Create separate tweens for each minion to avoid cumulative delays
		for i in range(1, count):
			var tween = create_tween()
			# Each summon happens at a fixed interval after the first one
			tween.tween_callback(summon_single_wizard).set_delay(SUMMON_DELAY)

func summon_single_knight():
	if not is_instance_valid(player) or not minion_knight_scene:
		return
		
	# Check again if we have room (in case the delayed summon should be canceled)
	if current_minions.size() >= MAX_MINIONS:
		print("Maximum number of minions reached during sequence!")
		return
		
	# Instance the minion scene
	var minion = minion_knight_scene.instantiate()
	
	if minion:
		# Add to the scene
		player.get_tree().get_root().add_child(minion)
		
		# Initialize with player as owner
		if minion.has_method("initialize"):
			minion.initialize(player)
		
		# Add to our tracking array
		current_minions.append(minion)
		
		# Spawn visual effect if available
		spawn_summon_effect(minion.global_position)
		
		print("Knight minion summoned! Current count: ", current_minions.size())
	else:
		push_error("Failed to instantiate knight minion!")

func summon_single_wizard():
	if not is_instance_valid(player) or not minion_wizard_scene:
		return
		
	# Check again if we have room (in case the delayed summon should be canceled)
	if current_minions.size() >= MAX_MINIONS:
		print("Maximum number of minions reached during sequence!")
		return
		
	# Instance the minion scene
	var minion = minion_wizard_scene.instantiate()
	
	if minion:
		# Add to the scene
		player.get_tree().get_root().add_child(minion)
		
		# Initialize with player as owner
		if minion.has_method("initialize"):
			minion.initialize(player)
		
		# Add to our tracking array
		current_minions.append(minion)
		
		# Spawn visual effect if available
		spawn_summon_effect(minion.global_position)
		
		print("Wizard minion summoned! Current count: ", current_minions.size())
	else:
		push_error("Failed to instantiate wizard minion!")

func clean_invalid_minions():
	# Remove any invalid minions from the tracking array
	var i = current_minions.size() - 1
	while i >= 0:
		if not is_instance_valid(current_minions[i]):
			current_minions.remove_at(i)
		i -= 1

func spawn_summon_effect_visual(position: Vector2):
	# Spawn a visual effect for the summoning if available
	if summon_effect_scene:
		var effect = summon_effect_scene.instantiate()
		if effect:
			player.get_tree().get_root().add_child(effect)
			effect.global_position = position
			
			# If the effect has a one-shot animation, it should clean itself up
			if effect.has_method("play"):
				effect.play()
	
	# Calculate how many minions we can summon
	var minions_to_summon = min(SUMMON_COUNT, MAX_MINIONS - current_minions.size())
	
	if minions_to_summon <= 0:
		print("Cannot summon any more minions!")
		return
		
	print("Summoning ", minions_to_summon, " minion knights!")
	
	# Start the summoning sequence
	summon_sequence(minions_to_summon)

func summon_sequence(count: int):
	# Summon one minion immediately
	summon_single_minion()
	
	# Schedule the rest with fixed (non-cumulative) delays
	if count > 1:
		# Create separate tweens for each minion to avoid cumulative delays
		for i in range(1, count):
			var tween = create_tween()
			# Each summon happens at a fixed interval after the first one
			tween.tween_callback(summon_single_minion).set_delay(SUMMON_DELAY)

func summon_single_minion():
	if not is_instance_valid(player) or not minion_knight_scene:
		return
		
	# Check again if we have room (in case the delayed summon should be canceled)
	if current_minions.size() >= MAX_MINIONS:
		print("Maximum number of minions reached during sequence!")
		return
		
	# Instance the minion scene
	var minion = minion_knight_scene.instantiate()
	
	if minion:
		# Add to the scene
		player.get_tree().get_root().add_child(minion)
		
		# Initialize with player as owner
		if minion.has_method("initialize"):
			minion.initialize(player)
		
		# Add to our tracking array
		current_minions.append(minion)
		
		# Spawn visual effect if available
		spawn_summon_effect(minion.global_position)
		
		print("Minion summoned! Current count: ", current_minions.size())
	else:
		push_error("Failed to instantiate minion!")

func clean_minion_list():
	# Remove any invalid minions from the tracking array
	var i = current_minions.size() - 1
	while i >= 0:
		if not is_instance_valid(current_minions[i]):
			current_minions.remove_at(i)
		i -= 1

func spawn_summon_effect(position: Vector2):
	# Spawn a visual effect for the summoning if available
	if summon_effect_scene:
		var effect = summon_effect_scene.instantiate()
		if effect:
			player.get_tree().get_root().add_child(effect)
			effect.global_position = position
			
			# If the effect has a one-shot animation, it should clean itself up
			if effect.has_method("play"):
				effect.play()
