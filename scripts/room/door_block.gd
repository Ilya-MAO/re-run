class_name DoorBlock
extends Node2D

signal nextRoomRequested(direction: Vector2)

@onready var doorUp: Area2D    = $DoorUp
@onready var doorDown: Area2D  = $DoorDown
@onready var doorLeft: Area2D  = $DoorLeft
@onready var doorRight: Area2D = $DoorRight

func _ready() -> void:
	doorUp.body_entered.connect(func(body): onBodyEntered(body, Vector2.UP))
	doorDown.body_entered.connect(func(body): onBodyEntered(body, Vector2.DOWN))
	doorLeft.body_entered.connect(func(body): onBodyEntered(body, Vector2.LEFT))
	doorRight.body_entered.connect(func(body): onBodyEntered(body, Vector2.RIGHT))

func onBodyEntered(body: Node2D, direction: Vector2):
	if body.is_in_group("Players"):
		nextRoomRequested.emit(direction)
