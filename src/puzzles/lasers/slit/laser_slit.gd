class_name LaserSlit
extends StaticBody2D

const DOORS_GROUP: StringName = &"Doors"

var is_active: bool = false
var _was_hit_this_frame: bool = false


func get_laser_mode() -> StringName:
	return &"pass"


func hit_by_laser() -> void:
	_was_hit_this_frame = true

func _ready() -> void:
	add_to_group("LaserSlits")


func _physics_process(_delta: float) -> void:
	if _was_hit_this_frame != is_active:
		is_active = _was_hit_this_frame
		get_tree().call_group(DOORS_GROUP, &"update_all_doors")
	
	_was_hit_this_frame = false
