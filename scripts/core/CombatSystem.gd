class_name CombatSystem
extends RefCounted


func resolve_combat(state: GameState, attacker: Dictionary, defender: Dictionary) -> Dictionary:
	var atk_def := state.get_unit_def(attacker["type"])
	var def_def := state.get_unit_def(defender["type"])

	# Terrain defense bonus for defender
	var terrain_bonus := _get_terrain_bonus(state, defender["x"], defender["y"])

	# Air superiority bonus: Interceptor vs AIR gets +2 attack
	var atk_bonus := 0
	if "air_superiority" in atk_def.get("special", []) and def_def["domain"] == "AIR":
		atk_bonus = 2

	# Attacker damage
	var atk_power: int = int(atk_def["attack"]) + atk_bonus
	var def_armor: int = int(def_def["defense"]) + terrain_bonus
	var damage: int = maxi(atk_power - def_armor, int(state.rules.get("min_damage", 1)))

	defender["hp"] -= damage
	var defender_destroyed: bool = defender["hp"] <= 0

	# Counter-attack (only if defender survives and is adjacent, non-air)
	var counter_damage := 0
	var attacker_destroyed := false
	if not defender_destroyed:
		if _can_counter(atk_def, def_def, attacker, defender):
			var def_terrain_bonus := _get_terrain_bonus(state, attacker["x"], attacker["y"])
			var counter_atk: int = int(def_def["attack"])
			var counter_def: int = int(atk_def["defense"]) + def_terrain_bonus
			counter_damage = maxi(counter_atk - counter_def, int(state.rules.get("min_damage", 1)))
			attacker["hp"] -= counter_damage
			attacker_destroyed = attacker["hp"] <= 0

	var result := {
		"attacker_damage_dealt": damage,
		"defender_damage_dealt": counter_damage,
		"attacker_destroyed": attacker_destroyed,
		"defender_destroyed": defender_destroyed,
		"attacker_hp": attacker["hp"],
		"defender_hp": defender["hp"]
	}

	# Remove destroyed units
	if defender_destroyed:
		state.remove_unit(defender["id"])
	if attacker_destroyed:
		state.remove_unit(attacker["id"])

	return result


func resolve_bomber_aoe(state: GameState, bomber: Dictionary, target_x: int, target_y: int) -> Array:
	var bomber_def := state.get_unit_def(bomber["type"])
	var aoe_radius: int = int(bomber_def.get("aoe_radius", 2))
	var bonus_damage: int = int(state.rules.get("bomber_primary_bonus_damage", 2))
	var results: Array = []
	var to_remove: Array = []

	# Find all units in AoE radius (Chebyshev distance)
	for unit in state.units.duplicate():
		var dx: int = absi(unit["x"] - target_x)
		var dy: int = absi(unit["y"] - target_y)
		var dist: int = maxi(dx, dy)
		if dist > aoe_radius:
			continue
		if unit["id"] == bomber["id"]:
			continue

		var unit_def := state.get_unit_def(unit["type"])
		var is_primary: bool = (unit["x"] == target_x and unit["y"] == target_y)
		var terrain_bonus := _get_terrain_bonus(state, unit["x"], unit["y"])

		var atk_power: int = int(bomber_def["attack"])
		if is_primary:
			atk_power += bonus_damage
		var def_armor: int = int(unit_def["defense"]) + terrain_bonus
		var damage: int = maxi(atk_power - def_armor, int(state.rules.get("min_damage", 1)))

		unit["hp"] -= damage
		var destroyed: bool = unit["hp"] <= 0

		results.append({
			"unit_id": unit["id"],
			"unit_type": unit["type"],
			"owner": unit["owner"],
			"damage_taken": damage,
			"destroyed": destroyed,
			"is_primary": is_primary,
			"is_friendly": unit["owner"] == bomber["owner"]
		})

		if destroyed:
			to_remove.append(unit["id"])

	# Remove destroyed units
	for uid in to_remove:
		state.remove_unit(uid)

	# Mark bomber as having acted
	bomber["has_acted"] = true
	bomber["mp_remaining"] = 0

	return results


