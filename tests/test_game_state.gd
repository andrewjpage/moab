extends TestBase


func test_init_from_map_data_dimensions() -> void:
	set_test_name("test_init_from_map_data_dimensions")
	var state := TestBase.create_test_state()
	assert_eq(state.map_width, 10)
	assert_eq(state.map_height, 10)


func test_init_terrain_size() -> void:
	set_test_name("test_init_terrain_size")
	var state := TestBase.create_test_state()
	assert_eq(state.terrain.size(), 100, "terrain flat array should be 10*10=100")


func test_init_cities() -> void:
	set_test_name("test_init_cities")
	var state := TestBase.create_test_state()
	assert_eq(state.cities.size(), 2)
	assert_eq(state.cities[0]["name"], "Alpha")
	assert_eq(state.cities[0]["owner"], 0)
	assert_eq(state.cities[1]["name"], "Beta")
	assert_eq(state.cities[1]["owner"], 1)


func test_init_units() -> void:
	set_test_name("test_init_units")
	var state := TestBase.create_test_state()
	assert_eq(state.units.size(), 2)
	assert_eq(state.units[0]["type"], "infantry")
	assert_eq(state.units[1]["type"], "infantry")


func test_init_day_and_player() -> void:
	set_test_name("test_init_day_and_player")
	var state := TestBase.create_test_state()
	assert_eq(state.day, 1)
	assert_eq(state.current_player, 0)


func test_get_terrain() -> void:
	set_test_name("test_get_terrain")
	var state := TestBase.create_test_state()
	assert_eq(state.get_terrain(1, 1), GameState.Terrain.CITY)
	assert_eq(state.get_terrain(5, 5), GameState.Terrain.MOUNTAIN)
	assert_eq(state.get_terrain(3, 3), GameState.Terrain.LAND)
	assert_eq(state.get_terrain(0, 0), GameState.Terrain.SEA)


func test_set_terrain() -> void:
	set_test_name("test_set_terrain")
	var state := TestBase.create_test_state()
	state.set_terrain(3, 3, GameState.Terrain.MOUNTAIN)
	assert_eq(state.get_terrain(3, 3), GameState.Terrain.MOUNTAIN)


func test_out_of_bounds_returns_sea() -> void:
	set_test_name("test_out_of_bounds_returns_sea")
	var state := TestBase.create_test_state()
	assert_eq(state.get_terrain(-1, 0), GameState.Terrain.SEA)
	assert_eq(state.get_terrain(0, -1), GameState.Terrain.SEA)
	assert_eq(state.get_terrain(100, 0), GameState.Terrain.SEA)
	assert_eq(state.get_terrain(0, 100), GameState.Terrain.SEA)


func test_get_city_at_found() -> void:
	set_test_name("test_get_city_at_found")
	var state := TestBase.create_test_state()
	var city = state.get_city_at(1, 1)
	assert_not_null(city)
	assert_eq(city["name"], "Alpha")


func test_get_city_at_not_found() -> void:
	set_test_name("test_get_city_at_not_found")
	var state := TestBase.create_test_state()
	var city = state.get_city_at(5, 5)
	assert_null(city)


func test_add_unit() -> void:
	set_test_name("test_add_unit")
	var state := TestBase.create_test_state()
	var initial_count := state.units.size()
	var unit := state.add_unit("infantry", 0, 3, 3)
	assert_not_null(unit)
	assert_eq(state.units.size(), initial_count + 1)
	assert_eq(unit["type"], "infantry")
	assert_eq(unit["owner"], 0)
	assert_eq(unit["x"], 3)
	assert_eq(unit["y"], 3)


func test_remove_unit() -> void:
	set_test_name("test_remove_unit")
	var state := TestBase.create_test_state()
	var unit := state.add_unit("infantry", 0, 3, 3)
	var count_before := state.units.size()
	state.remove_unit(unit["id"])
	assert_eq(state.units.size(), count_before - 1)
	assert_null(state.get_unit_by_id(unit["id"]))


