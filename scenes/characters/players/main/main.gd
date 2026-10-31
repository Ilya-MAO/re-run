class_name MainPlayer
extends DefaultCharacter

signal coinsChanged(amount: int)

@export var maxCoins: float = 200.0
@export var coins: int = 0
@export var beam: Node2D
var lastMove: Vector2 = Vector2.ZERO
var lastFire: Vector2 = Vector2.ZERO

const STAND_OFFSET: float = 0.2
const WALK_OFFSET: float = 0.4

func _physics_process(_delta: float) -> void:
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	
	if direction != Vector2.ZERO:
		animationTree.set("parameters/blend_position", direction * WALK_OFFSET)
		lastMove = direction
	else:
		animationTree.set("parameters/blend_position", lastMove * STAND_OFFSET)

	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	var direction = Vector2.ZERO
	
	if   Input.is_action_pressed("ui_right"): lastFire = Vector2.RIGHT
	elif Input.is_action_pressed("ui_left"):  lastFire = Vector2.LEFT
	elif Input.is_action_pressed("ui_up"):    lastFire = Vector2.UP
	elif Input.is_action_pressed("ui_down"):  lastFire = Vector2.DOWN

	if   event.is_action_released("ui_right") and lastFire == Vector2.RIGHT: lastFire = Vector2.ZERO
	elif event.is_action_released("ui_left")  and lastFire == Vector2.LEFT:  lastFire = Vector2.ZERO
	elif event.is_action_released("ui_up")    and lastFire == Vector2.UP:    lastFire = Vector2.ZERO
	elif event.is_action_released("ui_down")  and lastFire == Vector2.DOWN:  lastFire = Vector2.ZERO
		
	if lastFire != Vector2.ZERO && beam:
		beam.setDirection(lastFire)

func _process(_delta: float) -> void:
	if lastFire != Vector2.ZERO:
		beam.setDirection(lastFire)

func addCoins(amount: int) -> void:
	coins += clamp(coins + amount, 0, maxCoins)
	coinsChanged.emit(coins)

func spendCoins(amount: int) -> bool:
	if coins >= amount:
		coins -= amount
		coinsChanged.emit(coins)
		return true
	return false
