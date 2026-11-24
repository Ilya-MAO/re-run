class_name MainMenu
extends CanvasLayer

@onready var continue_control: Control = get_node_or_null("%Continue")
@onready var play_control: Control = %Play
@onready var exit_control: Control = %Exit

var _buttons: Array[Control] = []
var _callbacks: Array[Callable] = []
var _selected_index: int = 0
var _busy: bool = false

func refresh_menu_buttons() -> void:
	_buttons.clear()
	_callbacks.clear()

	var gen := _find_generator() as PlatformGenerator
	var can_continue := gen != null and gen.has_saved_world()

	_add_button(play_control, _start_new_gameplay)

	if continue_control:
		continue_control.visible = can_continue
		if can_continue:
			_add_button(continue_control, _continue_gameplay)

	_add_button(exit_control, _quit_game)
	_selected_index = 0
	_apply_initial_selection()

#region Helpers

func _add_button(btn: Control, cb: Callable) -> void:
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not btn.resized.is_connected(_on_button_resized.bind(btn)):
		btn.resized.connect(_on_button_resized.bind(btn))
	for child in btn.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buttons.append(btn)
	_callbacks.append(cb)


func _on_button_resized(btn: Control) -> void:
	btn.pivot_offset = btn.size * 0.5


func _apply_initial_selection() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	for btn in _buttons:
		btn.pivot_offset = btn.size * 0.5
	_update_selection()


func _move_selection(delta: int) -> void:
	_selected_index = (_selected_index + delta + _buttons.size()) % _buttons.size()
	_update_selection()


func _update_selection() -> void:
	for i in range(_buttons.size()):
		var btn := _buttons[i]
		var active := i == _selected_index
		btn.pivot_offset = btn.size * 0.5
		btn.scale = Vector2.ONE * 1.06 if active else Vector2.ONE

		var spr := btn.get_node_or_null("Sprtie") as CanvasItem
		if not spr:
			spr = btn.get_node_or_null("Sprite") as CanvasItem
		var lbl := btn.get_node_or_null("Label") as Label

		if spr:
			spr.modulate = Color(1.2, 1.2, 1.05) if active else Color.WHITE
		if lbl:
			lbl.modulate = Color.WHITE
			if lbl.label_settings:
				lbl.label_settings = lbl.label_settings.duplicate()
				lbl.label_settings.font_color = Color.WHITE if active else Color.BLACK
			else:
				lbl.add_theme_color_override("font_color", Color.WHITE if active else Color.BLACK)


func _activate_selected() -> void:
	_callbacks[_selected_index].call()


func _continue_gameplay() -> void:
	if _busy:
		return
	_busy = true
	hide()
	var gen := _find_generator() as PlatformGenerator
	if gen:
		gen.continue_last_world()
	_busy = false


func _start_new_gameplay() -> void:
	if _busy:
		return
	_busy = true
	hide()
	var gen := _find_generator() as PlatformGenerator
	if gen:
		gen.start_new_world()
	_busy = false


func _quit_game() -> void:
	if _busy:
		return
	_busy = true
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	get_tree().quit()


func _find_generator() -> Node:
	if get_parent() and get_parent().get_node_or_null("PlatformGenerator"):
		return get_parent().get_node_or_null("PlatformGenerator")
	if get_tree().current_scene:
		return get_tree().current_scene.find_child("PlatformGenerator", true, false)
	return null

#endregion

#region Specials

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	show()
	await get_tree().process_frame
	refresh_menu_buttons()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _busy or _buttons.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_W or event.keycode == KEY_UP:
			_move_selection(-1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_S or event.keycode == KEY_DOWN:
			_move_selection(1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_activate_selected()
			get_viewport().set_input_as_handled()

#endregion
