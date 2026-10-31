class_name SpawnBlock
extends Node2D

signal enemiesCleared

@onready var enemySpawners: Node2D = $EnemySpawners
var enemies: Array[Node2D] = []

func spawnEnemies() -> void:
	if not enemySpawners: return
	
	for child in enemySpawners.get_children():
		if child is EnemySpawner:
			var enemy = child.spawn()
			if enemy:
				get_parent().add_child(enemy)
				enemies.append(enemy)
				enemy.died.connect(enemyDied.bind(enemy))

func enemyDied(enemy: Node2D) -> void:
	enemies.erase(enemy)
	if enemies.is_empty():
		enemiesCleared.emit()

	enemy.queue_free()
