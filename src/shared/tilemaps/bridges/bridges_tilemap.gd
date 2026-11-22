class_name BridgesTilemap
extends TileMapLayer

signal next_platform_requested(direction: Vector2)

const PLAYERS_GROUP: StringName = &"Players"

@export var bridges_data: BridgesData = BridgesData.new()

@onready var blocks_tilemap: TileMapLayer = _find_layer(&"Blocks")
@onready var logic_tilemap: TileMapLayer = _find_layer(&"Logic")
@onready var borders_tilemap: TileMapLayer = _find_layer(&"Borders")
@onready var floor_tilemap: TileMapLayer = _find_layer(&"Floor")
@onready var doors_node: Node = _find_node(&"Doors")

var _saved_blockers: Dictionary = {}
var _disabled_scene_blockers: Dictionary = {}
var _opened_bridges: Dictionary = {}

var _available_directions: Array[Vector2i] = []
var _has_direction_filter: bool = false
var _is_mirrored_x: bool = false


func set_available_directions(valid_dirs: Array[Vector2i], is_mirrored_x: bool = false) -> void:
	_has_direction_filter = true
	_is_mirrored_x = is_mirrored_x
	_available_directions.clear()

	for d: Vector2i in valid_dirs:
		if is_mirrored_x and d.x != 0:
			_available_directions.append(Vector2i(-d.x, d.y))
		else:
			_available_directions.append(d)


func update_all_bridges() -> void:
	if not bridges_data: return

	for side in bridges_data.bridges.keys():
		var cfg: Dictionary = bridges_data.bridges[side]
		var dir_i := Vector2i(cfg["dir"])

		# Якщо сусідньої платформи немає — міст не будується і двері не відчиняються
		if _has_direction_filter and not _available_directions.has(dir_i):
			continue

		if doors_node and _find_door_nodes_at(cfg["blockers"]).is_empty():
			continue

		var should_open: bool = _are_triggers_active(cfg["triggers"])
		var is_open: bool = _opened_bridges.get(side, false)

		if should_open and not is_open:
			_opened_bridges[side] = true
			_open_bridge(side, cfg)
		elif not should_open and is_open:
			_opened_bridges[side] = false
			_close_bridge(side, cfg)


#region Specials

func _ready() -> void:
	add_to_group(&"Bridges")
	clear()

	await get_tree().process_frame
	_bind_doors_triggers()
	update_all_bridges()

#endregion

#region Helpers

func _find_node(node_name: StringName) -> Node:
	var unique := get_node_or_null("%" + String(node_name))
	if unique: return unique

	if get_parent():
		var sibling := get_parent().get_node_or_null(NodePath(node_name))
		if sibling: return sibling

	var root: Node = owner if owner else get_parent()
	return root.find_child(String(node_name), true, false) if root else null


func _find_layer(layer_name: StringName) -> TileMapLayer:
	return _find_node(layer_name) as TileMapLayer


func _bind_doors_triggers() -> void:
	if not doors_node: return

	for side in bridges_data.bridges.keys():
		var cfg: Dictionary = bridges_data.bridges[side]
		var dir_i := Vector2i(cfg["dir"])

		# Не підключаємо тригер виходу туди, де немає платформи (двері лишаються зачиненими)
		if _has_direction_filter and not _available_directions.has(dir_i):
			continue

		var world_dir := Vector2(cfg["dir"])
		if _is_mirrored_x and world_dir.x != 0.0:
			world_dir.x = -world_dir.x

		for door_node in _find_door_nodes_at(cfg["blockers"]):
			if door_node is Area2D and not door_node.body_entered.is_connected(_on_exit_entered):
				door_node.body_entered.connect(_on_exit_entered.bind(world_dir))


func _find_door_nodes_at(blocker_cells: Array) -> Array[Node2D]:
	var found: Array[Node2D] = []
	if not doors_node: return found

	for cell: Vector2i in blocker_cells:
		var cell_world_pos: Vector2 = to_global(map_to_local(cell))
		for child in doors_node.get_children():
			if child is Node2D and child not in found:
				if child.global_position.distance_to(cell_world_pos) <= 64.0:
					found.append(child)
	return found


func _are_triggers_active(cells: Array) -> bool:
	for cell: Vector2i in cells:
		if not _is_trigger_cell_active(cell):
			return false
	return true


