class_name FogSystem
extends RefCounted

const UNSEEN := 0
const SEEN_NOT_VISIBLE := 1
const VISIBLE := 2

# player_id -> Array[int] (one per tile, 0=UNSEEN, 1=SEEN_NOT_VISIBLE, 2=VISIBLE)
var visibility: Dictionary = {}

var _map_width: int = 0
var _map_height: int = 0


func init_fog(state: GameState) -> void:
	visibility.clear()
	_map_width = state.map_width
	_map_height = state.map_height
	for p in state.players:
		var pid: int = p["id"]
		var fog_arr: Array = []
		fog_arr.resize(state.map_width * state.map_height)
		fog_arr.fill(UNSEEN)
		visibility[pid] = fog_arr


func recompute_vision(state: GameState, player_id: int) -> void:
	if not visibility.has(player_id):
		return
	_map_width = state.map_width
	_map_height = state.map_height
	var fog_arr: Array = visibility[player_id]
	var w: int = state.map_width
	var h: int = state.map_height

	# Downgrade all VISIBLE tiles to SEEN_NOT_VISIBLE
	for i in range(fog_arr.size()):
		if fog_arr[i] == VISIBLE:
			fog_arr[i] = SEEN_NOT_VISIBLE

	# Mark tiles visible from units (Chebyshev distance <= vision radius)
	for unit in state.get_player_units(player_id):
		var def := state.get_unit_def(unit["type"])
		var vision_radius: int = int(def["vision"])
		_mark_visible(fog_arr, w, h, unit["x"], unit["y"], vision_radius)

	# Mark tiles visible from owned cities (radius 2)
	for city in state.get_player_cities(player_id):
		_mark_visible(fog_arr, w, h, city["x"], city["y"], 2)


func _mark_visible(fog_arr: Array, w: int, h: int, cx: int, cy: int, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if maxi(absi(dx), absi(dy)) > radius:
				continue
			var nx := cx + dx
			var ny := cy + dy
			if nx >= 0 and nx < w and ny >= 0 and ny < h:
				fog_arr[ny * w + nx] = VISIBLE


func get_visibility(player_id: int, x: int, y: int) -> int:
	if not visibility.has(player_id):
		return UNSEEN
	var idx := y * _map_width + x
	var fog_arr: Array = visibility[player_id]
	if idx < 0 or idx >= fog_arr.size():
		return UNSEEN
	return fog_arr[idx]


func is_visible(player_id: int, x: int, y: int) -> bool:
	return get_visibility(player_id, x, y) == VISIBLE


func serialize() -> Dictionary:
	var data: Dictionary = {
		"map_width": _map_width,
		"map_height": _map_height,
	}
	for pid in visibility:
		data[str(pid)] = visibility[pid].duplicate()
	return data


func deserialize(data: Dictionary) -> void:
	_map_width = data.get("map_width", 0)
	_map_height = data.get("map_height", 0)
	visibility.clear()
	for key in data:
		if key == "map_width" or key == "map_height":
			continue
		visibility[int(key)] = data[key]
