class_name LaserEmitter
extends StaticBody2D


const UNSHADED_MAT: Material = preload("res://assets/resources/unshaded.tres")

const DOORS_GROUP: StringName = &"Doors"
const LASERS_GROUP: StringName = &"Lasers"

const MODE_BLOCK: StringName = &"block"
const MODE_REFLECT: StringName = &"reflect"
const MODE_SLASH: StringName = &"reflect_slash"
const MODE_BACKSLASH: StringName = &"reflect_backslash"
const MODE_SPLIT: StringName = &"split"
const MODE_PASS: StringName = &"pass"

const EMIT_OFFSET: float = 16.0
const BOUNCE_OFFSET: float = 17.0
const MAX_BEAM_SEGMENTS: int = 64

@export var max_bounces: int = 16
@export var max_distance: float = 1000.0
@export var beam_color: Color = Color(0.72, 1.81, 2.117, 0.949)
@export var beam_width: float = 10.0
@export var require_connector_power: bool = true
@export var beam_z_index: int = 300
@export_flags_2d_physics var beam_collision_mask: int = 23

@onready var raycast: RayCast2D = %RayCast
@onready var beams: Node2D = %Beams


func update_all_doors() -> void:
	if not require_connector_power:
		_is_active = true
		return
	_is_active = _check_connector_powered()

#region Specials

var _is_active: bool = false
var _line_pool: Array[Line2D] = []
var _active_lines: int = 0
var _connectors_list: Array[ConnectorsTilemap] = []

func _ready() -> void:
	add_to_group(DOORS_GROUP)
	add_to_group(LASERS_GROUP)
	raycast.enabled = false
	raycast.hit_from_inside = true
	raycast.collision_mask = beam_collision_mask

	_bind_connectors()
	update_all_doors()
	call_deferred(&"_late_init")


func _physics_process(_delta: float) -> void:
	_clear_beams()
	if not _is_active: return

	raycast.clear_exceptions()
	_trace_beam(global_position, _get_emit_dir(), 0, EMIT_OFFSET)

#endregion

#region Helpers

func _late_init() -> void:
	_bind_connectors()
	update_all_doors()


func _bind_connectors() -> void:
	if _connectors_list.is_empty():
		_connectors_list = _find_platform_connectors()

	for conn: ConnectorsTilemap in _connectors_list:
		if is_instance_valid(conn) and not conn.network_changed.is_connected(update_all_doors):
			conn.network_changed.connect(update_all_doors)


func _find_platform_connectors() -> Array[ConnectorsTilemap]:
	var result: Array[ConnectorsTilemap] = []
	var node: Node = get_parent()
	while node:
		for child: Node in node.find_children("*", "TileMapLayer", true, false):
			if child is ConnectorsTilemap:
				result.append(child)
		if not result.is_empty():
			return result
		node = node.get_parent()
	return result


func _get_emit_dir() -> Vector2:
	return global_transform.y.normalized().round()


func _trace_beam(start_pos: Vector2, dir: Vector2, depth: int, ray_offset: float = 0.0) -> void:
	if depth > max_bounces or _active_lines >= MAX_BEAM_SEGMENTS: return

	var ray_start: Vector2 = start_pos + dir * ray_offset
	var remaining_dist: float = max_distance

	while remaining_dist > 0.0:
		raycast.global_position = ray_start
		raycast.target_position = raycast.to_local(ray_start + dir * remaining_dist)
		raycast.force_raycast_update()

		if not raycast.is_colliding():
			_draw_segment(start_pos, ray_start + dir * remaining_dist)
			return

		var collider: Object = raycast.get_collider()
		if collider is Mirror and collider.is_lifted:
			raycast.add_exception(collider)
			continue

		var end_pos: Vector2 = raycast.get_collision_point()
		var hit_normal: Vector2 = raycast.get_collision_normal()
		var hit_info: Dictionary = _get_collider_hit_info(collider, end_pos, dir)
		var mode: StringName = hit_info["mode"]
		var center_pos: Vector2 = hit_info["center"]

		_notify_collider(collider, end_pos, hit_normal)

		var is_redirect: bool = mode in [MODE_SLASH, MODE_BACKSLASH, MODE_SPLIT]
		var is_pass: bool = (mode == MODE_PASS)

		if is_pass:
			raycast.add_exception(collider)
			remaining_dist -= ray_start.distance_to(end_pos)
			ray_start = end_pos
			continue

		_draw_segment(start_pos, center_pos if is_redirect else end_pos)

		match mode:
			MODE_SLASH:
				_trace_beam(center_pos, Vector2(-dir.y, -dir.x), depth + 1, BOUNCE_OFFSET)
			MODE_BACKSLASH:
				_trace_beam(center_pos, Vector2(dir.y, dir.x), depth + 1, BOUNCE_OFFSET)
			MODE_SPLIT:
				_trace_beam(center_pos, dir, depth + 1, BOUNCE_OFFSET)
				_trace_beam(center_pos, Vector2(dir.y, -dir.x), depth + 1, BOUNCE_OFFSET)
				_trace_beam(center_pos, Vector2(-dir.y, dir.x), depth + 1, BOUNCE_OFFSET)
		return


