class_name PirateEnemy
extends DefaultCharacter

var player: Node2D = null
var timePassed: float = 0.0

func _ready() -> void:
	maxHealth = 10
	health = maxHealth
	speed = 100.0

	player = get_tree().get_first_node_in_group("Players")

func _physics_process(delta: float) -> void:
	timePassed += delta
	
	if player:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed
		
		animationTree.set("parameters/blend_position", direction)
		move_and_slide()
	
	sprite.position.y = sin(timePassed * floatSpeed) * floatAmplitude
