class_name InteractArea
extends Area2D

const NONE_CELL = Vector2i(-999, -999)

var target_cell: Vector2i = NONE_CELL
var active_tilemap: TileMapLayer
var current_slot_type: String
var _using_prompt: bool

@onready var prompt: Prompt = $"../Prompt"
@onready var item_slot: ItemSlot = $"../ItemSlot"
@onready var collision: CollisionShape2D = $Collision

func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body is TileMapLayer:
			var found := _get_interactive_cell(body)
			if found == NONE_CELL: continue

			var data: TileData = body.get_cell_tile_data(found)

			var type = data.get_custom_data("slot_type")
			if not type: continue
			
			current_slot_type = type
			active_tilemap = body
			target_cell = found
			_using_prompt = true

			_update_prompt()
			return

	active_tilemap = null
	target_cell = NONE_CELL
	current_slot_type = ""

	if _using_prompt:
		_using_prompt = false
		if prompt: prompt.hide_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if not active_tilemap or current_slot_type == "": return

	if event.is_action_pressed("interact"): _activate_current_slot()

func _update_prompt() -> void:
	match current_slot_type:
		"rune":
			if item_slot.has_item("rune"):          prompt.show_persistent("Press [E] to set the rune")
			else:                                   prompt.show_persistent("You need a rune")
		"coin":
			if (get_parent() as Player).coins >= 1: prompt.show_persistent("Press [E] to insert a coin")
			else:                                   prompt.show_persistent("Not enough coins")

func _activate_current_slot() -> void:
	match current_slot_type:
		"rune": if not item_slot.consume_item("rune"): return
		"coin": if not (get_parent() as Player).spendCoins(1): return

	var id: int = active_tilemap.get_cell_source_id(target_cell)
	var atlas: Vector2i = active_tilemap.get_cell_atlas_coords(target_cell)
	var alt: int = active_tilemap.get_cell_alternative_tile(target_cell)

	active_tilemap.set_cell(target_cell, id, Vector2i(atlas.x + 1, atlas.y), alt)

	get_tree().call_group("Doors", "update_all_doors")


func _get_interactive_cell(tilemap: TileMapLayer) -> Vector2i:
	var half := collision.shape.get_rect().size * 0.5
	var top_left := tilemap.local_to_map(tilemap.to_local(global_position - half))
	var bottom_right := tilemap.local_to_map(tilemap.to_local(global_position + half))

	for x in range(top_left.x, bottom_right.x + 1):
		for y in range(top_left.y, bottom_right.y + 1):
			var cell := Vector2i(x, y)
			var data := tilemap.get_cell_tile_data(cell)
			if data and str(data.get_custom_data("slot_type")) != "":
				return cell

	return NONE_CELL
