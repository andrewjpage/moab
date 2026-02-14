extends TestBase


func _create_state_and_fog() -> Array:
	var state := TestBase.create_test_state()
	var fog := FogSystem.new()
	fog.init_fog(state)
	return [state, fog]


func test_start_turn_refreshes_mp() -> void:
	set_test_name("test_start_turn_refreshes_mp")
	var arr := _create_state_and_fog()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	var ts := TurnSystem.new()
	# Deplete MP first
	var unit = state.units[0]
	unit["mp_remaining"] = 0
	unit["has_acted"] = true
	ts.start_turn(state, fog)
	var def := state.get_unit_def(unit["type"])
	assert_eq(unit["mp_remaining"], int(def["mp"]), "MP should be refreshed")
	assert_false(unit["has_acted"], "has_acted should be reset")


func test_start_turn_refuels_air_at_friendly_city() -> void:
	set_test_name("test_start_turn_refuels_air_at_friendly_city")
	var arr := _create_state_and_fog()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	var ts := TurnSystem.new()
	# Place air unit at player 0's city (1,1)
	var air := state.add_unit("interceptor", 0, 1, 1)
	air["fuel_remaining"] = 3
	ts.start_turn(state, fog)
	var def := state.get_unit_def("interceptor")
	assert_eq(air["fuel_remaining"], def["fuel"], "should be fully refueled at own city")


func test_start_turn_no_refuel_at_enemy_city() -> void:
	set_test_name("test_start_turn_no_refuel_at_enemy_city")
	var arr := _create_state_and_fog()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	var ts := TurnSystem.new()
	# Place air unit at player 1's city (8,8) but owned by player 0
	var air := state.add_unit("interceptor", 0, 8, 8)
	air["fuel_remaining"] = 3
	ts.start_turn(state, fog)
	# City at (8,8) is owned by player 1, so no refuel
	assert_eq(air["fuel_remaining"], 3, "should NOT refuel at enemy city")


func test_start_turn_city_production() -> void:
	set_test_name("test_start_turn_city_production")
	var arr := _create_state_and_fog()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	var ts := TurnSystem.new()
	# Set city production to infantry with 1 day left
	var city = state.cities[0]
	city["production_queue"] = "infantry"
	city["production_days_left"] = 1
	var units_before := state.units.size()
	var events := ts.start_turn(state, fog)
	assert_gt(state.units.size(), units_before, "should spawn a unit")
	var has_spawn_event := false
	for e in events:
		if e["type"] == "unit_spawned":
			has_spawn_event = true
	assert_true(has_spawn_event, "should have unit_spawned event")
	assert_eq(city["production_queue"], "", "queue should be cleared after spawn")


func test_start_turn_production_ticks_down() -> void:
	set_test_name("test_start_turn_production_ticks_down")
	var arr := _create_state_and_fog()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	var ts := TurnSystem.new()
	var city = state.cities[0]
	city["production_queue"] = "infantry"
	city["production_days_left"] = 3
	ts.start_turn(state, fog)
	assert_eq(city["production_days_left"], 2, "days should tick down by 1")


func test_start_turn_repair_at_city() -> void:
	set_test_name("test_start_turn_repair_at_city")
	var arr := _create_state_and_fog()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	var ts := TurnSystem.new()
	var unit = state.units[0]  # at (1,1), city at (1,1)
	unit["hp"] = 5  # max is 10
	ts.start_turn(state, fog)
	assert_eq(unit["hp"], 7, "should repair 2 HP at friendly city")


func test_start_turn_no_over_repair() -> void:
	set_test_name("test_start_turn_no_over_repair")
	var arr := _create_state_and_fog()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	var ts := TurnSystem.new()
	var unit = state.units[0]
	unit["hp"] = 9  # max is 10
	ts.start_turn(state, fog)
	assert_eq(unit["hp"], 10, "should not exceed max HP")


func test_end_turn_advances_player() -> void:
	set_test_name("test_end_turn_advances_player")
	var arr := _create_state_and_fog()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	var ts := TurnSystem.new()
	assert_eq(state.current_player, 0)
	ts.end_turn(state, fog)
	assert_eq(state.current_player, 1)


func test_end_turn_day_advances_on_wrap() -> void:
	set_test_name("test_end_turn_day_advances_on_wrap")
	var arr := _create_state_and_fog()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	var ts := TurnSystem.new()
	state.current_player = 1
	assert_eq(state.day, 1)
	ts.end_turn(state, fog)
	assert_eq(state.current_player, 0)
	assert_eq(state.day, 2)


func test_end_turn_air_crash() -> void:
	set_test_name("test_end_turn_air_crash")
	var arr := _create_state_and_fog()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	var ts := TurnSystem.new()
	# Place interceptor with 0 fuel NOT at a friendly city
	var air := state.add_unit("interceptor", 0, 5, 5)
	air["fuel_remaining"] = 0
	var air_id: int = air["id"]
	var events := ts.end_turn(state, fog)
	# Air unit should be destroyed
	assert_null(state.get_unit_by_id(air_id), "crashed air unit should be removed")
	var has_crash := false
	for e in events:
		if e["type"] == "unit_crashed":
			has_crash = true
	assert_true(has_crash, "should have unit_crashed event")


func test_end_turn_air_no_crash_at_friendly_city() -> void:
	set_test_name("test_end_turn_air_no_crash_at_friendly_city")
	var arr := _create_state_and_fog()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	var ts := TurnSystem.new()
	# Place interceptor with 0 fuel at friendly city (1,1)
	var air := state.add_unit("interceptor", 0, 1, 1)
	air["fuel_remaining"] = 0
	var air_id: int = air["id"]
	ts.end_turn(state, fog)
	assert_not_null(state.get_unit_by_id(air_id), "air at friendly city should not crash")


func test_end_turn_victory_check() -> void:
	set_test_name("test_end_turn_victory_check")
	var arr := _create_state_and_fog()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	var ts := TurnSystem.new()
	# Give all cities to player 0 and remove player 1 units
	state.cities[1]["owner"] = 0
	var p1_units := state.get_player_units(1)
	for u in p1_units:
		state.remove_unit(u["id"])
	var events := ts.end_turn(state, fog)
	assert_true(state.game_over, "game should be over")
	assert_eq(state.winner, 0, "player 0 should win")
	var has_game_over := false
	for e in events:
		if e["type"] == "game_over":
			has_game_over = true
	assert_true(has_game_over, "should have game_over event")
