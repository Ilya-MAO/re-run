class_name Room
extends Node2D

signal next_room_requested(direction: Vector2)
signal enemies_cleared

@export var doors: Doors
@export var enemy_spawners: Spawners = null

func _ready() -> void:
	doors.next_room_requested.connect(next_room_requested.emit)

	if enemy_spawners:
		enemy_spawners.spawn()
		enemy_spawners.enemies_cleared.connect(enemies_cleared.emit)
