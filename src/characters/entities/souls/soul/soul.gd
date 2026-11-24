class_name Soul
extends Character

@export_group("Visuals")
@export var float_data: SoulData = SoulData.new()
@export var shadow_node: Node2D
@export var min_shadow_scale: float = 0.7

@export_group("Shell Identity")
@export var soul_name: String = "Невідома душа"
@export var soul_dialogue: SoulDialogue

var role: SoulRole = null
var link_id: int = -1
var link_members: Array[Soul] = []
var friends: Array[Soul] = []
var enemies: Array[Soul] = []

var _time_passed: float
var _base_shadow_scale: Vector2 = Vector2.ONE


#region Specials

func _ready() -> void:
	super._ready()
	_time_passed = randf() * TAU
	if shadow_node:
		_base_shadow_scale = shadow_node.scale


func _process(delta: float) -> void:
	_time_passed += delta
	var wave: float = sin(_time_passed * float_data.speed)
	sprite.position.y = wave * float_data.amplitude

	if shadow_node:
		var height_factor: float = (1.0 - wave) * 0.5
		var scale_multiplier: float = lerp(1.0, min_shadow_scale, height_factor)
		shadow_node.scale = _base_shadow_scale * scale_multiplier

#endregion

#region Awakening & Link Setup

func is_awakened() -> bool:
	return role != null


func can_talk() -> bool:
	return soul_dialogue != null


func get_display_name() -> String:
	if soul_dialogue and not soul_dialogue.character_name.is_empty():
		return soul_dialogue.character_name
	return soul_name


func assign_role(new_role: SoulRole, new_link_id: int) -> void:
	role = new_role
	link_id = new_link_id
	_on_role_assigned()


func setup_relationships(members: Array[Soul]) -> void:
	link_members.clear()
	friends.clear()
	enemies.clear()

	for member: Soul in members:
		if member != self and is_instance_valid(member):
			link_members.append(member)

	if not role:
		return

	var candidates: Array[Soul] = link_members.duplicate()
	candidates.shuffle()

	var friends_to_pick: int = mini(role.friends_count, candidates.size())
	for i in friends_to_pick:
		friends.append(candidates.pop_back())

	var enemies_to_pick: int = mini(role.enemies_count, candidates.size())
	for i in enemies_to_pick:
		enemies.append(candidates.pop_back())


func start_soul_dialogue(_player: Player = null) -> void:
	if not soul_dialogue:
		return

	var dialogue_ui := get_tree().get_first_node_in_group(&"Dialogue") as Dialogue
	if not dialogue_ui or dialogue_ui.is_dialogue_active():
		return

	var role_id: StringName = &""
	if role and "id" in role:
		role_id = role.id
	elif role and not role.resource_name.is_empty():
		role_id = StringName(role.resource_name)

	var raw_lines: Array[DialogueLine] = soul_dialogue.get_lines_for_role(role_id)
	if raw_lines.is_empty():
		return

	var prepared_lines: Array[DialogueLine] = []
	for raw: DialogueLine in raw_lines:
		if not raw:
			continue
		var copy := raw.duplicate() as DialogueLine
		if not copy.portrait:
			copy.portrait = soul_dialogue.default_portrait
		prepared_lines.append(copy)

	dialogue_ui.start_dialogue(prepared_lines, _build_names_map())


func _build_names_map() -> Dictionary:
	var map: Dictionary = {}
	for i in range(link_members.size()):
		if is_instance_valid(link_members[i]):
			map[str(i)] = link_members[i].get_display_name()
	for i in range(friends.size()):
		if is_instance_valid(friends[i]):
			map["friend_" + str(i)] = friends[i].get_display_name()
	for i in range(enemies.size()):
		if is_instance_valid(enemies[i]):
			map["enemy_" + str(i)] = enemies[i].get_display_name()
	return map


func _on_role_assigned() -> void:
	pass

#endregion
