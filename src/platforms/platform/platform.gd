class_name Platform
extends Node

signal next_platform_requested(direction: Vector2)

enum Type {
	START,
	LIGHT_ACTIVE,
	LIGHT_PASSIVE,
	DARK_UP,
	DARK_DOWN,
	DARK_SIDE
}

@export var type: Type = Type.LIGHT_ACTIVE
@export var spawners: Spawners

@onready var bridges: BridgesTilemap = %Bridges

var grid_coords: Vector2i = Vector2i.ZERO
var is_mirrored_x: bool = false
var available_directions: Array[Vector2i] = []


func setup(p_coords: Vector2i, p_mirror_x: bool = false, p_directions: Array[Vector2i] = []) -> void:
	grid_coords = p_coords
	is_mirrored_x = p_mirror_x
	available_directions = p_directions


#region Specials

func _ready() -> void:
	if is_mirrored_x:
		_apply_horizontal_mirror()

	if bridges:
		bridges.set_available_directions(available_directions, is_mirrored_x)
		bridges.next_platform_requested.connect(next_platform_requested.emit)

	if spawners:
		spawners.spawn()

#endregion

#region Helpers

func _apply_horizontal_mirror() -> void:
	var center_x: float = PlatformGenerator.PLATFORM_SIZE.x / 2.0
	for child in get_children():
		if child is Node2D:
			child.position.x = center_x * 2.0 - child.position.x
			child.scale.x *= -1.0

#endregion
