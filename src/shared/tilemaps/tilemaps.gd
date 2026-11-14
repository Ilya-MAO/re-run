class_name Tilemaps
extends Node2D

signal logic_network_changed

@onready var walls: TileMapLayer = $Walls
@onready var logic: LogicTilemap = $Logic
@onready var blocks: TileMapLayer = $Blocks

@export_group("Crystals")
@export var charge_duration: float = 10.0
@export var slow_multiplier: float = 0.5
@export var player_hitbox_extents: Vector2 = Vector2(5.0, 5.0)
@export var blocks_crystal_offset_x: int = 3
@export var walls_crystal_offset_x: int = 6

const NEIGHBORS_8: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1,  0),                  Vector2i(1,  0),
	Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1)
]

var _active_clusters: Dictionary = {}
var _cell_key_to_cluster: Dictionary = {}
var _next_cluster_id: int = 1


func _ready() -> void:
	if logic:
		logic.network_changed.connect(_on_logic_network_changed)


func _physics_process(delta: float) -> void:
	_process_crystals(delta)


func _on_logic_network_changed() -> void:
	_update_powered_walls()
	logic_network_changed.emit()
	get_tree().call_group("Doors", "update_all_doors")


func _update_powered_walls() -> void:
	var transform_mask := (
		TileSetAtlasSource.TRANSFORM_FLIP_H
		| TileSetAtlasSource.TRANSFORM_FLIP_V
		| TileSetAtlasSource.TRANSFORM_TRANSPOSE
	)

	for cell in walls.get_used_cells():
		if logic.get_cell_connect_mask(cell) > 0:
			var is_powered := logic.is_cell_powered(cell)
			var source_id := walls.get_cell_source_id(cell)
			var coords := walls.get_cell_atlas_coords(cell)
			var current_alt := walls.get_cell_alternative_tile(cell)

			var flags := current_alt & transform_mask
			var new_alt := (1 if is_powered else 0) | flags

			if current_alt != new_alt:
				walls.set_cell(cell, source_id, coords, new_alt)


func set_direct_logic_signal(source: Object, world_pos: Vector2, is_on: bool) -> void:
	logic.set_direct_signal(source, world_pos, is_on)


func is_logic_cell_powered(cell: Vector2i) -> bool:
	return logic.is_cell_powered(cell)


func is_logic_powered_at(world_pos: Vector2) -> bool:
	return logic.is_powered_at(world_pos)


func handle_laser_hit(hit_layer: TileMapLayer, collision_point: Vector2, collision_normal: Vector2) -> void:
	if hit_layer != walls and hit_layer != blocks and hit_layer != logic:
		return

	var inside_point := collision_point - collision_normal * 2.0
	var hit_cell := hit_layer.local_to_map(hit_layer.to_local(inside_point))
	var data := hit_layer.get_cell_tile_data(hit_cell)

	if data != null and data.get_custom_data("is_crystal") == true:
		_charge_crystal_at(hit_layer, hit_cell)


func _process_crystals(delta: float) -> void:
	if _active_clusters.is_empty():
		return

	var player := get_tree().get_first_node_in_group("Players") as Player
	var player_block_cells: Array[Vector2i] = []
	var player_wall_cells: Array[Vector2i] = []

	if is_instance_valid(player):
		player_block_cells = _get_occupied_cells(blocks, player.global_position, player_hitbox_extents)
		player_wall_cells = _get_occupied_cells(walls, player.global_position, player_hitbox_extents)

	var is_player_on_charged := false
	var to_discharge: Array[int] = []

	for cluster_id in _active_clusters.keys():
		var cluster: Dictionary = _active_clusters[cluster_id]
		var nodes: Array = cluster["nodes"]
		var player_inside := false

		for node in nodes:
			var layer: TileMapLayer = node["layer"]
			var cell: Vector2i = node["cell"]
			if (layer == blocks and player_block_cells.has(cell)) or (layer == walls and player_wall_cells.has(cell)):
				player_inside = true
				break

		if player_inside:
			is_player_on_charged = true

		cluster["time_left"] -= delta
		if cluster["time_left"] <= 0.0:
			if player_inside:
				cluster["time_left"] = 0.1
			else:
				to_discharge.append(cluster_id)

	if is_instance_valid(player):
		if is_player_on_charged:
			player.add_slow_source(self, slow_multiplier)
		else:
			player.remove_slow_source(self)

	for id in to_discharge:
		_discharge_cluster(id)


