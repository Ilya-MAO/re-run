class_name DefaultCharacter
extends CharacterBody2D

signal healthChanged(health: float, maxHealth: float)
signal protectionChanged(protection: float)
signal died

@export var maxHealth: float = 100.0
@export var health: float = 100.0

@export var protection: float = 0

@export var speed: float = 250.0
@export var speedUp: float = 25.0
@export var speedDown: float = 10.0

@export var floatAmplitude: float = 4.0
@export var floatSpeed: float = 3.0

@export var damage: float = 5

@export var animationTree: AnimationTree
@export var sprite: Sprite2D
var isPause: bool = false

func takeDamage(amount: float) -> void:
	if isPause: return
	isPause = true

	var damage = abs(protection - amount)
	health = clamp(health - damage, 0.0, maxHealth)

	var tween = create_tween().set_loops(5)
	tween.tween_property(sprite, "modulate:a", 0.2, 0.05)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.05)

	healthChanged.emit(health, maxHealth)
	
	if health <= 0: died.emit()
	get_tree().create_timer(0.1).timeout.connect(func(): isPause = false)

func heal(amount: float) -> void:
	health = clamp(health + amount, 0.0, maxHealth)
	healthChanged.emit(health, maxHealth)

func setProtection(factor: float) -> void:
	protection = factor
	protectionChanged.emit(protection)
