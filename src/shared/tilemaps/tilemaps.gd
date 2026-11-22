class_name Tilemaps
extends Node2D

const TILEMAPS_GROUP: StringName = &"Tilemaps"
const PLAYERS_GROUP: StringName = &"Players"

const NEIGHBORS_8: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1,  0),                  Vector2i(1,  0),
	Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1)
]

@export_group("Crystals")
@export var charge_duration: float = 10.0
@export var slow_multiplier: float = 0.5
@export var player_hitbox_extents: Vector2 = Vector2(5.0, 5.0)
@export var blocks_crystal_offset_x: int = 3

@onready var blocks: TileMapLayer = _find_layer(&"Blocks")
@onready var borders: TileMapLayer = _find_layer(&"Borders")
@onready var logic: TileMapLayer = _find_layer(&"Logic")
@onready var connectors_layers: Array[ConnectorsTilemap] = _find_all_connectors()


func handle_laser_hit(hit_layer: TileMapLayer, collision_point: Vector2, collision_normal: Vector2) -> void:
	if hit_layer != blocks and hit_layer != borders and hit_layer != logic: return

	var inside_point: Vector2 = collision_point - collision_normal * 2.0
	var hit_cell: Vector2i = hit_layer.local_to_map(hit_layer.to_local(inside_point))

	if _is_crystal(hit_layer, hit_cell):
		_charge_crystal_at(hit_layer, hit_cell)
	elif hit_layer == logic or hit_layer == blocks:
		_activate_trigger_at(hit_layer, hit_cell)


func sync_connectors() -> void:
	if connectors_layers.is_empty():
		connectors_layers = _find_all_connectors()

	for conn: ConnectorsTilemap in connectors_layers:
		if is_instance_valid(conn):
			conn.sync_from_blocks()


#region Specials

var _active_clusters: Dictionary = {}
var _cell_to_cluster: Dictionary = {}
var _next_cluster_id: int = 1


func _ready() -> void:
	add_to_group(TILEMAPS_GROUP)
	call_deferred(&"sync_connectors")


func _physics_process(delta: float) -> void:
	_process_crystals(delta)

#endregion

#region Helpers

func _find_layer(layer_name: StringName) -> TileMapLayer:
	var unique := get_node_or_null("%" + String(layer_name)) as TileMapLayer
	if unique: return unique

	var direct := get_node_or_null(NodePath(layer_name)) as TileMapLayer
	if direct: return direct

	var found := find_child(String(layer_name), true, false) as TileMapLayer
	if found: return found

	var root: Node = owner if owner else get_parent()
	return root.find_child(String(layer_name), true, false) as TileMapLayer if root else null


func _find_all_connectors() -> Array[ConnectorsTilemap]:
	var result: Array[ConnectorsTilemap] = []
	var search_root: Node = owner if owner else (get_parent() if get_parent() else self)

	for child: Node in search_root.find_children("*", "TileMapLayer", true, false):
		if child is ConnectorsTilemap:
			result.append(child)

	return result


func _activate_trigger_at(layer: TileMapLayer, hit_cell: Vector2i) -> void:
	if not layer: return

	var candidates: Array[Vector2i] = []
	for dx: int in range(-2, 3):
		for dy: int in range(-2, 3):
			candidates.append(hit_cell + Vector2i(dx, dy))

	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(hit_cell) < b.distance_squared_to(hit_cell)
	)

	for cell: Vector2i in candidates:
		var data: TileData = layer.get_cell_tile_data(cell)
		if data and data.has_custom_data(&"is_active") and not bool(data.get_custom_data(&"is_active")):
			var source_id: int = layer.get_cell_source_id(cell)
			var atlas_coords: Vector2i = layer.get_cell_atlas_coords(cell)
			var alt_tile: int = layer.get_cell_alternative_tile(cell)
			layer.set_cell(cell, source_id, atlas_coords + Vector2i(blocks_crystal_offset_x, 0), alt_tile)
			sync_connectors()
			_notify_bridges()
			return


func _notify_bridges() -> void:
	var root: Node = owner if owner else get_parent()
	var bridges := root.find_child("Bridges", true, false) if root else null
	if bridges and bridges.has_method(&"update_all_bridges"):
		bridges.update_all_bridges()
	else:
		get_tree().call_group(&"Bridges", &"update_all_bridges")