func _notify_collider(collider: Object, hit_pos: Vector2, hit_normal: Vector2) -> void:
	if not collider: return

	if collider.has_method(&"hit_by_laser"):
		collider.hit_by_laser()
	if collider is TileMapLayer and collider.get_parent() is Tilemaps:
		collider.get_parent().handle_laser_hit(collider, hit_pos, hit_normal)


func _get_collider_hit_info(collider: Object, hit_pos: Vector2, dir: Vector2) -> Dictionary:
	if collider is TileMapLayer:
		return _get_tilemap_hit_info(collider as TileMapLayer, hit_pos, dir)

	if collider and collider.has_method(&"get_laser_mode"):
		return {"mode": StringName(collider.get_laser_mode()), "center": collider.global_position}

	return {"mode": MODE_BLOCK, "center": hit_pos}


func _get_tilemap_hit_info(tm: TileMapLayer, hit_pos: Vector2, dir: Vector2) -> Dictionary:
	var sample_pos: Vector2 = hit_pos + dir * 2.0
	var cell: Vector2i = tm.local_to_map(tm.to_local(sample_pos))
	var center: Vector2 = tm.to_global(tm.map_to_local(cell))
	var data: TileData = tm.get_cell_tile_data(cell)

	if not data:
		return {"mode": MODE_BLOCK, "center": hit_pos}

	var raw_mode := StringName(str(data.get_custom_data(&"laser_mode")))
	if raw_mode == MODE_REFLECT:
		var flips: int = int(tm.is_cell_flipped_h(cell)) + int(tm.is_cell_flipped_v(cell)) + int(tm.is_cell_transposed(cell))
		var resolved_mode: StringName = MODE_BACKSLASH if (flips % 2 == 1) else MODE_SLASH
		return {"mode": resolved_mode, "center": center}

	if raw_mode != &"":
		return {"mode": raw_mode, "center": center}

	return {"mode": MODE_BLOCK, "center": hit_pos}


func _check_connector_powered() -> bool:
	_bind_connectors()
	var total_sockets: int = 0
	var powered_sockets: int = 0

	for conn: ConnectorsTilemap in _connectors_list:
		if is_instance_valid(conn):
			var stats: Vector2i = conn.get_endpoint_power_stats_at(global_position, true)
			powered_sockets += stats.x
			total_sockets += stats.y

	return total_sockets > 0 and powered_sockets == total_sockets


func _clear_beams() -> void:
	for line in _line_pool:
		line.visible = false
	_active_lines = 0


func _draw_segment(from_global: Vector2, to_global: Vector2) -> void:
	var line: Line2D
	if _active_lines < _line_pool.size():
		line = _line_pool[_active_lines]
	else:
		line = _create_beam_line()
		_line_pool.append(line)

	_active_lines += 1
	line.visible = true
	line.clear_points()
	line.add_point(to_local(from_global))
	line.add_point(to_local(to_global))


func _create_beam_line() -> Line2D:
	var line := Line2D.new()
	line.default_color = beam_color
	line.width = beam_width
	line.z_index = beam_z_index
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.material = UNSHADED_MAT
	beams.add_child(line)
	return line

#endregion
