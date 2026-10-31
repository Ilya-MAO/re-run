class_name HealthBar
extends TextureProgressBar

@onready var player: DefaultCharacter = get_tree().get_first_node_in_group("Players")

func _ready() -> void:
	if player:
		max_value = player.maxHealth
		value = player.health
		player.healthChanged.connect(onHealthChanged)

func onHealthChanged(health: float, maxHealth: float) -> void:
	max_value = maxHealth
	value = health
