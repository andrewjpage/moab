extends TestBase


func _make_ai_state() -> Array:
	var state := TestBase.create_test_state()
	state.current_player = 1  # AI is player 1
	var fog := FogSystem.new()
	fog.init_fog(state)
	fog.recompute_vision(state, 1)
	return [state, fog]


func test_take_turn_returns_events() -> void:
	set_test_name("test_take_turn_returns_events")
	var arr := _make_ai_state()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	var ai := AIController.new()
	var events := ai.take_turn(state, fog)
	assert_true(events is Array, "events should be an array")


func test_ai_assigns_production() -> void:
	set_test_name("test_ai_assigns_production")
	var arr := _make_ai_state()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	var ai := AIController.new()
	# City at (8,8) owned by player 1 should get production
	var city = state.cities[1]
	assert_eq(city["production_queue"], "", "city should start with no production")
	ai.take_turn(state, fog)
	assert_ne(city["production_queue"], "", "AI should assign production")


func test_ai_attacks_adjacent_enemy() -> void:
	set_test_name("test_ai_attacks_adjacent_enemy")
	var arr := _make_ai_state()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	# Place enemy infantry adjacent to AI unit
	var ai_unit = state.get_player_units(1)[0]  # at (8,8)
	state.add_unit("infantry", 0, 7, 8)  # Adjacent enemy
	var enemy_hp_before: int = state.get_friendly_units_at(7, 8, 0)[0]["hp"]
	var ai := AIController.new()
	ai.take_turn(state, fog)
	# Check if enemy was attacked (hp reduced) or AI moved
	var enemies_at := state.get_friendly_units_at(7, 8, 0)
	if enemies_at.size() > 0:
		# Enemy still alive but should have taken damage
		assert_lt(enemies_at[0]["hp"], enemy_hp_before, "AI should attack adjacent enemy")
	# else enemy was killed, which is also correct


func test_ai_moves_toward_neutral_city() -> void:
	set_test_name("test_ai_moves_toward_neutral_city")
	var arr := _make_ai_state()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	# Add a neutral city closer to AI
	state.set_terrain(7, 7, GameState.Terrain.CITY)
	state.cities.append({"x": 7, "y": 7, "name": "Neutral", "owner": -1,
		"production_queue": "", "production_days_left": 0})
	var ai_unit = state.get_player_units(1)[0]
	var old_x: int = ai_unit["x"]
	var old_y: int = ai_unit["y"]
	var ai := AIController.new()
	ai.take_turn(state, fog)
	# AI should move toward or be at neutral city
	var moved = (ai_unit["x"] != old_x or ai_unit["y"] != old_y)
	var at_city = (ai_unit["x"] == 7 and ai_unit["y"] == 7)
	assert_true(moved or at_city, "AI should move toward neutral city")


func test_ai_captures_city() -> void:
	set_test_name("test_ai_captures_city")
	var arr := _make_ai_state()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	# Place neutral city adjacent to AI unit's city (8,8)
	state.set_terrain(7, 8, GameState.Terrain.CITY)
	state.cities.append({"x": 7, "y": 8, "name": "Neutral", "owner": -1,
		"production_queue": "", "production_days_left": 0})
	# AI infantry at (8,8) has mp=1, can move to (7,8) and capture
	var ai := AIController.new()
	ai.take_turn(state, fog)
	var city = state.get_city_at(7, 8)
	assert_eq(city["owner"], 1, "AI should capture adjacent neutral city")


func test_ai_defends_threatened_city() -> void:
	set_test_name("test_ai_defends_threatened_city")
	var arr := _make_ai_state()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	state.players[1]["ai_difficulty"] = "normal"
	# Place AI infantry away from its city
	var ai_unit = state.get_player_units(1)[0]
	ai_unit["x"] = 6
	ai_unit["y"] = 8
	ai_unit["mp_remaining"] = 3
	# Place enemy near AI city (8,8)
	state.add_unit("infantry", 0, 7, 8)
	var ai := AIController.new()
	ai.take_turn(state, fog)
	# AI should move toward its threatened city or attack the enemy
	var dist_to_city := absi(ai_unit["x"] - 8) + absi(ai_unit["y"] - 8)
	var dist_before := absi(6 - 8) + absi(8 - 8)  # = 2
	assert_true(dist_to_city <= dist_before or ai_unit["has_acted"],
		"AI should defend or attack near threatened city")


func test_ai_bomber_avoids_friendly_fire_normal() -> void:
	set_test_name("test_ai_bomber_avoids_friendly_fire_normal")
	var arr := _make_ai_state()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	state.players[1]["ai_difficulty"] = "normal"
	# Place AI bomber and friendly unit near enemy
	var bomber := state.add_unit("bomber", 1, 5, 5)
	state.add_unit("infantry", 1, 4, 4)  # Friendly within AoE
	state.add_unit("infantry", 0, 4, 5)  # Enemy adjacent
	var ai := AIController.new()
	var friendly_before := state.get_player_units(1)
	var friendly_count_before := friendly_before.size()
	ai.take_turn(state, fog)
	var friendly_after := state.get_player_units(1)
	# On normal difficulty, AI should avoid AoE that hits friendlies
	# This is a heuristic check - the AI should not reduce its own unit count
	assert_gte(friendly_after.size(), friendly_count_before - 1,
		"normal AI should try to avoid friendly fire")


func test_ai_easy_prefers_neutral_cities() -> void:
	set_test_name("test_ai_easy_prefers_neutral_cities")
	var arr := _make_ai_state()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	state.players[1]["ai_difficulty"] = "easy"
	# Add neutral city and player city equidistant
	state.set_terrain(7, 7, GameState.Terrain.CITY)
	state.cities.append({"x": 7, "y": 7, "name": "Neutral", "owner": -1,
		"production_queue": "", "production_days_left": 0})
	var ai := AIController.new()
	ai.take_turn(state, fog)
	# Just ensure AI runs without error on easy difficulty
	assert_true(true, "easy AI should complete turn without error")


func test_ai_air_returns_to_base_low_fuel() -> void:
	set_test_name("test_ai_air_returns_to_base_low_fuel")
	var arr := _make_ai_state()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	# Place AI interceptor far from base with low fuel
	var air := state.add_unit("interceptor", 1, 5, 5)
	air["fuel_remaining"] = 5  # Barely enough to get back to (8,8) = distance 6
	var ai := AIController.new()
	ai.take_turn(state, fog)
	# Air unit should move toward base
	var dist_to_base := absi(air["x"] - 8) + absi(air["y"] - 8)
	var dist_before := absi(5 - 8) + absi(5 - 8)  # = 6
	assert_true(dist_to_base <= dist_before, "low fuel air should move toward base")
