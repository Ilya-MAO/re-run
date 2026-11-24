class_name HealthBar
extends TextureProgressBar


var _player: Player


#region Specials

func _ready() -> void:
	_bind_to_player.call_deferred()

#endregion

#region Helpers

func bind_player(target_player: Player) -> void:
	if not is_instance_valid(target_player):
		return
	if is_instance_valid(_player):
		if _player.health_changed.is_connected(_on_health_changed):
			_player.health_changed.disconnect(_on_health_changed)
		if _player.max_health_changed.is_connected(_on_max_health_changed):
			_player.max_health_changed.disconnect(_on_max_health_changed)

	_player = target_player
	if not _player.health_changed.is_connected(_on_health_changed):
		_player.health_changed.connect(_on_health_changed)
	if not _player.max_health_changed.is_connected(_on_max_health_changed):
		_player.max_health_changed.connect(_on_max_health_changed)

	_on_health_changed(_player.health)
	_on_max_health_changed(_player.max_health)


func _bind_to_player() -> void:
	var player := get_tree().get_first_node_in_group(&"Players") as Player
	if player:
		bind_player(player)


func _on_health_changed(health: float) -> void:
	value = health


func _on_max_health_changed(max_health: float) -> void:
	max_value = max_health

#endregion
