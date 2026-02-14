class_name AIController
extends RefCounted

var pathfinding: Pathfinding = Pathfinding.new()
var combat_system: CombatSystem = CombatSystem.new()
var difficulty: String = "normal"  # "easy" or "normal"


func take_turn(state: GameState, fog: FogSystem) -> Array:
	var events: Array = []
	var pid: int = state.current_player
	difficulty = state.players[pid].get("ai_difficulty", "normal")

	# Choose production for each city
	for city in state.get_player_cities(pid):
		if city["production_queue"] == "":
			var unit_type := _choose_production(city, state)
			if unit_type != "":
				city["production_queue"] = unit_type
				var def := state.get_unit_def(unit_type)
				city["production_days_left"] = int(def["build_days"])
				events.append({
					"type": "ai_production",
					"city": city["name"],
					"unit_type": unit_type
				})

	# Process each unit
	var ai_units := state.get_player_units(pid)
	for unit in ai_units:
		if unit["is_sleeping"] or unit["has_acted"]:
			continue
		var action := _evaluate_unit_action(unit, state, fog)
		match action["type"]:
			"move":
				_execute_move(unit, action["target"], state, fog)
				events.append(action)
			"attack":
				var result := _execute_attack(unit, action["target"], state)
				action["result"] = result
				events.append(action)
			"capture":
				_execute_move(unit, action["target"], state, fog)
				_try_capture_city(unit, state)
				events.append(action)
			"hold":
				pass  # Do nothing

	return events


func _evaluate_unit_action(unit: Dictionary, state: GameState, fog: FogSystem) -> Dictionary:
	var def := state.get_unit_def(unit["type"])
	var pid: int = unit["owner"]

	# Check for attackable enemies
	var attack_targets := combat_system.get_attackable_targets(state, unit)
	if attack_targets.size() > 0:
		var best_target := _pick_best_attack_target(unit, attack_targets, state)
		if best_target != Vector2i(-1, -1):
			return {"type": "attack", "target": best_target, "unit_id": unit["id"]}

	# Check for capturable cities
	if def.get("can_capture", false):
		var nearest_city := _find_nearest_capturable_city(unit, state)
		if nearest_city != Vector2i(-1, -1):
			return {"type": "capture", "target": nearest_city, "unit_id": unit["id"]}

	# Normal mode: defend own cities if threatened
	if difficulty == "normal":
		var defend_pos := _find_defense_position(unit, state)
		if defend_pos != Vector2i(-1, -1):
			return {"type": "move", "target": defend_pos, "unit_id": unit["id"]}

	# Move toward nearest objective
	var move_target := _find_move_target(unit, state)
	if move_target != Vector2i(-1, -1):
		return {"type": "move", "target": move_target, "unit_id": unit["id"]}

	return {"type": "hold", "unit_id": unit["id"]}


func _pick_best_attack_target(unit: Dictionary, targets: Array, state: GameState) -> Vector2i:
	var def := state.get_unit_def(unit["type"])
	var best_score := -999
	var best_target := Vector2i(-1, -1)

	for target_pos in targets:
		var enemies := state.get_enemy_units_at(target_pos.x, target_pos.y, unit["owner"])
		if enemies.size() == 0:
			continue
		var enemy: Dictionary = enemies[0]
		var enemy_def := state.get_unit_def(enemy["type"])

		# Bomber AoE check - avoid friendly fire in Normal mode
		if "aoe_attack" in def.get("special", []) and difficulty == "normal":
			if _would_hit_own_units(unit, target_pos, state):
				continue

		# Calculate expected damage trade
		var our_atk: int = int(def["attack"])
		var their_def: int = int(enemy_def["defense"])
		var our_damage: int = maxi(our_atk - their_def, 1)

		var score: int = our_damage
		# Bonus for killing
		if our_damage >= enemy["hp"]:
			score += 10
		# Bonus for attacking cities (capturing after kill)
		if state.get_city_at(target_pos.x, target_pos.y) != null:
			score += 5

		# Easy mode: only attack if trade is favorable
		if difficulty == "easy":
			var their_atk: int = int(enemy_def["attack"])
			var our_def_val: int = int(def["defense"])
			var their_damage: int = maxi(their_atk - our_def_val, 1)
			if their_damage >= our_damage and our_damage < enemy["hp"]:
				continue

		if score > best_score:
			best_score = score
			best_target = target_pos

	return best_target


