extends PanelContainer

var info_label: RichTextLabel


func _ready() -> void:
	custom_minimum_size = Vector2(220, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.9)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)

	info_label = RichTextLabel.new()
	info_label.bbcode_enabled = true
	info_label.fit_content = true
	info_label.scroll_active = false
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(info_label)

	clear_info()


func clear_info() -> void:
	info_label.text = ""
	visible = false


func show_tile_info(x: int, y: int, state: GameState) -> void:
	var terrain_name := state.get_terrain_name(x, y)
	var text := "[b]Tile[/b] (%d, %d)\n" % [x, y]
	text += "Terrain: %s\n" % terrain_name

	var city := state.get_city_at(x, y)
	if city != null:
		text += "\n[b]City: %s[/b]\n" % city["name"]
		var owner_str := "Neutral"
		if city["owner"] == 0:
			owner_str = "[color=cyan]Player[/color]"
		elif city["owner"] == 1:
			owner_str = "[color=red]Enemy[/color]"
		text += "Owner: %s\n" % owner_str

		if state.is_port_city(city):
			text += "Type: Port\n"

		if city["production_queue"] != "" and city["owner"] == state.current_player:
			var def := state.get_unit_def(city["production_queue"])
			text += "Building: %s (%d days)\n" % [def.get("name", city["production_queue"]), city["production_days_left"]]

	info_label.text = text
	visible = true


func show_unit_info(unit: Dictionary, state: GameState) -> void:
	var def := state.get_unit_def(unit["type"])
	if def.is_empty():
		return

	var owner_str := "Player" if unit["owner"] == 0 else "Enemy"
	var color := "cyan" if unit["owner"] == 0 else "red"

	var text := "[b][color=%s]%s[/color] %s[/b]\n" % [color, owner_str, def["name"]]
	text += "HP: %d / %d\n" % [unit["hp"], int(def["hp"])]
	text += "MP: %d / %d\n" % [unit["mp_remaining"], int(def["mp"])]
	text += "ATK: %d  DEF: %d\n" % [int(def["attack"]), int(def["defense"])]
	text += "Vision: %d\n" % int(def["vision"])

	if def["domain"] == "AIR" and unit["fuel_remaining"] != null:
		text += "Fuel: %d / %d\n" % [int(unit["fuel_remaining"]), int(def["fuel"])]

	if "transport" in def.get("special", []):
		var carried: Array = unit.get("carried_units", [])
		text += "Cargo: %d / %d\n" % [carried.size(), int(def.get("capacity", 0))]

	if unit["is_sleeping"]:
		text += "[i]Sleeping[/i]\n"

	info_label.text = text
	visible = true


func show_combat_result(result: Dictionary) -> void:
	var text := "[b]Combat Result[/b]\n"
	if result.has("aoe_results"):
		text += "Bomber AoE Strike!\n"
		for r in result["aoe_results"]:
			var status := "DESTROYED" if r["destroyed"] else "Hit"
			var ff := " [FRIENDLY FIRE]" if r["is_friendly"] else ""
			text += "  %s: %d dmg %s%s\n" % [r["unit_type"], r["damage_taken"], status, ff]
	else:
		text += "Damage dealt: %d\n" % result.get("attacker_damage_dealt", 0)
		text += "Damage taken: %d\n" % result.get("defender_damage_dealt", 0)
		if result.get("defender_destroyed", false):
			text += "[color=green]Enemy destroyed![/color]\n"
		if result.get("attacker_destroyed", false):
			text += "[color=red]Unit lost![/color]\n"

	info_label.text = text
	visible = true
