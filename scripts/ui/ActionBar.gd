extends HBoxContainer

signal action_move()
signal action_attack()
signal action_drop()
signal action_load()
signal action_unload()
signal action_sleep()
signal action_wake()
signal action_end_turn()
signal action_save()

var btn_move: Button
var btn_attack: Button
var btn_drop: Button
var btn_load: Button
var btn_unload: Button
var btn_sleep: Button
var btn_end_turn: Button
var btn_save: Button


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 8)

	btn_move = _create_button("Move", _on_move)
	btn_attack = _create_button("Attack", _on_attack)
	btn_drop = _create_button("Drop", _on_drop)
	btn_load = _create_button("Load", _on_load)
	btn_unload = _create_button("Unload", _on_unload)
	btn_sleep = _create_button("Sleep", _on_sleep)
	btn_save = _create_button("Save", _on_save)
	btn_end_turn = _create_button("End Turn", _on_end_turn)

	hide_all_actions()
	btn_end_turn.visible = true
	btn_save.visible = true


func _create_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(80, 48)
	btn.pressed.connect(callback)
	add_child(btn)
	return btn


func hide_all_actions() -> void:
	btn_move.visible = false
	btn_attack.visible = false
	btn_drop.visible = false
	btn_load.visible = false
	btn_unload.visible = false
	btn_sleep.visible = false


func update_for_unit(unit: Dictionary, unit_def: Dictionary, game_state: GameState) -> void:
	hide_all_actions()

	if unit.is_empty() or unit_def.is_empty():
		return

	# Only show actions for current player's units
	if unit["owner"] != game_state.current_player:
		return

	var domain: String = unit_def["domain"]

	# Move (if has MP remaining)
	if unit["mp_remaining"] > 0 and not unit["has_acted"]:
		btn_move.visible = true

	# Attack
	if not unit["has_acted"]:
		btn_attack.visible = true

	# Drop (Airborne only, when in AIR domain)
	if "drop" in unit_def.get("special", []):
		btn_drop.visible = true

	# Load/Unload (Transport)
	if "transport" in unit_def.get("special", []):
		var carried: Array = unit.get("carried_units", [])
		if carried.size() < int(unit_def.get("capacity", 0)):
			btn_load.visible = true
		if carried.size() > 0:
			btn_unload.visible = true

	# Sleep/Wake
	if unit["is_sleeping"]:
		btn_sleep.text = "Wake"
	else:
		btn_sleep.text = "Sleep"
	btn_sleep.visible = true


func _on_move() -> void:
	action_move.emit()

func _on_attack() -> void:
	action_attack.emit()

func _on_drop() -> void:
	action_drop.emit()

func _on_load() -> void:
	action_load.emit()

func _on_unload() -> void:
	action_unload.emit()

func _on_sleep() -> void:
	if btn_sleep.text == "Wake":
		action_wake.emit()
	else:
		action_sleep.emit()

func _on_end_turn() -> void:
	action_end_turn.emit()

func _on_save() -> void:
	action_save.emit()
