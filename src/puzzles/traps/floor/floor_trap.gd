class_name FloorTrap
extends Area2D

enum State { IDLE, ARMED, ACTIVE }

@onready var sprite: AnimatedSprite2D = $AnimatedSprite
@onready var delay_timer: Timer = $DelayTimer
@onready var attack_area: AttackArea = $AttackArea

var state: State = State.IDLE
var is_revealed: bool = false

func _ready() -> void:
	add_to_group("Traps")
	_set_spikes_active(false)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	delay_timer.timeout.connect(_on_delay_timeout)

func _on_body_entered(body: Node2D) -> void:
	if body is not Player:
		return

	if state == State.IDLE:
		state = State.ARMED
		if body.has_method("add_trap_warning"):
			body.add_trap_warning(self, "!")
		delay_timer.start()
	elif state == State.ACTIVE:
		delay_timer.stop()

func _on_body_exited(body: Node2D) -> void:
	if body is not Player:
		return

	if body.has_method("remove_trap_warning"):
		body.remove_trap_warning(self)

	if state == State.ACTIVE and not _has_player_inside():
		delay_timer.start()

func _on_delay_timeout() -> void:
	if state == State.ARMED:
		state = State.ACTIVE
		is_revealed = true
		_set_spikes_active(true)

		for body in get_overlapping_bodies():
			if body is Player and body.has_method("remove_trap_warning"):
				body.remove_trap_warning(self)

		if not _has_player_inside():
			delay_timer.start()

	elif state == State.ACTIVE and not _has_player_inside():
		state = State.IDLE
		_set_spikes_active(false)

func _has_player_inside() -> bool:
	for body in get_overlapping_bodies():
		if body is Player:
			return true
	return false

func reveal() -> void:
	if not is_revealed:
		is_revealed = true
		_update_visuals()

func disarm() -> void:
	queue_free()

func _set_spikes_active(active: bool) -> void:
	attack_area.set_deferred("monitoring", active)
	_update_visuals()

func _update_visuals() -> void:
	if state == State.ACTIVE:
		sprite.visible = true
		sprite.play("spikes")
	else:
		sprite.visible = is_revealed
		if is_revealed:
			sprite.play("holes")
