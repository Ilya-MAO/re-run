class_name CharacterData
extends Resource

const HEALTH_RANGE     = Vector2i(10,  1000)
const PROTECTION_RANGE = Vector2i(0,   20)
const DAMAGE_RANGE     = Vector2i(1,   100)
const SPEED_RANGE      = Vector2(50.0, 1000.0)
const SPEED_DIFF_RANGE = Vector2(5.0,  50.0)


@export var speed_up: float = 3000.0: set = _set_speed_up
@export var speed_down: float = 1500.0: set = _set_speed_down


#region Setters

func _set_speed_up(value: float) -> void:
	speed_up = clamp(value, SPEED_DIFF_RANGE.x, SPEED_DIFF_RANGE.y)


func _set_speed_down(value: float) -> void:
	speed_down = clamp(value, SPEED_DIFF_RANGE.x, SPEED_DIFF_RANGE.y)

#endregion
