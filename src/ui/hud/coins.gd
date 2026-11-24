class_name Coins
extends PanelContainer


@onready var coin_label: Label = $HContainer/Label

var _player: Player


#region Specials

func _ready() -> void:
	_bind_to_player.call_deferred()

#endregion

#region Helpers

func bind_player(target_player: Player) -> void:
	if not is_instance_valid(target_player):
		return
	if is_instance_valid(_player) and _player.coins_changed.is_connected(_on_coins_changed):
		_player.coins_changed.disconnect(_on_coins_changed)

	_player = target_player
	if not _player.coins_changed.is_connected(_on_coins_changed):
		_player.coins_changed.connect(_on_coins_changed)
	_on_coins_changed(_player.coins)


func _bind_to_player() -> void:
	var player := get_tree().get_first_node_in_group(&"Players") as Player
	if player:
		bind_player(player)


func _on_coins_changed(new_amount: int) -> void:
	coin_label.text = str(new_amount)

#endregion
