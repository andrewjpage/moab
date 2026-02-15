extends TestBase


func _create_state_and_fog() -> Array:
	var state := TestBase.create_test_state()
	var fog := FogSystem.new()
	fog.init_fog(state)
	fog.recompute_vision(state, 0)
	return [state, fog]


func test_save_and_load_roundtrip() -> void:
	set_test_name("test_save_and_load_roundtrip")
	var arr := _create_state_and_fog()
	var state: GameState = arr[0]
	var fog: FogSystem = arr[1]
	var ss := SaveSystem.new()

	var slot := "test_slot_roundtrip"
	assert_true(ss.save_game(state, fog, slot), "save_game should succeed")
	var loaded := ss.load_game(slot)
	assert_true(loaded.has("state_data"), "state_data should be present")
	assert_true(loaded.has("fog_data"), "fog_data should be present")

	ss.delete_save(slot)


func test_load_game_rejects_missing_fields() -> void:
	set_test_name("test_load_game_rejects_missing_fields")
	var ss := SaveSystem.new()
	var path := SaveSystem.SAVE_DIR + "test_slot_missing_fields.json"
	var dir := DirAccess.open("user://")
	if not dir:
		assert_true(false, "user:// should be available")
		return
	dir.make_dir_recursive("saves")
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "test save file should be writable")
	if file == null:
		return
	file.store_string('{"schema_version": 1, "state": {}}')
	file.close()

	var loaded := ss.load_game("test_slot_missing_fields")
	assert_true(loaded.is_empty(), "missing fog field should be rejected")

	ss.delete_save("test_slot_missing_fields")


func test_get_save_slots_handles_invalid_json() -> void:
	set_test_name("test_get_save_slots_handles_invalid_json")
	var ss := SaveSystem.new()
	var path := SaveSystem.SAVE_DIR + "test_slot_invalid_json.json"
	var dir := DirAccess.open("user://")
	if not dir:
		assert_true(false, "user:// should be available")
		return
	dir.make_dir_recursive("saves")
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "test save file should be writable")
	if file == null:
		return
	file.store_string("{not_json")
	file.close()

	var slots := ss.get_save_slots()
	var found := false
	for s in slots:
		if s.get("slot", "") == "test_slot_invalid_json":
			found = true
			assert_eq(s.get("date", ""), "unknown")
			assert_eq(int(s.get("day", -1)), 0)
	assert_true(found, "invalid json save slot should still be listed")

	ss.delete_save("test_slot_invalid_json")
