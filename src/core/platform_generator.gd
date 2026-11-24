class_name PlatformGenerator
extends Node2D

const TILE_SIZE: float = 32.0
const PLATFORM_SIZE: Vector2 = Vector2(624.0, 352.0)
const PLATFORM_GAP: Vector2 = Vector2.ONE * (3.0 * TILE_SIZE)
const PLATFORM_STEP: Vector2 = PLATFORM_SIZE + PLATFORM_GAP
const ENTRY_OFFSET_X: float = 2.5 * TILE_SIZE
const ENTRY_OFFSET_UP: float = 3.5 * TILE_SIZE
const ENTRY_OFFSET_DOWN: float = 2.0 * TILE_SIZE
const GRID_SIZE: int = 9
const LINKS_PER_FLOOR: int = 3

@export var hud_scene: PackedScene
@export var player_scene: PackedScene
@export_dir var platforms_dir: String = "res://platforms"
@export var platform_subfolders: Array[String] = ["dark", "light", "start"]
@export_dir var soul_links_dir: String = "res://resources/soul_links"

var player: Player
var platforms: Dictionary = {}
var floor_plan: Dictionary = {}
var coords: Vector2i = Vector2i.ZERO
var active_links: Array[Dictionary] = []
var has_active_world: bool = false

var _pools: Dictionary = {}
var _soul_links_pool: Array[SoulLink] = []
var _minimap: Minimap
var _hud: Node

func has_saved_world() -> bool:
	return has_active_world


func start_new_world() -> void:
	_clear_all_nodes()
	_generate_floor_plan()
	_build_floor()
	has_active_world = true
	_set_active(true)


func continue_last_world() -> void:
	if not has_active_world or platforms.is_empty():
		start_new_world()
		return
	_set_active(true)


func stop_generation() -> void:
	_set_active(false)


func spawn_platform_at(p_coords: Vector2i) -> void:
	if platforms.has(p_coords) or not floor_plan.has(p_coords):
		return
	var info: Dictionary = floor_plan[p_coords]
	var pool: Array = _pools[info["type"]]
	if pool.is_empty():
		return

	var valid_dirs: Array[Vector2i] = []
	var is_dark := _is_dark_type(info["type"])
	for dir: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var n_coords: Vector2i = p_coords + dir
		if floor_plan.has(n_coords) and not (is_dark and _is_dark_type(floor_plan[n_coords]["type"])):
			valid_dirs.append(dir)

	var platform := (pool.pick_random() as PackedScene).instantiate() as Platform
	platform.setup(p_coords, info["mirror_x"], valid_dirs)
	platform.next_platform_requested.connect(_on_next_platform_requested.bind(p_coords))
	platforms[p_coords] = platform
	add_child(platform)
	move_child(platform, 0)

	var offset: Vector2 = Vector2(p_coords) * PLATFORM_STEP
	for child in platform.get_children():
		if child is Node2D:
			child.position += offset

#region Helpers

func _set_active(enabled: bool) -> void:
	visible = enabled
	process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	set_process(enabled)
	set_physics_process(enabled)
	_set_hud_visible(enabled)

	if is_instance_valid(player):
		player.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED

	for p_coords: Vector2i in platforms.keys():
		var platform: Platform = platforms[p_coords]
		if is_instance_valid(platform):
			platform.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED


func _set_hud_visible(enabled: bool) -> void:
	if not is_instance_valid(_hud):
		return
	if _hud is CanvasLayer:
		(_hud as CanvasLayer).visible = enabled
	elif _hud is CanvasItem:
		(_hud as CanvasItem).visible = enabled


func _clear_hud() -> void:
	if is_instance_valid(_hud):
		if _hud.get_parent():
			_hud.get_parent().remove_child(_hud)
		_hud.queue_free()
	_hud = null
	_minimap = null


