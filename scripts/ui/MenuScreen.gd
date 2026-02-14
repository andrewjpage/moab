extends Control

signal new_game_pressed()
signal load_game_pressed()
signal quit_pressed()


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
	title.text = "CONQUEST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A Turn-Based Strategy Game"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	vbox.add_child(subtitle)

	# Spacer
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer2)

	# Buttons container (centered)
	var btn_container := VBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_container.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_container)

	var btn_new := Button.new()
	btn_new.text = "New Game"
	btn_new.custom_minimum_size = Vector2(240, 56)
	btn_new.pressed.connect(func(): new_game_pressed.emit())
	btn_container.add_child(btn_new)

	var btn_load := Button.new()
	btn_load.text = "Load Game"
	btn_load.custom_minimum_size = Vector2(240, 56)
	btn_load.pressed.connect(func(): load_game_pressed.emit())
	btn_container.add_child(btn_load)

	var btn_quit := Button.new()
	btn_quit.text = "Quit"
	btn_quit.custom_minimum_size = Vector2(240, 56)
	btn_quit.pressed.connect(func(): quit_pressed.emit())
	btn_container.add_child(btn_quit)

	# Bottom spacer
	var spacer3 := Control.new()
	spacer3.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer3)