func _is_trigger_cell_active(cell: Vector2i) -> bool:
	var cell_world_pos: Vector2 = to_global(map_to_local(cell))

	if blocks_tilemap:
		# 1. Перевіряємо тайл на шарі Blocks із Custom Data "is_active"
		var block_cell: Vector2i = blocks_tilemap.local_to_map(blocks_tilemap.to_local(cell_world_pos))
		var block_data: TileData = blocks_tilemap.get_cell_tile_data(block_cell)
		if block_data and block_data.has_custom_data(&"is_active"):
			return bool(block_data.get_custom_data(&"is_active"))

		# 2. Якщо на Blocks використаний Scene Tile зі змінною is_active
		for child in blocks_tilemap.get_children():
			if child is Node2D and child.get(&"is_active") != null:
				if cell_world_pos.distance_to(child.global_position) <= 32.0:
					return bool(child.get(&"is_active"))

	# 3. Резервна перевірка шару Logic
	if logic_tilemap:
		var logic_cell: Vector2i = logic_tilemap.local_to_map(logic_tilemap.to_local(cell_world_pos))
		var logic_data: TileData = logic_tilemap.get_cell_tile_data(logic_cell)
		if logic_data and logic_data.has_custom_data(&"is_active"):
			return bool(logic_data.get_custom_data(&"is_active"))

	# 4. Якщо в цій клітинці немає елемента логіки (наприклад, на старті чи в пасивній кімнаті)
	return true


func _open_bridge(side: int, cfg: Dictionary) -> void:
	_set_blockers_enabled(side, cfg["blockers"], false)
	_set_door_open(cfg["blockers"], true)

	if not tile_set: return
	var pattern: TileMapPattern = tile_set.get_pattern(cfg["pattern"])
	if not pattern: return

	var dir: Vector2i = cfg["dir"]
	var start: Vector2i = cfg["start"]
	var local_cells: Array[Vector2i] = pattern.get_used_cells()

	local_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a.x * dir.x + a.y * dir.y) < (b.x * dir.x + b.y * dir.y)
	)

	for p_cell in local_cells:
		if not _opened_bridges.get(side, false): return

		set_cell(
			start + p_cell,
			pattern.get_cell_source_id(p_cell),
			pattern.get_cell_atlas_coords(p_cell),
			pattern.get_cell_alternative_tile(p_cell)
		)


func _close_bridge(side: int, cfg: Dictionary) -> void:
	_set_blockers_enabled(side, cfg["blockers"], true)
	_set_door_open(cfg["blockers"], false)

	if not tile_set: return
	var pattern: TileMapPattern = tile_set.get_pattern(cfg["pattern"])
	if not pattern: return

	var start: Vector2i = cfg["start"]
	for p_cell in pattern.get_used_cells():
		erase_cell(start + p_cell)


func _set_door_open(blocker_cells: Array, is_open: bool) -> void:
	for door_node in _find_door_nodes_at(blocker_cells):
		var sprite := door_node.get_node_or_null("Sprite") as CanvasItem
		var physic := door_node.get_node_or_null("PhysicArea/Collision") as CollisionShape2D

		if sprite: sprite.visible = not is_open
		if physic: physic.set_deferred(&"disabled", is_open)


func _set_blockers_enabled(side: int, blocker_cells: Array, enabled: bool) -> void:
	if not enabled:
		var disabled_nodes: Array[StaticBody2D] = []

		for block_cell: Vector2i in blocker_cells:
			if borders_tilemap and borders_tilemap.get_cell_source_id(block_cell) != -1:
				_saved_blockers[block_cell] = {
					"source": borders_tilemap.get_cell_source_id(block_cell),
					"atlas": borders_tilemap.get_cell_atlas_coords(block_cell),
					"alt": borders_tilemap.get_cell_alternative_tile(block_cell)
				}
				borders_tilemap.erase_cell(block_cell)

			if floor_tilemap:
				var cell_world_pos: Vector2 = to_global(map_to_local(block_cell))
				for child in floor_tilemap.get_children():
					if child is StaticBody2D and child not in disabled_nodes:
						if child.global_position.distance_to(cell_world_pos) <= 24.0:
							var col := child.get_node_or_null("Collision") as CollisionShape2D
							if col:
								col.set_deferred(&"disabled", true)
							child.visible = false
							disabled_nodes.append(child)

		_disabled_scene_blockers[side] = disabled_nodes
	else:
		if borders_tilemap:
			for block_cell: Vector2i in blocker_cells:
				if _saved_blockers.has(block_cell):
					var b: Dictionary = _saved_blockers[block_cell]
					borders_tilemap.set_cell(block_cell, b["source"], b["atlas"], b["alt"])

		for child: StaticBody2D in _disabled_scene_blockers.get(side, []):
			if is_instance_valid(child):
				var col := child.get_node_or_null("Collision") as CollisionShape2D
				if col:
					col.set_deferred(&"disabled", false)
				child.visible = true

		_disabled_scene_blockers.erase(side)


func _on_exit_entered(body: Node2D, direction: Vector2) -> void:
	if body is not Player or not body.is_in_group(PLAYERS_GROUP): return

	if body.telekinesis: body.telekinesis.release_object()
	next_platform_requested.emit(direction)

#endregion
