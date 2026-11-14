class_name HealthBar
extends TextureProgressBar

@onready var player: Player = get_tree().get_first_node_in_group("Players")

func _ready() -> void:
	if player:
		max_value = player.max_health
		value = player.health
		player.health_changed.connect(on_health_changed)

func on_health_changed(health: float, max_health: float) -> void:
	max_value = max_health
	value = health
