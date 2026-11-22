class_name Character
extends CharacterBody2D

signal health_changed(health: int)
signal max_health_changed(max_health: int)
signal protection_changed(protection: int)
signal damage_changed(damage: int)
signal speed_changed(speed: float)
signal died


@export_group("Stats")
@export var character_data: CharacterData = CharacterData.new()

@export var max_health: int = 100: set = _set_max_health
@export var health: int = -1: set = _set_health

@export var protection: int = 0: set = _set_protection
@export var damage: int = 10: set = _set_damage
@export var speed: float = 250.0: set = _set_speed

@onready var animation: AnimationTree = %Tree
@onready var sprite: Sprite2D = %Sprite


var _has_block: bool = false

func take_damage(amount: int) -> void:
	if _has_block: return
	_has_block = true

	var damage = max(amount - protection, 0)
	health -= damage

	var tween = create_tween().set_loops(5)
	tween.tween_property(sprite, "modulate:a", 0.2, 0.05)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.05)

	await get_tree().create_timer(0.3).timeout
	_has_block = false

#region Specials

func _ready() -> void:
	if health <= 0: health = max_health

#endregion

#region Setters

func _set_health(value: int) -> void:
	health = clamp(value, 0, max_health)
	health_changed.emit(health)
	if health <= 0: died.emit()


func _set_max_health(value: int) -> void:
	max_health = clamp(value, character_data.HEALTH_RANGE.x, character_data.HEALTH_RANGE.y)
	max_health_changed.emit(max_health)
	if health > max_health: health = max_health


func _set_protection(value: int) -> void:
	protection = clamp(value, character_data.PROTECTION_RANGE.x, character_data.PROTECTION_RANGE.y)
	protection_changed.emit(protection)


func _set_damage(value: int) -> void:
	damage = clamp(value, character_data.DAMAGE_RANGE.x, character_data.DAMAGE_RANGE.y)
	damage_changed.emit(damage)


func _set_speed(value: float) -> void:
	speed = clampf(value, character_data.SPEED_RANGE.x, character_data.SPEED_RANGE.y)
	speed_changed.emit(speed)

#endregion
