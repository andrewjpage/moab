extends Node

var current_screen: Control = null
var save_system: SaveSystem = SaveSystem.new()


func _ready() -> void:
	_show_menu()


func _show_menu() -> void:
	_clear_screen()
	var menu_scene := load("res://scenes/screens/MenuScreen.tscn")
	current_screen = menu_scene.instantiate()
	add_child(current_screen)
	current_screen.new_game_pressed.connect(_on_new_game)
	current_screen.load_game_pressed.connect(_on_load_game)
	current_screen.quit_pressed.connect(_on_quit)


func _on_new_game() -> void:
	_clear_screen()
	var new_game_scene := load("res://scenes/screens/NewGameScreen.tscn")
	current_screen = new_game_scene.instantiate()
	add_child(current_screen)
	current_screen.start_game.connect(_on_start_game)
	current_screen.back_pressed.connect(_show_menu)


func _on_load_game() -> void:
	_clear_screen()
	var load_scene := load("res://scenes/screens/LoadScreen.tscn")
	current_screen = load_scene.instantiate()
	add_child(current_screen)
	current_screen.load_requested.connect(_on_load_requested)
	current_screen.back_pressed.connect(_show_menu)


func _on_start_game(config: Dictionary) -> void:
	_clear_screen()
	var game_scene := load("res://scenes/screens/GameScreen.tscn")
	current_screen = game_scene.instantiate()
	add_child(current_screen)
	current_screen.return_to_menu.connect(_show_menu)
	current_screen.start_new_game(config)


func _on_load_requested(slot: String) -> void:
	var data := save_system.load_game(slot)
	if data.is_empty():
		return

	_clear_screen()
	var game_scene := load("res://scenes/screens/GameScreen.tscn")
	current_screen = game_scene.instantiate()
	add_child(current_screen)
	current_screen.return_to_menu.connect(_show_menu)
	current_screen.load_saved_game(data)


func _on_quit() -> void:
	get_tree().quit()


func _clear_screen() -> void:
	if current_screen != null:
		current_screen.queue_free()
		current_screen = null
