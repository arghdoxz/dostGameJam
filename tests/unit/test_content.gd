extends TestCase


func test_registry_loads_without_errors() -> void:
	var reg: ContentRegistry = load(REGISTRY_PATH) as ContentRegistry
	assert_true(reg != null, "registry resource must load")
	var cat: ContentCatalog = ContentCatalog.from_registry(reg)
	assert_eq(cat.errors.size(), 0, ", ".join(cat.errors))


func test_content_counts_match_mvp_plan() -> void:
	var cat: ContentCatalog = catalog()
	assert_eq(cat.disasters.size(), 7)
	assert_eq(cat.buildings.size(), 7)
	assert_eq(cat.territories.size(), 5)


func test_ids_unique_and_prefixed() -> void:
	var reg: ContentRegistry = load(REGISTRY_PATH) as ContentRegistry
	var seen: Dictionary = {}
	for c: CardDefinition in reg.cards:
		assert_false(seen.has(c.id), "duplicate " + c.id)
		seen[c.id] = true
		var ok: bool = c.id.begins_with("res_") or c.id.begins_with("bld_") or c.id.begins_with("prep_") or c.id.begins_with("dis_")
		assert_true(ok, "unexpected id prefix: " + c.id)


func test_decks_reference_known_cards_of_the_right_deck() -> void:
	var cat: ContentCatalog = catalog()
	for k: Variant in cat.config.town_deck.keys():
		var d: CardDefinition = cat.card(String(k))
		assert_true(d != null, "town deck references unknown card " + String(k))
		if d != null:
			assert_eq(d.deck, CardDefinition.DeckKind.TOWN)
	for k: Variant in cat.config.disaster_deck.keys():
		var d2: CardDefinition = cat.card(String(k))
		assert_true(d2 != null, "disaster deck references unknown card " + String(k))
		if d2 != null:
			assert_eq(d2.deck, CardDefinition.DeckKind.DISASTER)


func test_disaster_cards_reference_valid_definitions() -> void:
	var cat: ContentCatalog = catalog()
	for k: Variant in cat.cards.keys():
		var c: CardDefinition = cat.card(String(k))
		if c is DisasterCardDef:
			var dis: DisasterDefinition = (c as DisasterCardDef).disaster
			assert_true(dis != null and cat.disaster(dis.id) != null, "bad disaster on " + c.id)
			assert_true(dis.level >= 1 and dis.level <= 3)
			assert_true(dis.damage_min <= dis.damage_max)
			if dis.targeting == DisasterDefinition.Targeting.OPPONENTS_WITHOUT_BUILDING:
				assert_true(cat.building(dis.condition_building_id) != null, "condition building missing for " + dis.id)


func test_every_card_has_tip_and_art_id_and_placeholder() -> void:
	var cat: ContentCatalog = catalog()
	for k: Variant in cat.cards.keys():
		var c: CardDefinition = cat.card(String(k))
		assert_ne(c.dr_tip, "", c.id + " needs a DRR tip")
		assert_ne(c.art_id, "", c.id + " needs an art id")
		assert_true(AssetLibrary.get_texture("cards", c.art_id) != null)


func test_missing_art_falls_back_without_crashing() -> void:
	var tex: Texture2D = AssetLibrary.get_texture("cards", "definitely_not_a_real_art_id")
	assert_true(tex != null)
	assert_false(AssetLibrary.has_final_art("cards", "definitely_not_a_real_art_id"))


func test_flood_example_buildings_have_expected_numbers() -> void:
	var cat: ContentCatalog = catalog()
	var tags: PackedStringArray = PackedStringArray(["flood"])
	assert_eq(cat.building("bld_seawall").reduction_against(tags), 3)
	assert_eq(cat.building("bld_drainage_system").reduction_against(tags), 1)
