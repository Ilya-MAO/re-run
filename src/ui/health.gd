class_name HealthBar
extends TextureProgressBar


#region Specials

func _ready() -> void:
	var player := get_tree().get_first_node_in_group(&"Players") as Player
	if not player: return

	player.health_changed.connect(_on_health_changed)
	player.max_health_changed.connect(_on_max_health_changed)

	_on_health_changed(player.health)
	_on_max_health_changed(player.max_health)

#endregion

#region Helpers

func _on_health_changed(health: float) -> void:
	value = health


func _on_max_health_changed(max_health: float) -> void:
	max_value = max_health

#endregion
