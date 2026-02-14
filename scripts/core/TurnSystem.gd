class_name TurnSystem
extends RefCounted


func start_turn(state: GameState, fog: FogSystem) -> Array:
	var events: Array = []

	var pid: int = state.current_player

	# 1. Refresh movement points for all current player units
	for unit in state.get_player_units(pid):
		var def := state.get_unit_def(unit["type"])
		unit["mp_remaining"] = int(def["mp"])
		unit["has_acted"] = false
		# Refuel air units at friendly cities
		if def["domain"] == "AIR" and unit["fuel_remaining"] != null:
			var city := state.get_city_at(unit["x"], unit["y"])
			if city != null and city["owner"] == pid:
				unit["fuel_remaining"] = def["fuel"]

	# 2. Tick city production
	for city in state.get_player_cities(pid):
		if city["production_queue"] != "" and city["production_days_left"] > 0:
			city["production_days_left"] -= 1
			if city["production_days_left"] <= 0:
				var spawned := _spawn_produced_unit(state, city)
				if spawned:
					events.append({
						"type": "unit_spawned",
						"unit_type": city["production_queue"],
						"city": city["name"],
						"x": spawned["x"],
						"y": spawned["y"]
					})
				city["production_queue"] = ""
				city["production_days_left"] = 0

	# 3. Repair units in friendly cities
	var repair_amount: int = state.rules.get("repair_amount", 2)
	for unit in state.get_player_units(pid):
		var city := state.get_city_at(unit["x"], unit["y"])
		if city != null and city["owner"] == pid:
			var def := state.get_unit_def(unit["type"])
			var max_hp: int = int(def["hp"])
			if unit["hp"] < max_hp:
				var old_hp: int = unit["hp"]
				unit["hp"] = mini(unit["hp"] + repair_amount, max_hp)
				if unit["hp"] != old_hp:
					events.append({
						"type": "unit_repaired",
						"unit_id": unit["id"],
						"hp_restored": unit["hp"] - old_hp
					})

	# 4. Recompute vision
	fog.recompute_vision(state, pid)

	return events


func end_turn(state: GameState, fog: FogSystem) -> Array:
	var events: Array = []
	var pid: int = state.current_player

	# Check air units: destroy any that ran out of fuel and aren't at a friendly city
	var to_remove: Array = []
	for unit in state.get_player_units(pid):
		var def := state.get_unit_def(unit["type"])
		if def["domain"] == "AIR" and unit["fuel_remaining"] != null:
			if int(unit["fuel_remaining"]) <= 0:
				var city := state.get_city_at(unit["x"], unit["y"])
				if city == null or city["owner"] != pid:
					to_remove.append(unit["id"])
					events.append({
						"type": "unit_crashed",
						"unit_id": unit["id"],
						"unit_type": unit["type"]
					})
	for uid in to_remove:
		state.remove_unit(uid)

	# Advance to next player
	state.current_player = (state.current_player + 1) % state.players.size()
	if state.current_player == 0:
		state.day += 1

	# Check victory
	var v := state.check_victory()
	if v >= 0:
		state.game_over = true
		state.winner = v
		events.append({
			"type": "game_over",
			"winner": v
		})

	# Recompute fog for new player
	fog.recompute_vision(state, state.current_player)

	return events


func _spawn_produced_unit(state: GameState, city: Dictionary):
	var cx: int = city["x"]
	var cy: int = city["y"]
	var unit_type: String = city["production_queue"]
	var def := state.get_unit_def(unit_type)

	# Try to spawn at city first
	var existing := state.get_units_at(cx, cy)
	var can_place_here := true
	for u in existing:
		if u["owner"] == city["owner"]:
			var udef := state.get_unit_def(u["type"])
			if udef["domain"] == def["domain"]:
				can_place_here = false
				break

	if can_place_here:
		return state.add_unit(unit_type, city["owner"], cx, cy)

	# Try adjacent tiles
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var nx := cx + dir.x
		var ny := cy + dir.y
		if not state.in_bounds(nx, ny):
			continue
		# Check if unit can enter this terrain
		var dummy_unit := {"type": unit_type, "owner": city["owner"], "x": cx, "y": cy}
		if state.can_unit_enter(dummy_unit, nx, ny):
			var adj_units := state.get_friendly_units_at(nx, ny, city["owner"])
			var blocked := false
			for u in adj_units:
				var udef := state.get_unit_def(u["type"])
				if udef["domain"] == def["domain"]:
					blocked = true
					break
			if not blocked:
				return state.add_unit(unit_type, city["owner"], nx, ny)

	return null
