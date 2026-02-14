class_name GameState
extends RefCounted

# Terrain constants
enum Terrain { SEA = 0, LAND = 1, MOUNTAIN = 2, CITY = 3 }

# Map data
var map_width: int = 30
var map_height: int = 30
var terrain: Array = []  # Flat array, index = y * width + x

# Game entities
var cities: Array = []   # Array of city dicts
var units: Array = []    # Array of unit dicts
var next_unit_id: int = 1

# Players
var players: Array = []  # [{id, is_human, ai_difficulty}]
var current_player: int = 0
var day: int = 1

# RNG
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var seed_value: int = 0

# Data
var unit_defs: Dictionary = {}  # id -> unit def dict
var rules: Dictionary = {}

# Game status
var game_over: bool = false
var winner: int = -1


func _init() -> void:
	load_unit_defs()
	load_rules()


func load_unit_defs() -> void:
	var file := FileAccess.open("res://data/units.json", FileAccess.READ)
	if not file:
		push_error("Failed to load units.json")
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("Failed to parse units.json")
		return
	var arr: Array = json.data
	for u in arr:
		unit_defs[u["id"]] = u


func load_rules() -> void:
	var file := FileAccess.open("res://data/rules.json", FileAccess.READ)
	if not file:
		push_error("Failed to load rules.json")
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("Failed to parse rules.json")
		return
	rules = json.data


func init_from_map_data(map_data: Dictionary, seed_val: int) -> void:
	seed_value = seed_val
	rng.seed = seed_value
	map_width = map_data["width"]
	map_height = map_data["height"]

	# Flatten 2D terrain array
	terrain.clear()
	terrain.resize(map_width * map_height)
	var terrain_2d: Array = map_data["terrain"]
	for y in range(map_height):
		var row: Array = terrain_2d[y]
		for x in range(map_width):
			terrain[y * map_width + x] = row[x]

	# Load cities
	cities.clear()
	for c in map_data["cities"]:
		var city := {
			"x": int(c["x"]),
			"y": int(c["y"]),
			"name": c["name"],
			"owner": int(c["owner"]),
			"production_queue": "",
			"production_days_left": 0
		}
		cities.append(city)
		# Ensure terrain at city position is CITY
		set_terrain(city["x"], city["y"], Terrain.CITY)

	# Load starting units
	units.clear()
	next_unit_id = 1
	if map_data.has("starting_units"):
		for su in map_data["starting_units"]:
			add_unit(su["type"].to_lower(), int(su["owner"]), int(su["x"]), int(su["y"]))

	# Setup players
	players = [
		{"id": 0, "is_human": true, "ai_difficulty": ""},
		{"id": 1, "is_human": false, "ai_difficulty": "normal"}
	]

	game_over = false
	winner = -1
	day = 1
	current_player = 0


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < map_width and y >= 0 and y < map_height


