extends Control

signal return_to_menu()

# Core systems
var game_state: GameState = null
var turn_system: TurnSystem = TurnSystem.new()
var fog_system: FogSystem = FogSystem.new()
var combat_system: CombatSystem = CombatSystem.new()
var ai_controller: AIController = AIController.new()
var map_generator: MapGenerator = MapGenerator.new()
var save_system: SaveSystem = SaveSystem.new()
var pathfinding: Pathfinding = Pathfinding.new()

# UI elements
var grid_renderer: GridRenderer = null
var input_controller: InputController = null
var action_bar = null  # ActionBar
var inspect_panel = null  # InspectPanel
var city_panel = null  # CityPanel
var camera: Camera2D = null
var status_label: Label = null
var notification_label: Label = null
var notification_timer: float = 0.0

# State
var selected_unit: Dictionary = {}
var selected_tile: Vector2i = Vector2i(-1, -1)
var is_ai_turn: bool = false
var game_config: Dictionary = {}

# Camera
var zoom_level: float = 1.0
var min_zoom: float = 0.3
var max_zoom: float = 3.0


func _ready() -> void:
	_build_ui()


func start_new_game(config: Dictionary) -> void:
	game_config = config
	game_state = GameState.new()

	var map_data: Dictionary
	if config["map_type"] == "sample":
		map_data = map_generator.load_map_from_json("res://data/maps/sample_map.json")
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = config["seed"]
		var map_size: int = config.get("map_size", 30)
		map_data = map_generator.generate_map(map_size, map_size, rng)

	game_state.init_from_map_data(map_data, config["seed"])
	game_state.players[1]["ai_difficulty"] = config["ai_difficulty"]

	fog_system.init_fog(game_state)
	fog_system.recompute_vision(game_state, 0)

	grid_renderer.setup(game_state, fog_system, 0)
	input_controller.setup(grid_renderer, camera, game_state)

	# Center camera on player's starting city
	var player_cities := game_state.get_player_cities(0)
	if player_cities.size() > 0:
		var cx: int = player_cities[0]["x"]
		var cy: int = player_cities[0]["y"]
		camera.position = Vector2(cx * GridRenderer.TILE_SIZE, cy * GridRenderer.TILE_SIZE)

	# Start first turn
	var events := turn_system.start_turn(game_state, fog_system)
	_process_events(events)
	_update_status()


func load_saved_game(save_data: Dictionary) -> void:
	game_state = GameState.deserialize(save_data["state_data"])
	fog_system.deserialize(save_data["fog_data"])

	grid_renderer.setup(game_state, fog_system, 0)
	input_controller.setup(grid_renderer, camera, game_state)

	_update_status()
	grid_renderer.queue_redraw()


func _build_ui() -> void:
	# Camera
	camera = Camera2D.new()
	camera.zoom = Vector2(zoom_level, zoom_level)
	add_child(camera)

	# Grid renderer (world-space)
	grid_renderer = GridRenderer.new()
	add_child(grid_renderer)

	# Input controller
	input_controller = InputController.new()
	add_child(input_controller)
	input_controller.tile_selected.connect(_on_tile_selected)
	input_controller.unit_selected.connect(_on_unit_selected)
	input_controller.move_requested.connect(_on_move_requested)
	input_controller.attack_requested.connect(_on_attack_requested)
	input_controller.pan_changed.connect(_on_pan)
	input_controller.zoom_changed.connect(_on_zoom)

	# Status bar (top)
	status_label = Label.new()
	status_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	status_label.offset_bottom = 32
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 16)
	var status_bg := PanelContainer.new()
	status_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	status_bg.offset_bottom = 32
	var status_style := StyleBoxFlat.new()
	status_style.bg_color = Color(0.1, 0.1, 0.12, 0.85)
	status_bg.add_theme_stylebox_override("panel", status_style)
	add_child(status_bg)
	add_child(status_label)

	# Notification label (center)
	notification_label = Label.new()
	notification_label.set_anchors_preset(Control.PRESET_CENTER)
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_label.add_theme_font_size_override("font_size", 24)
	notification_label.visible = false
	add_child(notification_label)

	# Inspect panel (right side)
	var inspect_script := load("res://scripts/ui/InspectPanel.gd")
	inspect_panel = PanelContainer.new()
	inspect_panel.set_script(inspect_script)
	inspect_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	inspect_panel.offset_left = -230
	inspect_panel.offset_top = 40
	inspect_panel.offset_bottom = -70
	add_child(inspect_panel)

	# City panel (center)
	var city_script := load("res://scripts/ui/CityPanel.gd")
	city_panel = PanelContainer.new()
	city_panel.set_script(city_script)
	city_panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(city_panel)
	city_panel.production_selected.connect(_on_production_selected)

	# Action bar (bottom)
	var bar_script := load("res://scripts/ui/ActionBar.gd")
	action_bar = HBoxContainer.new()
	action_bar.set_script(bar_script)
	action_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	action_bar.offset_top = -60
	var bar_bg := PanelContainer.new()
	bar_bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar_bg.offset_top = -60
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.1, 0.1, 0.12, 0.85)
	bar_bg.add_theme_stylebox_override("panel", bar_style)
	add_child(bar_bg)
	add_child(action_bar)

	# Connect action bar signals (deferred to allow _ready to complete)
	call_deferred("_connect_action_bar")


