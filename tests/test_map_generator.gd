extends TestBase


func test_generate_map_dimensions() -> void:
	set_test_name("test_generate_map_dimensions")
	var mg := MapGenerator.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 100
	var data := mg.generate_map(20, 20, rng)
	assert_eq(data["width"], 20)
	assert_eq(data["height"], 20)
	assert_eq(data["terrain"].size(), 20, "should have 20 rows")
	assert_eq(data["terrain"][0].size(), 20, "each row should have 20 cols")


func test_generate_map_has_cities() -> void:
	set_test_name("test_generate_map_has_cities")
	var mg := MapGenerator.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 100
	var data := mg.generate_map(30, 30, rng)
	assert_gt(data["cities"].size(), 0, "should have at least one city")


func test_generate_map_has_owned_cities() -> void:
	set_test_name("test_generate_map_has_owned_cities")
	var mg := MapGenerator.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 100
	var data := mg.generate_map(30, 30, rng)
	var has_p0 := false
	var has_p1 := false
	for c in data["cities"]:
		if c["owner"] == 0:
			has_p0 = true
		if c["owner"] == 1:
			has_p1 = true
	assert_true(has_p0, "should have player 0 city")
	assert_true(has_p1, "should have player 1 city")


func test_generate_map_has_starting_units() -> void:
	set_test_name("test_generate_map_has_starting_units")
	var mg := MapGenerator.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 100
	var data := mg.generate_map(30, 30, rng)
	assert_eq(data["starting_units"].size(), 2, "should have 2 starting units")


func test_deterministic_same_seed() -> void:
	set_test_name("test_deterministic_same_seed")
	var mg := MapGenerator.new()
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 42
	var data1 := mg.generate_map(20, 20, rng1)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 42
	var data2 := mg.generate_map(20, 20, rng2)
	assert_eq(data1["terrain"], data2["terrain"], "same seed should produce same terrain")
	assert_eq(data1["cities"].size(), data2["cities"].size(), "same seed should produce same cities count")


func test_different_seeds_produce_different_maps() -> void:
	set_test_name("test_different_seeds_produce_different_maps")
	var mg := MapGenerator.new()
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 42
	var data1 := mg.generate_map(20, 20, rng1)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 999
	var data2 := mg.generate_map(20, 20, rng2)
	assert_ne(data1["terrain"], data2["terrain"], "different seeds should produce different terrain")


func test_has_land_tiles() -> void:
	set_test_name("test_has_land_tiles")
	var mg := MapGenerator.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 100
	var data := mg.generate_map(30, 30, rng)
	var land_count := 0
	for row in data["terrain"]:
		for t in row:
			if t == GameState.Terrain.LAND or t == GameState.Terrain.MOUNTAIN:
				land_count += 1
	assert_gt(land_count, 0, "should have land tiles")


func test_city_positions_have_city_terrain() -> void:
	set_test_name("test_city_positions_have_city_terrain")
	var mg := MapGenerator.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 100
	var data := mg.generate_map(30, 30, rng)
	for city in data["cities"]:
		var x: int = city["x"]
		var y: int = city["y"]
		assert_eq(data["terrain"][y][x], GameState.Terrain.CITY,
			"city at (%d,%d) should have CITY terrain" % [x, y])


func test_load_map_from_json() -> void:
	set_test_name("test_load_map_from_json")
	var mg := MapGenerator.new()
	var data := mg.load_map_from_json("res://data/maps/sample_map.json")
	assert_true(data.has("width"), "loaded map should have width")
	assert_true(data.has("height"), "loaded map should have height")
	assert_true(data.has("terrain"), "loaded map should have terrain")
	assert_true(data.has("cities"), "loaded map should have cities")
	assert_gt(data["cities"].size(), 0, "loaded map should have cities")


func test_load_map_from_json_missing_file_returns_empty() -> void:
	set_test_name("test_load_map_from_json_missing_file_returns_empty")
	var mg := MapGenerator.new()
	var data := mg.load_map_from_json("res://data/maps/does_not_exist.json")
	assert_true(data.is_empty(), "missing file should return empty dictionary")


func test_load_map_from_json_rejects_non_dictionary_root() -> void:
	set_test_name("test_load_map_from_json_rejects_non_dictionary_root")
	var mg := MapGenerator.new()
	var temp_path := "user://map_invalid_root.json"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	assert_not_null(file, "temp map should be writable")
	if file == null:
		return
	file.store_string("[1,2,3]")
	file.close()

	var data := mg.load_map_from_json(temp_path)
	assert_true(data.is_empty(), "array root should be rejected")
	DirAccess.remove_absolute(temp_path)
