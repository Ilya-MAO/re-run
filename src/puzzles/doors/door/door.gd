class_name Door
extends Area2D

enum Type {
	NORMAL,
	SPIKED
}

@export var type: Type = Type.NORMAL
