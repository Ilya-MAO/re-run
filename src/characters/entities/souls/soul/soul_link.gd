class_name SoulLink
extends Resource

@export var link_name: String = ""
@export var roles: Array[SoulRole] = []


func is_valid() -> bool:
	return roles.size() >= 2 and roles.size() <= 4
