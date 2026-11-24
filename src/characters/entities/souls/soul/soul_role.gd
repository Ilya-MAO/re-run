class_name SoulRole
extends Resource

@export var role_id: StringName = &""
@export var role_name: String = ""

@export_group("Link Relationships")
@export_range(0, 2) var friends_count: int = 1
@export_range(0, 2) var enemies_count: int = 1
