class_name Platform
extends Node

signal next_platform_requested(direction: Vector2)

enum Type {
	START,
	LIGHT_ACTIVE,
	LIGHT_PASSIVE,
	DARK_UP,
	DARK_DOWN,
	DARK_SIDE
}

@export var type: Type = Type.LIGHT_ACTIVE

@onready var bridges: BridgesTilemap = %Bridges
@onready var spawner: Spawner = %Spawner

var grid_coords: Vector2i = Vector2i.ZERO
var is_mirrored_x: bool = false
var available_directions: Array[Vector2i] = []
var spawned_soul: Soul = null


func setup(p_coords: Vector2i, p_mirror_x: bool = false, p_directions: Array[Vector2i] = []) -> void:
	grid_coords = p_coords
	is_mirrored_x = p_mirror_x
	available_directions = p_directions


#region Specials

func _ready() -> void:
	if is_mirrored_x:
		_apply_horizontal_mirror()

	if bridges:
		bridges.set_available_directions(available_directions, is_mirrored_x)
		bridges.next_platform_requested.connect(next_platform_requested.emit)

#endregion

#region Souls

func is_dark() -> bool:
	return type == Type.DARK_UP or type == Type.DARK_DOWN or type == Type.DARK_SIDE


func can_spawn_soul() -> bool:
	if is_dark() or spawned_soul != null:
		return false
	return spawner != null and spawner.has_scenes()


func spawn_soul(assigned_role: SoulRole, link_id: int) -> Soul:
	if not can_spawn_soul():
		return null

	var soul: Soul = spawner.spawn_soul()
	if not soul:
		return null

	add_child(soul)
	soul.global_position = spawner.global_position
	soul.assign_role(assigned_role, link_id)
	soul.died.connect(_on_soul_died)

	spawned_soul = soul
	return soul


func _on_soul_died() -> void:
	if is_instance_valid(spawned_soul):
		spawned_soul.queue_free()
	spawned_soul = null

#endregion

#region Helpers

func _apply_horizontal_mirror() -> void:
	var center_x: float = PlatformGenerator.PLATFORM_SIZE.x / 2.0
	for child in get_children():
		if child is Node2D:
			child.position.x = center_x * 2.0 - child.position.x
			child.scale.x *= -1.0

#endregion
