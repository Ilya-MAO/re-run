class_name ItemSlot
extends Node

signal item_changed(item: ItemData)

const ITEM_SCENE: PackedScene = preload("res://src/shared/items/item/item.tscn")


@onready var shadow: Sprite2D = %Shadow
@export var inventory_data: InventoryData = InventoryData.new(&"drop_item")

var item: ItemData: set = _set_item


#region Item

func item_is(item_id: StringName) -> bool:
	return item != null and item.id == item_id


func equip_item(p_item: ItemData) -> bool:
	if item or not p_item: return false
	item = p_item
	return true


func consume_item(item_id: StringName) -> bool:
	if not item_is(item_id): return false
	item = null
	return true


func drop_item() -> void:
	var player := owner as Player
	if not ITEM_SCENE or not item or not player: return

	var throw_dir: Vector2 = player.last_move_direction
	var dropped: Item = ITEM_SCENE.instantiate()

	dropped.item_data = item

	player.get_parent().add_child(dropped)
	dropped.global_position = shadow.global_position

	dropped.throw(throw_dir, player.player_data.throw_force)
	item = null

#endregion

#region Specials

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(inventory_data.action) and item: drop_item()

#endregion

#region Setters

func _set_item(value: ItemData) -> void:
	item = value
	item_changed.emit(item)

#endregion
