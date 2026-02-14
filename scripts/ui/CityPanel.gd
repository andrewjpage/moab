extends PanelContainer

signal production_selected(city: Dictionary, unit_type: String)

var city_data: Dictionary = {}
var game_state: GameState = null
var vbox: VBoxContainer


func _ready() -> void:
	custom_minimum_size = Vector2(280, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.92)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)

	vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	visible = false


func show_city(city: Dictionary, state: GameState) -> void:
	city_data = city
	game_state = state

	# Clear existing children
	for child in vbox.get_children():
		child.queue_free()

	# Title
	var title := Label.new()
	title.text = city["name"]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	# Owner
	var owner_label := Label.new()
	var owner_str := "Neutral"
	if city["owner"] == 0:
		owner_str = "Your City"
	elif city["owner"] == 1:
		owner_str = "Enemy City"
	owner_label.text = owner_str
	owner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(owner_label)

	if state.is_port_city(city):
		var port_label := Label.new()
		port_label.text = "Port City (can build ships)"
		port_label.add_theme_font_size_override("font_size", 12)
		port_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(port_label)

	# Only show production for player's cities
	if city["owner"] != state.current_player:
		visible = true
		return

	# Current production
	if city["production_queue"] != "":
		var prod_label := Label.new()
		var def := state.get_unit_def(city["production_queue"])
		prod_label.text = "Building: %s (%d days left)" % [def.get("name", "?"), city["production_days_left"]]
		prod_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(prod_label)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Build options header
	var header := Label.new()
	header.text = "Build Unit:"
	header.add_theme_font_size_override("font_size", 14)
	vbox.add_child(header)

	# Unit buttons
	var buildable := state.get_buildable_units(city)
	for unit_def in buildable:
		var btn := Button.new()
		btn.text = "%s  (ATK:%d DEF:%d HP:%d)  %d days" % [
			unit_def["name"],
			int(unit_def["attack"]),
			int(unit_def["defense"]),
			int(unit_def["hp"]),
			int(unit_def["build_days"])
		]
		btn.custom_minimum_size = Vector2(0, 44)
		var uid: String = unit_def["id"]
		btn.pressed.connect(func(): _on_unit_selected(uid))
		vbox.add_child(btn)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 40)
	close_btn.pressed.connect(func(): visible = false)
	vbox.add_child(close_btn)

	visible = true


func _on_unit_selected(unit_type: String) -> void:
	production_selected.emit(city_data, unit_type)
	visible = false
