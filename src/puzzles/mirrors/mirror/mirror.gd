class_name Mirror
extends AnimatableBody2D


enum MirrorType { SLASH, BACKSLASH, SPLIT, BLOCK }

const UNSHADED_MAT: Material = preload("res://assets/resources/unshaded.tres")

@export var active_color: Color = Color(0.85, 1.35, 1.85, 1.0)
@export var mirror_type: MirrorType = MirrorType.SLASH: set = _set_mirror_type
@export var grid_size: int = 32
@export var move_duration: float = 0.12
@export var lift_height: float = 9.0

@export_group("Visuals")
@export var grounded_z_index: int = 0
@export var lifted_z_index: int = 310

@export_group("Physics")
@export_range(1, 32) var block_layer: int = 2
@export_range(1, 32) var lifted_layer: int = 6
@export_flags_2d_physics var obstacle_mask: int = 3

@onready var visual: AnimatedSprite2D = %AnimatedSprite
@onready var shadow: Node2D = %Shadow

var is_lifted: bool = false
var is_moving: bool = false


func hit_by_laser() -> void:
	if is_lifted: return

	_lit_timer = 0.05
	if _is_lit: return

	_is_lit = true
	_emit_logic_signal(true)
	_refresh_visuals()


func get_laser_mode() -> StringName:
	if is_lifted: return &""
	match mirror_type:
		MirrorType.SLASH:     return &"reflect_slash"
		MirrorType.BACKSLASH: return &"reflect_backslash"
		MirrorType.SPLIT:     return &"split"
		_:                    return &"block"


func lift() -> void:
	if is_lifted: return

	is_lifted = true
	_float_time = 0.0
	z_index = lifted_z_index
	_set_lifted_collision(true)

	if _is_lit:
		_is_lit = false
		_emit_logic_signal(false)

	if shadow: shadow.visible = true
	_refresh_visuals()

	if _lift_tween: _lift_tween.kill()
	_lift_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_lift_tween.tween_property(self, ^"_lift_offset", lift_height, 0.18)


func drop() -> void:
	if not is_lifted: return

	is_lifted = false
	z_index = grounded_z_index
	_set_lifted_collision(false)
	visual.rotation = 0.0
	if shadow: shadow.visible = false
	_refresh_visuals()

	if _lift_tween: _lift_tween.kill()
	_lift_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	_lift_tween.tween_property(self, ^"_lift_offset", 0.0, 0.2)


func try_move_grid(dir: Vector2i, player_pos: Vector2, max_range: float) -> bool:
	if not is_lifted or is_moving or dir == Vector2i.ZERO: return false

	var target_pos: Vector2 = global_position + Vector2(dir) * grid_size
	if target_pos.distance_to(player_pos) > max_range: return false
	if not _is_cell_free(target_pos): return false

	is_moving = true
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, ^"global_position", target_pos, move_duration)
	tween.finished.connect(func() -> void: is_moving = false)
	return true

#region Specials

var _base_visual_pos: Vector2
var _base_shadow_scale: Vector2
var _lift_offset: float = 0.0
var _float_time: float = 0.0
var _lift_tween: Tween
var _is_lit: bool = false
var _lit_timer: float = 0.0
var _connectors: ConnectorsTilemap

func _ready() -> void:
	add_to_group(&"Telekinetic")
	_base_visual_pos = visual.position
	if shadow:
		_base_shadow_scale = shadow.scale
		shadow.visible = false

	z_index = grounded_z_index
	_snap_to_floor_grid()
	_set_lifted_collision(false)
	visual.flip_h = (mirror_type == MirrorType.BACKSLASH)
	_refresh_visuals()
	call_deferred(&"_bind_connectors")


func _process(delta: float) -> void:
	if _is_lit:
		_lit_timer -= delta
		if _lit_timer <= 0.0:
			_is_lit = false
			_emit_logic_signal(false)
			_refresh_visuals()

	if not is_lifted and _lift_offset <= 0.01: return

	_float_time += delta * 5.0
	var bob: float = sin(_float_time) * 1.8 if is_lifted else 0.0
	visual.position.y = _base_visual_pos.y - _lift_offset + bob
	visual.rotation = sin(_float_time * 0.7) * 0.04 if is_lifted else 0.0
	if shadow: shadow.scale = _base_shadow_scale * (1.0 - bob * 0.03)

#endregion

#region Helpers

func _snap_to_floor_grid() -> void:
	var parent_node := get_parent()
	var floor_tm: TileMapLayer = null

	if parent_node:
		floor_tm = parent_node.find_child("Floor", true, false) as TileMapLayer

	if floor_tm:
		var cell: Vector2i = floor_tm.local_to_map(floor_tm.to_local(global_position))
		global_position = floor_tm.to_global(floor_tm.map_to_local(cell))
	else:
		global_position = global_position.round()


func _bind_connectors() -> void:
	if _connectors: return

	var node: Node = get_parent()
	while node:
		if node is ConnectorsTilemap:
			_connectors = node
			return
		for child in node.find_children("*", "TileMapLayer", true, false):
			if child is ConnectorsTilemap:
				_connectors = child
				return
		node = node.get_parent()


func _set_lifted_collision(lifted: bool) -> void:
	set_collision_layer_value(block_layer, not lifted)
	set_collision_layer_value(lifted_layer, lifted)


func _emit_logic_signal(is_on: bool) -> void:
	if not _connectors:
		_bind_connectors()
	if _connectors:
		_connectors.set_direct_signal(self, global_position, is_on)


func _refresh_visuals() -> void:
	var target_anim: StringName = &"active" if _is_lit else &"passive"
	if visual.animation != target_anim:
		var frame: int = visual.frame
		visual.play(target_anim)
		visual.frame = frame

	var is_bright: bool = _is_lit or is_lifted
	visual.material = UNSHADED_MAT if is_bright else null
	visual.modulate = active_color if is_bright else Color.WHITE


func _is_cell_free(target_pos: Vector2) -> bool:
	var shape := RectangleShape2D.new()
	shape.size = Vector2.ONE * (grid_size - 6.0)

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, target_pos)
	query.collision_mask = obstacle_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = [get_rid()]

	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

#endregion

#region Setters

func _set_mirror_type(value: MirrorType) -> void:
	mirror_type = value
	if is_node_ready(): visual.flip_h = (mirror_type == MirrorType.BACKSLASH)

#endregion
