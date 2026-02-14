extends TestBase


func _make_state_with_adjacent_units() -> Array:
	var state := TestBase.create_test_state()
	# Place attacker at (3,3) and defender at (4,3)
	var attacker := state.add_unit("infantry", 0, 3, 3)
	var defender := state.add_unit("infantry", 1, 4, 3)
	return [state, attacker, defender]


func test_resolve_combat_basic() -> void:
	set_test_name("test_resolve_combat_basic")
	var arr := _make_state_with_adjacent_units()
	var state: GameState = arr[0]
	var attacker: Dictionary = arr[1]
	var defender: Dictionary = arr[2]
	var cs := CombatSystem.new()
	var result := cs.resolve_combat(state, attacker, defender)
	assert_gt(result["attacker_damage_dealt"], 0, "should deal damage")
	assert_true(result.has("defender_hp"), "result should have defender_hp")
	assert_true(result.has("attacker_hp"), "result should have attacker_hp")


func test_terrain_defense_bonus() -> void:
	set_test_name("test_terrain_defense_bonus")
	var state := TestBase.create_test_state()
	# Place defender on mountain (5,5) for +1 defense
	var attacker := state.add_unit("infantry", 0, 4, 5)
	var defender := state.add_unit("infantry", 1, 5, 5)
	var cs := CombatSystem.new()
	var hp_before: int = defender["hp"]
	cs.resolve_combat(state, attacker, defender)
	# Attack=4, Defense=3+1(mountain)=4, damage=max(4-4,1)=1
	var expected_damage := 1  # min_damage
	assert_eq(hp_before - defender["hp"], expected_damage, "mountain should give defense bonus")


func test_defender_destroyed() -> void:
	set_test_name("test_defender_destroyed")
	var state := TestBase.create_test_state()
	var attacker := state.add_unit("infantry", 0, 3, 3)
	var defender := state.add_unit("infantry", 1, 4, 3)
	defender["hp"] = 1  # Low HP
	var def_id: int = defender["id"]
	var cs := CombatSystem.new()
	var result := cs.resolve_combat(state, attacker, defender)
	assert_true(result["defender_destroyed"], "defender should be destroyed")
	assert_null(state.get_unit_by_id(def_id), "defender should be removed from state")


func test_attacker_destroyed() -> void:
	set_test_name("test_attacker_destroyed")
	var state := TestBase.create_test_state()
	var attacker := state.add_unit("infantry", 0, 3, 3)
	attacker["hp"] = 1
	var defender := state.add_unit("infantry", 1, 4, 3)
	var atk_id: int = attacker["id"]
	var cs := CombatSystem.new()
	var result := cs.resolve_combat(state, attacker, defender)
	# Attacker deals damage first, then counter. Counter should kill attacker.
	assert_true(result["attacker_destroyed"], "attacker should be destroyed by counter")
	assert_null(state.get_unit_by_id(atk_id), "attacker should be removed")


func test_no_counter_attack_cross_domain() -> void:
	set_test_name("test_no_counter_attack_cross_domain")
	var state := TestBase.create_test_state()
	var air := state.add_unit("interceptor", 0, 3, 3)
	var ground := state.add_unit("infantry", 1, 4, 3)
	var cs := CombatSystem.new()
	var result := cs.resolve_combat(state, air, ground)
	assert_eq(result["defender_damage_dealt"], 0, "ground should not counter air")


func test_air_superiority_bonus() -> void:
	set_test_name("test_air_superiority_bonus")
	var state := TestBase.create_test_state()
	var interceptor := state.add_unit("interceptor", 0, 3, 3)
	var enemy_air := state.add_unit("interceptor", 1, 4, 3)
	var hp_before: int = enemy_air["hp"]
	var cs := CombatSystem.new()
	cs.resolve_combat(state, interceptor, enemy_air)
	# Interceptor attack=5, air_superiority +2=7, vs defense=3, damage=max(7-3,1)=4
	var actual_damage: int = hp_before - enemy_air["hp"]
	assert_eq(actual_damage, 4, "interceptor should get +2 air superiority vs air")


