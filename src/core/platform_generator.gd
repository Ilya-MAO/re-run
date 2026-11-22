class_name PlatformGenerator
extends Node2D

const TILE_SIZE: float = 32.0
const PLATFORM_SIZE: Vector2 = Vector2(624.0, 352.0)
const PLATFORM_GAP: Vector2 = Vector2.ONE * (3.0 * TILE_SIZE)
const PLATFORM_STEP: Vector2 = PLATFORM_SIZE + PLATFORM_GAP

const ENTRY_OFFSET_X: float = 2.5 * TILE_SIZE
const ENTRY_OFFSET_UP: float = 3.5 * TILE_SIZE
const ENTRY_OFFSET_DOWN: float = 2.0 * TILE_SIZE

const GRID_SIZE: int = 9 # 1 outer + 2 light + 3 inner + 2 light + 1 outer

@export var hud_scene: PackedScene
@export var player_scene: PackedScene
@export_dir var platforms_dir: String = "res://platforms"
@export var platform_subfolders: Array[String] = ["dark", "light", "start"]

var player: Player
var platforms: Dictionary = {} # Vector2i -> Platform
var floor_plan: Dictionary = {} # Vector2i -> { "type": Platform.Type, "mirror_x": bool }
var coords: Vector2i = Vector2i.ZERO

var _pools: Dictionary = {} # Platform.Type -> Array[PackedScene]
var _minimap: Minimap


#region Specials

func _ready() -> void:
	_build_pools()
	_generate_floor_plan()

	for p_coords: Vector2i in floor_plan.keys():
		spawn_platform_at(p_coords)

	player = player_scene.instantiate()
	player.global_position = Vector2(coords) * PLATFORM_STEP + PLATFORM_SIZE / 2.0
	add_child(player)

	var hud := hud_scene.instantiate()
	add_child(hud)

	_minimap = hud.find_child("Minimap", true, false) as Minimap
	if _minimap:
		_minimap.setup_map(Vector2i(GRID_SIZE, GRID_SIZE), platforms)
		_minimap.set_current_platform(coords)

	_update_camera_limits(coords)

#endregion

#region Generation Logic

func _build_pools() -> void:
	for t in Platform.Type.values():
		_pools[t] = []

	for folder: String in platform_subfolders:
		var folder_path: String = platforms_dir.path_join(folder)
		var dir := DirAccess.open(folder_path)
		if not dir:
			push_warning("PlatformGenerator: не вдалося відкрити директорію %s" % folder_path)
			continue

		for file_name: String in dir.get_files():
			var clean_name: String = file_name.trim_suffix(".remap")
			if not clean_name.ends_with(".tscn"):
				continue
			# Ігноруємо базові шаблони на кшталт _light_a.tscn
			if clean_name.begins_with("_"):
				continue

			var scene := load(folder_path.path_join(clean_name)) as PackedScene
			if not scene:
				continue

			var temp := scene.instantiate() as Platform
			if temp:
				_pools[temp.type].append(scene)
				temp.free()


func _generate_floor_plan() -> void:
	floor_plan.clear()
	var center: int = GRID_SIZE / 2 # 4 для сітки 9x9

	# 1. Гарантоване світле кільце (шари 1..2 та 6..7)
	var light_ring_cells: Array[Vector2i] = []
	for y in range(1, GRID_SIZE - 1):
		for x in range(1, GRID_SIZE - 1):
			var dist_from_center: int = maxi(absi(x - center), absi(y - center))
			if dist_from_center >= 2:
				light_ring_cells.append(Vector2i(x, y))

	# 2. Випадкова стартова платформа на світлому кільці
	var start_coords: Vector2i = light_ring_cells.pick_random()
	coords = start_coords
	floor_plan[start_coords] = { "type": Platform.Type.START, "mirror_x": false }

	# 3. Заповнення світлого кільця (100%) та внутрішнього ядра 3x3 (75% -> 50% -> 25%)
	for y in range(1, GRID_SIZE - 1):
		for x in range(1, GRID_SIZE - 1):
			var cell := Vector2i(x, y)
			if cell == start_coords: continue

			var dist_from_center: int = maxi(absi(x - center), absi(y - center))
			var spawn_chance: float = 1.0
			if dist_from_center == 1:
				spawn_chance = 0.75 if (x == center or y == center) else 0.50
			elif dist_from_center == 0:
				spawn_chance = 0.25

			if randf() > spawn_chance:
				continue

			var manhattan: int = absi(x - start_coords.x) + absi(y - start_coords.y)
			var p_type := Platform.Type.LIGHT_ACTIVE if (manhattan % 2 == 1) else Platform.Type.LIGHT_PASSIVE
			floor_plan[cell] = { "type": p_type, "mirror_x": false }

	# 4. Зовнішнє кільце темних платформ (шар 0 та 8, без кутів)
	for i in range(1, GRID_SIZE - 1):
		if floor_plan.has(Vector2i(i, 1)):
			floor_plan[Vector2i(i, 0)] = { "type": Platform.Type.DARK_UP, "mirror_x": false }

		if floor_plan.has(Vector2i(i, GRID_SIZE - 2)):
			floor_plan[Vector2i(i, GRID_SIZE - 1)] = { "type": Platform.Type.DARK_DOWN, "mirror_x": false }

		if floor_plan.has(Vector2i(1, i)):
			floor_plan[Vector2i(0, i)] = { "type": Platform.Type.DARK_SIDE, "mirror_x": false }

		if floor_plan.has(Vector2i(GRID_SIZE - 2, i)):
			floor_plan[Vector2i(GRID_SIZE - 1, i)] = { "type": Platform.Type.DARK_SIDE, "mirror_x": true }


