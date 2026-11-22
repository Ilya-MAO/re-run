class_name ConnectorsTilemap
extends TileMapLayer

signal network_changed

const CONNECTORS_GROUP: StringName = &"Connectors"
const UNSHADED_MAT: Material = preload("res://assets/resources/unshaded.tres")
const SOCKET_ATLAS_COORD: Vector2i = Vector2i(0, 4)
const DIR_BITS: Dictionary = {
	Vector2i.UP: 1,
	Vector2i.RIGHT: 2,
	Vector2i.DOWN: 4,
	Vector2i.LEFT: 8
}
const FOOTPRINT_2X2_QUAD_OFFSETS: Array[Vector2] = [
	Vector2(-8.0, -8.0),
	Vector2( 8.0, -8.0),
	Vector2(-8.0,  8.0),
	Vector2( 8.0,  8.0)
]
const COLUMN_2X2_CELL_OFFSETS: Array[Vector2] = [
	Vector2(-16.0, -16.0),
	Vector2(  0.0, -16.0),
	Vector2(-16.0,   0.0),
	Vector2(  0.0,   0.0)
]

@export var active_offset_x: int = 3


static func get_all_in_context(context: Node) -> Array[ConnectorsTilemap]:
	var result: Array[ConnectorsTilemap] = []
	if not is_instance_valid(context):
		return result

	var node: Node = context if context is TileMapLayer else context.get_parent()
	while node:
		for child: Node in node.find_children("*", "TileMapLayer", true, false):
			if child is ConnectorsTilemap:
				result.append(child)
		if not result.is_empty():
			return result
		node = node.get_parent()

	return result


static func sync_all(context: Node) -> void:
	for conn: ConnectorsTilemap in get_all_in_context(context):
		conn.sync_from_blocks()


## Логіка AND по всіх шарах проводів: усі кінцеві конектори під об'єктом мають бути активні
static func is_any_powered_at(context: Node, world_pos: Vector2, is_2x2: bool = true) -> bool:
	var total_sockets: int = 0
	var powered_sockets: int = 0

	for conn: ConnectorsTilemap in get_all_in_context(context):
		var stats: Vector2i = conn.get_endpoint_power_stats_at(world_pos, is_2x2)
		powered_sockets += stats.x
		total_sockets += stats.y

	return total_sockets > 0 and powered_sockets == total_sockets


func set_direct_signal(source: Object, world_pos: Vector2, is_on: bool) -> void:
	var id: int = source.get_instance_id()
	if is_on:
		var cells: Array[Vector2i] = []
		for offset: Vector2 in FOOTPRINT_2X2_QUAD_OFFSETS:
			var c: Vector2i = local_to_map(to_local(world_pos + offset))
			if is_endpoint_cell(c) and not cells.has(c):
				cells.append(c)
		_direct_sources[id] = cells
	else:
		_direct_sources.erase(id)
	_update_network()


func sync_from_blocks(custom_layer: TileMapLayer = null) -> void:
	var layers_to_scan: Array[TileMapLayer] = []
	if is_instance_valid(custom_layer):
		layers_to_scan.append(custom_layer)
	else:
		if not is_instance_valid(_logic_layer):
			_logic_layer = _find_layer(&"Logic")
		if is_instance_valid(_logic_layer) and not (_logic_layer is ConnectorsTilemap):
			layers_to_scan.append(_logic_layer)

		if not is_instance_valid(_blocks_layer):
			_blocks_layer = _find_layer(&"Blocks")
		if is_instance_valid(_blocks_layer) and not (_blocks_layer is ConnectorsTilemap):
			layers_to_scan.append(_blocks_layer)

	if layers_to_scan.is_empty():
		return

	var active_cells: Array[Vector2i] = []

	for layer: TileMapLayer in layers_to_scan:
		var tile_size_i: Vector2i = layer.tile_set.tile_size if layer.tile_set else Vector2i(16, 16)

		for cell: Vector2i in layer.get_used_cells():
			var data: TileData = layer.get_cell_tile_data(cell)
			if not data or not data.has_custom_data(&"is_active"):
				continue
			if not bool(data.get_custom_data(&"is_active")):
				continue

			var size_in_atlas: Vector2i = _get_tile_atlas_size(layer, cell)
			var region_size: Vector2i = _get_tile_region_size(layer, cell)
			var anchor_local: Vector2 = layer.map_to_local(cell) - Vector2(data.texture_origin)

			var sample_offsets: Array[Vector2] = [Vector2.ZERO]
			if layer == _logic_layer or tile_size_i.x >= 32 or size_in_atlas.x >= 2 or region_size.x >= 32:
				sample_offsets = COLUMN_2X2_CELL_OFFSETS

			for offset: Vector2 in sample_offsets:
				var world_pos: Vector2 = layer.to_global(anchor_local + offset)
				var conn_cell: Vector2i = local_to_map(to_local(world_pos))
				if is_endpoint_cell(conn_cell) and not active_cells.has(conn_cell):
					active_cells.append(conn_cell)

	active_cells.sort()
	if active_cells == _last_synced_cells:
		return

	_last_synced_cells = active_cells.duplicate()

	if active_cells.is_empty():
		_direct_sources.erase(&"LogicColumns")
	else:
		_direct_sources[&"LogicColumns"] = active_cells

	_update_network()


