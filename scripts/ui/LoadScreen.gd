extends Control

signal load_requested(slot: String)
signal back_pressed()

var save_system: SaveSystem = SaveSystem.new()
var slot_container: VBoxContainer


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
	title.text = "LOAD GAME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	# Slot list
	slot_container = VBoxContainer.new()
	slot_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot_container.add_theme_constant_override("separation", 8)
	vbox.add_child(slot_container)

	# Back button
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer2)

	var btn_back := Button.new()
	btn_back.text = "Back"
	btn_back.custom_minimum_size = Vector2(180, 52)
	btn_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_back.pressed.connect(func(): back_pressed.emit())
	vbox.add_child(btn_back)

	# Bottom spacer
	var spacer3 := Control.new()
	spacer3.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer3)

	_refresh_slots()


func _refresh_slots() -> void:
	for child in slot_container.get_children():
		child.queue_free()

	var slots := save_system.get_save_slots()
	if slots.size() == 0:
		var no_saves := Label.new()
		no_saves.text = "No save files found."
		no_saves.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_container.add_child(no_saves)
		return

	for slot_info in slots:
		var btn := Button.new()
		btn.text = "%s  -  Day %d  -  %s" % [slot_info["slot"], slot_info["day"], slot_info["date"]]
		btn.custom_minimum_size = Vector2(400, 52)
		var slot_name: String = slot_info["slot"]
		btn.pressed.connect(func(): load_requested.emit(slot_name))
		slot_container.add_child(btn)