func _find_nearest_capturable_city(unit: Dictionary, state: GameState) -> Vector2i:
	var pid: int = unit["owner"]
	var unit_pos := Vector2i(unit["x"], unit["y"])
	var best_dist := 9999
	var best_city := Vector2i(-1, -1)

	for city in state.cities:
		if city["owner"] == pid:
			continue
		var city_pos := Vector2i(city["x"], city["y"])
		var dist := absi(unit_pos.x - city_pos.x) + absi(unit_pos.y - city_pos.y)

		# Easy mode: prefer neutral cities
		if difficulty == "easy" and city["owner"] != -1:
			dist += 20

		if dist < best_dist:
			best_dist = dist
			best_city = city_pos

	if best_city == Vector2i(-1, -1):
		return best_city

	# Find a step along the path toward the city
	return _get_step_toward(unit, best_city, state)


func _find_defense_position(unit: Dictionary, state: GameState) -> Vector2i:
	var pid: int = unit["owner"]
	var my_cities := state.get_player_cities(pid)

	for city in my_cities:
		var city_pos := Vector2i(city["x"], city["y"])
		# Check if enemy is near this city
		var threatened := false
		for enemy_unit in state.units:
			if enemy_unit["owner"] == pid:
				continue
			var dx := absi(enemy_unit["x"] - city["x"])
			var dy := absi(enemy_unit["y"] - city["y"])
			if dx + dy <= 4:
				threatened = true
				break

		if threatened:
			var defenders := state.get_friendly_units_at(city["x"], city["y"], pid)
			if defenders.size() == 0:
				return _get_step_toward(unit, city_pos, state)

	return Vector2i(-1, -1)


func _find_move_target(unit: Dictionary, state: GameState) -> Vector2i:
	var def := state.get_unit_def(unit["type"])
	var domain: String = def["domain"]

	# Sea units: patrol or move toward enemy
	if domain == "SEA":
		return _find_sea_objective(unit, state)

	# Air units: move toward enemies or back to base for fuel
	if domain == "AIR":
		return _find_air_objective(unit, state)

	# Land units: move toward nearest uncaptured city
	return _find_nearest_capturable_city(unit, state)


func _find_sea_objective(unit: Dictionary, state: GameState) -> Vector2i:
	var pid: int = unit["owner"]
	# Find nearest enemy sea unit or enemy port city
	var best_dist := 9999
	var best_target := Vector2i(-1, -1)

	for enemy in state.units:
		if enemy["owner"] == pid:
			continue
		var edef := state.get_unit_def(enemy["type"])
		if edef["domain"] == "SEA":
			var dist := absi(unit["x"] - enemy["x"]) + absi(unit["y"] - enemy["y"])
			if dist < best_dist:
				best_dist = dist
				best_target = Vector2i(enemy["x"], enemy["y"])

	if best_target != Vector2i(-1, -1):
		return _get_step_toward(unit, best_target, state)
	return Vector2i(-1, -1)


func _find_air_objective(unit: Dictionary, state: GameState) -> Vector2i:
	var pid: int = unit["owner"]
	var def := state.get_unit_def(unit["type"])

	# Check fuel - if low, head back to base
	if unit["fuel_remaining"] != null:
		var fuel: int = int(unit["fuel_remaining"])
		var nearest_base := _find_nearest_friendly_city(unit, state)
		if nearest_base != Vector2i(-1, -1):
			var dist_to_base := absi(unit["x"] - nearest_base.x) + absi(unit["y"] - nearest_base.y)
			if fuel <= dist_to_base + 2:
				return _get_step_toward(unit, nearest_base, state)

	# Otherwise, seek enemies
	var best_dist := 9999
	var best_target := Vector2i(-1, -1)

	for enemy in state.units:
		if enemy["owner"] == pid:
			continue
		var dist := absi(unit["x"] - enemy["x"]) + absi(unit["y"] - enemy["y"])
		if dist < best_dist:
			best_dist = dist
			best_target = Vector2i(enemy["x"], enemy["y"])

	if best_target != Vector2i(-1, -1):
		return _get_step_toward(unit, best_target, state)
	return Vector2i(-1, -1)


func _find_nearest_friendly_city(unit: Dictionary, state: GameState) -> Vector2i:
	var pid: int = unit["owner"]
	var best_dist := 9999
	var best_pos := Vector2i(-1, -1)

	for city in state.get_player_cities(pid):
		var dist := absi(unit["x"] - city["x"]) + absi(unit["y"] - city["y"])
		if dist < best_dist:
			best_dist = dist
			best_pos = Vector2i(city["x"], city["y"])

	return best_pos


