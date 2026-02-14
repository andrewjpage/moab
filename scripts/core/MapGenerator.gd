class_name MapGenerator
extends RefCounted


func generate_map(width: int, height: int, rng: RandomNumberGenerator, num_cities: int = 12) -> Dictionary:
	var terrain: Array = []
	terrain.resize(width * height)
	terrain.fill(GameState.Terrain.SEA)

	# Generate landmasses using random walk / blob approach
	var num_land_blobs := 3
	var land_centers: Array = []

	# Place blob centers ensuring good separation
	land_centers.append(Vector2i(width / 4, height / 4))         # NW
	land_centers.append(Vector2i(3 * width / 4, 3 * height / 4)) # SE
	land_centers.append(Vector2i(width / 2, height / 2))          # Center island

	for center in land_centers:
		var blob_size: int = rng.randi_range(80, 140)
		_grow_blob(terrain, width, height, center, blob_size, rng)

	# Add mountains on land (10-15% of land tiles)
	var land_tiles: Array = []
	for y in range(height):
		for x in range(width):
			if terrain[y * width + x] == GameState.Terrain.LAND:
				land_tiles.append(Vector2i(x, y))

	var num_mountains := int(land_tiles.size() * rng.randf_range(0.10, 0.15))
	land_tiles.shuffle()
	for i in range(mini(num_mountains, land_tiles.size())):
		var pos: Vector2i = land_tiles[i]
		terrain[pos.y * width + pos.x] = GameState.Terrain.MOUNTAIN

	# Place cities with minimum spacing
	var city_positions: Array = []
	var min_dist := 4

	# Home cities first - on the two main landmasses
	var home1 := _find_land_near(terrain, width, height, land_centers[0], rng)
	var home2 := _find_land_near(terrain, width, height, land_centers[1], rng)
	city_positions.append(home1)
	city_positions.append(home2)

	# Neutral cities
	var attempts := 0
	while city_positions.size() < num_cities and attempts < 500:
		attempts += 1
		var x := rng.randi_range(1, width - 2)
		var y := rng.randi_range(1, height - 2)
		if terrain[y * width + x] != GameState.Terrain.LAND:
			continue
		var too_close := false
		for existing in city_positions:
			var dx := absi(x - existing.x)
			var dy := absi(y - existing.y)
			if dx + dy < min_dist:
				too_close = true
				break
		if not too_close:
			city_positions.append(Vector2i(x, y))

	# Set terrain to CITY at city positions
	for pos in city_positions:
		terrain[pos.y * width + pos.x] = GameState.Terrain.CITY

	# Build city data
	var cities: Array = []
	for i in range(city_positions.size()):
		var pos: Vector2i = city_positions[i]
		var owner := -1
		var name_str := "City " + str(i + 1)
		if i == 0:
			owner = 0
			name_str = "Alpha Base"
		elif i == 1:
			owner = 1
			name_str = "Omega Base"
		else:
			name_str = _generate_city_name(rng, i)
		cities.append({
			"x": pos.x,
			"y": pos.y,
			"name": name_str,
			"owner": owner
		})

	# Starting units
	var starting_units: Array = [
		{"type": "infantry", "x": city_positions[0].x, "y": city_positions[0].y, "owner": 0},
		{"type": "infantry", "x": city_positions[1].x, "y": city_positions[1].y, "owner": 1}
	]

	# Build 2D terrain array for JSON compatibility
	var terrain_2d: Array = []
	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(terrain[y * width + x])
		terrain_2d.append(row)

	return {
		"version": 1,
		"name": "Procedural",
		"width": width,
		"height": height,
		"terrain": terrain_2d,
		"cities": cities,
		"starting_units": starting_units
	}


func load_map_from_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to load map: " + path)
		return {}
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("Failed to parse map JSON: " + path)
		return {}
	return json.data


func _grow_blob(terrain: Array, w: int, h: int, center: Vector2i, size: int, rng: RandomNumberGenerator) -> void:
	var frontier: Array = [center]
	var placed := 0
	var visited: Dictionary = {}

	while placed < size and frontier.size() > 0:
		var idx := rng.randi_range(0, frontier.size() - 1)
		var pos: Vector2i = frontier[idx]
		frontier.remove_at(idx)

		if visited.has(pos):
			continue
		visited[pos] = true

		if pos.x < 1 or pos.x >= w - 1 or pos.y < 1 or pos.y >= h - 1:
			continue

		terrain[pos.y * w + pos.x] = GameState.Terrain.LAND
		placed += 1

		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next := pos + dir
			if not visited.has(next):
				frontier.append(next)


func _find_land_near(terrain: Array, w: int, h: int, center: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	# Find a land tile near the center
	var best := center
	var best_dist := 999
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			var x := center.x + dx
			var y := center.y + dy
			if x >= 0 and x < w and y >= 0 and y < h:
				if terrain[y * w + x] == GameState.Terrain.LAND:
					var dist := absi(dx) + absi(dy)
					if dist < best_dist:
						best_dist = dist
						best = Vector2i(x, y)
	return best


func _generate_city_name(rng: RandomNumberGenerator, idx: int) -> String:
	var prefixes := ["Fort", "Port", "New", "East", "West", "North", "South", "Iron", "Storm", "Silver"]
	var suffixes := ["haven", "watch", "hold", "gate", "ridge", "bay", "peak", "ford", "vale", "rock"]
	var p := prefixes[rng.randi_range(0, prefixes.size() - 1)]
	var s := suffixes[rng.randi_range(0, suffixes.size() - 1)]
	return p + " " + s.capitalize()
