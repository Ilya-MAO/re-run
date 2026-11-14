class_name Minimap
extends Control

@export var cell_size: Vector2 = Vector2(18, 18)
@export var cell_margin: Vector2 = Vector2(2, 2)

@export var grid: GridContainer

var coords: Vector2i = Vector2i.ZERO
var current_pos: Vector2i = Vector2i.ZERO
var visited_rooms: Array[Vector2i] = []
var rooms: Dictionary = {}
var room_nodes: Dictionary = {}

var min_bounds: Vector2i = Vector2i.ZERO
var max_bounds: Vector2i = Vector2i.ZERO

var is_expanded: bool = false
var minimap_orig_size: Vector2
var minimap_orig_pos: Vector2

func _ready() -> void:
	minimap_orig_size = size
	minimap_orig_pos = position

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map"):
		toggle_expanded_map()

func setup_map(_p_grid_size: Vector2i, p_rooms: Dictionary) -> void:
	if p_rooms.is_empty():
		return

	min_bounds = p_rooms.keys()[0]
	max_bounds = p_rooms.keys()[0]
	
	for pos in p_rooms.keys():
		min_bounds.x = mini(min_bounds.x, pos.x)
		min_bounds.y = mini(min_bounds.y, pos.y)
		max_bounds.x = maxi(max_bounds.x, pos.x)
		max_bounds.y = maxi(max_bounds.y, pos.y)

	var cols = (max_bounds.x - min_bounds.x) + 1
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", int(cell_margin.x))
	grid.add_theme_constant_override("v_separation", int(cell_margin.y))

	for child in grid.get_children():
		child.queue_free()
	room_nodes.clear()

	for y in range(min_bounds.y, max_bounds.y + 1):
		for x in range(min_bounds.x, max_bounds.x + 1):
			var cell_pos = Vector2i(x, y)
			
			if p_rooms.has(cell_pos):
				var room_icon = ColorRect.new()
				room_icon.custom_minimum_size = cell_size
				room_icon.size = cell_size
				
				if cell_pos == current_pos:
					room_icon.color = Color(0.1, 0.85, 0.3, 1.0)
				elif cell_pos in visited_rooms:
					room_icon.color = Color(0.4, 0.4, 0.45, 0.8)
				else:
					room_icon.color = Color(0.2, 0.2, 0.25, 0.6)
					
				grid.add_child(room_icon)
				room_nodes[cell_pos] = room_icon
			else:
				var dummy = Control.new()
				dummy.custom_minimum_size = cell_size
				grid.add_child(dummy)

	call_deferred("center_on_room", current_pos)

func set_current_room(p_grid_pos: Vector2i) -> void:
	if not p_grid_pos in visited_rooms:
		visited_rooms.append(p_grid_pos)

	if room_nodes.has(current_pos):
		room_nodes[current_pos].color = Color(0.4, 0.4, 0.45, 0.8)
		
	current_pos = p_grid_pos
	
	if room_nodes.has(current_pos):
		room_nodes[current_pos].color = Color(0.1, 0.85, 0.3, 1.0)
		
	call_deferred("center_on_room", current_pos)

func center_on_room(p_grid_pos: Vector2i) -> void:
	if not room_nodes.has(p_grid_pos):
		return
		
	var step = cell_size + cell_margin
	
	var col_index = p_grid_pos.x - min_bounds.x
	var row_index = p_grid_pos.y - min_bounds.y
	
	var icon_pos = Vector2(col_index * step.x, row_index * step.y)
	
	var icon_center = icon_pos + (cell_size / 2.0)
	var viewport_center = grid.size / 2.0
	
	grid.position = viewport_center - icon_center

func toggle_expanded_map() -> void:
	is_expanded = !is_expanded
	
	if is_expanded:
		anchor_left = 0.5
		anchor_top = 0.5
		anchor_right = 0.5
		anchor_bottom = 0.5
		offset_left = -150
		offset_top = -150
		offset_right = 150
		offset_bottom = 150
		grid.size = Vector2(300, 300)
	else:
		anchor_left = 1.0
		anchor_top = 0.0
		anchor_right = 1.0
		anchor_bottom = 0.0
		position = minimap_orig_pos
		size = minimap_orig_size
		grid.size = minimap_orig_size

	call_deferred("center_on_room", current_pos)
