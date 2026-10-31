class_name Room
extends Node2D

signal nextRoomRequested(direction: Vector2)

@onready var doorBlock: DoorBlock = $DoorBlock
@onready var spawnBlock: SpawnBlock = $SpawnBlock

func _ready() -> void:
	if doorBlock:
		doorBlock.nextRoomRequested.connect(func(direction): nextRoomRequested.emit(direction))
	
	if spawnBlock:
		await get_tree().process_frame
		spawnBlock.spawnEnemies()
