extends SceneTree

var total_tests := 0
var total_passed := 0
var total_failed := 0
var failed_details: Array = []


func _init() -> void:
	var test_classes: Array = [
		["test_game_state", preload("res://tests/test_game_state.gd")],
		["test_fog_system", preload("res://tests/test_fog_system.gd")],
		["test_turn_system", preload("res://tests/test_turn_system.gd")],
		["test_combat_system", preload("res://tests/test_combat_system.gd")],
		["test_map_generator", preload("res://tests/test_map_generator.gd")],
		["test_pathfinding", preload("res://tests/test_pathfinding.gd")],
		["test_ai_controller", preload("res://tests/test_ai_controller.gd")],
		["test_save_system", preload("res://tests/test_save_system.gd")],
		["test_integration", preload("res://tests/test_integration.gd")],
	]

	print("")
	print("=== CONQUEST TEST SUITE ===")
	print("")

	for entry in test_classes:
		var suite_name: String = entry[0]
		var script: GDScript = entry[1]
		_run_suite(suite_name, script)

	print("")
	print("=== RESULTS ===")
	print("Total: %d  Passed: %d  Failed: %d" % [total_tests, total_passed, total_failed])

	if failed_details.size() > 0:
		print("")
		print("FAILURES:")
		for detail in failed_details:
			print("  FAIL: " + detail)

	print("")
	if total_failed > 0:
		print("SOME TESTS FAILED")
		quit(1)
	else:
		print("ALL TESTS PASSED")
		quit(0)


func _run_suite(suite_name: String, script: GDScript) -> void:
	var instance = script.new()
	var methods: Array = []

	# Get all test methods
	for m in instance.get_method_list():
		var method_name: String = m["name"]
		if method_name.begins_with("test_"):
			methods.append(method_name)

	if methods.size() == 0:
		return

	print("--- " + suite_name + " (" + str(methods.size()) + " tests) ---")

	for method_name in methods:
		total_tests += 1
		instance.set_test_name(suite_name + "." + method_name)

		# Call the test method
		instance.call(method_name)

		var failures: Array = instance.get_failures()
		if failures.size() == 0:
			total_passed += 1
			print("  PASS: " + method_name)
		else:
			total_failed += 1
			print("  FAIL: " + method_name)
			for f in failures:
				print("    -> " + f)
				failed_details.append(f)
