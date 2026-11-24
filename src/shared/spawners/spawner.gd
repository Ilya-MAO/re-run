class_name Spawner
extends Marker2D

@export var soul_scenes: Array[PackedScene] = []


func has_scenes() -> bool:
	return not soul_scenes.is_empty()


func spawn_soul() -> Soul:
	if soul_scenes.is_empty():
		return null

	var scene: PackedScene = soul_scenes.pick_random()
	if not scene:
		return null

	var soul := scene.instantiate() as Soul
	if not soul:
		return null

	soul.global_position = global_position
	return soul