func _clear_all_nodes() -> void:
	_clear_hud()
	if is_instance_valid(player):
		if player.is_in_group(&"Players"):
			player.remove_from_group(&"Players")
		if player.get_parent():
			player.get_parent().remove_child(player)
		player.queue_free()
	player = null

	for child in get_children():
		if is_instance_valid(child):
			child.queue_free()
	platforms.clear()
	floor_plan.clear()
	active_links.clear()


func _build_floor() -> void:
	for p_coords: Vector2i in floor_plan.keys():
		spawn_platform_at(p_coords)
	_spawn_soul_links()
	_spawn_player()
	_spawn_hud()
	_update_camera_limits(coords)


func _spawn_player() -> void:
	player = player_scene.instantiate() as Player
	if not player.is_in_group(&"Players"):
		player.add_to_group(&"Players")
	player.global_position = Vector2(coords) * PLATFORM_STEP + PLATFORM_SIZE / 2.0
	add_child(player)


func _spawn_hud() -> void:
	_clear_hud()
	if not hud_scene:
		return
	_hud = hud_scene.instantiate()
	add_child(_hud)
	_set_hud_visible(visible)
	_bind_hud_to_player(player)
	_minimap = _hud.find_child("Minimap", true, false) as Minimap
	if _minimap:
		_minimap.setup_map(Vector2i(GRID_SIZE, GRID_SIZE), platforms)
		_minimap.set_current_platform(coords)


func _bind_hud_to_player(target_player: Player) -> void:
	if not is_instance_valid(_hud) or not is_instance_valid(target_player):
		return
	if _hud.has_method("bind_player"):
		_hud.call("bind_player", target_player)
	for node in _hud.find_children("*", "", true, false):
		if node.has_method("bind_player"):
			node.call("bind_player", target_player)


func _build_pools() -> void:
	for t in Platform.Type.values():
		_pools[t] = []
	for folder: String in platform_subfolders:
		var path := platforms_dir.path_join(folder)
		var dir := DirAccess.open(path)
		if not dir:
			continue
		for f: String in dir.get_files():
			var clean := f.trim_suffix(".remap")
			if not clean.ends_with(".tscn") or clean.begins_with("_"):
				continue
			var scene := load(path.path_join(clean)) as PackedScene
			if scene:
				var temp := scene.instantiate() as Platform
				if temp:
					_pools[temp.type].append(scene)
					temp.free()


func _load_soul_links() -> void:
	_soul_links_pool.clear()
	var dir := DirAccess.open(soul_links_dir)
	if not dir:
		return
	for f: String in dir.get_files():
		var clean := f.trim_suffix(".remap")
		if (not clean.ends_with(".tres") and not clean.ends_with(".res")) or clean.begins_with("_"):
			continue
		var res := load(soul_links_dir.path_join(clean)) as SoulLink
		if res and res.is_valid():
			_soul_links_pool.append(res)


func _generate_floor_plan() -> void:
	floor_plan.clear()
	var center: int = GRID_SIZE / 2
	var ring: Array[Vector2i] = []
	for y in range(1, GRID_SIZE - 1):
		for x in range(1, GRID_SIZE - 1):
			if maxi(absi(x - center), absi(y - center)) >= 2:
				ring.append(Vector2i(x, y))

	var start_coords: Vector2i = ring.pick_random()
	coords = start_coords
	floor_plan[start_coords] = { "type": Platform.Type.START, "mirror_x": false }

	for y in range(1, GRID_SIZE - 1):
		for x in range(1, GRID_SIZE - 1):
			var cell := Vector2i(x, y)
			if cell == start_coords:
				continue
			var dist: int = maxi(absi(x - center), absi(y - center))
			var chance: float = 1.0 if dist > 1 else (0.75 if (x == center or y == center) else 0.50) if dist == 1 else 0.25
			if randf() > chance:
				continue
			var manhattan: int = absi(x - start_coords.x) + absi(y - start_coords.y)
			var p_type := Platform.Type.LIGHT_ACTIVE if (manhattan % 2 == 1) else Platform.Type.LIGHT_PASSIVE
			floor_plan[cell] = { "type": p_type, "mirror_x": false }

	for i in range(1, GRID_SIZE - 1):
		if floor_plan.has(Vector2i(i, 1)):
			floor_plan[Vector2i(i, 0)] = { "type": Platform.Type.DARK_UP, "mirror_x": false }
		if floor_plan.has(Vector2i(i, GRID_SIZE - 2)):
			floor_plan[Vector2i(i, GRID_SIZE - 1)] = { "type": Platform.Type.DARK_DOWN, "mirror_x": false }
		if floor_plan.has(Vector2i(1, i)):
			floor_plan[Vector2i(0, i)] = { "type": Platform.Type.DARK_SIDE, "mirror_x": false }
		if floor_plan.has(Vector2i(GRID_SIZE - 2, i)):
			floor_plan[Vector2i(GRID_SIZE - 1, i)] = { "type": Platform.Type.DARK_SIDE, "mirror_x": true }


