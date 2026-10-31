class_name LogicCollision
extends Area2D

@export var ownerCharacter: DefaultCharacter
@export var attackRate: float = 0.8

var target: DefaultCharacter = null
var canDealDamage: bool = true

func _ready() -> void:
	body_entered.connect(onBodyEntered)
	body_exited.connect(onBodyExited)

func onBodyEntered(body: Node2D) -> void:
	if body is DefaultCharacter:
		target = body
		applyPeriodicDamage()

func onBodyExited(body: Node2D) -> void:
	if body == target:
		target = null

func applyPeriodicDamage() -> void:
	while target != null and canDealDamage:
		canDealDamage = false
		target.takeDamage(ownerCharacter.damage)
		
		await get_tree().create_timer(attackRate).timeout
		canDealDamage = true
