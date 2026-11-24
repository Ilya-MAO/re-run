class_name InteractArea
extends Area2D


const VALID_SLOT_TYPES: Array[String] = ["rune", "coin"]
const IGNORED_LAYERS: Array[StringName] = [&"Borders", &"Floor", &"Doors", &"Bridges"]

@export var active_offset_x: int = 3

@onready var prompt: Prompt = %Prompt
@onready var item_slot: ItemSlot = %ItemSlot
@onready var collision: CollisionShape2D = $Collision

#region Classes

class Target:
	const NONE_CELL = Vector2i(-999, -999)

	var tilemap: TileMapLayer
	var cell: Vector2i = NONE_CELL
	var slot_type: String
	var soul: Soul

	func _init(p_tilemap: TileMapLayer = null, p_cell: Vector2i = NONE_CELL, p_slot_type: String = "", p_soul: Soul = null) -> void:
		tilemap = p_tilemap
		cell = p_cell
		slot_type = p_slot_type
		soul = p_soul

#endregion

var _current_target: Target


#region Specials

func _physics_process(_delta: float) -> void:
	# Якщо діалог уже відкритий — ховаємо підказку і не шукаємо цілі
	var dialogue_ui := get_tree().get_first_node_in_group(&"Dialogue") as Dialogue
	if dialogue_ui and dialogue_ui.is_dialogue_active():
		_update_target(null)
		return

	for body in get_overlapping_bodies():
		if body == get_parent():
			continue

		if body is Soul and (body as Soul).can_talk():
			_update_target(Target.new(null, Target.NONE_CELL, "soul", body as Soul))
			return

		if body is TileMapLayer:
			if IGNORED_LAYERS.has(body.name):
				continue

			var target: Target = _get_target_cell(body)
			if not target: continue

			_update_target(target)
			return

	_update_target(null)


func _unhandled_input(event: InputEvent) -> void:
	if not _current_target: return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if _current_target.slot_type == "soul" and is_instance_valid(_current_target.soul):
			_current_target.soul.start_soul_dialogue(get_parent() as Player)
			_update_target(null)
		else:
			_activate_current_slot()

#endregion

#region Helpers

func _get_target_cell(tilemap: TileMapLayer) -> Target:
	if not is_instance_valid(tilemap) or not tilemap.tile_set:
		return null

	var half         := collision.shape.get_rect().size * 0.5
	var interact_rect := Rect2(global_position - half, half * 2.0)
	var tile_size    := Vector2(tilemap.tile_set.tile_size)
	var top_left     := tilemap.local_to_map(tilemap.to_local(global_position - half)) - Vector2i.ONE
	var bottom_right := tilemap.local_to_map(tilemap.to_local(global_position + half)) + Vector2i.ONE

	for x in range(top_left.x, bottom_right.x + 1):
		for y in range(top_left.y, bottom_right.y + 1):
			var cell := Vector2i(x, y)
			var data := tilemap.get_cell_tile_data(cell)
			if not data: continue

			if data.has_custom_data(&"is_active") and bool(data.get_custom_data(&"is_active")):
				continue

			var raw_slot: Variant = data.get_custom_data(&"slot_type")
			if not (raw_slot is String or raw_slot is StringName):
				continue

			var type: String = String(raw_slot).strip_edges().to_lower()
			if not VALID_SLOT_TYPES.has(type):
				continue

			var id: int = tilemap.get_cell_source_id(cell)
			var atlas: Vector2i = tilemap.get_cell_atlas_coords(cell)
			var new_coords := Vector2i(atlas.x + active_offset_x, atlas.y)
			var atlas_source := tilemap.tile_set.get_source(id) as TileSetAtlasSource
			if not atlas_source or not atlas_source.has_tile(new_coords):
				continue

			var size_in_atlas: Vector2i = atlas_source.get_tile_size_in_atlas(atlas)
			var visual_size: Vector2 = Vector2(size_in_atlas) * tile_size
			var center_global: Vector2 = tilemap.to_global(tilemap.map_to_local(cell) - Vector2(data.texture_origin))
			var tile_rect := Rect2(center_global - visual_size * 0.5, visual_size)

			if not tile_rect.intersects(interact_rect):
				continue

			return Target.new(tilemap, cell, type)

	return null


var _using_prompt: bool

func _update_target(target: Target) -> void:
	if target:
		_using_prompt = true
		_current_target = target
		_update_prompt()
	else:
		_current_target = null
		if _using_prompt:
			_using_prompt = false
			if prompt: prompt.hide_prompt()


func _update_prompt() -> void:
	if not _current_target: return

	match _current_target.slot_type:
		"soul":
			prompt.show_persistent("Press [E] to talk")
		"rune":
			if item_slot.item_is("rune"):          prompt.show_persistent("Press [E] to set the rune")
			else:                                   prompt.show_persistent("You need a rune")
		"coin":
			if (get_parent() as Player).coins >= 1: prompt.show_persistent("Press [E] to insert a coin")
			else:                                   prompt.show_persistent("Not enough coins")


func _activate_current_slot() -> void:
	if not _current_target: return

	var tilemap: TileMapLayer = _current_target.tilemap
	var cell   : Vector2i     = _current_target.cell
	if not is_instance_valid(tilemap) or not tilemap.tile_set:
		_update_target(null)
		return

	var data: TileData = tilemap.get_cell_tile_data(cell)
	if not data:
		_update_target(null)
		return
	if data.has_custom_data(&"is_active") and bool(data.get_custom_data(&"is_active")):
		_update_target(null)
		return

	var id    : int      = tilemap.get_cell_source_id(cell)
	var atlas : Vector2i = tilemap.get_cell_atlas_coords(cell)
	var alt   : int      = tilemap.get_cell_alternative_tile(cell)
	var new_coords := Vector2i(atlas.x + active_offset_x, atlas.y)

	var atlas_source := tilemap.tile_set.get_source(id) as TileSetAtlasSource
	if not atlas_source or not atlas_source.has_tile(new_coords):
		_update_target(null)
		return

	match _current_target.slot_type:
		"rune":
			if not item_slot.consume_item("rune"): return
		"coin":
			if not (get_parent() as Player).try_spend_coins(1): return
		_:
			return

	if tilemap is ConnectorsTilemap:
		var world_cell_pos: Vector2 = tilemap.to_global(tilemap.map_to_local(cell))
		tilemap.set_direct_signal(tilemap, world_cell_pos, true)

	tilemap.set_cell(cell, id, new_coords, alt)

	ConnectorsTilemap.sync_all(tilemap)
	get_tree().call_group(&"Bridges", &"update_all_bridges")
	get_tree().call_group(&"Doors", &"update_all_doors")
	_update_target(null)

#endregion
