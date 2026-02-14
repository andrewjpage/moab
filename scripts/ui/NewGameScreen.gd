extends Control

signal start_game(config: Dictionary)
signal back_pressed()


func _ready() -> void:
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Title
	var title := Label.new()
	title.text = "NEW GAME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	# Options container
	var opts := VBoxContainer.new()
	opts.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	opts.add_theme_constant_override("separation", 12)
	vbox.add_child(opts)

	# Map type
	var map_hbox := HBoxContainer.new()
	map_hbox.add_theme_constant_override("separation", 8)
	opts.add_child(map_hbox)
	var map_label := Label.new()
	map_label.text = "Map:"
	map_label.custom_minimum_size = Vector2(120, 0)
	map_hbox.add_child(map_label)
	var map_option := OptionButton.new()
	map_option.name = "MapOption"
	map_option.add_item("Sample Map", 0)
	map_option.add_item("Procedural", 1)
	map_option.custom_minimum_size = Vector2(200, 44)
	map_hbox.add_child(map_option)

	# Map size
	var size_hbox := HBoxContainer.new()
	size_hbox.add_theme_constant_override("separation", 8)
	opts.add_child(size_hbox)
	var size_label := Label.new()
	size_label.text = "Map Size:"
	size_label.custom_minimum_size = Vector2(120, 0)
	size_hbox.add_child(size_label)
	var size_spin := SpinBox.new()
	size_spin.name = "SizeSpin"
	size_spin.min_value = 15
	size_spin.max_value = 60
	size_spin.value = 30
	size_spin.step = 5
	size_spin.custom_minimum_size = Vector2(200, 44)
	size_hbox.add_child(size_spin)

	# Seed
	var seed_hbox := HBoxContainer.new()
	seed_hbox.add_theme_constant_override("separation", 8)
	opts.add_child(seed_hbox)
	var seed_label := Label.new()
	seed_label.text = "Seed:"
	seed_label.custom_minimum_size = Vector2(120, 0)
	seed_hbox.add_child(seed_label)
	var seed_input := LineEdit.new()
	seed_input.name = "SeedInput"
	seed_input.placeholder_text = "Random"
	seed_input.custom_minimum_size = Vector2(200, 44)
	seed_hbox.add_child(seed_input)

	# AI Difficulty
	var ai_hbox := HBoxContainer.new()
	ai_hbox.add_theme_constant_override("separation", 8)
	opts.add_child(ai_hbox)
	var ai_label := Label.new()
	ai_label.text = "AI:"
	ai_label.custom_minimum_size = Vector2(120, 0)
	ai_hbox.add_child(ai_label)
	var ai_option := OptionButton.new()
	ai_option.name = "AIOption"
	ai_option.add_item("Easy", 0)
	ai_option.add_item("Normal", 1)
	ai_option.selected = 1
	ai_option.custom_minimum_size = Vector2(200, 44)
	ai_hbox.add_child(ai_option)

	# Spacer
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer2)

	# Buttons
	var btn_container := HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_container)

	var btn_back := Button.new()
	btn_back.text = "Back"
	btn_back.custom_minimum_size = Vector2(140, 52)
	btn_back.pressed.connect(func(): back_pressed.emit())
	btn_container.add_child(btn_back)

	var btn_start := Button.new()
	btn_start.text = "Start Game"
	btn_start.custom_minimum_size = Vector2(180, 52)
	btn_start.pressed.connect(_on_start)
	btn_container.add_child(btn_start)

	# Bottom spacer
	var spacer3 := Control.new()
	spacer3.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer3)


func _on_start() -> void:
	var map_option: OptionButton = _find_child_by_name(self, "MapOption")
	var size_spin: SpinBox = _find_child_by_name(self, "SizeSpin")
	var seed_input: LineEdit = _find_child_by_name(self, "SeedInput")
	var ai_option: OptionButton = _find_child_by_name(self, "AIOption")

	var seed_val: int = 0
	if seed_input and seed_input.text != "":
		seed_val = seed_input.text.hash()
	else:
		seed_val = randi()

	var config := {
		"map_type": "sample" if (map_option and map_option.selected == 0) else "procedural",
		"map_size": int(size_spin.value) if size_spin else 30,
		"seed": seed_val,
		"ai_difficulty": "easy" if (ai_option and ai_option.selected == 0) else "normal"
	}

	start_game.emit(config)


func _find_child_by_name(node: Node, child_name: String):
	for child in node.get_children():
		if child.name == child_name:
			return child
		var found = _find_child_by_name(child, child_name)
		if found:
			return found
	return null
