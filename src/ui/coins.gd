class_name Coins
extends PanelContainer

@onready var coin_label: Label = $HContainer/Label

func _ready() -> void:
	var player := get_tree().get_first_node_in_group("Players") as Player
	if player:
		player.coins_changed.connect(_on_coins_changed)
		_on_coins_changed(player.coins)

func _on_coins_changed(new_amount: int) -> void:
	coin_label.text = str(new_amount)
