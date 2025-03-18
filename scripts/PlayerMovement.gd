extends Node

var player: Node = null
var dodge_timer: Timer = null
var dodge_recovery: Timer = null
var dodge_cooldown: Timer = null

func initialize(player_node: Node):
	player = player_node
	dodge_timer = player.get_node("DodgeTimer")
	dodge_recovery = player.get_node("DodgeRecovery")
	dodge_cooldown = player.get_node("DodgeCooldown")

	# Connect all signals
	dodge_timer.timeout.connect(_on_dodge_timer_timeout)
	dodge_recovery.timeout.connect(_on_dodge_recovery_timeout)
	dodge_cooldown.timeout.connect(_on_dodge_cooldown_timeout)

func _physics_process(_delta):
	# Skip movement if knockback is active
	if player.knockback_active:
		return

	# Normal movement code
	if player:
		handle_movement()

func handle_movement():
	if not player.dodging:
		player.move_input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var SPEED = player.run_speed if not player.dodging else player.dodge_speed
	var movedirection = player.move_input * SPEED
	player.velocity = movedirection
	if player.can_dodge:
		if Input.is_action_just_pressed("dash") and not player.dodging and player.dodges > 0:
			handle_dodge()

func handle_dodge():
	if player.dodges > 0:
		player.dodges -= 1 
		print("Dodge started! Remaining dashes: " + str(player.dodges))
		player.dodge_label.text = str(player.dodges)
		player.dodging = true
		player.can_dodge = false
		player.dodge_timer.start()

func _on_dodge_timer_timeout():
	player.dodging = false
	player.dodge_cooldown.start()
	print("Dodge ended, starting cooldown")

	if player.dodges < player.MAX_DODGES and not player.dodge_recovering:
		player.dodge_recovering = true
		player.dodge_recovery.start()
		print("Starting dodge recovery")

func _on_dodge_recovery_timeout():
	if player.dodges < player.MAX_DODGES:
		player.dodges += 1
		print("Recovered a dodge. Current dodges: " + str(player.dodges))
		player.dodge_label.text = str(player.dodges)
				
		if player.dodges < player.MAX_DODGES:
			player.dodge_recovery.start()
		else:
			player.dodge_recovering = false

func _on_dodge_cooldown_timeout():
	player.can_dodge = true
	print("Can dodge again")
