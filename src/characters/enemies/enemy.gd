class_name Enemy
extends Character

var target: Node2D = null

func _ready() -> void:
	target = get_tree().get_first_node_in_group("Players")

func _physics_process(delta: float) -> void:
	float_time_passed += delta
	
	if target:
		var direction = (target.global_position - global_position).normalized()
		velocity = direction * speed
		
		animation_tree.set("parameters/blend_position", direction)
		move_and_slide()
	
	sprite.position.y = sin(float_time_passed * float_speed) * float_amplitude
