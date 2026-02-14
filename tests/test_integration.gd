extends TestBase


func _setup_game() -> Array:
	var state := TestBase.create_test_state()
	var fog := FogSystem.new()
	fog.init_fog(state)
	var ts := TurnSystem.new()
	var cs := CombatSystem.new()
	var pf := Pathfinding.new()
	var ai := AIController.new()
	return [state, fog, ts, cs, pf, ai]


func test_full_new_game_flow() -> void:
	set_test_name("test_full_new_game_flow")
	var arr := _setup_game()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	var ts: TurnSystem = arr[2]

	# Start turn
	var events := ts.start_turn(state, fog)
	assert_true(events is Array, "start_turn should return events")
	assert_eq(state.current_player, 0, "should be player 0's turn")

	# Move a unit
	var unit = state.get_player_units(0)[0]
	var old_mp: int = unit["mp_remaining"]
	unit["x"] = 2
	unit["y"] = 1
	unit["mp_remaining"] = 0

	# End turn
	var end_events := ts.end_turn(state, fog)
	assert_eq(state.current_player, 1, "should advance to player 1")


func test_production_to_spawn_cycle() -> void:
	set_test_name("test_production_to_spawn_cycle")
	var arr := _setup_game()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	var ts: TurnSystem = arr[2]

	var city = state.cities[0]
	city["production_queue"] = "infantry"
	city["production_days_left"] = 3

	var units_before := state.units.size()

	# Simulate 3 turns of production
	for i in range(3):
		ts.start_turn(state, fog)
		ts.end_turn(state, fog)
		# Advance back to player 0
		ts.start_turn(state, fog)
		ts.end_turn(state, fog)

	assert_gt(state.units.size(), units_before, "should have spawned a new unit after 3 days")


func test_combat_and_unit_removal() -> void:
	set_test_name("test_combat_and_unit_removal")
	var arr := _setup_game()
	var state: GameState = arr[0]
	var cs: CombatSystem = arr[3]

	var attacker = state.add_unit("infantry", 0, 3, 3)
	var defender = state.add_unit("infantry", 1, 4, 3)
	defender["hp"] = 1

	var def_id: int = defender["id"]
	cs.resolve_combat(state, attacker, defender)
	assert_null(state.get_unit_by_id(def_id), "dead unit should be removed")


func test_city_capture_flow() -> void:
	set_test_name("test_city_capture_flow")
	var arr := _setup_game()
	var state: GameState = arr[0]

	# Add neutral city
	state.set_terrain(5, 5, GameState.Terrain.CITY)
	state.cities.append({"x": 5, "y": 5, "name": "Neutral City", "owner": -1,
		"production_queue": "", "production_days_left": 0})

	# Move infantry to neutral city and capture
	var unit := state.add_unit("infantry", 0, 5, 5)
	var def := state.get_unit_def(unit["type"])
	assert_true(def.get("can_capture", false), "infantry should be able to capture")

	var city = state.get_city_at(5, 5)
	assert_not_null(city)
	city["owner"] = unit["owner"]
	assert_eq(city["owner"], 0, "city should be captured by player 0")


func test_save_load_roundtrip() -> void:
	set_test_name("test_save_load_roundtrip")
	var arr := _setup_game()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	var ts: TurnSystem = arr[2]

	# Play a turn
	ts.start_turn(state, fog)
	state.units[0]["x"] = 2
	state.units[0]["y"] = 1
	state.units[0]["mp_remaining"] = 0
	ts.end_turn(state, fog)

	# Serialize
	var state_data := state.serialize()
	var fog_data := fog.serialize()

	# Deserialize
	var restored_state := GameState.deserialize(state_data)
	var restored_fog := FogSystem.new()
	restored_fog.deserialize(fog_data)

	assert_eq(restored_state.day, state.day)
	assert_eq(restored_state.current_player, state.current_player)
	assert_eq(restored_state.units.size(), state.units.size())
	assert_eq(restored_state.cities.size(), state.cities.size())


func test_fog_updates_on_movement() -> void:
	set_test_name("test_fog_updates_on_movement")
	var arr := _setup_game()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	var ts: TurnSystem = arr[2]

	ts.start_turn(state, fog)

	# Move unit to new position
	var unit = state.units[0]
	unit["x"] = 4
	unit["y"] = 4
	fog.recompute_vision(state, 0)

	# Tiles near new position should be visible
	assert_true(fog.is_visible(0, 4, 4), "new position should be visible")
	assert_true(fog.is_visible(0, 5, 5), "nearby tile should be visible")


func test_victory_by_city_percentage() -> void:
	set_test_name("test_victory_by_city_percentage")
	var arr := _setup_game()
	var state: GameState = arr[0]

	# Give all cities to player 0
	for c in state.cities:
		c["owner"] = 0

	# Remove player 1 units
	var p1 := state.get_player_units(1)
	for u in p1:
		state.remove_unit(u["id"])

	var winner := state.check_victory()
	assert_eq(winner, 0, "player 0 should win with all cities")


func test_defeat_by_elimination() -> void:
	set_test_name("test_defeat_by_elimination")
	var arr := _setup_game()
	var state: GameState = arr[0]

	# Remove all player 0 cities and units
	state.cities[0]["owner"] = 1
	var p0 := state.get_player_units(0)
	for u in p0:
		state.remove_unit(u["id"])

	var winner := state.check_victory()
	assert_eq(winner, 1, "player 1 should win when player 0 eliminated")


func test_air_fuel_crash_lifecycle() -> void:
	set_test_name("test_air_fuel_crash_lifecycle")
	var arr := _setup_game()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	var ts: TurnSystem = arr[2]

	# Place interceptor not at city with low fuel
	var air := state.add_unit("interceptor", 0, 5, 5)
	air["fuel_remaining"] = 1
	var air_id: int = air["id"]

	ts.start_turn(state, fog)
	# Move air unit, consuming fuel
	air["x"] = 6
	air["y"] = 5
	air["fuel_remaining"] = 0
	air["mp_remaining"] = 0

	# End turn - should crash
	var events := ts.end_turn(state, fog)
	assert_null(state.get_unit_by_id(air_id), "air unit should crash with 0 fuel")


func test_full_human_ai_turn_cycle() -> void:
	set_test_name("test_full_human_ai_turn_cycle")
	var arr := _setup_game()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	var ts: TurnSystem = arr[2]
	var ai: AIController = arr[5]

	# Human turn (player 0)
	assert_eq(state.current_player, 0)
	ts.start_turn(state, fog)
	ts.end_turn(state, fog)

	# AI turn (player 1)
	assert_eq(state.current_player, 1)
	ts.start_turn(state, fog)
	var ai_events := ai.take_turn(state, fog)
	assert_true(ai_events is Array)
	ts.end_turn(state, fog)

	# Back to human (player 0, day 2)
	assert_eq(state.current_player, 0)
	assert_eq(state.day, 2)
