class_name Spawners
extends Node2D

signal enemies_cleared

var enemies: Array[Node2D] = []

func spawn() -> void:
	for spawner in get_children():
		if spawner is EnemySpawner:
			var enemy = spawner.spawn()
			if enemy:
				get_parent().add_child(enemy)
				enemies.append(enemy)
				enemy.died.connect(died.bind(enemies, enemy))

func died(array: Array[Node2D], enemy: Node2D) -> void:
	array.erase(enemy)
	check_arrays()
	enemy.queue_free()

func check_arrays() -> void:
	if enemies.is_empty(): enemies_cleared.emit()
