extends TestBase


func test_find_path_same_tile() -> void:
	set_test_name("test_find_path_same_tile")
	var state := TestBase.create_test_state()
	var pf := Pathfinding.new()
	var unit = state.units[0]  # at (1,1)
	var path := pf.find_path(state, unit, Vector2i(1, 1), Vector2i(1, 1))
	assert_eq(path.size(), 1, "same tile path should have 1 element")
	assert_eq(path[0], Vector2i(1, 1))


func test_find_path_adjacent() -> void:
	set_test_name("test_find_path_adjacent")
	var state := TestBase.create_test_state()
	var pf := Pathfinding.new()
	var unit = state.units[0]  # infantry at (1,1)
	var path := pf.find_path(state, unit, Vector2i(1, 1), Vector2i(2, 1))
	assert_eq(path.size(), 2, "adjacent path should have 2 elements")
	assert_eq(path[0], Vector2i(1, 1))
	assert_eq(path[1], Vector2i(2, 1))


func test_find_path_longer() -> void:
	set_test_name("test_find_path_longer")
	var state := TestBase.create_test_state()
	var pf := Pathfinding.new()
	var unit = state.units[0]
	var path := pf.find_path(state, unit, Vector2i(1, 1), Vector2i(4, 1))
	assert_gt(path.size(), 2, "longer path should have more elements")
	assert_eq(path[0], Vector2i(1, 1), "should start at origin")
	assert_eq(path[path.size() - 1], Vector2i(4, 1), "should end at destination")


func test_path_around_obstacle() -> void:
	set_test_name("test_path_around_obstacle")
	var state := TestBase.create_test_state()
	# Place sea tiles blocking direct east path from (1,3)
	state.set_terrain(2, 3, GameState.Terrain.SEA)
	var pf := Pathfinding.new()
	var unit := state.add_unit("infantry", 0, 1, 3)
	var path := pf.find_path(state, unit, Vector2i(1, 3), Vector2i(3, 3))
	assert_gt(path.size(), 0, "should find a path around obstacle")
	# Make sure path doesn't go through sea
	for pos in path:
		assert_ne(state.get_terrain(pos.x, pos.y), GameState.Terrain.SEA,
			"path should not include sea tiles for infantry")


func test_impassable() -> void:
	set_test_name("test_impassable")
	var state := TestBase.create_test_state()
	# Surround tile (3,3) with sea on all sides
	state.set_terrain(2, 3, GameState.Terrain.SEA)
	state.set_terrain(4, 3, GameState.Terrain.SEA)
	state.set_terrain(3, 2, GameState.Terrain.SEA)
	state.set_terrain(3, 4, GameState.Terrain.SEA)
	# Place infantry at (3,3) - it's on land but surrounded by sea
	var unit := state.add_unit("infantry", 0, 3, 3)
	var pf := Pathfinding.new()
	var path := pf.find_path(state, unit, Vector2i(3, 3), Vector2i(5, 5))
	assert_empty(path, "should find no path when surrounded by impassable terrain")


func test_get_reachable_tiles() -> void:
	set_test_name("test_get_reachable_tiles")
	var state := TestBase.create_test_state()
	var pf := Pathfinding.new()
	var unit = state.units[0]  # infantry at (1,1), mp=1
	var reachable := pf.get_reachable_tiles(state, unit)
	assert_gt(reachable.size(), 0, "should have reachable tiles")
	# mp=1, so only tiles 1 move cost away
	for pos in reachable:
		var dx: int = absi(pos.x - 1)
		var dy: int = absi(pos.y - 1)
		assert_true(dx + dy <= 2, "tiles should be within movement range")


func test_get_reachable_tiles_mountain_cost() -> void:
	set_test_name("test_get_reachable_tiles_mountain_cost")
	var state := TestBase.create_test_state()
	var pf := Pathfinding.new()
	# Place unit with 1mp next to mountain
	var unit := state.add_unit("infantry", 0, 4, 5)
	unit["mp_remaining"] = 1
	var reachable := pf.get_reachable_tiles(state, unit)
	# Mountain at (5,5) costs 2, so not reachable with 1 mp
	var has_mountain := false
	for pos in reachable:
		if pos == Vector2i(5, 5):
			has_mountain = true
	assert_false(has_mountain, "mountain should not be reachable with 1mp")


func test_get_path_cost() -> void:
	set_test_name("test_get_path_cost")
	var state := TestBase.create_test_state()
	var pf := Pathfinding.new()
	var unit = state.units[0]
	var path := [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]
	var cost := pf.get_path_cost(state, unit, path)
	assert_eq(cost, 2, "2 steps on land should cost 2")


func test_get_path_cost_with_mountain() -> void:
	set_test_name("test_get_path_cost_with_mountain")
	var state := TestBase.create_test_state()
	var pf := Pathfinding.new()
	var unit = state.units[0]
	# Path going through mountain at (5,5)
	var path := [Vector2i(4, 5), Vector2i(5, 5)]
	var cost := pf.get_path_cost(state, unit, path)
	assert_eq(cost, 2, "mountain should cost 2 for land unit")


func test_air_path_over_sea() -> void:
	set_test_name("test_air_path_over_sea")
	var state := TestBase.create_test_state()
	var pf := Pathfinding.new()
	var air := state.add_unit("interceptor", 0, 1, 1)
	# Path from (1,1) through sea tile (0,1) to another edge
	var path := pf.find_path(state, air, Vector2i(1, 1), Vector2i(1, 0))
	assert_gt(path.size(), 0, "air should be able to path over sea")
	assert_eq(path[path.size() - 1], Vector2i(1, 0), "should reach sea tile destination")