func can_attack(state: GameState, attacker: Dictionary, target_x: int, target_y: int) -> bool:
	var atk_def := state.get_unit_def(attacker["type"])
	if attacker["has_acted"]:
		return false

	# Check for enemy units at target
	var enemies := state.get_enemy_units_at(target_x, target_y, attacker["owner"])
	if enemies.size() == 0:
		return false

	var domain: String = atk_def["domain"]

	# Bomber uses AoE - can attack within movement range
	if "aoe_attack" in atk_def.get("special", []):
		var dx: int = absi(attacker["x"] - target_x)
		var dy: int = absi(attacker["y"] - target_y)
		return maxi(dx, dy) <= attacker["mp_remaining"]

	# LAND/SEA: must be adjacent
	if domain == "LAND" or domain == "SEA":
		var dx: int = absi(attacker["x"] - target_x)
		var dy: int = absi(attacker["y"] - target_y)
		return (dx + dy) == 1

	# AIR: adjacent
	if domain == "AIR":
		var dx: int = absi(attacker["x"] - target_x)
		var dy: int = absi(attacker["y"] - target_y)
		return maxi(dx, dy) <= 1

	return false


func get_attackable_targets(state: GameState, unit: Dictionary) -> Array:
	var targets: Array = []
	var def := state.get_unit_def(unit["type"])
	var domain: String = def["domain"]

	if unit["has_acted"]:
		return targets

	if "aoe_attack" in def.get("special", []):
		# Bomber: any tile within movement range that has enemies
		var mp: int = unit["mp_remaining"]
		for dy in range(-mp, mp + 1):
			for dx in range(-mp, mp + 1):
				if maxi(absi(dx), absi(dy)) > mp:
					continue
				var tx: int = unit["x"] + dx
				var ty: int = unit["y"] + dy
				if not state.in_bounds(tx, ty):
					continue
				var enemies := state.get_enemy_units_at(tx, ty, unit["owner"])
				if enemies.size() > 0:
					targets.append(Vector2i(tx, ty))
		return targets

	# Standard attack: adjacent tiles with enemies
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var tx: int = unit["x"] + dir.x
		var ty: int = unit["y"] + dir.y
		if not state.in_bounds(tx, ty):
			continue
		var enemies := state.get_enemy_units_at(tx, ty, unit["owner"])
		if enemies.size() > 0:
			targets.append(Vector2i(tx, ty))

	# AIR: also diagonals
	if domain == "AIR":
		for dir in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var tx: int = unit["x"] + dir.x
			var ty: int = unit["y"] + dir.y
			if not state.in_bounds(tx, ty):
				continue
			var enemies := state.get_enemy_units_at(tx, ty, unit["owner"])
			if enemies.size() > 0:
				targets.append(Vector2i(tx, ty))

	return targets


func _get_terrain_bonus(state: GameState, x: int, y: int) -> int:
	var terrain_name := state.get_terrain_name(x, y)
	var bonuses: Dictionary = state.rules.get("terrain_defense_bonus", {})
	return int(bonuses.get(terrain_name, 0))


func _can_counter(atk_def: Dictionary, def_def: Dictionary, attacker: Dictionary, defender: Dictionary) -> bool:
	# Air units don't counter-attack ground/sea, and ground/sea don't counter air
	if def_def["domain"] == "AIR" or atk_def["domain"] == "AIR":
		# Only air vs air can counter
		if def_def["domain"] != "AIR" or atk_def["domain"] != "AIR":
			return false
	# Must be adjacent
	var dx: int = absi(attacker["x"] - defender["x"])
	var dy: int = absi(attacker["y"] - defender["y"])
	return (dx + dy) <= 1 or (def_def["domain"] == "AIR" and maxi(dx, dy) <= 1)