func _connect_action_bar() -> void:
	if action_bar == null:
		return
	action_bar.action_move.connect(_on_action_move)
	action_bar.action_attack.connect(_on_action_attack)
	action_bar.action_drop.connect(_on_action_drop)
	action_bar.action_load.connect(_on_action_load)
	action_bar.action_unload.connect(_on_action_unload)
	action_bar.action_sleep.connect(_on_action_sleep)
	action_bar.action_wake.connect(_on_action_wake)
	action_bar.action_end_turn.connect(_on_end_turn)
	action_bar.action_save.connect(_on_save)


func _unhandled_input(event: InputEvent) -> void:
	if is_ai_turn:
		return
	if game_state == null:
		return
	input_controller.handle_input(event)


func _process(delta: float) -> void:
	if notification_timer > 0:
		notification_timer -= delta
		if notification_timer <= 0:
			notification_label.visible = false


func _on_tile_selected(pos: Vector2i) -> void:
	selected_tile = pos
	selected_unit = {}
	grid_renderer.clear_overlays()

	# Show tile info
	if inspect_panel:
		inspect_panel.show_tile_info(pos.x, pos.y, game_state)

	# Check for city - show city panel
	var city = game_state.get_city_at(pos.x, pos.y)
	if city != null and city["owner"] == game_state.current_player:
		if city_panel:
			city_panel.show_city(city, game_state)

	grid_renderer.set_overlays([], [], pos)


func _on_unit_selected(unit: Dictionary) -> void:
	selected_unit = unit
	selected_tile = Vector2i(unit["x"], unit["y"])

	# Show unit info
	if inspect_panel:
		inspect_panel.show_unit_info(unit, game_state)

	# Update action bar
	var def := game_state.get_unit_def(unit["type"])
	if action_bar:
		action_bar.update_for_unit(unit, def, game_state)

	# Show movement range and attack targets
	var moves := game_state.get_movement_range(unit)
	var attacks := combat_system.get_attackable_targets(game_state, unit)
	grid_renderer.set_overlays(moves, attacks, Vector2i(unit["x"], unit["y"]))


func _on_move_requested(unit_id: int, target: Vector2i) -> void:
	var unit = game_state.get_unit_by_id(unit_id)
	if unit == null:
		return

	# Verify move is valid
	var reachable := game_state.get_movement_range(unit)
	var can_move := false
	for pos in reachable:
		if pos == target:
			can_move = true
			break

	if not can_move:
		_show_notification("Cannot move there!")
		return

	# Calculate move cost
	var path := pathfinding.find_path(game_state, unit, Vector2i(unit["x"], unit["y"]), target)
	var cost := pathfinding.get_path_cost(game_state, unit, path)

	# Move unit
	unit["x"] = target.x
	unit["y"] = target.y
	unit["mp_remaining"] = maxi(unit["mp_remaining"] - cost, 0)

	# Deduct fuel for air
	var def := game_state.get_unit_def(unit["type"])
	if def["domain"] == "AIR" and unit["fuel_remaining"] != null:
		unit["fuel_remaining"] = maxi(int(unit["fuel_remaining"]) - cost, 0)

	# Try capture city
	if def.get("can_capture", false):
		var city = game_state.get_city_at(target.x, target.y)
		if city != null and city["owner"] != unit["owner"]:
			city["owner"] = unit["owner"]
			city["production_queue"] = ""
			city["production_days_left"] = 0
			_show_notification("City captured: " + city["name"])

	# Recompute fog
	fog_system.recompute_vision(game_state, game_state.current_player)

	# Refresh UI
	_on_unit_selected(unit)
	_update_status()
	grid_renderer.queue_redraw()

	# Check victory
	_check_game_over()


