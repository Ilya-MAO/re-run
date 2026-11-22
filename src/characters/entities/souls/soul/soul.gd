class_name Soul
extends Character


@export var float_data: SoulData = SoulData.new()
@export var shadow_node: Node2D
@export var min_shadow_scale: float = 0.7


#region Specials

var _time_passed: float
var _base_shadow_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	super._ready()
	_time_passed = randf() * TAU
	if shadow_node:
		_base_shadow_scale = shadow_node.scale


func _process(delta: float) -> void:
	_time_passed += delta
	var wave: float = sin(_time_passed * float_data.speed)
	sprite.position.y = wave * float_data.amplitude
	
	if shadow_node:
		var height_factor: float = (1.0 - wave) * 0.5
		var scale_multiplier: float = lerp(1.0, min_shadow_scale, height_factor)
		shadow_node.scale = _base_shadow_scale * scale_multiplier

#endregion
