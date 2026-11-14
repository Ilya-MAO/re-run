class_name Mirror
extends AnimatableBody2D

const UNSHADED_MAT := preload("res://assets/resources/unshaded.tres")

enum MirrorType { SLASH, BACKSLASH, SPLIT, BLOCK }

@export var active_color: Color = Color(0.85, 1.35, 1.85, 1.0)
@export var mirror_type: MirrorType = MirrorType.SLASH:
	set(value):
		mirror_type = value
		_apply_visual_orientation()
@export var grid_size: int = 32
@export var move_duration: float = 0.12
@export var lift_height: float = 9.0

@onready var visual: AnimatedSprite2D = $AnimatedSprite
@onready var shadow: Node2D = $Shadow

var is_lifted: bool = false
var is_moving: bool = false

var _base_visual_pos: Vector2 = Vector2.ZERO
var _base_shadow_scale: Vector2 = Vector2.ONE
var _current_lift_offset: float = 0.0
var _float_time: float = 0.0
var _lift_tween: Tween

var _is_lit: bool = false
var _lit_timer: float = 0.0


func _ready() -> void:
	add_to_group("Telekinetic")
	_base_visual_pos = visual.position
	global_position = _snap_to_grid(global_position)

	if shadow:
		_base_shadow_scale = shadow.scale
		shadow.visible = false

	_apply_visual_orientation()
	visual.play("passive")
	_update_visual_lighting()


func _process(delta: float) -> void:
	if _is_lit:
		_lit_timer -= delta
		if _lit_timer <= 0.0:
			_is_lit = false
			_update_animation()
			_update_visual_lighting()

	if is_lifted or _current_lift_offset > 0.01:
		_float_time += delta * 5.0
		var bob := sin(_float_time) * 1.8 if is_lifted else 0.0
		visual.position.y = _base_visual_pos.y - _current_lift_offset + bob
		visual.rotation = sin(_float_time * 0.7) * 0.04 if is_lifted else 0.0

		if shadow and shadow.visible:
			var scale_factor := 1.0 - (bob * 0.03)
			shadow.scale = _base_shadow_scale * scale_factor


func hit_by_laser() -> void:
	_lit_timer = 0.05
	if not _is_lit:
		_is_lit = true
		_update_animation()
		_update_visual_lighting()


func get_laser_mode() -> String:
	if is_lifted:
		return ""
	match mirror_type:
		MirrorType.SLASH: return "reflect_slash"
		MirrorType.BACKSLASH: return "reflect_backslash"
		MirrorType.SPLIT: return "split"
		_: return "block"


func lift() -> void:
	if is_lifted:
		return
	is_lifted = true
	_float_time = 0.0
	set_collision_layer_value(5, false)
	_update_visual_lighting()

	if shadow:
		shadow.visible = true
		shadow.modulate.a = 0.0
		create_tween().tween_property(shadow, "modulate:a", 0.65, 0.15)

	if _lift_tween:
		_lift_tween.kill()
	_lift_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_lift_tween.tween_property(self, "_current_lift_offset", lift_height, 0.18)
	visual.modulate = Color(1.15, 1.25, 1.4, 1.0)


func drop() -> void:
	if not is_lifted:
		return
	is_lifted = false
	set_collision_layer_value(5, true)
	visual.rotation = 0.0
	visual.modulate = Color.WHITE
	_update_visual_lighting()

	if shadow:
		var s_tween := create_tween()
		s_tween.tween_property(shadow, "modulate:a", 0.0, 0.12)
		s_tween.finished.connect(func(): shadow.visible = false)

	if _lift_tween:
		_lift_tween.kill()
	_lift_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	_lift_tween.tween_property(self, "_current_lift_offset", 0.0, 0.2)


func try_move_grid(dir: Vector2i, player_pos: Vector2, max_range: float) -> bool:
	if not is_lifted or is_moving or dir == Vector2i.ZERO:
		return false

	var target_pos := global_position + Vector2(dir) * grid_size
	if target_pos.distance_to(player_pos) > max_range:
		return false
	if not _is_cell_free(target_pos):
		return false

	is_moving = true
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "global_position", target_pos, move_duration)
	tween.finished.connect(func(): is_moving = false)
	return true


func _apply_visual_orientation() -> void:
	if not is_node_ready():
		return
	visual.flip_h = (mirror_type == MirrorType.BACKSLASH)


func _update_animation() -> void:
	var target_anim := "active" if _is_lit else "passive"
	if visual.animation != target_anim:
		var current_frame := visual.frame
		visual.play(target_anim)
		visual.frame = current_frame


func _update_visual_lighting() -> void:
	if visual:
		var is_bright := _is_lit or is_lifted
		visual.material = UNSHADED_MAT if is_bright else null
		visual.modulate = active_color if is_bright else Color.WHITE


func _is_cell_free(target_pos: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = target_pos
	query.collision_mask = 1 | (1 << 4)
	query.exclude = [get_rid()]
	return space.intersect_point(query, 1).is_empty()


func _snap_to_grid(pos: Vector2) -> Vector2:
	var half := grid_size * 0.5
	return Vector2(
		floor(pos.x / grid_size) * grid_size + half,
		floor(pos.y / grid_size) * grid_size + half
	)
