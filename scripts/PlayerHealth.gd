extends Node

var player: Node = null

func initialize(player_node: Node):
	player = player_node

func _physics_process(_delta):
	if player:
		handle_health()

func handle_health():
	if player.health <= 0:
		player.alive = false
		die()

func take_damage(amount):
	if not player.dodging and player.alive:
		print("Player taking damage: ", amount)
		player.health -= amount
		print("Player health now: ", player.health)
		
		if player.healthbar:
			print("Updating player healthbar to: ", player.health)
			player.healthbar.value = player.health
			
		if player.health <= 0:
			die()

func die():
	if not player.alive:
		return
		
	print("Player died!")
	player.alive = false
	player.visible = false
	player.respawn_timer.start()

func _on_respawn_timer_timeout():
	player.health = player.max_health
	player.alive = true
	player.visible = true
	player.position = Vector2(100, 100)
	if player.healthbar:
		player.healthbar.value = player.health
	print("Player respawned!")
