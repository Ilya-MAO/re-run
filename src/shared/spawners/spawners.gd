class_name Spawners
extends Node

signal all_enemies_died


var entities: Array[Character] = []


func spawn() -> void:
	for spawner in get_children():
		if spawner is not Spawner: continue

		var entity: Character = spawner.spawn()
		if not entity: continue

		entity.died.connect(_on_entity_died.bind(entity))
		entities.append(entity)
		get_parent().add_child(entity)

#region Helpers

func _on_entity_died(enemy: Character) -> void:
	entities.erase(enemy)
	enemy.queue_free()

	if entities.is_empty(): all_enemies_died.emit()

#endregion