func spawn_platform_at(p_coords: Vector2i) -> void:
	if platforms.has(p_coords) or not floor_plan.has(p_coords): return

	var info: Dictionary = floor_plan[p_coords]
	var pool: Array = _pools[info["type"]]
	if pool.is_empty():
		push_warning("PlatformGenerator: порожній пул для типу %s" % Platform.Type.keys()[info["type"]])
		return

	# Визначаємо, у яких напрямках реально існують сусідні платформи
	var valid_dirs: Array[Vector2i] = []
	var is_current_dark: bool = _is_dark_type(info["type"])

	for dir: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor_coords: Vector2i = p_coords + dir
		if not floor_plan.has(neighbor_coords):
			continue

		# Темні платформи зовнішнього кільця не з'єднуються між собою (тільки зі світлими)
		if is_current_dark and _is_dark_type(floor_plan[neighbor_coords]["type"]):
			continue

		valid_dirs.append(dir)

	var scene: PackedScene = pool.pick_random()
	var platform := scene.instantiate() as Platform
	platform.setup(p_coords, info["mirror_x"], valid_dirs)
	platform.next_platform_requested.connect(_on_next_platform_requested.bind(p_coords))

	platforms[p_coords] = platform
	add_child(platform)
	move_child(platform, 0)

	# Оскільки Platform extends Node, зсуваємо дочірні Node2D у координати клітинки
	var offset: Vector2 = Vector2(p_coords) * PLATFORM_STEP
	for child in platform.get_children():
		if child is Node2D:
			child.position += offset

#endregion

#region Helpers

func _update_camera_limits(p_coords: Vector2i) -> void:
	if not player: return

	var camera := player.get_node_or_null("Camera") as Camera2D
	if not camera: return

	var top_left: Vector2i = Vector2i(Vector2(p_coords) * PLATFORM_STEP)
	var bottom_right: Vector2i = top_left + Vector2i(PLATFORM_SIZE)

	var viewport_size: Vector2 = get_viewport_rect().size / camera.zoom
	if viewport_size.x > PLATFORM_SIZE.x:
		var pad_x: int = int(round((viewport_size.x - PLATFORM_SIZE.x) / 2.0))
		top_left.x -= pad_x
		bottom_right.x += pad_x

	camera.limit_left   = top_left.x
	camera.limit_top    = top_left.y
	camera.limit_right  = bottom_right.x
	camera.limit_bottom = bottom_right.y

	camera.reset_smoothing()
	camera.force_update_scroll()


func _is_dark_type(t: Platform.Type) -> bool:
	return t == Platform.Type.DARK_UP or t == Platform.Type.DARK_DOWN or t == Platform.Type.DARK_SIDE
	

func _on_next_platform_requested(direction: Vector2, current_coords: Vector2i) -> void:
	var new_coords: Vector2i = current_coords + Vector2i(direction)
	if not floor_plan.has(new_coords):
		return

	var new_platform_origin: Vector2 = Vector2(new_coords) * PLATFORM_STEP
	var platform_center: Vector2 = new_platform_origin + PLATFORM_SIZE / 2.0

	if direction.x != 0.0:
		player.global_position.x = platform_center.x - direction.x * (PLATFORM_SIZE.x / 2.0 - ENTRY_OFFSET_X)
	elif direction.y < 0.0:
		player.global_position.y = (new_platform_origin.y + PLATFORM_SIZE.y) - ENTRY_OFFSET_UP
	elif direction.y > 0.0:
		player.global_position.y = new_platform_origin.y + ENTRY_OFFSET_DOWN

	coords = new_coords
	if _minimap:
		_minimap.set_current_platform(coords)

	_update_camera_limits(coords)

#endregion
