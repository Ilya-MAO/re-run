class_name EnemySpawner
extends Marker2D

@export var enemy_scene: PackedScene
@export_range(0.0, 1.0) var spawn_chance: float = 1.0

func spawn() -> CharacterBody2D:
	if enemy_scene and randf() > spawn_chance: return null

	var enemy: CharacterBody2D = enemy_scene.instantiate()
	enemy.z_index = 5
	enemy.position = position
	return enemy
