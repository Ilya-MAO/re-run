class_name BeamNode
extends Node2D

@export var distance: float = 150.0
@export var cooldown: float = 0.3
@export var beamDuration: float = 0.1

@export var ownerCharacter: DefaultCharacter
@export var rayCast: RayCast2D
@export var line: Line2D
@export var logicCollision: LogicCollision
@export var collisionShape: CollisionShape2D

var canFire: bool = true

func _ready() -> void:
	visible = false
	logicCollision.monitoring = false

func setDirection(direction: Vector2) -> void:
	if not canFire: return
	
	rotation = direction.angle()
	
	rayCast.target_position = Vector2(distance, 0)
	rayCast.force_raycast_update()
	
	var actualDistance = distance
	if rayCast.is_colliding():
		var hit = rayCast.get_collision_point()
		actualDistance = global_position.distance_to(hit)
		actualDistance = min(actualDistance + 10.0, distance)

	line.set_point_position(1, Vector2(actualDistance, 0))
	
	var rect = collisionShape.shape as RectangleShape2D
	if rect:
		rect.size = Vector2(actualDistance, rect.size.y)
		collisionShape.position = Vector2(actualDistance / 2.0, 0)
	
	activateBeam()

func activateBeam() -> void:
	canFire = false
	visible = true
	
	logicCollision.monitoring = true
	
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	var areas = logicCollision.get_overlapping_areas()
	for area in areas:
		var parent = area.get_parent()
		if parent and parent != ownerCharacter and parent.has_method("takeDamage"):
			parent.takeDamage(ownerCharacter.damage)

	logicCollision.monitoring = false
	
	await get_tree().create_timer(beamDuration).timeout
	visible = false
	
	await get_tree().create_timer(cooldown).timeout
	canFire = true
