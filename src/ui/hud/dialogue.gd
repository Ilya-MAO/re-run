class_name Dialogue
extends PanelContainer

signal dialogue_started
signal dialogue_finished
signal choice_selected(choice_id: StringName)

const CHAR_DELAY: float = 0.025

@onready var portrait_rect: TextureRect = $Margin/HBox/Portrait
@onready var asterisk_label: Label = $Margin/HBox/ContentVBox/TextHBox/AsteriskLabel
@onready var text_label: RichTextLabel = $Margin/HBox/ContentVBox/TextHBox/TextLabel
@onready var choices_box: VBoxContainer = $Margin/HBox/ContentVBox/ChoicesBox

var _lines: Array[DialogueLine] = []
var _current_index: int = 0
var _is_typing: bool = false
var _is_choosing: bool = false
var _selected_choice: int = 0
var _choice_labels: Array[Label] = []
var _names_map: Dictionary = {}
var _tween: Tween

func is_dialogue_active() -> bool:
	return visible


func start_dialogue(lines: Array[DialogueLine], names_map: Dictionary = {}) -> void:
	if lines.is_empty():
		return

	_lines = lines.duplicate()
	_names_map = names_map
	_current_index = 0
	show()
	dialogue_started.emit()
	_show_line(_current_index)


func close_dialogue() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_clear_choices()
	hide()
	_lines.clear()
	_is_choosing = false
	_is_typing = false
	dialogue_finished.emit()

#region Helpers

func _show_line(index: int) -> void:
	_clear_choices()
	_is_choosing = false

	var line: DialogueLine = _lines[index]
	if line.portrait:
		portrait_rect.texture = line.portrait
		portrait_rect.show()
	else:
		portrait_rect.hide()

	asterisk_label.show()
	text_label.text = line.text.format(_names_map)
	text_label.visible_ratio = 0.0
	_is_typing = true

	if _tween and _tween.is_valid():
		_tween.kill()

	var total_chars: int = text_label.get_total_character_count()
	var duration: float = maxf(total_chars * CHAR_DELAY, 0.08)

	_tween = create_tween()
	_tween.tween_property(text_label, "visible_ratio", 1.0, duration)
	_tween.finished.connect(_on_typing_finished)


func _on_typing_finished() -> void:
	_is_typing = false
	var line: DialogueLine = _lines[_current_index]
	if not line.choices.is_empty():
		_show_choices(line.choices)


func _show_choices(choices: Array[DialogueChoice]) -> void:
	_clear_choices()
	_is_choosing = true
	_selected_choice = 0

	for choice: DialogueChoice in choices:
		var lbl := Label.new()
		lbl.text = "  " + choice.choice_text.format(_names_map)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choices_box.add_child(lbl)
		_choice_labels.append(lbl)

	choices_box.show()
	_update_choice_visuals()


func _update_choice_visuals() -> void:
	var line: DialogueLine = _lines[_current_index]
	for i in range(_choice_labels.size()):
		var choice: DialogueChoice = line.choices[i]
		var raw_text: String = choice.choice_text.format(_names_map)
		if i == _selected_choice:
			_choice_labels[i].text = "♥ " + raw_text
			_choice_labels[i].modulate = Color(1.0, 0.95, 0.35)
		else:
			_choice_labels[i].text = "  " + raw_text
			_choice_labels[i].modulate = Color.WHITE


func _clear_choices() -> void:
	for lbl in _choice_labels:
		if is_instance_valid(lbl):
			lbl.queue_free()
	_choice_labels.clear()
	choices_box.hide()


func _confirm_choice() -> void:
	var line: DialogueLine = _lines[_current_index]
	var chosen: DialogueChoice = line.choices[_selected_choice]
	_is_choosing = false
	_clear_choices()

	if chosen.choice_id != &"":
		choice_selected.emit(chosen.choice_id)

	if not chosen.next_lines.is_empty():
		for i in range(chosen.next_lines.size()):
			_lines.insert(_current_index + 1 + i, chosen.next_lines[i])

	_current_index += 1
	if _current_index < _lines.size():
		_show_line(_current_index)
	else:
		close_dialogue()


func _advance() -> void:
	if _is_typing:
		if _tween and _tween.is_valid():
			_tween.kill()
		text_label.visible_ratio = 1.0
		_on_typing_finished()
		return

	if _is_choosing:
		_confirm_choice()
		return

	_current_index += 1
	if _current_index < _lines.size():
		_show_line(_current_index)
	else:
		close_dialogue()

#endregion

#region Specials

func _ready() -> void:
	add_to_group(&"Dialogue")
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if _is_choosing and not _choice_labels.is_empty():
			if event.keycode in [KEY_A, KEY_W, KEY_LEFT, KEY_UP]:
				_selected_choice = (_selected_choice - 1 + _choice_labels.size()) % _choice_labels.size()
				_update_choice_visuals()
				get_viewport().set_input_as_handled()
				return
			elif event.keycode in [KEY_D, KEY_S, KEY_RIGHT, KEY_DOWN]:
				_selected_choice = (_selected_choice + 1) % _choice_labels.size()
				_update_choice_visuals()
				get_viewport().set_input_as_handled()
				return

		if event.keycode in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_advance()
			get_viewport().set_input_as_handled()

#endregion
