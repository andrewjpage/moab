class_name TestBase
extends RefCounted

var _failures: Array = []
var _test_name: String = ""


func set_test_name(name: String) -> void:
	_test_name = name
	_failures.clear()


func get_failures() -> Array:
	return _failures


func assert_eq(actual, expected, msg: String = "") -> void:
	if actual != expected:
		var text := _test_name + ": Expected " + str(expected) + " but got " + str(actual)
		if msg != "":
			text += " (" + msg + ")"
		_failures.append(text)


func assert_ne(actual, not_expected, msg: String = "") -> void:
	if actual == not_expected:
		var text := _test_name + ": Expected NOT " + str(not_expected) + " but got it"
		if msg != "":
			text += " (" + msg + ")"
		_failures.append(text)


func assert_true(val: bool, msg: String = "") -> void:
	if not val:
		var text := _test_name + ": Expected true but got false"
		if msg != "":
			text += " (" + msg + ")"
		_failures.append(text)


func assert_false(val: bool, msg: String = "") -> void:
	if val:
		var text := _test_name + ": Expected false but got true"
		if msg != "":
			text += " (" + msg + ")"
		_failures.append(text)


func assert_not_null(val, msg: String = "") -> void:
	if val == null:
		var text := _test_name + ": Expected non-null but got null"
		if msg != "":
			text += " (" + msg + ")"
		_failures.append(text)


func assert_null(val, msg: String = "") -> void:
	if val != null:
		var text := _test_name + ": Expected null but got " + str(val)
		if msg != "":
			text += " (" + msg + ")"
		_failures.append(text)


func assert_gt(actual, threshold, msg: String = "") -> void:
	if actual <= threshold:
		var text := _test_name + ": Expected > " + str(threshold) + " but got " + str(actual)
		if msg != "":
			text += " (" + msg + ")"
		_failures.append(text)


func assert_gte(actual, threshold, msg: String = "") -> void:
	if actual < threshold:
		var text := _test_name + ": Expected >= " + str(threshold) + " but got " + str(actual)
		if msg != "":
			text += " (" + msg + ")"
		_failures.append(text)


func assert_lt(actual, threshold, msg: String = "") -> void:
	if actual >= threshold:
		var text := _test_name + ": Expected < " + str(threshold) + " but got " + str(actual)
		if msg != "":
			text += " (" + msg + ")"
		_failures.append(text)


func assert_has(arr: Array, item, msg: String = "") -> void:
	if not arr.has(item):
		var text := _test_name + ": Array does not contain " + str(item)
		if msg != "":
			text += " (" + msg + ")"
		_failures.append(text)


func assert_empty(arr: Array, msg: String = "") -> void:
	if arr.size() > 0:
		var text := _test_name + ": Expected empty array but has " + str(arr.size()) + " elements"
		if msg != "":
			text += " (" + msg + ")"
		_failures.append(text)


func assert_not_empty(arr: Array, msg: String = "") -> void:
	if arr.size() == 0:
		var text := _test_name + ": Expected non-empty array"
		if msg != "":
			text += " (" + msg + ")"
		_failures.append(text)


# Helper: create a minimal test map (10x10, all land, 2 cities, 2 infantry)
static func create_test_map() -> Dictionary:
	var terrain_2d: Array = []
	for y in range(10):
		var row: Array = []
		for x in range(10):
			row.append(GameState.Terrain.LAND)
		terrain_2d.append(row)

	# Add some sea tiles on edges
	for x in range(10):
		terrain_2d[0][x] = GameState.Terrain.SEA
		terrain_2d[9][x] = GameState.Terrain.SEA
	for y in range(10):
		terrain_2d[y][0] = GameState.Terrain.SEA
		terrain_2d[y][9] = GameState.Terrain.SEA

	# Add a mountain
	terrain_2d[5][5] = GameState.Terrain.MOUNTAIN

	# City terrain
	terrain_2d[1][1] = GameState.Terrain.CITY
	terrain_2d[8][8] = GameState.Terrain.CITY

	var cities: Array = [
		{"x": 1, "y": 1, "name": "Alpha", "owner": 0},
		{"x": 8, "y": 8, "name": "Beta", "owner": 1}
	]

	var starting_units: Array = [
		{"type": "infantry", "x": 1, "y": 1, "owner": 0},
		{"type": "infantry", "x": 8, "y": 8, "owner": 1}
	]

	return {
		"version": 1,
		"name": "Test Map",
		"width": 10,
		"height": 10,
		"terrain": terrain_2d,
		"cities": cities,
		"starting_units": starting_units
	}


# Helper: create a GameState from the test map
static func create_test_state() -> GameState:
	var state := GameState.new()
	var map_data := create_test_map()
	state.init_from_map_data(map_data, 42)
	return state
