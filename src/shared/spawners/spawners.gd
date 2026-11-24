class_name Spawners
extends Node2D

signal soul_died

@export var default_soul_scenes: Array[PackedScene] = []

var spawned_soul: Soul = null
var _has_spawned: bool = false


func can_spawn_soul() -> bool:
	if _has_spawned:
		return false
	return not _get_valid_spawners().is_empty()


func spawn_soul(assigned_role: SoulRole, link_id: int) -> Soul:
	if not can_spawn_soul():
		return null

	var valid_spawners: Array[Spawner] = _get_valid_spawners()
	var spawner: Spawner = valid_spawners.pick_random()

	var soul: Soul = spawner.spawn_soul(default_soul_scenes)
	if not soul:
		return null

	_has_spawned = true
	spawned_soul = soul

	get_parent().add_child(soul)
	soul.global_position = spawner.global_position
	soul.assign_role(assigned_role, link_id)
	soul.died.connect(_on_soul_died)

	return soul


#region Helpers

func _get_valid_spawners() -> Array[Spawner]:
	var result: Array[Spawner] = []
	for child in get_children():
		if child is Spawner and child.has_scenes(default_soul_scenes):
			result.append(child)
	return result


func _on_soul_died() -> void:
	if is_instance_valid(spawned_soul):
		spawned_soul.queue_free()
	spawned_soul = null
	soul_died.emit()

#endregion
