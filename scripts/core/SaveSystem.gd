class_name SaveSystem
extends RefCounted

const SAVE_DIR := "user://saves/"
const SCHEMA_VERSION := 1


func save_game(state: GameState, fog: FogSystem, slot: String = "slot1") -> bool:
	_ensure_save_dir()
	var path := SAVE_DIR + slot + ".json"
	var data := {
		"schema_version": SCHEMA_VERSION,
		"save_date": Time.get_datetime_string_from_system(),
		"state": state.serialize(),
		"fog": fog.serialize()
	}
	var json_str := JSON.stringify(data, "  ")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Failed to save game to: " + path)
		return false
	file.store_string(json_str)
	file.close()
	return true


func load_game(slot: String = "slot1") -> Dictionary:
	var path := SAVE_DIR + slot + ".json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("Failed to parse save file: " + path)
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("Invalid save format: " + path)
		return {}
	var data: Dictionary = json.data
	if not data.has("state") or not data.has("fog"):
		push_error("Save file missing required fields: " + path)
		return {}
	if typeof(data["state"]) != TYPE_DICTIONARY or typeof(data["fog"]) != TYPE_DICTIONARY:
		push_error("Save file has invalid state/fog payload: " + path)
		return {}
	if data.get("schema_version", 0) != SCHEMA_VERSION:
		push_warning("Save schema version mismatch")
	return {
		"state_data": data["state"],
		"fog_data": data["fog"]
	}


func autosave(state: GameState, fog: FogSystem) -> void:
	save_game(state, fog, "autosave")


func get_save_slots() -> Array:
	_ensure_save_dir()
	var slots: Array = []
	var dir := DirAccess.open(SAVE_DIR)
	if not dir:
		return slots
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var slot_name := file_name.get_basename()
			var metadata := _get_save_metadata(slot_name)
			slots.append(metadata)
		file_name = dir.get_next()
	dir.list_dir_end()
	return slots


func delete_save(slot: String) -> void:
	var path := SAVE_DIR + slot + ".json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _get_save_metadata(slot: String) -> Dictionary:
	var path := SAVE_DIR + slot + ".json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {"slot": slot, "day": 0, "date": "unknown"}
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		return {"slot": slot, "day": 0, "date": "unknown"}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {"slot": slot, "day": 0, "date": "unknown"}
	var data: Dictionary = json.data
	var state_data = data.get("state", {})
	if typeof(state_data) != TYPE_DICTIONARY:
		state_data = {}
	return {
		"slot": slot,
		"day": state_data.get("day", 0),
		"date": data.get("save_date", "unknown"),
		"current_player": state_data.get("current_player", 0)
	}
