class_name PlateLogic
extends Area2D

const UNSHADED_MAT: Material = preload("res://assets/resources/unshaded.tres")

@export var active_color: Color = Color(0.728, 1.632, 2.117, 1.0)
@export var connectors: ConnectorsTilemap

@onready var sprite: AnimatedSprite2D = %AnimatedSprite


#region Specials

var _is_pressed: bool = false
var _connectors_list: Array[ConnectorsTilemap] = []

func _ready() -> void:
	_update_visual()
	call_deferred(&"_bind_connectors")


func _physics_process(_delta: float) -> void:
	var has_weight: bool = false

	for body in get_overlapping_bodies():
		if body is Item or body is Player or (body is Mirror and not body.is_lifted):
			has_weight = true
			break

	if has_weight == _is_pressed: return

	_is_pressed = has_weight
	_update_visual()

	if _connectors_list.is_empty():
		_bind_connectors()

	for conn: ConnectorsTilemap in _connectors_list:
		if is_instance_valid(conn):
			conn.set_direct_signal(self, global_position, _is_pressed)

#endregion

#region Helpers

func _bind_connectors() -> void:
	_connectors_list.clear()

	if connectors:
		_connectors_list.append(connectors)
		return

	var root: Node = owner if owner else get_parent()
	while root and root.get_parent() and not (root is SubViewport):
		if root.find_children("*", "TileMapLayer", true, false).size() > 0:
			break
		root = root.get_parent()

	if not root:
		return

	for child: Node in root.find_children("*", "TileMapLayer", true, false):
		if child is ConnectorsTilemap:
			_connectors_list.append(child)


func _update_visual() -> void:
	if not sprite: return

	sprite.play(&"active" if _is_pressed else &"passive")
	sprite.material = UNSHADED_MAT if _is_pressed else null
	sprite.modulate = active_color if _is_pressed else Color.WHITE

#endregion