func _on_attack_requested(unit_id: int, target: Vector2i) -> void:
	var unit = game_state.get_unit_by_id(unit_id)
	if unit == null:
		return

	if not combat_system.can_attack(game_state, unit, target.x, target.y):
		_show_notification("Cannot attack there!")
		return

	var def := game_state.get_unit_def(unit["type"])
	var result: Dictionary

	if "aoe_attack" in def.get("special", []):
		var results := combat_system.resolve_bomber_aoe(game_state, unit, target.x, target.y)
		result = {"aoe_results": results}
	else:
		var enemies := game_state.get_enemy_units_at(target.x, target.y, unit["owner"])
		if enemies.size() == 0:
			return
		result = combat_system.resolve_combat(game_state, unit, enemies[0])
		unit["has_acted"] = true
		unit["mp_remaining"] = 0

	# Show result
	if inspect_panel:
		inspect_panel.show_combat_result(result)

	# Recompute fog
	fog_system.recompute_vision(game_state, game_state.current_player)

	# Clear selection if attacker destroyed
	if result.get("attacker_destroyed", false) or (unit != null and game_state.get_unit_by_id(unit_id) == null):
		selected_unit = {}
		grid_renderer.clear_overlays()
		if action_bar:
			action_bar.hide_all_actions()
	else:
		_on_unit_selected(unit)

	_update_status()
	grid_renderer.queue_redraw()
	_check_game_over()


func _on_action_move() -> void:
	if not selected_unit.is_empty():
		input_controller.enter_move_mode(selected_unit)
		_show_notification("Tap a tile to move")


func _on_action_attack() -> void:
	if not selected_unit.is_empty():
		input_controller.enter_attack_mode(selected_unit)
		_show_notification("Tap an enemy to attack")


func _on_action_drop() -> void:
	if selected_unit.is_empty():
		return
	# Convert airborne to infantry at current position
	var unit := selected_unit
	var def := game_state.get_unit_def(unit["type"])
	if "drop" not in def.get("special", []):
		return
	var t := game_state.get_terrain(unit["x"], unit["y"])
	if t == GameState.Terrain.SEA:
		_show_notification("Cannot drop on sea!")
		return
	# Convert to infantry
	unit["type"] = "infantry"
	var inf_def := game_state.get_unit_def("infantry")
	unit["fuel_remaining"] = null
	unit["mp_remaining"] = 0
	unit["has_acted"] = true
	_show_notification("Airborne dropped as Infantry")
	_on_unit_selected(unit)
	grid_renderer.queue_redraw()


func _on_action_load() -> void:
	if selected_unit.is_empty():
		return
	var transport := selected_unit
	var def := game_state.get_unit_def(transport["type"])
	if "transport" not in def.get("special", []):
		return

	# Find adjacent friendly infantry/airborne to load
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = transport["x"] + dir.x
		var ny: int = transport["y"] + dir.y
		var units := game_state.get_friendly_units_at(nx, ny, transport["owner"])
		for u in units:
			var udef := game_state.get_unit_def(u["type"])
			if udef["domain"] == "LAND":
				var carried: Array = transport.get("carried_units", [])
				if carried.size() < int(def.get("capacity", 4)):
					carried.append(u.duplicate())
					transport["carried_units"] = carried
					game_state.remove_unit(u["id"])
					_show_notification("Unit loaded")
					_on_unit_selected(transport)
					grid_renderer.queue_redraw()
					return

	_show_notification("No adjacent units to load")


func _on_action_unload() -> void:
	if selected_unit.is_empty():
		return
	var transport := selected_unit
	var carried: Array = transport.get("carried_units", [])
	if carried.size() == 0:
		_show_notification("No units to unload")
		return

	# Find adjacent land tile to unload
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = transport["x"] + dir.x
		var ny: int = transport["y"] + dir.y
		if not game_state.in_bounds(nx, ny):
			continue
		var t := game_state.get_terrain(nx, ny)
		if t == GameState.Terrain.LAND or t == GameState.Terrain.CITY or t == GameState.Terrain.MOUNTAIN:
			var u_data: Dictionary = carried.pop_back()
			transport["carried_units"] = carried
			var new_unit := game_state.add_unit(u_data["type"], transport["owner"], nx, ny)
			new_unit["hp"] = u_data["hp"]
			new_unit["has_acted"] = true
			new_unit["mp_remaining"] = 0
			_show_notification("Unit unloaded")
			_on_unit_selected(transport)
			grid_renderer.queue_redraw()
			return

	_show_notification("No adjacent land to unload")


