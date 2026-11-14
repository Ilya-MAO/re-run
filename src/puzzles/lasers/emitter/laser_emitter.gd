class_name LaserEmitter
extends Node2D

const UNSHADED_MAT := preload("res://assets/resources/unshaded.tres")

@export var max_bounces: int = 16
@export var max_distance: float = 1000.0
@export var beam_color: Color = Color(0.72, 1.81, 2.117, 0.949)
@export var beam_width: float = 10.0
@export var require_adjacent_power: bool = true

@onready var raycast: RayCast2D = $RayCast
@onready var beams: Node2D = $Beams

var _is_activate: bool = false
var _line_pool: Array[Line2D] = []
var _active_lines: int = 0


func _ready() -> void:
	add_to_group("Doors")
	add_to_group("Lasers")
	raycast.enabled = false
	update_all_doors()


func update_all_doors() -> void:
	if not require_adjacent_power:
		_is_activate = true
		return
	_is_activate = _check_adjacent_walls_powered()


func _get_emit_dir() -> Vector2:
	return global_transform.y.normalized().round()


func _physics_process(_delta: float) -> void:
	_clear_beams()
	if not _is_activate:
		return

	var dir := _get_emit_dir()
	_trace_beam(global_position, dir, 0, 14.0)


func _trace_beam(start_pos: Vector2, dir: Vector2, depth: int, ray_offset: float = 0.0) -> void:
	if depth > max_bounces:
		return

	var ray_start := start_pos + dir * ray_offset
	raycast.global_position = ray_start
	raycast.target_position = raycast.to_local(ray_start + dir * max_distance)
	raycast.force_raycast_update()

	if not raycast.is_colliding():
		_draw_segment(start_pos, ray_start + dir * max_distance)
		return

	var end_pos: Vector2 = raycast.get_collision_point()
	var hit_normal: Vector2 = raycast.get_collision_normal()
	var collider := raycast.get_collider()
	var hit_info := _get_collider_hit_info(collider, end_pos, dir)
	var mode: String = hit_info["mode"]
	var center_pos: Vector2 = hit_info["center"]

	if collider:
		if collider.has_method("hit_by_laser"):
			collider.hit_by_laser()
		if collider is TileMapLayer and collider.get_parent() is Tilemaps:
			collider.get_parent().handle_laser_hit(collider, end_pos, hit_normal)

	if mode in ["reflect_slash", "reflect_backslash", "split"]:
		_draw_segment(start_pos, center_pos)
	else:
		_draw_segment(start_pos, end_pos)

	match mode:
		"reflect_slash":
			var new_dir := Vector2(-dir.y, -dir.x)
			_trace_beam(center_pos, new_dir, depth + 1, 9.5)

		"reflect_backslash":
			var new_dir := Vector2(dir.y, dir.x)
			_trace_beam(center_pos, new_dir, depth + 1, 9.5)

		"split":
			var left_dir := Vector2(dir.y, -dir.x)
			var right_dir := Vector2(-dir.y, dir.x)
			_trace_beam(center_pos, dir, depth + 1, 9.5)
			_trace_beam(center_pos, left_dir, depth + 1, 9.5)
			_trace_beam(center_pos, right_dir, depth + 1, 9.5)


func _get_collider_hit_info(collider: Object, hit_pos: Vector2, dir: Vector2) -> Dictionary:
	if collider is TileMapLayer:
		var tm := collider as TileMapLayer
		var sample_pos := hit_pos + dir * 2.0
		var cell := tm.local_to_map(tm.to_local(sample_pos))
		var center := tm.to_global(tm.map_to_local(cell))
		var data := tm.get_cell_tile_data(cell)

		if data:
			var raw_mode := str(data.get_custom_data("laser_mode"))
			if raw_mode == "reflect":
				var flips := 0
				if tm.is_cell_flipped_h(cell): flips += 1
				if tm.is_cell_flipped_v(cell): flips += 1
				if tm.is_cell_transposed(cell): flips += 1

				var resolved_mode := "reflect_backslash" if (flips % 2 == 1) else "reflect_slash"
				return {"mode": resolved_mode, "center": center}
			elif raw_mode != "":
				return {"mode": raw_mode, "center": center}

		return {"mode": "block", "center": hit_pos}

	if collider and collider.has_method("get_laser_mode"):
		return {"mode": collider.get_laser_mode(), "center": collider.global_position}

	return {"mode": "block", "center": hit_pos}


func _check_adjacent_walls_powered() -> bool:
	var dir := _get_emit_dir()
	var perp := Vector2i(int(-dir.y), int(dir.x))
	if perp == Vector2i.ZERO:
		perp = Vector2i(0, 1)

	for child in get_tree().current_scene.find_children("Walls", "TileMapLayer", true, false):
		var tm := child as TileMapLayer
		var my_cell := tm.local_to_map(tm.to_local(global_position))
		var data_a := tm.get_cell_tile_data(my_cell + perp)
		var data_b := tm.get_cell_tile_data(my_cell - perp)
		if data_a != null and data_b != null:
			return _is_cell_active(tm, my_cell + perp) and _is_cell_active(tm, my_cell - perp)

	return false


func _is_cell_active(tm: TileMapLayer, cell: Vector2i) -> bool:
	var data := tm.get_cell_tile_data(cell)
	if not data:
		return false
	return bool(data.get_custom_data("is_active"))


func _clear_beams() -> void:
	for line in _line_pool:
		line.visible = false
	_active_lines = 0


func _draw_segment(from_global: Vector2, to_global: Vector2) -> void:
	var line: Line2D
	if _active_lines < _line_pool.size():
		line = _line_pool[_active_lines]
	else:
		line = Line2D.new()
		line.default_color = beam_color
		line.width = beam_width
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.material = UNSHADED_MAT
		beams.add_child(line)
		_line_pool.append(line)

	_active_lines += 1
	line.visible = true
	line.clear_points()
	line.add_point(to_local(from_global))
	line.add_point(to_local(to_global))
