class_name BridgesData
extends Resource

enum Side { TOP = 1, BOTTOM = 2, LEFT = 4, RIGHT = 8 }

@export var bridges: Dictionary = {
	Side.TOP: {
		"pattern": 0, "start": Vector2i(7, -3),
		"triggers": [Vector2i(6, 0), Vector2i(9, 0)],
		"blockers": [Vector2i(7, -1), Vector2i(8, -1)],
		"dir": Vector2i.UP
	},
	Side.BOTTOM: {
		"pattern": 0,
		"start": Vector2i(7, 7),
		"triggers": [Vector2i(6, 7), Vector2i(9, 7)],
		"blockers": [Vector2i(7, 8), Vector2i(8, 8)],
		"dir": Vector2i.DOWN
	},
	Side.LEFT: {
		"pattern": 1,
		"start": Vector2i(-3, 3),
		"triggers": [Vector2i(0, 2), Vector2i(0, 5)],
		"blockers": [Vector2i(-1, 3), Vector2i(-1, 4)],
		"dir": Vector2i.LEFT
	},
	Side.RIGHT: {
		"pattern": 2,
		"start": Vector2i(15, 3),
		"triggers": [Vector2i(15, 2), Vector2i(15, 5)],
		"blockers": [Vector2i(16, 3), Vector2i(16, 4)],
		"dir": Vector2i.RIGHT
	}
}
