class_name ItemSlot
extends Node2D

signal item_changed(new_item: ItemData)

@export var item_scene: PackedScene
@export var drop_action: StringName = &"drop_item"

var current_item: ItemData = null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(drop_action) and current_item != null:
		drop_current_item()

func has_item(item_id: StringName) -> bool:
	return current_item != null and current_item.id == item_id

func consume_item(item_id: StringName) -> bool:
	if not has_item(item_id): return false

	current_item = null
	item_changed.emit(null)
	return true

func equip_item(new_item: ItemData) -> bool:
	if not new_item or current_item != null: return false

	current_item = new_item
	item_changed.emit(current_item)
	return true

func drop_current_item() -> void:
	var owner_player := get_parent() as Player
	if not item_scene or not current_item or not owner_player:
		return

	var throw_dir := owner_player.last_move_direction
	if throw_dir == Vector2.ZERO:
		throw_dir = Vector2.DOWN

	var dropped := item_scene.instantiate() as Item
	dropped.item_data = current_item
	dropped.pickup_delay = 0.25

	owner_player.get_parent().add_child(dropped)
	dropped.global_position = owner_player.global_position + throw_dir.normalized() * 2.0
	dropped.toss(throw_dir, 140.0)

	current_item = null
	item_changed.emit(null)
