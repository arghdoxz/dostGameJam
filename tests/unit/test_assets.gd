extends TestCase
## Artist integration: every asset slot resolves, missing files fall back, paths live in one place.


func test_every_content_asset_resolves_to_a_texture() -> void:
	var cat: ContentCatalog = catalog()
	for cid: String in cat.card_ids():
		var def: CardDefinition = cat.card(cid)
		assert_true(AssetLibrary.get_texture("cards", def.art_id) != null, "card " + cid)
		if def is BuildingCardDef:
			assert_true(AssetLibrary.get_texture("buildings", def.art_id) != null, "building " + cid)
		if def is DisasterCardDef:
			assert_true(AssetLibrary.get_texture("hazards", def.art_id) != null, "hazard " + cid)
	for tid: String in cat.territory_ids():
		assert_true(AssetLibrary.get_texture("territories", cat.territory(tid).art_id) != null, "territory " + tid)


func test_every_ui_asset_resolves_to_a_texture() -> void:
	for row: Array in AssetLibrary.UI_ASSETS:
		assert_true(AssetLibrary.get_texture(String(row[0]), String(row[1])) != null, String(row[1]))


func test_manifest_rows_match_asset_paths_and_are_unique() -> void:
	var rows: Array[Dictionary] = AssetLibrary.all_assets(catalog())
	var seen: Dictionary = {}
	for r: Dictionary in rows:
		var expected: String = AssetLibrary.path_for(String(r["category"]), String(r["id"]))
		assert_eq(String(r["path"]), expected)
		assert_false(seen.has(expected), "duplicate asset path " + expected)
		seen[expected] = true
		assert_true(String(r["path"]).ends_with(".png"))
		assert_true(["final", "placeholder"].has(String(r["status"])))
		assert_eq(String(r["status"]) == "final", AssetLibrary.has_final_art(String(r["category"]), String(r["id"])))
		assert_true(int(r["w"]) > 0 and int(r["h"]) > 0)
	assert_true(rows.size() > 60, "cards, tokens, hazards, regions and UI slots")


func test_placeholders_keep_the_required_aspect_ratio() -> void:
	for r: Dictionary in AssetLibrary.all_assets(catalog()):
		if String(r["status"]) == "final":
			continue
		var tex: Texture2D = AssetLibrary.get_texture(String(r["category"]), String(r["id"]))
		var want: float = float(r["w"]) / float(r["h"])
		var got: float = float(tex.get_width()) / float(tex.get_height())
		assert_true(absf(want - got) < 0.05, "%s: want %.3f got %.3f" % [r["path"], want, got])


func test_missing_asset_returns_placeholder_and_is_tracked_once() -> void:
	AssetLibrary.reset()
	var a: Texture2D = AssetLibrary.get_texture("cards", "no_such_card")
	var b: Texture2D = AssetLibrary.get_texture("cards", "no_such_card")
	assert_true(a != null)
	assert_true(a == b, "placeholder is cached")
	assert_eq(AssetLibrary.missing_paths().size(), 1)
	assert_eq(AssetLibrary.missing_paths()[0], "res://assets/art/cards/card_no_such_card.png")
	assert_true(AssetLibrary.get_texture("not_a_category", "x") != null, "unknown categories still fall back")
	AssetLibrary.reset()


func test_color_for_is_valid_for_negative_hashes() -> void:
	for id: String in ["a", "bld_seawall", "terr_coastal", "mayor_1", "zzzzzzzzzz", "dis_flood"]:
		var c: Color = AssetLibrary.color_for(id)
		assert_true(c.h >= 0.0 and c.h <= 1.0, id)


func test_missing_fonts_fall_back_to_the_engine_default() -> void:
	for slot: String in AssetLibrary.FONT_SLOTS:
		var f: Font = AssetLibrary.find_font(slot)
		if not ResourceLoader.exists("res://assets/fonts/font_%s.ttf" % slot) and not ResourceLoader.exists("res://assets/fonts/font_%s.otf" % slot):
			assert_true(f == null, slot + " should fall back")
	UiTheme.install()
	assert_true(true, "install() must not fail without fonts")


func test_game_scripts_do_not_hardcode_asset_paths() -> void:
	var offenders: Array[String] = []
	_scan("res://scripts", offenders)
	assert_eq(offenders, [] as Array[String], "asset paths belong in AssetLibrary only")


func _scan(dir_path: String, offenders: Array[String]) -> void:
	for f: String in DirAccess.get_files_at(dir_path):
		if not f.ends_with(".gd") or f == "asset_library.gd":
			continue
		var fa: FileAccess = FileAccess.open(dir_path + "/" + f, FileAccess.READ)
		if fa != null and fa.get_as_text().contains("res://assets/"):
			offenders.append(dir_path + "/" + f)
	for d: String in DirAccess.get_directories_at(dir_path):
		_scan(dir_path + "/" + d, offenders)