func is_endpoint_cell(cell: Vector2i) -> bool:
	var mask: int = get_cell_connect_mask(cell)
	if mask == 0:
		return false

	if (mask & (mask - 1)) == 0:
		return true

	if get_cell_atlas_coords(cell) == SOCKET_ATLAS_COORD:
		return true

	var data: TileData = get_cell_tile_data(cell)
	if data and data.has_custom_data(&"slot_type"):
		var slot_type: Variant = data.get_custom_data(&"slot_type")
		if slot_type is String or slot_type is StringName:
			return not slot_type.is_empty()
		if slot_type is int:
			return slot_type > 0

	return false


func is_cell_powered(cell: Vector2i) -> bool:
	return _powered_cells.has(cell) and is_endpoint_cell(cell)


## Повертає Vector2i(заживлені_сокети, всього_сокетів) під областю приймача
func get_endpoint_power_stats_at(world_pos: Vector2, is_2x2: bool = true) -> Vector2i:
	var offsets: Array[Vector2] = [Vector2.ZERO]
	if is_2x2:
		offsets = FOOTPRINT_2X2_QUAD_OFFSETS

	var checked_cells: Array[Vector2i] = []
	var total: int = 0
	var powered: int = 0

	for offset: Vector2 in offsets:
		var cell: Vector2i = local_to_map(to_local(world_pos + offset))
		if checked_cells.has(cell):
			continue
		checked_cells.append(cell)

		if is_endpoint_cell(cell):
			total += 1
			if _powered_cells.has(cell):
				powered += 1

	return Vector2i(powered, total)


## Логіка AND на поточному шарі проводів
func is_powered_at(world_pos: Vector2, is_2x2: bool = true) -> bool:
	var stats: Vector2i = get_endpoint_power_stats_at(world_pos, is_2x2)
	return stats.y > 0 and stats.x == stats.y


func get_slot_type_at(world_pos: Vector2) -> Variant:
	var cell: Vector2i = local_to_map(to_local(world_pos))
	var data: TileData = get_cell_tile_data(cell)
	if not data:
		return null
	return data.get_custom_data(&"slot_type")


func is_receiver_at(world_pos: Vector2) -> bool:
	var slot_type: Variant = get_slot_type_at(world_pos)
	if slot_type == null:
		return false

	if slot_type is String or slot_type is StringName:
		return not slot_type.is_empty()

	if slot_type is int:
		return slot_type > 0

	return false


func get_cell_connect_mask(cell: Vector2i) -> int:
	var data: TileData = get_cell_tile_data(cell)
	if not data:
		return 0

	var mask: int = int(data.get_custom_data(&"connect_mask"))
	if mask == 0:
		return 0

	var u: bool = (mask & 1) != 0
	var r: bool = (mask & 2) != 0
	var d: bool = (mask & 4) != 0
	var l: bool = (mask & 8) != 0

	if is_cell_transposed(cell):
		var tmp: bool = u; u = l; l = tmp
		tmp = d; d = r; r = tmp
	if is_cell_flipped_h(cell):
		var tmp: bool = l; l = r; r = tmp
	if is_cell_flipped_v(cell):
		var tmp: bool = u; u = d; d = tmp

	return (1 if u else 0) | (2 if r else 0) | (4 if d else 0) | (8 if l else 0)