func test_get_unit_by_id() -> void:
	set_test_name("test_get_unit_by_id")
	var state := TestBase.create_test_state()
	var unit = state.units[0]
	var found = state.get_unit_by_id(unit["id"])
	assert_not_null(found)
	assert_eq(found["id"], unit["id"])
	assert_null(state.get_unit_by_id(9999))


func test_get_units_at() -> void:
	set_test_name("test_get_units_at")
	var state := TestBase.create_test_state()
	var units := state.get_units_at(1, 1)
	assert_eq(units.size(), 1)
	assert_eq(units[0]["owner"], 0)


func test_get_friendly_units_at() -> void:
	set_test_name("test_get_friendly_units_at")
	var state := TestBase.create_test_state()
	var friendly := state.get_friendly_units_at(1, 1, 0)
	assert_eq(friendly.size(), 1)
	var enemy := state.get_friendly_units_at(1, 1, 1)
	assert_eq(enemy.size(), 0)


func test_get_enemy_units_at() -> void:
	set_test_name("test_get_enemy_units_at")
	var state := TestBase.create_test_state()
	var enemies := state.get_enemy_units_at(1, 1, 1)
	assert_eq(enemies.size(), 1)
	var no_enemies := state.get_enemy_units_at(1, 1, 0)
	assert_eq(no_enemies.size(), 0)


func test_can_unit_enter_land() -> void:
	set_test_name("test_can_unit_enter_land")
	var state := TestBase.create_test_state()
	var unit = state.units[0]  # infantry (LAND)
	assert_true(state.can_unit_enter(unit, 3, 3), "infantry can enter LAND")
	assert_true(state.can_unit_enter(unit, 5, 5), "infantry can enter MOUNTAIN")
	assert_true(state.can_unit_enter(unit, 1, 1), "infantry can enter CITY")
	assert_false(state.can_unit_enter(unit, 0, 0), "infantry cannot enter SEA")


func test_can_unit_enter_sea() -> void:
	set_test_name("test_can_unit_enter_sea")
	var state := TestBase.create_test_state()
	var ship := state.add_unit("frigate", 0, 0, 0)
	assert_true(state.can_unit_enter(ship, 0, 0), "frigate can enter SEA")
	assert_false(state.can_unit_enter(ship, 3, 3), "frigate cannot enter LAND")


func test_can_unit_enter_air() -> void:
	set_test_name("test_can_unit_enter_air")
	var state := TestBase.create_test_state()
	var air := state.add_unit("interceptor", 0, 3, 3)
	assert_true(state.can_unit_enter(air, 0, 0), "air can enter SEA")
	assert_true(state.can_unit_enter(air, 3, 3), "air can enter LAND")
	assert_true(state.can_unit_enter(air, 5, 5), "air can enter MOUNTAIN")


func test_get_movement_range_basic() -> void:
	set_test_name("test_get_movement_range_basic")
	var state := TestBase.create_test_state()
	var unit = state.units[0]  # infantry at (1,1), mp=1
	var moves := state.get_movement_range(unit)
	assert_gt(moves.size(), 0, "should have at least one reachable tile")
	# Infantry has mp=1, so max 1 tile away (but mountains cost 2)
	for pos in moves:
		assert_true(state.in_bounds(pos.x, pos.y), "reachable tile should be in bounds")


func test_get_movement_range_mountains() -> void:
	set_test_name("test_get_movement_range_mountains")
	var state := TestBase.create_test_state()
	# Place infantry with 2mp adjacent to mountain
	var unit := state.add_unit("infantry", 0, 4, 5)
	unit["mp_remaining"] = 2
	var moves := state.get_movement_range(unit)
	# Mountain at (5,5) costs 2mp, so it should be reachable with 2mp
	assert_has(moves, Vector2i(5, 5), "should reach mountain with 2mp")


