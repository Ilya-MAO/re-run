class_name AttackArea
extends Area2D


@export var entity: Character
@export var attack_rate: float = 0.8
@export var damage: int = 5

var target: Character


#region Specials

var _can_attack: bool = true

func _ready() -> void:
	if entity: damage = entity.damage

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

#endregion

#region Helpers

func _on_body_entered(body: Node2D) -> void:
	if body is not Character or body == entity: return
	target = body
	_apply_attack()


func _on_body_exited(body: Node2D) -> void:
	if body != target: return
	target = null


func _apply_attack() -> void:
	while is_instance_valid(target) and _can_attack:
		_can_attack = false
		if target.has_method("take_damage"): target.take_damage(damage)

		await get_tree().create_timer(attack_rate).timeout
		_can_attack = true

#endregion
