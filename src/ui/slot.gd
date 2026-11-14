class_name Slot
extends PanelContainer

@onready var icon: TextureRect = $Icon
var item_slot: ItemSlot

func _ready() -> void:
	_update_visual(null)
	_bind_to_player.call_deferred()

func _bind_to_player() -> void:
	var player := get_tree().get_first_node_in_group("Players")
	if not player:
		return
		
	for child in player.get_children():
		if child is ItemSlot:
			item_slot = child
			item_slot.item_changed.connect(_update_visual)
			_update_visual(item_slot.current_item)
			break

func _update_visual(data: ItemData) -> void:
	if not data:
		icon.texture = null
		icon.visible = false
		return
		
	icon.texture = data.icon
	icon.visible = true
