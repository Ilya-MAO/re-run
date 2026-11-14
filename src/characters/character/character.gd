class_name Character
extends CharacterBody2D

signal health_changed(health: float, max_health: float)
signal died

@export var max_health: float = 100.0
@export var health: float = 100.0

@export var protection: float = 0

@export var speed: float = 250.0
@export var speed_up: float = 25.0
@export var speed_down: float = 10.0

@export var float_amplitude: float = 4.0
@export var float_speed: float = 3.0
var float_time_passed: float = 0.0

@export var damage: float = 5

@export var animation_tree: AnimationTree
@export var sprite: Sprite2D

var is_pause: bool = false

func take_damage(amount: float) -> void:
	if is_pause: return
	is_pause = true

	var damage = abs(protection - amount)
	health = clamp(health - damage, 0.0, max_health)

	var tween = create_tween().set_loops(5)
	tween.tween_property(sprite, "modulate:a", 0.2, 0.05)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.05)

	health_changed.emit(health, max_health)
	
	if health <= 0: died.emit()
	get_tree().create_timer(0.1).timeout.connect(func(): is_pause = false)

func heal(amount: float) -> void:
	health = clamp(health + amount, 0.0, max_health)
	health_changed.emit(health, max_health)

func setProtection(factor: float) -> void:
	protection = factor
