class_name EnemySpawner
extends Marker2D

@export var enemyScene: PackedScene = preload("res://scenes/characters/enemies/pirate/pirate.tscn")
@export_range(0.0, 1.0) var spawnChance: float = 1.0

func spawn() -> CharacterBody2D:
	if enemyScene and randf() <= spawnChance:
		var enemy: CharacterBody2D = enemyScene.instantiate()
		enemy.z_index = 5
		enemy.position = position
		return enemy
	return null
