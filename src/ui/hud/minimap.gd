class_name Minimap
extends Control

enum Category { START, LIGHT, DARK }

const COLOR_CURRENT := Color(0.1, 0.85, 0.3, 1.0)
const COLOR_UNVISITED := Color(0.2, 0.2, 0.25, 0.6)
const COLOR_HIDDEN := Color(0.2, 0.2, 0.25, 0.0)

const CATEGORY_COLORS: Dictionary = {
	Category.START: Color(0.68, 0.68, 0.74, 0.95),
	Category.LIGHT: Color(0.4, 0.4, 0.45, 0.8),
	Category.DARK: Color(0.23, 0.23, 0.28, 0.9),
}

@export var cell_size: Vector2 = Vector2(10, 10)
@export var cell_margin: Vector2 = Vector2(2, 2)
@export var expanded_size: Vector2 = Vector2(132, 132)
@export var hide_unvisited_platforms: bool = true: set = _set_hide_unvisited_platforms

@onready var grid: GridContainer = %Grid

var current_pos: Vector2i = Vector2i.ZERO
var visited_platforms: Array[Vector2i] = []
var platform_nodes: Dictionary = {}
var platform_categories: Dictionary = {}

var min_bounds: Vector2i = Vector2i.ZERO
var max_bounds: Vector2i = Vector2i.ZERO
var is_expanded: bool = false


func setup_map(_p_grid_size: Vector2i, p_platforms: Dictionary) -> void:
	if p_platforms.is_empty(): return

	min_bounds = p_platforms.keys()[0]
	max_bounds = p_platforms.keys()[0]

	for pos: Vector2i in p_platforms.keys():
		min_bounds.x = mini(min_bounds.x, pos.x)
		min_bounds.y = mini(min_bounds.y, pos.y)
		max_bounds.x = maxi(max_bounds.x, pos.x)
		max_bounds.y = maxi(max_bounds.y, pos.y)

	var cols: int = (max_bounds.x - min_bounds.x) + 1
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", int(cell_margin.x))
	grid.add_theme_constant_override("v_separation", int(cell_margin.y))

	for child in grid.get_children(): child.queue_free()

	platform_nodes.clear()
	platform_categories.clear()
	visited_platforms.clear()
	_start_pos = Vector2i(-1, -1)

	for cell_pos: Vector2i in p_platforms.keys():
		var category: Category = _resolve_platform_category(p_platforms[cell_pos])
		platform_categories[cell_pos] = category
		if category == Category.START:
			_start_pos = cell_pos

	if p_platforms.has(current_pos):
		visited_platforms.append(current_pos)
		if _start_pos == Vector2i(-1, -1):
			_start_pos = current_pos
			platform_categories[current_pos] = Category.START

	for y in range(min_bounds.y, max_bounds.y + 1):
		for x in range(min_bounds.x, max_bounds.x + 1):
			var cell_pos := Vector2i(x, y)

			if p_platforms.has(cell_pos):
				var platform_icon := ColorRect.new()
				platform_icon.custom_minimum_size = cell_size
				platform_icon.size = cell_size
				platform_icon.color = _get_platform_color(cell_pos)

				grid.add_child(platform_icon)
				platform_nodes[cell_pos] = platform_icon
			else:
				var dummy := Control.new()
				dummy.custom_minimum_size = cell_size
				grid.add_child(dummy)

	_update_outer_cells_alpha(1.0 if is_expanded else 0.0)
	call_deferred("center_on_platform", current_pos)


func set_current_platform(p_grid_pos: Vector2i) -> void:
	if visited_platforms.is_empty() and _start_pos == Vector2i(-1, -1):
		_start_pos = p_grid_pos
		if platform_categories.get(p_grid_pos, Category.LIGHT) == Category.LIGHT:
			platform_categories[p_grid_pos] = Category.START

	if not p_grid_pos in visited_platforms:
		visited_platforms.append(p_grid_pos)

	var prev_pos: Vector2i = current_pos
	current_pos = p_grid_pos

	if platform_nodes.has(prev_pos):
		platform_nodes[prev_pos].color = _get_platform_color(prev_pos)

	if platform_nodes.has(current_pos):
		platform_nodes[current_pos].color = _get_platform_color(current_pos)

	_update_outer_cells_alpha(1.0 if is_expanded else 0.0)
	call_deferred("center_on_platform", current_pos)


func set_platform_category(p_grid_pos: Vector2i, p_category: Category) -> void:
	platform_categories[p_grid_pos] = p_category
	if p_category == Category.START:
		_start_pos = p_grid_pos
	if platform_nodes.has(p_grid_pos):
		platform_nodes[p_grid_pos].color = _get_platform_color(p_grid_pos)


func center_on_platform(p_grid_pos: Vector2i) -> void:
	if not platform_nodes.has(p_grid_pos): return

	var box_size: Vector2 = size if size != Vector2.ZERO else _collapsed_size
	grid.position = _get_target_grid_position(p_grid_pos, box_size, is_expanded)


func toggle_expanded_map() -> void:
	is_expanded = not is_expanded

	var start_box: Vector2 = size
	var target_box: Vector2 = expanded_size if is_expanded else _collapsed_size

	var start_grid: Vector2 = grid.position
	var target_grid: Vector2 = _get_target_grid_position(current_pos, target_box, is_expanded)

	var start_alpha: float = 0.0 if is_expanded else 1.0
	var target_alpha: float = 1.0 if is_expanded else 0.0

	if _resize_tween and _resize_tween.is_valid(): _resize_tween.kill()

	_resize_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_resize_tween.tween_method(
		func(t: float) -> void:
			var cur_box: Vector2 = start_box.lerp(target_box, t).round()
			var cur_grid: Vector2 = start_grid.lerp(target_grid, t).round()
			_apply_box_geometry(cur_box, cur_grid)
			_update_outer_cells_alpha(lerpf(start_alpha, target_alpha, t)),
		0.0, 1.0, 0.18
	)