func _process_crystals(delta: float) -> void:
	if _active_clusters.is_empty(): return

	var player := get_tree().get_first_node_in_group(PLAYERS_GROUP) as Player
	var to_discharge: Array[int] = []

	for cluster_id in _active_clusters.keys():
		var cluster: Dictionary = _active_clusters[cluster_id]
		var layer: TileMapLayer = cluster["layer"]
		var player_inside: bool = false

		if is_instance_valid(player) and is_instance_valid(layer):
			var player_cells: Array[Vector2i] = _get_occupied_cells(layer, player.global_position, player_hitbox_extents)
			player_inside = _is_player_in_cluster(cluster["cells"], player_cells)

		cluster["time_left"] -= delta
		if cluster["time_left"] <= 0.0:
			if player_inside:
				cluster["time_left"] = 0.1
			else:
				to_discharge.append(cluster_id)

	for id in to_discharge:
		_discharge_cluster(id)


func _is_player_in_cluster(cluster_cells: Array, player_cells: Array[Vector2i]) -> bool:
	for node in cluster_cells:
		if player_cells.has(node["cell"]):
			return true
	return false


func _get_occupied_cells(layer: TileMapLayer, center_global: Vector2, extents: Vector2) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var offsets: Array[Vector2] = [
		Vector2(-extents.x, -extents.y),
		Vector2( extents.x, -extents.y),
		Vector2(-extents.x,  extents.y),
		Vector2( extents.x,  extents.y)
	]
	for off in offsets:
		var cell: Vector2i = layer.local_to_map(layer.to_local(center_global + off))
		if not cells.has(cell):
			cells.append(cell)
	return cells


func _charge_crystal_at(layer: TileMapLayer, start_cell: Vector2i) -> void:
	var layer_map: Dictionary = _cell_to_cluster.get(layer, {})
	if layer_map.has(start_cell):
		var existing_id: int = layer_map[start_cell]
		if _active_clusters.has(existing_id):
			_active_clusters[existing_id]["time_left"] = charge_duration
		return

	var cluster_cells: Array[Dictionary] = _collect_connected_crystals(layer, start_cell)
	if cluster_cells.is_empty(): return

	var cluster_id: int = _next_cluster_id
	_next_cluster_id += 1

	_active_clusters[cluster_id] = {
		"layer": layer,
		"cells": cluster_cells,
		"time_left": charge_duration
	}

	if not _cell_to_cluster.has(layer):
		_cell_to_cluster[layer] = {}

	for node in cluster_cells:
		var cell: Vector2i = node["cell"]
		_cell_to_cluster[layer][cell] = cluster_id
		layer.set_cell(cell, node["source_id"], node["atlas_coords"] + Vector2i(blocks_crystal_offset_x, 0), node["alt_tile"])


func _discharge_cluster(cluster_id: int) -> void:
	if not _active_clusters.has(cluster_id): return

	var layer: TileMapLayer = _active_clusters[cluster_id]["layer"]
	var layer_map: Dictionary = _cell_to_cluster.get(layer, {})

	for node in _active_clusters[cluster_id]["cells"]:
		var cell: Vector2i = node["cell"]
		layer_map.erase(cell)
		if is_instance_valid(layer):
			layer.set_cell(cell, node["source_id"], node["atlas_coords"], node["alt_tile"])

	_active_clusters.erase(cluster_id)


func _collect_connected_crystals(layer: TileMapLayer, start_cell: Vector2i) -> Array[Dictionary]:
	var visited: Dictionary = {}
	var result: Array[Dictionary] = []
	var queue: Array[Vector2i] = [start_cell]
	visited[start_cell] = true

	while not queue.is_empty():
		var curr_cell: Vector2i = queue.pop_front()

		result.append({
			"cell": curr_cell,
			"source_id": layer.get_cell_source_id(curr_cell),
			"atlas_coords": layer.get_cell_atlas_coords(curr_cell),
			"alt_tile": layer.get_cell_alternative_tile(curr_cell)
		})

		for offset in NEIGHBORS_8:
			var neighbor_cell: Vector2i = curr_cell + offset
			if not visited.has(neighbor_cell) and _is_crystal(layer, neighbor_cell):
				visited[neighbor_cell] = true
				queue.append(neighbor_cell)

	return result


func _is_crystal(layer: TileMapLayer, cell: Vector2i) -> bool:
	var data: TileData = layer.get_cell_tile_data(cell)
	return data != null and data.get_custom_data(&"is_crystal") == true

#endregion
