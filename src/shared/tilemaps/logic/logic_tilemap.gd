class_name LogicTilemap
extends TileMapLayer

signal network_changed

const UNSHADED_MAT := preload("res://assets/resources/unshaded.tres")
const RECEIVER_COORDS := Vector2i(4, 0)
const DIR_BITS: Dictionary = {
	Vector2i.UP: 1,
	Vector2i.RIGHT: 2,
	Vector2i.DOWN: 4,
	Vector2i.LEFT: 8
}

@export var active_offset_x: int = 1

var _direct_sources: Dictionary = {}
var _powered_cells: Dictionary = {}
var _active_layer: TileMapLayer


func _ready() -> void:
	_active_layer = get_node_or_null("ActiveOverlay") as TileMapLayer
	if _active_layer == null:
		_active_layer = TileMapLayer.new()
		_active_layer.name = "ActiveOverlay"
		_active_layer.tile_set = tile_set
		_active_layer.material = UNSHADED_MAT
		add_child(_active_layer)


func _physics_process(_delta: float) -> void:
	_update_network()


func set_direct_signal(source: Object, world_pos: Vector2, is_on: bool) -> void:
	var id := source.get_instance_id()
	if is_on:
		_direct_sources[id] = local_to_map(to_local(world_pos))
	else:
		_direct_sources.erase(id)


func is_cell_powered(cell: Vector2i) -> bool:
	return _powered_cells.has(cell)


func is_powered_at(world_pos: Vector2) -> bool:
	return _powered_cells.has(local_to_map(to_local(world_pos)))


func _update_network() -> void:
	var active_seeds: Array[Vector2i] = []

	for source_id in _direct_sources.keys():
		var cell: Vector2i = _direct_sources[source_id]
		if get_cell_connect_mask(cell) > 0:
			active_seeds.append(cell)

	for node in get_tree().get_nodes_in_group("Telekinetic"):
		if node is Mirror and not node.is_lifted and node._is_lit:
			var cell := local_to_map(to_local(node.global_position))
			if _is_receiver_cell(cell) and not active_seeds.has(cell):
				active_seeds.append(cell)

	var new_powered: Dictionary = {}
	var queue: Array[Vector2i] = []

	for seed_cell in active_seeds:
		if not new_powered.has(seed_cell):
			new_powered[seed_cell] = true
			queue.append(seed_cell)

	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		var curr_mask := get_cell_connect_mask(curr)

		for dir in DIR_BITS.keys():
			if (curr_mask & DIR_BITS[dir]) == 0:
				continue

			var next_cell: Vector2i = curr + dir
			if new_powered.has(next_cell):
				continue

			var next_mask := get_cell_connect_mask(next_cell)
			if (next_mask & DIR_BITS[-dir]) != 0:
				new_powered[next_cell] = true
				queue.append(next_cell)

	var changed := false

	for cell in _powered_cells.keys():
		if not new_powered.has(cell):
			var orig: Dictionary = _powered_cells[cell]
			set_cell(cell, orig["source_id"], orig["coords"], orig["alt"])
			_active_layer.erase_cell(cell)
			_powered_cells.erase(cell)
			changed = true

	for cell in new_powered.keys():
		if not _powered_cells.has(cell):
			var src := get_cell_source_id(cell)
			var coords := get_cell_atlas_coords(cell)
			var alt := get_cell_alternative_tile(cell)
			var active_coords := coords + Vector2i(active_offset_x, 0)
			_powered_cells[cell] = {
				"source_id": src,
				"coords": coords,
				"alt": alt
			}
			set_cell(cell, src, active_coords, alt)
			_active_layer.set_cell(cell, src, active_coords, alt)
			changed = true

	if changed:
		network_changed.emit()


func get_cell_connect_mask(cell: Vector2i) -> int:
	var data := get_cell_tile_data(cell)
	if data == null: return 0

	var raw_mask = data.get_custom_data("connect_mask")
	if raw_mask == null: return 0

	var mask := int(raw_mask)
	if mask == 0: return 0

	var u := (mask & 1) != 0
	var r := (mask & 2) != 0
	var d := (mask & 4) != 0
	var l := (mask & 8) != 0

	if is_cell_transposed(cell):
		var tmp := u; u = l; l = tmp
		tmp = d; d = r; r = tmp
	if is_cell_flipped_h(cell):
		var tmp := l; l = r; r = tmp
	if is_cell_flipped_v(cell):
		var tmp := u; u = d; d = tmp

	return (1 if u else 0) | (2 if r else 0) | (4 if d else 0) | (8 if l else 0)


func _is_receiver_cell(cell: Vector2i) -> bool:
	if _powered_cells.has(cell):
		return _powered_cells[cell]["coords"] == RECEIVER_COORDS
	return get_cell_atlas_coords(cell) == RECEIVER_COORDS
