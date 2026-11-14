@tool
class_name Item
extends RigidBody2D

@export var item_data: ItemData:
	set(value):
		item_data = value
		_apply_item_data()

var pickup_delay: float = 0.0
var _picked_up: bool = false

@onready var sprite: Sprite2D = $Sprite
@onready var logic_area: Area2D = $LogicArea


func _ready() -> void:
	_apply_item_data()
	if Engine.is_editor_hint(): return

	logic_area.body_entered.connect(_on_body_entered)

	if pickup_delay > 0.0:
		logic_area.monitoring = false
		await get_tree().create_timer(pickup_delay).timeout
		if is_instance_valid(logic_area):
			logic_area.monitoring = true


func _on_body_entered(body: Node2D) -> void:
	if _picked_up or body is not Player or not item_data:
		return

	var item_slot: ItemSlot = body.get_node("ItemSlot")
	if item_slot.equip_item(item_data):
		_picked_up = true
		queue_free()


func _apply_item_data() -> void:
	if not is_node_ready():
		await ready

	if not sprite:
		return

	sprite.texture = item_data.icon if item_data else null


func toss(direction: Vector2, force: float) -> void:
	apply_central_impulse(direction.normalized() * force)
