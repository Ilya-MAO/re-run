class_name RoomGenerator
extends Node2D

@export var Hud: PackedScene
@export var Player: PackedScene
@export var StartRoom: PackedScene
@export var Rooms: Array[PackedScene]

var player: Node2D = null
var rooms: Dictionary = {}

const ROOM_WIDTH: float = 1024.0
const ROOM_HEIGHT: float = 576.0

var coords: Vector2i = Vector2i.ZERO
var minimap: Minimap = null

func _ready() -> void:
	var start_room = StartRoom.instantiate()
	start_room.global_position = Vector2.ZERO
	start_room.next_room_requested.connect(next_room.bind(Vector2i.ZERO))
	
	rooms[Vector2i.ZERO] = start_room
	add_child(start_room)
	
	player = Player.instantiate()
	player.global_position = Vector2(ROOM_WIDTH / 2.0, ROOM_HEIGHT / 2.0)
	add_child(player)

	var hud = Hud.instantiate()
	add_child(hud)

	minimap = hud.find_child("Minimap", true, false)

	update_camera_limits(Vector2i.ZERO)

	if minimap:
		minimap.setup_map(Vector2i.ZERO, rooms)
		minimap.set_current_room(coords)

func spawn_room_at(p_coords: Vector2i) -> void:
	if Rooms.is_empty() or rooms.has(p_coords): return
	
	var new_room = Rooms.pick_random().instantiate()
	new_room.global_position = Vector2(p_coords.x * ROOM_WIDTH, p_coords.y * ROOM_HEIGHT)
	new_room.next_room_requested.connect(next_room.bind(p_coords))
	
	rooms[p_coords] = new_room
	add_child(new_room)

	if minimap: minimap.setup_map(Vector2i.ZERO, rooms)

func next_room(current_coords: Vector2i, direction: Vector2) -> void:
	var new_coords = current_coords + Vector2i(direction)
	
	if not rooms.has(new_coords): 
		spawn_room_at(new_coords)

	player.global_position += direction * 80.0

	coords = new_coords
	update_camera_limits(coords)

func update_camera_limits(p_coords: Vector2i) -> void:
	if not player or not player.has_node("Camera"):
		return
		
	var camera: Camera2D = player.get_node("Camera")
	
	camera.limit_left   = int(p_coords.x * ROOM_WIDTH)
	camera.limit_top    = int(p_coords.y * ROOM_HEIGHT)
	camera.limit_right  = int((p_coords.x + 1) * ROOM_WIDTH)
	camera.limit_bottom = int((p_coords.y + 1) * ROOM_HEIGHT)

	if minimap: 
		minimap.set_current_room(p_coords)
