class_name GridRenderer
extends Node2D

const TILE_SIZE := 32
const COLORS := {
	"SEA": Color(0.15, 0.3, 0.6),
	"LAND": Color(0.35, 0.55, 0.2),
	"MOUNTAIN": Color(0.5, 0.45, 0.35),
	"CITY": Color(0.6, 0.6, 0.5),
}
const FOG_UNSEEN := Color(0.0, 0.0, 0.0, 1.0)
const FOG_DIMMED := Color(0.0, 0.0, 0.0, 0.5)

const PLAYER_COLORS := [
	Color(0.2, 0.5, 1.0),  # Player 0: Blue
	Color(0.9, 0.2, 0.2),  # Player 1: Red
]
const NEUTRAL_COLOR := Color(0.7, 0.7, 0.7)

const UNIT_LETTERS := {
	"infantry": "I",
	"airborne": "A",
	"interceptor": "F",
	"bomber": "B",
	"landing_craft": "L",
	"frigate": "S",
}

var game_state: GameState = null
var fog_system: FogSystem = null
var human_player: int = 0

# Overlays
var move_range: Array = []
var attack_targets: Array = []
var selected_pos: Vector2i = Vector2i(-1, -1)

# Font
var font: Font = null


func _ready() -> void:
	font = ThemeDB.fallback_font


func setup(state: GameState, fog: FogSystem, player_id: int) -> void:
	game_state = state
	fog_system = fog
	human_player = player_id
	queue_redraw()


func set_overlays(moves: Array, attacks: Array, sel_pos: Vector2i) -> void:
	move_range = moves
	attack_targets = attacks
	selected_pos = sel_pos
	queue_redraw()


func clear_overlays() -> void:
	move_range.clear()
	attack_targets.clear()
	selected_pos = Vector2i(-1, -1)
	queue_redraw()


func tile_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * TILE_SIZE, grid_pos.y * TILE_SIZE)


func world_to_tile(world_pos: Vector2) -> Vector2i:
	var local := to_local(world_pos)
	return Vector2i(int(floor(local.x / TILE_SIZE)), int(floor(local.y / TILE_SIZE)))


func get_map_pixel_size() -> Vector2:
	if game_state == null:
		return Vector2.ZERO
	return Vector2(game_state.map_width * TILE_SIZE, game_state.map_height * TILE_SIZE)


func _draw() -> void:
	if game_state == null:
		return

	var w: int = game_state.map_width
	var h: int = game_state.map_height

	# Draw terrain tiles
	for y in range(h):
		for x in range(w):
			var rect := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			var vis := fog_system.get_visibility(human_player, x, y)

			if vis == FogSystem.UNSEEN:
				draw_rect(rect, FOG_UNSEEN)
				continue

			var t := game_state.get_terrain(x, y)
			var color: Color
			match t:
				GameState.Terrain.SEA: color = COLORS["SEA"]
				GameState.Terrain.LAND: color = COLORS["LAND"]
				GameState.Terrain.MOUNTAIN: color = COLORS["MOUNTAIN"]
				GameState.Terrain.CITY: color = COLORS["CITY"]
				_: color = COLORS["SEA"]

			draw_rect(rect, color)

			# City marker
			if t == GameState.Terrain.CITY:
				var city = game_state.get_city_at(x, y)
				if city != null:
					var city_color: Color
					if city["owner"] == -1:
						city_color = NEUTRAL_COLOR
					elif city["owner"] < PLAYER_COLORS.size():
						city_color = PLAYER_COLORS[city["owner"]]
					else:
						city_color = NEUTRAL_COLOR
					var inner := Rect2(rect.position + Vector2(3, 3), rect.size - Vector2(6, 6))
					draw_rect(inner, city_color, false, 2.0)

			# Mountain indicator
			if t == GameState.Terrain.MOUNTAIN:
				var cx_pos := x * TILE_SIZE + TILE_SIZE / 2
				var cy_pos := y * TILE_SIZE + TILE_SIZE - 6
				draw_line(Vector2(cx_pos - 8, cy_pos), Vector2(cx_pos, cy_pos - 12), Color(0.3, 0.25, 0.2), 2.0)
				draw_line(Vector2(cx_pos, cy_pos - 12), Vector2(cx_pos + 8, cy_pos), Color(0.3, 0.25, 0.2), 2.0)

			# Dim if seen but not currently visible
			if vis == FogSystem.SEEN_NOT_VISIBLE:
				draw_rect(rect, FOG_DIMMED)

			# Grid lines
			draw_rect(rect, Color(0.0, 0.0, 0.0, 0.15), false, 1.0)

	# Draw move range overlay
	for pos in move_range:
		var rect := Rect2(pos.x * TILE_SIZE, pos.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		draw_rect(rect, Color(0.2, 0.5, 1.0, 0.25))

	# Draw attack targets overlay
	for pos in attack_targets:
		var rect := Rect2(pos.x * TILE_SIZE, pos.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		draw_rect(rect, Color(1.0, 0.2, 0.2, 0.35))

	# Draw selected tile
	if selected_pos != Vector2i(-1, -1):
		var rect := Rect2(selected_pos.x * TILE_SIZE, selected_pos.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		draw_rect(rect, Color(1.0, 1.0, 0.0, 0.6), false, 2.0)

	# Draw units (only on visible tiles)
	for unit in game_state.units:
		var vis := fog_system.get_visibility(human_player, unit["x"], unit["y"])
		if vis != FogSystem.VISIBLE:
			# Show own units always
			if unit["owner"] != human_player:
				continue

		_draw_unit(unit)


func _draw_unit(unit: Dictionary) -> void:
	var x: int = unit["x"]
	var y: int = unit["y"]
	var owner: int = unit["owner"]
	var unit_type: String = unit["type"]

	var base_color: Color
	if owner < PLAYER_COLORS.size():
		base_color = PLAYER_COLORS[owner]
	else:
		base_color = NEUTRAL_COLOR

	var cx_pos := x * TILE_SIZE + TILE_SIZE / 2
	var cy_pos := y * TILE_SIZE + TILE_SIZE / 2

	# Unit circle
	draw_circle(Vector2(cx_pos, cy_pos), 10, base_color)
	draw_arc(Vector2(cx_pos, cy_pos), 10, 0, TAU, 24, Color(0, 0, 0, 0.5), 1.5)

	# Unit letter
	var letter: String = UNIT_LETTERS.get(unit_type, "?")
	var text_pos := Vector2(cx_pos - 4, cy_pos + 5)
	draw_string(font, text_pos, letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)

	# HP bar
	if game_state != null:
		var def := game_state.get_unit_def(unit_type)
		if not def.is_empty():
			var max_hp: int = int(def["hp"])
			var hp: int = unit["hp"]
			var hp_pct := float(hp) / float(max_hp)
			var bar_width := TILE_SIZE - 4
			var bar_x := x * TILE_SIZE + 2
			var bar_y := y * TILE_SIZE + TILE_SIZE - 5
			draw_rect(Rect2(bar_x, bar_y, bar_width, 3), Color(0.2, 0.2, 0.2, 0.8))
			var hp_color := Color.GREEN
			if hp_pct < 0.5:
				hp_color = Color.YELLOW
			if hp_pct < 0.25:
				hp_color = Color.RED
			draw_rect(Rect2(bar_x, bar_y, bar_width * hp_pct, 3), hp_color)
