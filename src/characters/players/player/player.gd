class_name Player
extends Character

signal coins_changed(amount: int)

const STAND_OFFSET: float = 0.2
const WALK_OFFSET: float = 0.4

var last_move_direction: Vector2 = Vector2.ZERO
var _warning_sources: Array[Node] = []
var _slow_sources: Dictionary = {}

@export var max_coins: float = 200.0
@export var coins: int = 0:
	set(value):
		coins = max(0, value)
		coins_changed.emit(coins)

@export var push_force: float = 80.0

@onready var telekinesis: Telekinesis = $Telekinesis
@onready var prompt: Prompt = $Prompt
@onready var alert_label: Label = $AlertLabel

func _physics_process(_delta: float) -> void:
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * (speed * _get_speed_multiplier())
	
	if direction != Vector2.ZERO:
		animation_tree.set("parameters/blend_position", direction * WALK_OFFSET)
		last_move_direction = direction
	else:
		animation_tree.set("parameters/blend_position", last_move_direction * STAND_OFFSET)

	move_and_slide()
	_apply_rigidbody_push()

func _apply_rigidbody_push() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is RigidBody2D:
			collider.apply_central_impulse(-collision.get_normal() * push_force)

func add_slow_source(source: Object, multiplier: float) -> void:
	_slow_sources[source] = multiplier

func remove_slow_source(source: Object) -> void:
	_slow_sources.erase(source)

func _get_speed_multiplier() -> float:
	var mult := 1.0
	for source in _slow_sources.keys():
		if is_instance_valid(source):
			mult = minf(mult, _slow_sources[source])
		else:
			_slow_sources.erase(source)
	return mult

func add_trap_warning(source: Node, symbol: String = "!") -> void:
	if not _warning_sources.has(source):
		_warning_sources.append(source)
	if alert_label:
		alert_label.text = symbol
		alert_label.visible = true

func remove_trap_warning(source: Node) -> void:
	_warning_sources.erase(source)
	_warning_sources = _warning_sources.filter(func(n): return is_instance_valid(n))

	if _warning_sources.is_empty() and alert_label:
		alert_label.visible = false

func addCoins(amount: int) -> void:
	coins += clamp(coins + amount, 0, max_coins)
	coins_changed.emit(coins)

func spendCoins(amount: int) -> bool:
	if coins < amount: return false

	coins -= amount
	coins_changed.emit(coins)
	return true
