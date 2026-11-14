class_name CrystalDoorArea
extends Area2D

enum Direction { UP, DOWN, LEFT, RIGHT }

@export var direction: Direction = Direction.UP

func get_direction() -> Vector2:
	match direction:
		Direction.UP: return Vector2.UP
		Direction.DOWN: return Vector2.DOWN
		Direction.LEFT: return Vector2.LEFT
		Direction.RIGHT: return Vector2.RIGHT
	return Vector2.ZERO
