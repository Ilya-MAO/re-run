class_name SoulData
extends Resource

const AMPLITUDE_RANGE = Vector2(0.0, 20.0)
const SPEED_RANGE     = Vector2(0.0, 20.0)


@export_group("Float")
@export var amplitude: float = 4.0: set = _set_amplitude
@export var speed: float = 3.0: set = _set_speed


#region Setters

func _set_amplitude(value: float) -> void:
	amplitude = clamp(value, AMPLITUDE_RANGE.x, AMPLITUDE_RANGE.y)


func _set_speed(value: float) -> void:
	speed = clamp(value, SPEED_RANGE.x, SPEED_RANGE.y)

#endregion