#region Specials

var _start_pos: Vector2i = Vector2i(-1, -1)
var _collapsed_size: Vector2
var _screen_margin: Vector2 = Vector2(8, 8)
var _resize_tween: Tween


func _ready() -> void:
	clip_contents = true
	_read_scene_margins()
	_collapsed_size = _calculate_collapsed_size()

	_setup_visual_nodes()
	get_viewport().size_changed.connect(_sync_corner_position)
	call_deferred("_apply_box_geometry", _collapsed_size, _get_target_grid_position(current_pos, _collapsed_size, false))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map"): toggle_expanded_map()

#endregion

#region Helpers

func _resolve_platform_category(platform_data: Variant) -> Category:
	var p_type: Platform.Type = Platform.Type.LIGHT_ACTIVE

	if platform_data is Platform:
		p_type = platform_data.type
	elif platform_data is int:
		p_type = platform_data as Platform.Type
	elif platform_data is Dictionary and platform_data.has("type"):
		p_type = platform_data["type"]

	match p_type:
		Platform.Type.START:
			return Category.START
		Platform.Type.DARK_UP, Platform.Type.DARK_DOWN, Platform.Type.DARK_SIDE:
			return Category.DARK
		_:
			return Category.LIGHT


func _get_platform_color(cell_pos: Vector2i) -> Color:
	if cell_pos == current_pos:
		return COLOR_CURRENT

	if cell_pos in visited_platforms:
		var category: Category = platform_categories.get(cell_pos, Category.LIGHT)
		return CATEGORY_COLORS.get(category, CATEGORY_COLORS[Category.LIGHT])

	return COLOR_HIDDEN if hide_unvisited_platforms else COLOR_UNVISITED


func _refresh_platform_colors() -> void:
	for cell_pos: Vector2i in platform_nodes.keys():
		platform_nodes[cell_pos].color = _get_platform_color(cell_pos)


func _read_scene_margins() -> void:
	var parent_ctrl := get_parent() as Control
	if parent_ctrl and parent_ctrl.size != Vector2.ZERO:
		var viewport_w: float = get_viewport_rect().size.x
		_screen_margin = Vector2(
			maxf(0.0, viewport_w - (parent_ctrl.position.x + parent_ctrl.size.x)),
			maxf(0.0, parent_ctrl.position.y)
		)


func _calculate_collapsed_size() -> Vector2:
	var side_cells: int = 5
	var grid_5x5 := Vector2(
		side_cells * cell_size.x + (side_cells - 1) * cell_margin.x,
		side_cells * cell_size.y + (side_cells - 1) * cell_margin.y
	)
	var min_padded_size: Vector2 = grid_5x5 + Vector2(16.0, 16.0)
	return custom_minimum_size.max(min_padded_size)


func _update_outer_cells_alpha(outer_alpha: float) -> void:
	for cell_pos: Vector2i in platform_nodes.keys():
		var icon: ColorRect = platform_nodes[cell_pos]
		var is_in_5x5: bool = absi(cell_pos.x - current_pos.x) <= 2 and absi(cell_pos.y - current_pos.y) <= 2
		icon.modulate.a = 1.0 if is_in_5x5 else outer_alpha


func _get_target_grid_position(p_grid_pos: Vector2i, p_box_size: Vector2, p_expanded: bool) -> Vector2:
	if not platform_nodes.has(p_grid_pos):
		return grid.position

	if p_expanded:
		var cols: int = (max_bounds.x - min_bounds.x) + 1
		var rows: int = (max_bounds.y - min_bounds.y) + 1
		var total_grid_size := Vector2(
			cols * cell_size.x + maxi(0, cols - 1) * cell_margin.x,
			rows * cell_size.y + maxi(0, rows - 1) * cell_margin.y
		)
		grid.size = total_grid_size
		return ((p_box_size - total_grid_size) / 2.0).round()
	else:
		var step: Vector2 = cell_size + cell_margin
		var col_index: int = p_grid_pos.x - min_bounds.x
		var row_index: int = p_grid_pos.y - min_bounds.y
		var icon_center := Vector2(col_index * step.x, row_index * step.y) + (cell_size / 2.0)
		return ((p_box_size / 2.0) - icon_center).round()


func _apply_box_geometry(p_box_size: Vector2, p_grid_pos: Vector2) -> void:
	custom_minimum_size = p_box_size
	size = p_box_size

	var parent_ctrl := get_parent() as Control
	if parent_ctrl:
		var viewport_w: float = get_viewport_rect().size.x
		parent_ctrl.size = p_box_size
		parent_ctrl.position = Vector2(viewport_w - p_box_size.x - _screen_margin.x, _screen_margin.y).round()

	grid.position = p_grid_pos


func _sync_corner_position() -> void:
	_apply_box_geometry(size, grid.position)


func _setup_visual_nodes() -> void:
	grid.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	grid.scale = Vector2.ONE

	for node_name: String in ["Back", "Border"]:
		var ctrl := get_node_or_null(node_name) as Control
		if ctrl:
			ctrl.scale = Vector2.ONE
			if ctrl is TextureRect:
				ctrl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var back := get_node_or_null("Back")
	if back:
		move_child(back, 0)

	var border := get_node_or_null("Border")
	if border:
		move_child(border, -1)


func _set_hide_unvisited_platforms(value: bool) -> void:
	hide_unvisited_platforms = value
	if is_inside_tree(): _refresh_platform_colors()
	
#endregion
