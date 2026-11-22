class_name Spawner
extends Marker2D


@export var entity_scenes: Array[PackedScene] = []
@export_range(0.0, 1.0) var spawn_chance: float = 1.0


func spawn() -> Character:
	if entity_scenes.is_empty() or randf() > spawn_chance: return null

	var scene: PackedScene = entity_scenes.pick_random()
	if not scene: return null

	var entity := scene.instantiate() as Character
	if not entity: return null

	entity.z_index = 200
	entity.global_position = global_position
	return entity