func _get_occupied_cells(layer: TileMapLayer, center_global: Vector2, extents: Vector2) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var offsets: Array[Vector2] = [
		Vector2(-extents.x, -extents.y),
		Vector2( extents.x, -extents.y),
		Vector2(-extents.x,  extents.y),
		Vector2( extents.x,  extents.y)
	]
	for off in offsets:
		var cell := layer.local_to_map(layer.to_local(center_global + off))
		if not cells.has(cell):
			cells.append(cell)
	return cells


func _charge_crystal_at(start_layer: TileMapLayer, start_cell: Vector2i) -> void:
	var start_key := _make_cell_key(start_layer, start_cell)

	if _cell_key_to_cluster.has(start_key):
		var existing_id: int = _cell_key_to_cluster[start_key]
		if _active_clusters.has(existing_id):
			_active_clusters[existing_id]["time_left"] = charge_duration
		return

	var cluster_nodes := _collect_connected_crystals(start_layer, start_cell)
	if cluster_nodes.is_empty():
		return

	var cluster_id := _next_cluster_id
	_next_cluster_id += 1

	_active_clusters[cluster_id] = {
		"nodes": cluster_nodes,
		"time_left": charge_duration
	}

	for node in cluster_nodes:
		var layer: TileMapLayer = node["layer"]
		var cell: Vector2i = node["cell"]
		_cell_key_to_cluster[_make_cell_key(layer, cell)] = cluster_id

		var offset_x := blocks_crystal_offset_x if layer == blocks else walls_crystal_offset_x
		layer.set_cell(cell, node["source_id"], node["atlas_coords"] + Vector2i(offset_x, 0), node["alt_tile"])


func _discharge_cluster(cluster_id: int) -> void:
	if not _active_clusters.has(cluster_id):
		return

	for node in _active_clusters[cluster_id]["nodes"]:
		var layer: TileMapLayer = node["layer"]
		var cell: Vector2i = node["cell"]
		_cell_key_to_cluster.erase(_make_cell_key(layer, cell))
		layer.set_cell(cell, node["source_id"], node["atlas_coords"], node["alt_tile"])

	_active_clusters.erase(cluster_id)


func _collect_connected_crystals(start_layer: TileMapLayer, start_cell: Vector2i) -> Array[Dictionary]:
	var visited_keys: Dictionary = {}
	var result: Array[Dictionary] = []
	var queue: Array[Dictionary] = [{"layer": start_layer, "cell": start_cell}]
	visited_keys[_make_cell_key(start_layer, start_cell)] = true

	var target_layers: Array[TileMapLayer] = [blocks, walls]

	while not queue.is_empty():
		var current: Dictionary = queue.pop_front()
		var curr_layer: TileMapLayer = current["layer"]
		var curr_cell: Vector2i = current["cell"]

		result.append({
			"layer": curr_layer,
			"cell": curr_cell,
			"source_id": curr_layer.get_cell_source_id(curr_cell),
			"atlas_coords": curr_layer.get_cell_atlas_coords(curr_cell),
			"alt_tile": curr_layer.get_cell_alternative_tile(curr_cell)
		})

		for offset in NEIGHBORS_8:
			var neighbor_cell := curr_cell + offset
			for layer in target_layers:
				var key := _make_cell_key(layer, neighbor_cell)
				if not visited_keys.has(key) and _is_crystal(layer, neighbor_cell):
					visited_keys[key] = true
					queue.append({"layer": layer, "cell": neighbor_cell})

	return result


func _is_crystal(layer: TileMapLayer, cell: Vector2i) -> bool:
	var data := layer.get_cell_tile_data(cell)
	return data != null and data.get_custom_data("is_crystal") == true


func _make_cell_key(layer: TileMapLayer, cell: Vector2i) -> String:
	return "%d:%d,%d" % [layer.get_instance_id(), cell.x, cell.y]
