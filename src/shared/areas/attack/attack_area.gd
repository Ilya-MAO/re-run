class_name AttackArea
extends Area2D

@export var source: Character
var target: Character

@export var attack_rate: float = 0.8
@export var damage: float = 5

var can_attack: bool = true

func _ready() -> void:
	if source: damage = source.damage
	
	body_entered.connect(on_body_entered)
	body_exited.connect(on_body_exited)

func on_body_entered(body: Node2D) -> void:
	if body is not Character: return

	target = body
	apply_attack()

func on_body_exited(body: Node2D) -> void:
	if body != target: return

	target = null

func apply_attack() -> void:
	while target != null and can_attack:
		can_attack = false
		if target.has_method("take_damage"): target.take_damage(damage)
		
		await get_tree().create_timer(attack_rate).timeout
		can_attack = true
