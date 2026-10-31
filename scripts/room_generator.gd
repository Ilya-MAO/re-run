class_name RoomGenerator
extends Node2D

var WorldHud: PackedScene = preload("res://scenes/ui/world_hud.tscn")
var StartRoom: PackedScene = preload("res://scenes/layers/layer_1/rooms/start_room.tscn")
var MainPlayer: PackedScene = preload("res://scenes/characters/players/main/main.tscn")

@export var TemplateRooms: Array[PackedScene] = []

const ROOM_WIDTH: float = 1024.0
const ROOM_HEIGHT: float = 576.0

var rooms: Dictionary = {}
var coords: Vector2i = Vector2i.ZERO
var player: Node2D = null

func _ready() -> void:
	var startRoom = StartRoom.instantiate()
	startRoom.global_position = Vector2.ZERO
	startRoom.nextRoomRequested.connect(func(direction): nextRoom(Vector2.ZERO, direction))
	
	rooms[Vector2i.ZERO] = startRoom
	add_child(startRoom)
	
	player = MainPlayer.instantiate()
	player.z_index = 5
	player.global_position = Vector2(ROOM_WIDTH / 2, ROOM_HEIGHT / 2)
	
	add_child(player)

	add_child(WorldHud.instantiate())
	updateCameraLimits(Vector2i.ZERO)

func spawnRoomAt(coords: Vector2i) -> void:
	if rooms.has(coords): return
	
	var newRoom = TemplateRooms.pick_random().instantiate()
	newRoom.global_position = Vector2(coords.x * ROOM_WIDTH, coords.y * ROOM_HEIGHT)
	newRoom.nextRoomRequested.connect(func(direction): nextRoom(coords, direction))
	
	rooms[coords] = newRoom
	add_child(newRoom)

func nextRoom(currentCoords: Vector2i, direction: Vector2) -> void:
	var newCoords = currentCoords + Vector2i(direction)
	var newPosition = Vector2(currentCoords.x * ROOM_WIDTH, currentCoords.y * ROOM_HEIGHT)
	
	if not rooms.has(newCoords): spawnRoomAt(newCoords)

	if   direction == Vector2.UP:    player.global_position += Vector2(0, -80.0)
	elif direction == Vector2.DOWN:  player.global_position += Vector2(0, 80.0)
	elif direction == Vector2.LEFT:  player.global_position += Vector2(-80.0, 0)
	elif direction == Vector2.RIGHT: player.global_position += Vector2(80.0, 0)

	currentCoords = newCoords
	updateCameraLimits(newCoords)

func updateCameraLimits(coords: Vector2i) -> void:
	if not player or not player.has_node("Camera"): return
		
	var camera: Camera2D = player.get_node("Camera")
	
	camera.limit_left   = int(coords.x * ROOM_WIDTH)
	camera.limit_top    = int(coords.y * ROOM_HEIGHT)
	camera.limit_right  = int((coords.x + 1) * ROOM_WIDTH)
	camera.limit_bottom = int((coords.y + 1) * ROOM_HEIGHT)
