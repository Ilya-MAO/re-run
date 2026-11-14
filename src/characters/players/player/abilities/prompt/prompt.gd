class_name Prompt
extends Control

@onready var label: Label = $Background/Label
@onready var background: PanelContainer = $Background
@onready var base_offset_x: float = background.position.x

var _hide_timer: float = 0.0
var _is_temporary: bool = false

func _ready() -> void:
	visible = false

func _process(delta: float) -> void:
	if _is_temporary:
		_hide_timer -= delta
		if _hide_timer <= 0.0:
			_is_temporary = false
			visible = false
			return

	if not visible:
		return

	var parent_item := get_parent() as CanvasItem
	if not parent_item:
		return

	var screen_x: float = parent_item.get_global_transform_with_canvas().origin.x
	var screen_width: float = get_viewport_rect().size.x
	var scale_x: float = get_canvas_transform().get_scale().x

	if screen_x + (base_offset_x + background.size.x) * scale_x > screen_width - 8.0:
		background.position.x = -base_offset_x - background.size.x
	else:
		background.position.x = base_offset_x

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
		visible = false
