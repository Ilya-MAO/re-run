class_name Slot
extends PanelContainer


@onready var icon: TextureRect = $Icon


#region Specials

var _item_slot: ItemSlot

func _ready() -> void:
	_update_visual(null)
	_bind_to_player.call_deferred()

#endregion

#region Helpers

func _bind_to_player() -> void:
	var player := get_tree().get_first_node_in_group(&"Players") as Player
	if not player: return

	for child in player.get_children():
		if child is not ItemSlot: continue

		_item_slot = child
		_item_slot.item_changed.connect(_update_visual)
		_update_visual(_item_slot.item)
		return


func _update_visual(data: ItemData) -> void:
	if not data:
		icon.texture = null
		icon.visible = false
		return

	icon.texture = data.icon
	icon.visible = true

#endregion
