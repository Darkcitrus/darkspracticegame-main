extends Area2D
class_name BurgerPickup

# Burger-specific properties
@export var heal_amount: float = 25.0

# Node References
var player_node: Node2D = null

# Check if the player needs healing
func should_attract_to_player() -> bool:
	if player_node and "health" in player_node and "max_health" in player_node:
		return player_node.health < player_node.max_health
	return false

# Apply the healing effect to the player
func apply_pickup_effect(player):
	if player.has_method("heal"):
		player.heal(heal_amount)
		print("Healing player for: ", heal_amount)

# Only allow pickup if player needs healing
func can_be_picked_up_by(player) -> bool:
	if "health" in player and "max_health" in player:
		return player.health < player.max_health
	return false