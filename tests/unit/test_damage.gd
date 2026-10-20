extends TestCase


func _flood() -> DisasterDefinition:
	var d: DisasterDefinition = DisasterDefinition.new()
	d.id = "disaster_test_flood"
	d.tags = PackedStringArray(["flood"])
	d.level = 2
	return d


func test_flood_example_five_minus_three_minus_one() -> void:
	var reductions: Array[int] = [3, 1]
	assert_eq(DamageCalculator.calculate(5, 0, reductions, 0), 1)


func test_flood_example_through_buildings() -> void:
	var s: MatchState = play_match()
	add_building(s, 0, "bld_seawall")
	add_building(s, 0, "bld_drainage_system")
	var bd: Dictionary = DamageCalculator.breakdown(s, s.players[0], _flood(), 5, 0)
	assert_eq(bd["final"], 1, "Seawall -3 and Drainage -1 against base 5")
	assert_eq((bd["buildings"] as Array).size(), 2)


func test_damage_never_below_zero() -> void:
	var reductions: Array[int] = [3, 3]
	assert_eq(DamageCalculator.calculate(2, 0, reductions, 5), 0)


func test_territory_modifiers() -> void:
	var s: MatchState = play_match()
	# P0 is Coastal: resists drought, weak to storm_surge and typhoon.
	var drought: DisasterDefinition = DisasterDefinition.new()
	drought.tags = PackedStringArray(["drought"])
	assert_eq(DamageCalculator.breakdown(s, s.players[0], drought, 3, 0)["final"], 2)
	var typhoon: DisasterDefinition = DisasterDefinition.new()
	typhoon.tags = PackedStringArray(["typhoon", "wind"])
	assert_eq(DamageCalculator.breakdown(s, s.players[0], typhoon, 4, 0)["final"], 5)
	assert_eq(DamageCalculator.breakdown(s, s.players[1], typhoon, 4, 0)["final"], 4, "Riverside is neutral to typhoon")


func test_reaction_reduction() -> void:
	var s: MatchState = play_match()
	assert_eq(DamageCalculator.breakdown(s, s.players[1], _flood(), 5, 0)["final"], 6, "Riverside weak to flood: 5+1")
	assert_eq(DamageCalculator.breakdown(s, s.players[1], _flood(), 5, 3)["final"], 3)


func test_durability_loss_by_level() -> void:
	assert_eq(DamageCalculator.durability_loss(1), 1)
	assert_eq(DamageCalculator.durability_loss(2), 1)
	assert_eq(DamageCalculator.durability_loss(3), 2)


func test_building_destroyed_at_zero() -> void:
	var b: BuildingInstance = BuildingInstance.new(1, "bld_seawall", 3)
	assert_false(DamageCalculator.damage_building(b, 2))
	assert_eq(b.durability, 1)
	assert_true(DamageCalculator.damage_building(b, 2))
	assert_eq(b.durability, 0)


func test_building_does_not_stack_with_itself() -> void:
	var def: BuildingDefinition = BuildingDefinition.new()
	def.reductions = {"flood": 3, "storm_surge": 2}
	assert_eq(def.reduction_against(PackedStringArray(["storm_surge", "flood"])), 3)
	assert_eq(def.reduction_against(PackedStringArray(["drought"])), 0)