func _spawn_soul_links() -> void:
	active_links.clear()
	if _soul_links_pool.is_empty():
		return
	var available: Array[Platform] = []
	for p_coords: Vector2i in platforms.keys():
		if p_coords != coords and is_instance_valid(platforms[p_coords]) and platforms[p_coords].can_spawn_soul():
			available.append(platforms[p_coords])
	available.shuffle()

	for link_idx in LINKS_PER_FLOOR:
		if available.is_empty():
			break
		var link_res: SoulLink = _soul_links_pool.pick_random()
		var link_souls: Array[Soul] = []
		for role: SoulRole in link_res.roles:
			if available.is_empty():
				break
			var spawned: Soul = available.pop_back().spawn_soul(role, link_idx)
			if spawned:
				link_souls.append(spawned)
		for soul: Soul in link_souls:
			soul.setup_relationships(link_souls)
		if not link_souls.is_empty():
			active_links.append({ "id": link_idx, "resource": link_res, "souls": link_souls })


func _update_camera_limits(p_coords: Vector2i) -> void:
	var camera := player.get_node_or_null("Camera") as Camera2D
	if not camera:
		return
	var top_left: Vector2i = Vector2i(Vector2(p_coords) * PLATFORM_STEP)
	var bottom_right: Vector2i = top_left + Vector2i(PLATFORM_SIZE)
	var view_size: Vector2 = get_viewport_rect().size / camera.zoom
	if view_size.x > PLATFORM_SIZE.x:
		var pad_x: int = int(round((view_size.x - PLATFORM_SIZE.x) / 2.0))
		top_left.x -= pad_x
		bottom_right.x += pad_x
	camera.limit_left = top_left.x
	camera.limit_top = top_left.y
	camera.limit_right = bottom_right.x
	camera.limit_bottom = bottom_right.y
	camera.reset_smoothing()
	camera.force_update_scroll()


func _is_dark_type(t: Platform.Type) -> bool:
	return t == Platform.Type.DARK_UP or t == Platform.Type.DARK_DOWN or t == Platform.Type.DARK_SIDE


func _on_next_platform_requested(direction: Vector2, current_coords: Vector2i) -> void:
	var new_coords: Vector2i = current_coords + Vector2i(direction)
	if not floor_plan.has(new_coords):
		return
	var origin: Vector2 = Vector2(new_coords) * PLATFORM_STEP
	var center: Vector2 = origin + PLATFORM_SIZE / 2.0
	if direction.x != 0.0:
		player.global_position.x = center.x - direction.x * (PLATFORM_SIZE.x / 2.0 - ENTRY_OFFSET_X)
	elif direction.y < 0.0:
		player.global_position.y = (origin.y + PLATFORM_SIZE.y) - ENTRY_OFFSET_UP
	elif direction.y > 0.0:
		player.global_position.y = origin.y + ENTRY_OFFSET_DOWN
	coords = new_coords
	if _minimap:
		_minimap.set_current_platform(coords)
	_update_camera_limits(coords)

#endregion

#region Specials

func _ready() -> void:
	_build_pools()
	_load_soul_links()
	has_active_world = false
	stop_generation()

#endregion