func test_get_movement_range_enemy_blocking() -> void:
	set_test_name("test_get_movement_range_enemy_blocking")
	var state := TestBase.create_test_state()
	# Place player 0 infantry at (3,3) with lots of mp
	var unit := state.add_unit("infantry", 0, 3, 3)
	unit["mp_remaining"] = 5
	# Place enemy at (4,3) blocking east
	state.add_unit("infantry", 1, 4, 3)
	var moves := state.get_movement_range(unit)
	# (4,3) should NOT be reachable (enemy blocks land units)
	var found_blocked := false
	for pos in moves:
		if pos == Vector2i(4, 3):
			found_blocked = true
	assert_false(found_blocked, "enemy tile should not be reachable for land units")


func test_get_movement_range_air_over_sea() -> void:
	set_test_name("test_get_movement_range_air_over_sea")
	var state := TestBase.create_test_state()
	var air := state.add_unit("interceptor", 0, 1, 1)
	# interceptor has mp=10, fuel=12
	var moves := state.get_movement_range(air)
	# Air units can fly over sea tiles
	var has_sea_tile := false
	for pos in moves:
		if state.get_terrain(pos.x, pos.y) == GameState.Terrain.SEA:
			has_sea_tile = true
			break
	assert_true(has_sea_tile, "air unit should be able to reach sea tiles")


func test_get_move_cost() -> void:
	set_test_name("test_get_move_cost")
	var state := TestBase.create_test_state()
	var unit = state.units[0]  # infantry
	assert_eq(state.get_move_cost(unit, 3, 3), 1, "land costs 1")
	assert_eq(state.get_move_cost(unit, 5, 5), 2, "mountain costs 2 for land")


func test_check_victory_no_winner() -> void:
	set_test_name("test_check_victory_no_winner")
	var state := TestBase.create_test_state()
	assert_eq(state.check_victory(), -1)


func test_check_victory_elimination() -> void:
	set_test_name("test_check_victory_elimination")
	var state := TestBase.create_test_state()
	# Remove all player 1 units and cities
	var p1_units := state.get_player_units(1)
	for u in p1_units:
		state.remove_unit(u["id"])
	state.cities[1]["owner"] = 0  # Take player 1's city
	assert_eq(state.check_victory(), 0, "player 0 should win by elimination")


func test_check_victory_city_percentage() -> void:
	set_test_name("test_check_victory_city_percentage")
	var state := TestBase.create_test_state()
	# Only 2 cities. Give both to player 0 = 100%
	state.cities[1]["owner"] = 0
	assert_eq(state.check_victory(), 0, "player 0 should win with 100% cities")


func test_serialize_deserialize() -> void:
	set_test_name("test_serialize_deserialize")
	var state := TestBase.create_test_state()
	state.day = 5
	state.current_player = 1
	var data := state.serialize()
	var restored := GameState.deserialize(data)
	assert_eq(restored.map_width, state.map_width)
	assert_eq(restored.map_height, state.map_height)
	assert_eq(restored.day, 5)
	assert_eq(restored.current_player, 1)
	assert_eq(restored.units.size(), state.units.size())
	assert_eq(restored.cities.size(), state.cities.size())
	assert_eq(restored.terrain.size(), state.terrain.size())


func test_is_port_city() -> void:
	set_test_name("test_is_port_city")
	var state := TestBase.create_test_state()
	# City at (1,1) - adjacent to sea at (0,1) and (1,0)
	var city = state.cities[0]
	assert_true(state.is_port_city(city), "Alpha at (1,1) is adjacent to sea")


func test_get_buildable_units() -> void:
	set_test_name("test_get_buildable_units")
	var state := TestBase.create_test_state()
	var city = state.cities[0]
	var buildable := state.get_buildable_units(city)
	assert_gt(buildable.size(), 0, "should have buildable units")
	# Port city should be able to build sea units
	var has_sea := false
	for b in buildable:
		if b["domain"] == "SEA":
			has_sea = true
	assert_true(has_sea, "port city should build sea units")
