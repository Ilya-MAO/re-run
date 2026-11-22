class_name Telekinesis
extends Ability


const TELEKINETIC_GROUP: StringName = &"Telekinetic"

@export var step_cooldown: float = 0.16
@export var prompt_text: String = "Press [F] to move"

@onready var prompt: Prompt = %Prompt
@onready var interact_area: Area2D = %InteractArea

var hovered_object: PhysicsBody2D
var held_object: PhysicsBody2D


func is_active() -> bool:
	return held_object != null


func release_object() -> void:
	if is_instance_valid(held_object) and held_object.has_method(&"drop"):
		held_object.drop()
	held_object = null
	_refresh_hovered()

#region Specials

var _step_timer: float = 0.0
var _owns_prompt: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"telekinesis"): return

	if held_object: release_object()
	elif hovered_object: _grab_object(hovered_object)


func _physics_process(delta: float) -> void:
	if not held_object:
		_refresh_hovered()
		return

	if not is_instance_valid(held_object):
		release_object()
		return

	if _step_timer > 0.0:
		_step_timer -= delta
		return

	var input_dir: Vector2i = _get_grid_input()
	if input_dir != Vector2i.ZERO and held_object.has_method(&"try_move_grid"):
		if held_object.try_move_grid(input_dir, _get_origin(), INF):
			_step_timer = step_cooldown

#endregion

#region Helpers

func _get_origin() -> Vector2:
	return (owner as Node2D).global_position if owner is Node2D else Vector2.ZERO


func _get_grid_input() -> Vector2i:
	if Input.is_action_pressed(&"ui_up"):    return Vector2i.UP
	if Input.is_action_pressed(&"ui_down"):  return Vector2i.DOWN
	if Input.is_action_pressed(&"ui_right"): return Vector2i.RIGHT
	if Input.is_action_pressed(&"ui_left"):  return Vector2i.LEFT
	return Vector2i.ZERO


func _refresh_hovered() -> void:
	if held_object or not interact_area:
		hovered_object = null
		_set_prompt_visible(false)
		return

	var origin: Vector2 = _get_origin()
	var best_obj: PhysicsBody2D = null
	var best_dist: float = INF

	for body in interact_area.get_overlapping_bodies():
		if body is not PhysicsBody2D or not body.is_in_group(TELEKINETIC_GROUP): continue
		var dist: float = origin.distance_squared_to(body.global_position)
		if dist < best_dist:
			best_dist = dist
			best_obj = body

	hovered_object = best_obj
	_set_prompt_visible(hovered_object != null)


func _grab_object(obj: PhysicsBody2D) -> void:
	held_object = obj
	hovered_object = null
	_set_prompt_visible(false)

	if held_object.has_method(&"lift"):
		held_object.lift()


func _set_prompt_visible(active: bool) -> void:
	if active:
		if not _owns_prompt or (prompt and not prompt.visible):
			_owns_prompt = true
			if prompt: prompt.show_persistent(prompt_text)
	elif _owns_prompt:
		_owns_prompt = false
		if prompt: prompt.hide_prompt()

#endregion
