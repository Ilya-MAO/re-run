class_name Slot
extends PanelContainer


@onready var icon: TextureRect = $Icon

var _item_slot: ItemSlot


#region Specials

func _ready() -> void:
	_update_visual(null)
	_bind_to_player.call_deferred()

#endregion

#region Helpers

func bind_player(target_player: Player) -> void:
	if not is_instance_valid(target_player):
		return
	for child in target_player.get_children():
		if child is not ItemSlot:
			continue

		if is_instance_valid(_item_slot) and _item_slot != child and _item_slot.item_changed.is_connected(_update_visual):
			_item_slot.item_changed.disconnect(_update_visual)

		_item_slot = child
		if not _item_slot.item_changed.is_connected(_update_visual):
			_item_slot.item_changed.connect(_update_visual)
		_update_visual(_item_slot.item)
		return


func _bind_to_player() -> void:
	var player := get_tree().get_first_node_in_group(&"Players") as Player
	if player:
		bind_player(player)


func _update_visual(data: ItemData) -> void:
	if not data:
		icon.texture = null
		icon.visible = false
		return

	icon.texture = data.icon
	icon.visible = true

#endregion
