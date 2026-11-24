class_name PauseMenu
extends CanvasLayer

@onready var back_btn: Control = %Back
@onready var exit_game_btn: Control = %ExitGame

var _buttons: Array[Control] = []
var _callbacks: Array[Callable] = []
var _selected_index: int = 0
var _leaving: bool = false

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


func _open_pause() -> void:
	_leaving = false
	_selected_index = 0
	show()
	get_tree().paused = true
	for btn in _buttons:
		btn.pivot_offset = btn.size * 0.5
	_update_selection()


func _on_back_pressed() -> void:
	if _leaving:
		return
	get_tree().paused = false
	hide()


func _on_exit_game_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().paused = false
	hide()

	var gen := _find_generator()
	if gen:
		if gen.has_method("stop_generation"):
			gen.call("stop_generation")
		elif gen is CanvasItem:
			(gen as CanvasItem).hide()

	var mm := _find_main_menu()
	if mm:
		mm.show()
		if mm.has_method("refresh_menu_buttons"):
			mm.call("refresh_menu_buttons")
	_leaving = false


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
		var lbl := btn.get_node_or_null("Label") as CanvasItem

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


func _find_generator() -> Node:
	if get_parent() and get_parent().get_node_or_null("PlatformGenerator"):
		return get_parent().get_node_or_null("PlatformGenerator")
	if get_tree().current_scene:
		return get_tree().current_scene.find_child("PlatformGenerator", true, false)
	return null


func _find_main_menu() -> CanvasLayer:
	if get_parent() and get_parent().get_node_or_null("MainMenu"):
		return get_parent().get_node_or_null("MainMenu") as CanvasLayer
	if get_tree().current_scene:
		return get_tree().current_scene.find_child("MainMenu", true, false) as CanvasLayer
	return null

#endregion

#region Specials

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	get_tree().paused = false
	_buttons.clear()
	_callbacks.clear()
	_add_button(back_btn, _on_back_pressed)
	_add_button(exit_game_btn, _on_exit_game_pressed)
	_selected_index = 0
	await get_tree().process_frame
	for btn in _buttons:
		btn.pivot_offset = btn.size * 0.5
	_update_selection()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("ui_cancel"):
		var mm := _find_main_menu()
		if not visible and mm and mm.visible:
			return
		if visible:
			_on_back_pressed()
		else:
			_open_pause()
		get_viewport().set_input_as_handled()
		return
	if not visible or _buttons.is_empty():
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
