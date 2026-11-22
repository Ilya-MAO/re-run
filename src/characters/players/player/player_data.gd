class_name PlayerData
extends CharacterData

const STAND_OFFSET: float = 0.4 # 0.2
const WALK_OFFSET: float = 0.4
const COINS_RANGE = Vector2i(0, 999)
const SLOW_RANGE  = Vector2i(0, 1)


@export var push_force: float = 80.0
@export var throw_force: float = 200.0