func test_bomber_aoe() -> void:
	set_test_name("test_bomber_aoe")
	var state := TestBase.create_test_state()
	var bomber := state.add_unit("bomber", 0, 3, 3)
	# Place enemies within AoE radius (2)
	var primary := state.add_unit("infantry", 1, 5, 5)  # Primary target
	var splash := state.add_unit("infantry", 1, 4, 5)    # Within radius 2 of (5,5)
	var cs := CombatSystem.new()
	var results := cs.resolve_bomber_aoe(state, bomber, 5, 5)
	assert_gt(results.size(), 0, "should hit at least one unit")
	assert_true(bomber["has_acted"], "bomber should be marked as acted")
	# Check primary target got bonus damage
	for r in results:
		if r["is_primary"]:
			# bomber attack=6 + bonus_damage=2 = 8, vs defense=3+1(mountain)=4, damage=max(8-4,1)=4
			assert_eq(r["damage_taken"], 4, "primary target should take bonus damage (mountain defense)")


func test_bomber_aoe_friendly_fire() -> void:
	set_test_name("test_bomber_aoe_friendly_fire")
	var state := TestBase.create_test_state()
	var bomber := state.add_unit("bomber", 0, 3, 3)
	var enemy := state.add_unit("infantry", 1, 5, 5)
	var friendly := state.add_unit("infantry", 0, 4, 5)  # Within AoE
	var cs := CombatSystem.new()
	var results := cs.resolve_bomber_aoe(state, bomber, 5, 5)
	var hit_friendly := false
	for r in results:
		if r["is_friendly"]:
			hit_friendly = true
	assert_true(hit_friendly, "AoE should hit friendly units too")


func test_can_attack_adjacent() -> void:
	set_test_name("test_can_attack_adjacent")
	var state := TestBase.create_test_state()
	var attacker := state.add_unit("infantry", 0, 3, 3)
	state.add_unit("infantry", 1, 4, 3)
	var cs := CombatSystem.new()
	assert_true(cs.can_attack(state, attacker, 4, 3), "should be able to attack adjacent enemy")
	assert_false(cs.can_attack(state, attacker, 5, 3), "should not attack non-adjacent")


func test_can_attack_has_acted() -> void:
	set_test_name("test_can_attack_has_acted")
	var state := TestBase.create_test_state()
	var attacker := state.add_unit("infantry", 0, 3, 3)
	attacker["has_acted"] = true
	state.add_unit("infantry", 1, 4, 3)
	var cs := CombatSystem.new()
	assert_false(cs.can_attack(state, attacker, 4, 3), "acted unit cannot attack")


func test_can_attack_air_diagonal() -> void:
	set_test_name("test_can_attack_air_diagonal")
	var state := TestBase.create_test_state()
	var air := state.add_unit("interceptor", 0, 3, 3)
	state.add_unit("interceptor", 1, 4, 4)  # Diagonal
	var cs := CombatSystem.new()
	assert_true(cs.can_attack(state, air, 4, 4), "air should attack diagonally")


func test_can_attack_bomber_range() -> void:
	set_test_name("test_can_attack_bomber_range")
	var state := TestBase.create_test_state()
	var bomber := state.add_unit("bomber", 0, 3, 3)
	state.add_unit("infantry", 1, 5, 5)
	var cs := CombatSystem.new()
	# bomber mp=6, Chebyshev distance to (5,5) = max(2,2) = 2 <= 6
	assert_true(cs.can_attack(state, bomber, 5, 5), "bomber should attack within mp range")


func test_get_attackable_targets() -> void:
	set_test_name("test_get_attackable_targets")
	var state := TestBase.create_test_state()
	var attacker := state.add_unit("infantry", 0, 3, 3)
	state.add_unit("infantry", 1, 4, 3)
	state.add_unit("infantry", 1, 3, 4)
	var cs := CombatSystem.new()
	var targets := cs.get_attackable_targets(state, attacker)
	assert_eq(targets.size(), 2, "should find 2 adjacent enemies")
