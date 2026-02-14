class_name InputController
extends Node

signal tile_selected(pos: Vector2i)
signal unit_selected(unit: Dictionary)
signal move_requested(unit_id: int, target: Vector2i)
signal attack_requested(unit_id: int, target: Vector2i)
signal pan_changed(delta: Vector2)
signal zoom_changed(factor: float)

var grid_renderer: GridRenderer = null
var camera: Camera2D = null
var game_state: GameState = null

# Touch/drag state
var is_dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var drag_threshold: float = 10.0
var last_touch_pos: Vector2 = Vector2.ZERO

# Pinch zoom
var touches: Dictionary = {}
var initial_pinch_distance: float = 0.0
var initial_zoom: Vector2 = Vector2.ONE

# Selection state
var selected_unit: Dictionary = {}
var is_move_mode: bool = false
var is_attack_mode: bool = false


func setup(renderer: GridRenderer, cam: Camera2D, state: GameState) -> void:
	grid_renderer = renderer
	camera = cam
	game_state = state


func handle_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_apply_pan(-event.relative)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		touches[event.index] = event.position
		if touches.size() == 1:
			is_dragging = false
			drag_start = event.position
			last_touch_pos = event.position
		elif touches.size() == 2:
			var positions := touches.values()
			initial_pinch_distance = positions[0].distance_to(positions[1])
			initial_zoom = camera.zoom if camera else Vector2.ONE
	else:
		if touches.size() == 1 and not is_dragging:
			# Tap - select tile
			_handle_tap(event.position)
		touches.erase(event.index)
		is_dragging = false


func _handle_drag(event: InputEventScreenDrag) -> void:
	touches[event.index] = event.position

	if touches.size() == 2:
		# Pinch zoom
		var positions := touches.values()
		var current_dist := positions[0].distance_to(positions[1])
		if initial_pinch_distance > 0:
			var zoom_factor := current_dist / initial_pinch_distance
			zoom_changed.emit(zoom_factor)
	elif touches.size() == 1:
		var delta := event.position - last_touch_pos
		if not is_dragging and drag_start.distance_to(event.position) > drag_threshold:
			is_dragging = true
		if is_dragging:
			_apply_pan(-delta)
		last_touch_pos = event.position


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_tap(event.position)
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_changed.emit(1.1)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_changed.emit(0.9)


func _handle_tap(screen_pos: Vector2) -> void:
	if grid_renderer == null or camera == null:
		return

	# Convert screen position to world position via canvas transform
	var viewport := grid_renderer.get_viewport()
	if viewport == null:
		return
	var canvas_transform := viewport.get_canvas_transform()
	var global_pos := canvas_transform.affine_inverse() * screen_pos
	var tile_pos := Vector2i(int(floor(global_pos.x / GridRenderer.TILE_SIZE)), int(floor(global_pos.y / GridRenderer.TILE_SIZE)))

	if not game_state.in_bounds(tile_pos.x, tile_pos.y):
		return

	# If in move mode, request move
	if is_move_mode and not selected_unit.is_empty():
		move_requested.emit(selected_unit["id"], tile_pos)
		is_move_mode = false
		return

	# If in attack mode, request attack
	if is_attack_mode and not selected_unit.is_empty():
		attack_requested.emit(selected_unit["id"], tile_pos)
		is_attack_mode = false
		return

	tile_selected.emit(tile_pos)

	# Check for unit at tile
	var units := game_state.get_friendly_units_at(tile_pos.x, tile_pos.y, game_state.current_player)
	if units.size() > 0:
		unit_selected.emit(units[0])
	else:
		selected_unit = {}


func enter_move_mode(unit: Dictionary) -> void:
	selected_unit = unit
	is_move_mode = true
	is_attack_mode = false


func enter_attack_mode(unit: Dictionary) -> void:
	selected_unit = unit
	is_attack_mode = true
	is_move_mode = false


func cancel_mode() -> void:
	is_move_mode = false
	is_attack_mode = false


func _apply_pan(delta: Vector2) -> void:
	pan_changed.emit(delta)
