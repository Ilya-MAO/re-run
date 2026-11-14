class_name Telekinesis
extends Node2D

@export var interact_area: Area2D
@export var prompt: Prompt
@export var step_cooldown: float = 0.16
@export var prompt_text: String = "Press [F] to move"

var _candidates: Array[PhysicsBody2D] = []
var hovered_object: PhysicsBody2D = null
var held_object: PhysicsBody2D = null
var _step_timer: float = 0.0
var _owns_prompt: bool = false


func _ready() -> void:
	if not prompt:
		prompt = get_node_or_null("../Prompt") as Prompt
	if not interact_area:
		interact_area = get_node_or_null("../Interact") as Area2D

	if interact_area:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)


func is_active() -> bool:
	return held_object != null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("telekinesis"):
		if held_object:
			release_object()
		elif hovered_object:
			_grab_object(hovered_object)


func _physics_process(delta: float) -> void:
	if not held_object:
		return

	if not is_instance_valid(held_object):
		release_object()
		return

	if _step_timer > 0.0:
		_step_timer -= delta
		return

	var input_dir := Vector2i.ZERO
	if Input.is_action_pressed("ui_right"):
		input_dir.x = 1
	elif Input.is_action_pressed("ui_left"):
		input_dir.x = -1
	elif Input.is_action_pressed("ui_down"):
		input_dir.y = 1
	elif Input.is_action_pressed("ui_up"):
		input_dir.y = -1

	if input_dir != Vector2i.ZERO and held_object.has_method("try_move_grid"):
		if held_object.try_move_grid(input_dir, global_position, INF):
			_step_timer = step_cooldown


func _on_body_entered(body: Node2D) -> void:
	if body is PhysicsBody2D and body.is_in_group("Telekinetic"):
		if not _candidates.has(body):
			_candidates.append(body)
		_refresh_hovered()


func _on_body_exited(body: Node2D) -> void:
	if _candidates.has(body):
		_candidates.erase(body)
		_refresh_hovered()


func _refresh_hovered() -> void:
	_candidates = _candidates.filter(func(n): return is_instance_valid(n))

	if held_object or _candidates.is_empty():
		hovered_object = null
		if _owns_prompt:
			_owns_prompt = false
			if prompt:
				prompt.hide_prompt()
		return

	var best_obj: PhysicsBody2D = null
	var best_dist := INF
	for obj in _candidates:
		var dist := global_position.distance_squared_to(obj.global_position)
		if dist < best_dist:
			best_dist = dist
			best_obj = obj

	hovered_object = best_obj
	if hovered_object:
		_owns_prompt = true
		if prompt:
			prompt.show_persistent(prompt_text)


func _grab_object(obj: PhysicsBody2D) -> void:
	held_object = obj
	hovered_object = null
	if _owns_prompt:
		_owns_prompt = false
		if prompt:
			prompt.hide_prompt()

	if held_object.has_method("lift"):
		held_object.lift()


func release_object() -> void:
	if is_instance_valid(held_object) and held_object.has_method("drop"):
		held_object.drop()
	held_object = null
	_refresh_hovered()