func _get_step_toward(unit: Dictionary, target: Vector2i, state: GameState) -> Vector2i:
	var path := pathfinding.find_path(state, unit, Vector2i(unit["x"], unit["y"]), target)
	if path.size() < 2:
		return Vector2i(-1, -1)

	# Find how far we can move along the path
	var mp: int = unit["mp_remaining"]
	var cost := 0
	var last_valid := 0
	for i in range(1, path.size()):
		cost += state.get_move_cost(unit, path[i].x, path[i].y)
		if cost > mp:
			break
		last_valid = i

	if last_valid == 0:
		return Vector2i(-1, -1)

	return path[last_valid]


func _would_hit_own_units(bomber: Dictionary, target: Vector2i, state: GameState) -> bool:
	var pid: int = bomber["owner"]
	var bomber_def := state.get_unit_def(bomber["type"])
	var radius: int = int(bomber_def.get("aoe_radius", 2))

	for unit in state.units:
		if unit["owner"] != pid:
			continue
		if unit["id"] == bomber["id"]:
			continue
		var dx := absi(unit["x"] - target.x)
		var dy := absi(unit["y"] - target.y)
		if maxi(dx, dy) <= radius:
			return true

	return false


func _execute_move(unit: Dictionary, target: Vector2i, state: GameState, fog: FogSystem) -> void:
	if target == Vector2i(-1, -1):
		return
	var old_x := unit["x"]
	var old_y := unit["y"]
	var cost := state.get_move_cost(unit, target.x, target.y)
	var path := pathfinding.find_path(state, unit, Vector2i(old_x, old_y), target)
	var total_cost := 0
	if path.size() > 1:
		for i in range(1, path.size()):
			total_cost += state.get_move_cost(unit, path[i].x, path[i].y)
	else:
		total_cost = cost

	unit["x"] = target.x
	unit["y"] = target.y
	unit["mp_remaining"] = maxi(unit["mp_remaining"] - total_cost, 0)

	# Deduct fuel for air
	var def := state.get_unit_def(unit["type"])
	if def["domain"] == "AIR" and unit["fuel_remaining"] != null:
		unit["fuel_remaining"] = maxi(int(unit["fuel_remaining"]) - total_cost, 0)


func _execute_attack(unit: Dictionary, target: Vector2i, state: GameState) -> Dictionary:
	var enemies := state.get_enemy_units_at(target.x, target.y, unit["owner"])
	if enemies.size() == 0:
		return {}

	var def := state.get_unit_def(unit["type"])

	# Bomber AoE
	if "aoe_attack" in def.get("special", []):
		var results := combat_system.resolve_bomber_aoe(state, unit, target.x, target.y)
		return {"aoe_results": results}

	# Standard combat
	var result := combat_system.resolve_combat(state, unit, enemies[0])
	unit["has_acted"] = true
	unit["mp_remaining"] = 0
	return result


func _try_capture_city(unit: Dictionary, state: GameState) -> void:
	var def := state.get_unit_def(unit["type"])
	if not def.get("can_capture", false):
		return
	var city := state.get_city_at(unit["x"], unit["y"])
	if city == null:
		return
	if city["owner"] == unit["owner"]:
		return
	city["owner"] = unit["owner"]
	city["production_queue"] = ""
	city["production_days_left"] = 0


func _choose_production(city: Dictionary, state: GameState) -> String:
	var pid: int = city["owner"]
	var buildable := state.get_buildable_units(city)
	if buildable.size() == 0:
		return ""

	var my_units := state.get_player_units(pid)
	var infantry_count := 0
	var sea_count := 0
	var air_count := 0

	for u in my_units:
		var udef := state.get_unit_def(u["type"])
		match udef["domain"]:
			"LAND": infantry_count += 1
			"SEA": sea_count += 1
			"AIR": air_count += 1

	# Priority: Infantry first, then diversify
	if infantry_count < 3:
		return "infantry"

	# Port cities: build some naval units
	if state.is_port_city(city) and sea_count < 2:
		if state.can_city_build_unit(city, "frigate"):
			return "frigate"

	# Build air units if we have enough ground forces
	if infantry_count >= 4 and air_count < 2:
		if difficulty == "normal":
			return "interceptor"
		return "infantry"

	# Default: more infantry
	return "infantry"
