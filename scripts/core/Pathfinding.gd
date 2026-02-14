class_name Pathfinding
extends RefCounted


func find_path(state: GameState, unit: Dictionary, from: Vector2i, to: Vector2i) -> Array:
	if from == to:
		return [from]
	if not state.can_unit_enter(unit, to.x, to.y):
		return []

	var def := state.get_unit_def(unit["type"])
	var domain: String = def["domain"]

	# A* pathfinding
	var open_set: Array = []
	var came_from: Dictionary = {}
	var g_score: Dictionary = {}
	var f_score: Dictionary = {}

	g_score[from] = 0
	f_score[from] = _heuristic(from, to)
	open_set.append(from)

	while open_set.size() > 0:
		# Find node with lowest f_score
		var current: Vector2i = open_set[0]
		var best_f: float = f_score.get(current, INF)
		for node in open_set:
			var f: float = f_score.get(node, INF)
			if f < best_f:
				best_f = f
				current = node

		if current == to:
			return _reconstruct_path(came_from, current)

		open_set.erase(current)

		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var neighbor := current + dir
			if not state.in_bounds(neighbor.x, neighbor.y):
				continue
			if not state.can_unit_enter(unit, neighbor.x, neighbor.y):
				continue

			# Check for enemy blocking (LAND/SEA only, can path through to attack target)
			if domain != "AIR":
				var enemies := state.get_enemy_units_at(neighbor.x, neighbor.y, unit["owner"])
				if enemies.size() > 0 and neighbor != to:
					continue

			var move_cost := get_move_cost(state, unit, neighbor.x, neighbor.y)
			var tentative_g: int = int(g_score.get(current, 999)) + move_cost

			if tentative_g < int(g_score.get(neighbor, 999)):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + _heuristic(neighbor, to)
				if not open_set.has(neighbor):
					open_set.append(neighbor)

	return []  # No path found


func get_reachable_tiles(state: GameState, unit: Dictionary) -> Array:
	var def := state.get_unit_def(unit["type"])
	var domain: String = def["domain"]
	var mp: int = unit["mp_remaining"]
	var start := Vector2i(unit["x"], unit["y"])

	# BFS from unit position using mp_remaining
	var visited: Dictionary = {}
	var queue: Array = []
	queue.append({"pos": start, "cost": 0})
	visited[start] = 0
	var result: Array = []

	while queue.size() > 0:
		var current = queue.pop_front()
		var pos: Vector2i = current["pos"]
		var cost: int = current["cost"]

		if pos != start:
			result.append(pos)

		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next_pos := pos + dir
			if not state.in_bounds(next_pos.x, next_pos.y):
				continue
			if not state.can_unit_enter(unit, next_pos.x, next_pos.y):
				continue
			var move_cost := get_move_cost(state, unit, next_pos.x, next_pos.y)
			var new_cost := cost + move_cost
			if new_cost > mp:
				continue
			# Check fuel for air units
			if domain == "AIR" and unit["fuel_remaining"] != null:
				if new_cost > int(unit["fuel_remaining"]):
					continue
			# Check if enemy unit blocks movement (LAND/SEA only, not AIR)
			if domain != "AIR":
				var enemies := state.get_enemy_units_at(next_pos.x, next_pos.y, unit["owner"])
				if enemies.size() > 0:
					continue
			if not visited.has(next_pos) or visited[next_pos] > new_cost:
				visited[next_pos] = new_cost
				queue.append({"pos": next_pos, "cost": new_cost})

	return result


func get_move_cost(state: GameState, unit: Dictionary, x: int, y: int) -> int:
	var t := state.get_terrain(x, y)
	var def := state.get_unit_def(unit["type"])
	var domain: String = def["domain"]
	match domain:
		"LAND":
			if t == GameState.Terrain.MOUNTAIN:
				return 2
			if t == GameState.Terrain.LAND or t == GameState.Terrain.CITY:
				return 1
			return 999  # Impassable (SEA)
		"SEA":
			if t == GameState.Terrain.SEA:
				return 1
			return 999  # Impassable
		"AIR":
			return 1  # All terrain costs 1 MP (fuel)
	return 1


func get_attackable_targets(state: GameState, unit: Dictionary) -> Array:
	var targets: Array = []
	var def := state.get_unit_def(unit["type"])
	var domain: String = def["domain"]

	if unit["has_acted"]:
		return targets

	# Bomber: AoE targeting - any tile within remaining MP
	if "aoe_attack" in def.get("special", []):
		var mp: int = unit["mp_remaining"]
		for dy in range(-mp, mp + 1):
			for dx in range(-mp, mp + 1):
				if maxi(absi(dx), absi(dy)) > mp:
					continue
				var tx := unit["x"] + dx
				var ty := unit["y"] + dy
				if not state.in_bounds(tx, ty):
					continue
				var enemies := state.get_enemy_units_at(tx, ty, unit["owner"])
				if enemies.size() > 0:
					targets.append({"x": tx, "y": ty, "units": enemies})
		return targets

	# LAND/SEA: adjacent enemy units (4-directional)
	if domain == "LAND" or domain == "SEA":
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var tx := unit["x"] + dir.x
			var ty := unit["y"] + dir.y
			if not state.in_bounds(tx, ty):
				continue
			var enemies := state.get_enemy_units_at(tx, ty, unit["owner"])
			if enemies.size() > 0:
				targets.append({"x": tx, "y": ty, "units": enemies})

	# AIR: enemy units at current tile or adjacent (8-directional Chebyshev)
	if domain == "AIR":
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var tx := unit["x"] + dx
				var ty := unit["y"] + dy
				if not state.in_bounds(tx, ty):
					continue
				var enemies := state.get_enemy_units_at(tx, ty, unit["owner"])
				if enemies.size() > 0:
					targets.append({"x": tx, "y": ty, "units": enemies})

	return targets


func get_path_cost(state: GameState, unit: Dictionary, path: Array) -> int:
	var total := 0
	for i in range(1, path.size()):
		total += get_move_cost(state, unit, path[i].x, path[i].y)
	return total


func _heuristic(a: Vector2i, b: Vector2i) -> float:
	return float(absi(a.x - b.x) + absi(a.y - b.y))


func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array:
	var path: Array = [current]
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	return path