#region Private

var _direct_sources: Dictionary = {}
var _powered_cells: Dictionary = {}
var _last_synced_cells: Array[Vector2i] = []
var _active_layer: TileMapLayer
var _logic_layer: TileMapLayer
var _blocks_layer: TileMapLayer


func _ready() -> void:
	add_to_group(CONNECTORS_GROUP)
	_setup_active_layer()
	call_deferred(&"sync_from_blocks")


func _physics_process(_delta: float) -> void:
	sync_from_blocks()


func _get_tile_atlas_size(layer: TileMapLayer, cell: Vector2i) -> Vector2i:
	if not layer.tile_set:
		return Vector2i.ONE
	var source_id: int = layer.get_cell_source_id(cell)
	var atlas_source := layer.tile_set.get_source(source_id) as TileSetAtlasSource
	if not atlas_source:
		return Vector2i.ONE
	return atlas_source.get_tile_size_in_atlas(layer.get_cell_atlas_coords(cell))


func _get_tile_region_size(layer: TileMapLayer, cell: Vector2i) -> Vector2i:
	if not layer.tile_set:
		return Vector2i.ONE
	var source_id: int = layer.get_cell_source_id(cell)
	var atlas_source := layer.tile_set.get_source(source_id) as TileSetAtlasSource
	if not atlas_source:
		return Vector2i.ONE
	return atlas_source.get_tile_texture_region(layer.get_cell_atlas_coords(cell)).size


func _find_layer(layer_name: StringName) -> TileMapLayer:
	if get_parent():
		var sibling := get_parent().get_node_or_null(NodePath(layer_name)) as TileMapLayer
		if sibling:
			return sibling

	var unique := get_node_or_null("%" + String(layer_name)) as TileMapLayer
	if unique:
		return unique

	var root: Node = owner if owner else get_parent()
	return root.find_child(String(layer_name), true, false) as TileMapLayer if root else null


func _setup_active_layer() -> void:
	_active_layer = get_node_or_null("ActiveOverlay") as TileMapLayer
	if not _active_layer:
		_active_layer = TileMapLayer.new()
		_active_layer.name = &"ActiveOverlay"
		_active_layer.tile_set = tile_set
		add_child(_active_layer)

	_active_layer.material = UNSHADED_MAT


func _update_network() -> void:
	var new_powered: Dictionary = _propagate_power()
	if _apply_network_diff(new_powered):
		network_changed.emit()


func _propagate_power() -> Dictionary:
	var powered: Dictionary = {}
	var queue: Array[Vector2i] = []

	for cells in _direct_sources.values():
		for cell in cells:
			if is_endpoint_cell(cell) and not powered.has(cell):
				powered[cell] = true
				queue.append(cell)

	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		var curr_mask: int = get_cell_connect_mask(curr)

		for dir in DIR_BITS.keys():
			if (curr_mask & DIR_BITS[dir]) == 0:
				continue

			var next_cell: Vector2i = curr + dir
			if powered.has(next_cell):
				continue

			if (get_cell_connect_mask(next_cell) & DIR_BITS[-dir]) != 0:
				powered[next_cell] = true
				queue.append(next_cell)

	return powered


func _apply_network_diff(new_powered: Dictionary) -> bool:
	var changed: bool = false

	for cell in _powered_cells.keys():
		if new_powered.has(cell):
			continue
		_active_layer.erase_cell(cell)
		_powered_cells.erase(cell)
		changed = true

	for cell in new_powered.keys():
		if _powered_cells.has(cell):
			continue

		var src: int = get_cell_source_id(cell)
		var coords: Vector2i = get_cell_atlas_coords(cell)
		var alt: int = get_cell_alternative_tile(cell)
		var active_coords: Vector2i = coords + Vector2i(active_offset_x, 0)

		_powered_cells[cell] = true
		_active_layer.set_cell(cell, src, active_coords, alt)
		changed = true

	return changed

#endregion
