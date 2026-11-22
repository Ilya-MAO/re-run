class_name Prompt
extends Control


@onready var label: Label = %Label
@onready var background: PanelContainer = %Background


func show_persistent(text: String) -> void:
	_is_temporary = false
	label.text = text
	visible = true


func say(text: String, duration: float = 2.0) -> void:
	_is_temporary = true
	_hide_timer = duration
	label.text = text
	visible = true


func hide_prompt() -> void:
	if not _is_temporary:
		background.size.x = 0
		visible = false

#region Specials

var _hide_timer: float = 0.0
var _is_temporary: bool = false

func _ready() -> void:
	visible = false
	_base_offset_x = background.position.x

func _process(delta: float) -> void:
	if _is_temporary:
		_hide_timer -= delta
		if _hide_timer <= 0.0:
			_is_temporary = false
			visible = false
			return

	if not visible: return

	_update_flip()

#endregion

#region Helpers

var _base_offset_x: float
var _edge_margin: float = 8.0

func _update_flip() -> void:
	var canvas_item := owner as CanvasItem
	if not canvas_item: return

	var screen_x: float     = canvas_item.get_global_transform_with_canvas().origin.x
	var screen_width: float = get_viewport_rect().size.x
	var scale_x: float      = get_canvas_transform().get_scale().x

	var right_edge: float = screen_x + (_base_offset_x + background.size.x) * scale_x
	if right_edge > screen_width - _edge_margin:
		background.position.x = -_base_offset_x - background.size.x
	else:
		background.position.x = _base_offset_x

#endregion
