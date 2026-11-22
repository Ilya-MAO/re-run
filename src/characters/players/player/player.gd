class_name Player
extends Soul

signal coins_changed(coins: int)


@export_group("Money")
@export var coins: int = 0: set = _set_coins

@onready var telekinesis: Telekinesis = %Telekinesis
@onready var prompt: Prompt = %Prompt
@onready var alert_label: Label = %AlertLabel
@onready var item_slot: ItemSlot = %ItemSlot

var player_data: PlayerData: get = _get_player_data, set = _set_player_data
var last_move_direction: Vector2 = Vector2.DOWN


#region Coins

func add_coins(amount: int) -> void:
	coins += amount


func try_spend_coins(amount: int) -> bool:
	if coins < amount: return false
	coins -= amount
	return true

#endregion

#region Slow

var _slow_mult: float = 1.0

func slow(value: float) -> void:
	var clamped_slow = clampf(value, player_data.SLOW_RANGE.x, player_data.SLOW_RANGE.y)
	_slow_mult = minf(clamped_slow, _slow_mult)


func unslow(value: float) -> void:
	var clamped_slow = clampf(value, player_data.SLOW_RANGE.x, player_data.SLOW_RANGE.y)
	if is_equal_approx(clamped_slow, _slow_mult): _slow_mult = 1.0

#endregion

#region Prompts

var _warning_list: Array[Node]

func warning(source: Node, text: String = "!") -> void:
	if not _warning_list.has(source): _warning_list.append(source)
	alert_label.text = text
	alert_label.visible = true


func remove_warning(source: Node) -> void:
	_warning_list.erase(source)
	_warning_list = _warning_list.filter(func(n): return is_instance_valid(n))

	if _warning_list.is_empty(): alert_label.visible = false

#endregion

#region Specials

func _ready() -> void:
	super()
	add_to_group(&"Players")

func _physics_process(delta: float) -> void:
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var effective_slow: float = minf(_slow_mult, _get_ground_slow_multiplier())
	var target_velocity: Vector2 = direction * speed * effective_slow

	if direction != Vector2.ZERO:
		velocity = velocity.move_toward(target_velocity, character_data.speed_up * delta)
		animation.set("parameters/blend_position", direction * player_data.WALK_OFFSET)
		last_move_direction = direction
	else:
		velocity = velocity.move_toward(Vector2.ZERO, character_data.speed_down * delta)
		animation.set("parameters/blend_position", last_move_direction * player_data.STAND_OFFSET)

	move_and_slide()
	_handle_collisions()

#endregion

#region Helpers

func _get_ground_slow_multiplier() -> float:
	var mult: float = 1.0
	var sample_points: Array[Vector2] = _get_feet_sample_points()

	for tm_node: Node in get_tree().get_nodes_in_group(&"Tilemaps"):
		if not (tm_node is Tilemaps):
			continue

		var tm := tm_node as Tilemaps
		var layers: Array[TileMapLayer] = []
		if is_instance_valid(tm.blocks):
			layers.append(tm.blocks)
		var floor_layer := tm.get_node_or_null("Floor") as TileMapLayer
		if is_instance_valid(floor_layer):
			layers.append(floor_layer)

		for layer: TileMapLayer in layers:
			for pt: Vector2 in sample_points:
				var cell: Vector2i = layer.local_to_map(layer.to_local(pt))
				var data: TileData = layer.get_cell_tile_data(cell)
				if data and data.has_custom_data(&"slow_mult"):
					var tile_slow: float = float(data.get_custom_data(&"slow_mult"))
					if tile_slow > 0.0:
						mult = minf(mult, tile_slow)

	return mult


func _get_feet_sample_points() -> Array[Vector2]:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not shape_node:
		for child: Node in get_children():
			if child is CollisionShape2D and not child.disabled:
				shape_node = child
				break

	if shape_node and shape_node.shape:
		var rect: Rect2 = shape_node.shape.get_rect()
		var top_left: Vector2 = shape_node.to_global(rect.position)
		var bottom_right: Vector2 = shape_node.to_global(rect.end)
		return [
			top_left,
			Vector2(bottom_right.x, top_left.y),
			Vector2(top_left.x, bottom_right.y),
			bottom_right
		]

	return [
		global_position + Vector2(-5.0, -5.0),
		global_position + Vector2( 5.0, -5.0),
		global_position + Vector2(-5.0,  5.0),
		global_position + Vector2( 5.0,  5.0)
	]


func _handle_collisions() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()

		if collider is RigidBody2D:
			collider.apply_central_impulse(-collision.get_normal() * player_data.push_force)
		elif collider is TileMapLayer:
			_check_tile_damage(collider, collision)

func _check_tile_damage(tilemap: TileMapLayer, collision: KinematicCollision2D) -> void:
	var hit_pos: Vector2 = collision.get_position() - collision.get_normal() * 4.0
	var cell: Vector2i = tilemap.local_to_map(tilemap.to_local(hit_pos))
	var data: TileData = tilemap.get_cell_tile_data(cell)

	if data and data.has_custom_data(&"damage"):
		var tile_damage: int = int(data.get_custom_data(&"damage"))
		if tile_damage > 0:
			take_damage(tile_damage)

#endregion

#region Getters

func _get_player_data() -> PlayerData:
	return character_data as PlayerData

#endregion

#region Setters

func _set_coins(value: int) -> void:
	coins = clampi(value, player_data.COINS_RANGE.x, player_data.COINS_RANGE.y)
	coins_changed.emit(coins)

func _set_player_data(value: PlayerData) -> void:
	character_data = value

#endregion
