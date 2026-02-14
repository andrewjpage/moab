extends TestBase


func test_init_fog_all_unseen() -> void:
	set_test_name("test_init_fog_all_unseen")
	var state := TestBase.create_test_state()
	var fog := FogSystem.new()
	fog.init_fog(state)
	# All tiles should be UNSEEN initially
	for y in range(state.map_height):
		for x in range(state.map_width):
			assert_eq(fog.get_visibility(0, x, y), FogSystem.UNSEEN, "tile (%d,%d) should be UNSEEN" % [x, y])
			assert_eq(fog.get_visibility(1, x, y), FogSystem.UNSEEN, "tile (%d,%d) should be UNSEEN for p1" % [x, y])


func test_recompute_vision_from_unit() -> void:
	set_test_name("test_recompute_vision_from_unit")
	var state := TestBase.create_test_state()
	var fog := FogSystem.new()
	fog.init_fog(state)
	fog.recompute_vision(state, 0)
	# Infantry at (1,1) has vision=2 (Chebyshev). Tiles within Chebyshev distance 2 should be VISIBLE
	assert_eq(fog.get_visibility(0, 1, 1), FogSystem.VISIBLE, "unit position should be visible")
	assert_eq(fog.get_visibility(0, 2, 2), FogSystem.VISIBLE, "Chebyshev dist 1 should be visible")
	assert_eq(fog.get_visibility(0, 3, 3), FogSystem.VISIBLE, "Chebyshev dist 2 should be visible")
	# Far corner should still be unseen
	assert_eq(fog.get_visibility(0, 8, 8), FogSystem.UNSEEN, "far tile should be unseen")


func test_recompute_vision_from_city() -> void:
	set_test_name("test_recompute_vision_from_city")
	var state := TestBase.create_test_state()
	var fog := FogSystem.new()
	fog.init_fog(state)
	# Remove all player 0 units so only city provides vision
	var p0_units := state.get_player_units(0)
	for u in p0_units:
		state.remove_unit(u["id"])
	fog.recompute_vision(state, 0)
	# City at (1,1) gives radius 2 vision
	assert_eq(fog.get_visibility(0, 1, 1), FogSystem.VISIBLE, "city tile should be visible")
	assert_eq(fog.get_visibility(0, 2, 2), FogSystem.VISIBLE, "Chebyshev dist 1 from city")
	assert_eq(fog.get_visibility(0, 3, 3), FogSystem.VISIBLE, "Chebyshev dist 2 from city")
	assert_ne(fog.get_visibility(0, 4, 4), FogSystem.VISIBLE, "Chebyshev dist 3 should not be visible from city")


func test_vision_downgrade() -> void:
	set_test_name("test_vision_downgrade")
	var state := TestBase.create_test_state()
	var fog := FogSystem.new()
	fog.init_fog(state)
	fog.recompute_vision(state, 0)
	# Tile (2,1) should be VISIBLE now (within vision of unit at (1,1))
	assert_eq(fog.get_visibility(0, 2, 1), FogSystem.VISIBLE)

	# Move unit far away, recompute
	state.units[0]["x"] = 7
	state.units[0]["y"] = 7
	fog.recompute_vision(state, 0)
	# (2,1) should now be SEEN_NOT_VISIBLE (was visible before, now not)
	# But city at (1,1) still provides vision, so (2,1) might still be visible
	# Let's check a tile that's only visible by unit, not by city
	# Actually (2,1) is within city (1,1) range of 2, so check (4,1) which was previously unseen
	# Let's test (3,3) which was visible before (within Chebyshev 2 of (1,1))
	# Still within city range. Test with a tile that was in unit range but not city range
	# City at (1,1), radius 2 = Chebyshev. Max reachable: (3,3)
	# Unit was at (1,1) with vision 2 too. They overlap.
	# After moving to (7,7), tile (3,3) is within city range still.
	# Move the city owner to -1 to isolate unit vision effect
	state.cities[0]["owner"] = -1
	fog.recompute_vision(state, 0)
	# Now (2,1) was VISIBLE from city, now city is not owned -> should be SEEN_NOT_VISIBLE
	assert_eq(fog.get_visibility(0, 2, 1), FogSystem.SEEN_NOT_VISIBLE, "previously visible tile should be SEEN_NOT_VISIBLE")


func test_out_of_bounds_returns_unseen() -> void:
	set_test_name("test_out_of_bounds_returns_unseen")
	var state := TestBase.create_test_state()
	var fog := FogSystem.new()
	fog.init_fog(state)
	assert_eq(fog.get_visibility(0, -1, 0), FogSystem.UNSEEN)
	assert_eq(fog.get_visibility(0, 0, -1), FogSystem.UNSEEN)
	assert_eq(fog.get_visibility(0, 100, 0), FogSystem.UNSEEN)


func test_unknown_player_returns_unseen() -> void:
	set_test_name("test_unknown_player_returns_unseen")
	var state := TestBase.create_test_state()
	var fog := FogSystem.new()
	fog.init_fog(state)
	assert_eq(fog.get_visibility(99, 5, 5), FogSystem.UNSEEN)


func test_serialize_deserialize() -> void:
	set_test_name("test_serialize_deserialize")
	var state := TestBase.create_test_state()
	var fog := FogSystem.new()
	fog.init_fog(state)
	fog.recompute_vision(state, 0)
	var data := fog.serialize()
	var fog2 := FogSystem.new()
	fog2.deserialize(data)
	# Compare visibility for player 0
	for y in range(state.map_height):
		for x in range(state.map_width):
			assert_eq(fog2.get_visibility(0, x, y), fog.get_visibility(0, x, y),
				"visibility mismatch at (%d,%d)" % [x, y])


func test_is_visible_helper() -> void:
	set_test_name("test_is_visible_helper")
	var state := TestBase.create_test_state()
	var fog := FogSystem.new()
	fog.init_fog(state)
	fog.recompute_vision(state, 0)
	assert_true(fog.is_visible(0, 1, 1), "unit position should be visible")
	assert_false(fog.is_visible(0, 8, 8), "far tile should not be visible")