func get_terrain(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return Terrain.SEA
	return terrain[y * map_width + x]


func set_terrain(x: int, y: int, val: int) -> void:
	if in_bounds(x, y):
		terrain[y * map_width + x] = val


func get_terrain_name(x: int, y: int) -> String:
	match get_terrain(x, y):
		Terrain.SEA: return "SEA"
		Terrain.LAND: return "LAND"
		Terrain.MOUNTAIN: return "MOUNTAIN"
		Terrain.CITY: return "CITY"
	return "UNKNOWN"


func get_city_at(x: int, y: int):
	for c in cities:
		if c["x"] == x and c["y"] == y:
			return c
	return null


func get_units_at(x: int, y: int) -> Array:
	var result: Array = []
	for u in units:
		if u["x"] == x and u["y"] == y:
			result.append(u)
	return result


func get_friendly_units_at(x: int, y: int, player_id: int) -> Array:
	var result: Array = []
	for u in units:
		if u["x"] == x and u["y"] == y and u["owner"] == player_id:
			result.append(u)
	return result


func get_enemy_units_at(x: int, y: int, player_id: int) -> Array:
	var result: Array = []
	for u in units:
		if u["x"] == x and u["y"] == y and u["owner"] != player_id:
			result.append(u)
	return result


func get_player_units(player_id: int) -> Array:
	var result: Array = []
	for u in units:
		if u["owner"] == player_id:
			result.append(u)
	return result


func get_player_cities(player_id: int) -> Array:
	var result: Array = []
	for c in cities:
		if c["owner"] == player_id:
			result.append(c)
	return result


func is_port_city(city: Dictionary) -> bool:
	var cx: int = city["x"]
	var cy: int = city["y"]
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = cx + dir.x
		var ny: int = cy + dir.y
		if in_bounds(nx, ny) and get_terrain(nx, ny) == Terrain.SEA:
			return true
	return false


func get_unit_def(type_id: String) -> Dictionary:
	if unit_defs.has(type_id):
		return unit_defs[type_id]
	return {}


func add_unit(type_id: String, owner: int, x: int, y: int) -> Dictionary:
	var def := get_unit_def(type_id)
	if def.is_empty():
		push_error("Unknown unit type: " + type_id)
		return {}
	var unit := {
		"id": next_unit_id,
		"type": type_id,
		"owner": owner,
		"x": x,
		"y": y,
		"hp": int(def["hp"]),
		"mp_remaining": int(def["mp"]),
		"fuel_remaining": def["fuel"],
		"carried_units": [],
		"is_sleeping": false,
		"has_acted": false
	}
	next_unit_id += 1
	units.append(unit)
	return unit


func remove_unit(unit_id: int) -> void:
	for i in range(units.size() - 1, -1, -1):
		if units[i]["id"] == unit_id:
			units.remove_at(i)
			return


func get_unit_by_id(unit_id: int):
	for u in units:
		if u["id"] == unit_id:
			return u
	return null


func can_unit_enter(unit: Dictionary, x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return false
	var t := get_terrain(x, y)
	var def := get_unit_def(unit["type"])
	var domain: String = def["domain"]
	match domain:
		"LAND":
			return t == Terrain.LAND or t == Terrain.MOUNTAIN or t == Terrain.CITY
		"SEA":
			return t == Terrain.SEA
		"AIR":
			return true
	return false


func get_move_cost(_unit: Dictionary, x: int, y: int) -> int:
	var t := get_terrain(x, y)
	var def := get_unit_def(_unit["type"])
	var domain: String = def["domain"]
	if domain == "LAND" and t == Terrain.MOUNTAIN:
		return 2
	return 1


func get_movement_range(unit: Dictionary) -> Array:
	var def := get_unit_def(unit["type"])
	var domain: String = def["domain"]
	var mp: int = unit["mp_remaining"]
	var start := Vector2i(unit["x"], unit["y"])

	# BFS
	var visited: Dictionary = {}
	var queue: Array = []
	queue.append({"pos": start, "cost": 0})
	visited[start] = 0
	var result: Array = []

	while queue.size() > 0:
		var current = queue.pop_front()
		var pos: Vector2i = current["pos"]
		var cost: int = current["cost"]

		if pos != start:
			result.append(pos)

		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next_pos: Vector2i = pos + dir
			if not in_bounds(next_pos.x, next_pos.y):
				continue
			if not can_unit_enter(unit, next_pos.x, next_pos.y):
				continue
			var move_cost := get_move_cost(unit, next_pos.x, next_pos.y)
			var new_cost := cost + move_cost
			if new_cost > mp:
				continue
			# Check fuel for air units
			if domain == "AIR" and unit["fuel_remaining"] != null:
				if new_cost > int(unit["fuel_remaining"]):
					continue
			# Check if enemy unit blocks (LAND/SEA only, not AIR)
			var enemies := get_enemy_units_at(next_pos.x, next_pos.y, unit["owner"])
			if enemies.size() > 0 and domain != "AIR":
				continue
			if not visited.has(next_pos) or visited[next_pos] > new_cost:
				visited[next_pos] = new_cost
				queue.append({"pos": next_pos, "cost": new_cost})

	return result


func check_victory() -> int:
	if cities.size() == 0:
		return -1

	# Check each player
	for p in players:
		var pid: int = p["id"]
		var player_cities := get_player_cities(pid)
		var player_units := get_player_units(pid)

		# Defeat: 0 cities AND 0 units
		if player_cities.size() == 0 and player_units.size() == 0:
			# The other player wins
			for op in players:
				if op["id"] != pid:
					return op["id"]

	# Victory: >= 60% of cities
	for p in players:
		var pid: int = p["id"]
		var player_cities := get_player_cities(pid)
		var pct: float = float(player_cities.size()) / float(cities.size()) * 100.0
		if pct >= rules.get("victory_city_percentage", 60):
			return pid

	return -1


func can_city_build_unit(city: Dictionary, unit_type: String) -> bool:
	var def := get_unit_def(unit_type)
	if def.is_empty():
		return false
	var domain: String = def["domain"]
	if domain == "SEA":
		return is_port_city(city)
	return true


func get_buildable_units(city: Dictionary) -> Array:
	var result: Array = []
	for uid in unit_defs:
		if can_city_build_unit(city, uid):
			result.append(unit_defs[uid])
	return result


func serialize() -> Dictionary:
	return {
		"version": 1,
		"map_width": map_width,
		"map_height": map_height,
		"terrain": terrain.duplicate(),
		"cities": cities.duplicate(true),
		"units": units.duplicate(true),
		"next_unit_id": next_unit_id,
		"players": players.duplicate(true),
		"current_player": current_player,
		"day": day,
		"seed_value": seed_value,
		"game_over": game_over,
		"winner": winner
	}


static func deserialize(data: Dictionary) -> GameState:
	var state := GameState.new()
	state.map_width = data["map_width"]
	state.map_height = data["map_height"]
	state.terrain = data["terrain"]
	state.cities = data["cities"]
	state.units = data["units"]
	state.next_unit_id = data["next_unit_id"]
	state.players = data["players"]
	state.current_player = data["current_player"]
	state.day = data["day"]
	state.seed_value = data["seed_value"]
	state.rng.seed = state.seed_value
	state.game_over = data.get("game_over", false)
	state.winner = data.get("winner", -1)
	return state
