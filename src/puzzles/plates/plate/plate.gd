class_name PlateLogic
extends Area2D

const UNSHADED_MAT := preload("res://assets/resources/unshaded.tres")

@export var active_color: Color = Color(0.728, 1.632, 2.117, 1.0)
@export var tilemaps: Tilemaps
@onready var sprite: AnimatedSprite2D = $AnimatedSprite

var _is_pressed: bool = false


func _ready() -> void:
	if tilemaps == null:
		tilemaps = get_tree().current_scene.find_child("Tilemaps", true, false) as Tilemaps

	_update_visual()


func _physics_process(_delta: float) -> void:
	var has_weight := false

	for body in get_overlapping_bodies():
		if body is Item or body is Player:
			has_weight = true
			break
		if body is Mirror and not body.is_lifted:
			has_weight = true
			break

	if has_weight != _is_pressed:
		_is_pressed = has_weight
		_update_visual()
		if tilemaps:
			tilemaps.set_direct_logic_signal(self, global_position, _is_pressed)


func _update_visual() -> void:
	if sprite:
		sprite.play("active" if _is_pressed else "passive")
		sprite.material = UNSHADED_MAT if _is_pressed else null
		sprite.modulate = active_color if _is_pressed else Color.WHITE
