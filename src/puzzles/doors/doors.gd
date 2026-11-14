class_name Doors
extends Node2D

signal next_room_requested(direction: Vector2)

@export var walls_tilemap: TileMapLayer

@export var door_up: Area2D
@export var door_down: Area2D
@export var door_left: Area2D
@export var door_right: Area2D
@export var crystal_door_area: CrystalDoorArea

func _ready() -> void:
	add_to_group("Doors")

	if door_up:           door_up.body_entered.connect(_on_body_entered.bind(Vector2.UP))
	if door_down:         door_down.body_entered.connect(_on_body_entered.bind(Vector2.DOWN))
	if door_left:         door_left.body_entered.connect(_on_body_entered.bind(Vector2.LEFT))
	if door_right:        door_right.body_entered.connect(_on_body_entered.bind(Vector2.RIGHT))
	if crystal_door_area: crystal_door_area.body_entered.connect(_on_body_entered.bind(crystal_door_area.get_direction()))

	update_all_doors()

func update_all_doors() -> void:
	_update_door(door_up,    Vector2i(14, 0),  Vector2i(17, 0))
	_update_door(door_down,  Vector2i(14, 17), Vector2i(17, 17))
	_update_door(door_left,  Vector2i(0, 7),   Vector2i(0, 10))
	_update_door(door_right, Vector2i(31, 7),  Vector2i(31, 10))

func _update_door(door: Area2D, left_wall_coords: Vector2i, right_wall_coords: Vector2i) -> void:
	if not door or door.type == Door.Type.SPIKED: return

	var is_open: bool = _is_wall_active(left_wall_coords) and _is_wall_active(right_wall_coords)

	var sprite: Sprite2D = door.get_node("Sprite")
	var physic: CollisionShape2D = door.get_node("PhysicArea/Collision")

	sprite.visible = not is_open
	physic.set_deferred("disabled", is_open)

func _is_wall_active(cell: Vector2i) -> bool:
	var wall: TileData = walls_tilemap.get_cell_tile_data(cell)

	if wall: return bool(wall.get_custom_data("is_active"))
	return false

func _on_body_entered(body: Node2D, direction: Vector2) -> void:
	if body is not Player: return

	if body.is_in_group("Players"):
		body.telekinesis.release_object()
		next_room_requested.emit(direction)