func _on_action_sleep() -> void:
	if not selected_unit.is_empty():
		selected_unit["is_sleeping"] = true
		_show_notification("Unit sleeping")
		selected_unit = {}
		grid_renderer.clear_overlays()
		if action_bar:
			action_bar.hide_all_actions()
		grid_renderer.queue_redraw()


func _on_action_wake() -> void:
	if not selected_unit.is_empty():
		selected_unit["is_sleeping"] = false
		_show_notification("Unit awake")
		_on_unit_selected(selected_unit)


func _on_end_turn() -> void:
	if is_ai_turn:
		return

	# End human turn
	var end_events := turn_system.end_turn(game_state, fog_system)
	_process_events(end_events)

	if game_state.game_over:
		return

	# AI turn
	_run_ai_turn()


func _run_ai_turn() -> void:
	is_ai_turn = true
	_show_notification("AI is thinking...")

	# Start AI turn
	var start_events := turn_system.start_turn(game_state, fog_system)
	_process_events(start_events)

	# AI actions
	var ai_events := ai_controller.take_turn(game_state, fog_system)
	_process_events(ai_events)

	# End AI turn
	var end_events := turn_system.end_turn(game_state, fog_system)
	_process_events(end_events)

	if game_state.game_over:
		is_ai_turn = false
		return

	# Start human turn
	var human_events := turn_system.start_turn(game_state, fog_system)
	_process_events(human_events)

	# Autosave
	save_system.autosave(game_state, fog_system)

	is_ai_turn = false
	selected_unit = {}
	grid_renderer.clear_overlays()
	if action_bar:
		action_bar.hide_all_actions()
	_update_status()
	grid_renderer.queue_redraw()
	_show_notification("Day " + str(game_state.day) + " - Your turn")


func _on_save() -> void:
	save_system.save_game(game_state, fog_system, "slot1")
	_show_notification("Game saved!")


func _on_production_selected(city: Dictionary, unit_type: String) -> void:
	var def := game_state.get_unit_def(unit_type)
	if def.is_empty():
		return
	city["production_queue"] = unit_type
	city["production_days_left"] = int(def["build_days"])
	_show_notification("Building " + def["name"] + " in " + city["name"])
	grid_renderer.queue_redraw()


func _on_pan(delta: Vector2) -> void:
	if camera:
		camera.position += delta / camera.zoom


func _on_zoom(factor: float) -> void:
	zoom_level = clampf(zoom_level * factor, min_zoom, max_zoom)
	if camera:
		camera.zoom = Vector2(zoom_level, zoom_level)


func _process_events(events: Array) -> void:
	for event in events:
		match event.get("type", ""):
			"unit_spawned":
				_show_notification("Unit built: " + event["unit_type"] + " at " + event["city"])
			"unit_repaired":
				pass  # Silent
			"unit_crashed":
				_show_notification("Air unit crashed: " + event["unit_type"])
			"game_over":
				_handle_game_over(event["winner"])


func _handle_game_over(winner: int) -> void:
	var msg := ""
	if winner == 0:
		msg = "VICTORY! You have conquered the map!"
	else:
		msg = "DEFEAT! The enemy has conquered the map."

	_show_notification(msg)

	# Show game over dialog after a delay
	var timer := get_tree().create_timer(3.0)
	await timer.timeout
	return_to_menu.emit()


func _check_game_over() -> void:
	var v := game_state.check_victory()
	if v >= 0:
		game_state.game_over = true
		game_state.winner = v
		_handle_game_over(v)


func _update_status() -> void:
	if game_state == null or status_label == null:
		return
	var player_cities := game_state.get_player_cities(0)
	var total_cities := game_state.cities.size()
	var player_units := game_state.get_player_units(0)
	status_label.text = "Day %d  |  Cities: %d / %d  |  Units: %d  |  %d%% for victory" % [
		game_state.day,
		player_cities.size(),
		total_cities,
		player_units.size(),
		game_state.rules.get("victory_city_percentage", 60)
	]


func _show_notification(text: String) -> void:
	if notification_label:
		notification_label.text = text
		notification_label.visible = true
		notification_timer = 2.5
