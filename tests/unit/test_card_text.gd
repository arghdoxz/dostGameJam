extends TestCase
## Player-facing text helpers. BUG-004: raw tag ids such as "storm_surge" must never reach the screen.


func test_tag_names_are_readable() -> void:
	assert_eq(CardText.tag_name("storm_surge"), "storm surge")
	assert_eq(CardText.tag_name("*"), "all")
	assert_eq(CardText.tag_list(PackedStringArray(["storm_surge", "typhoon"])), "storm surge, typhoon")


func test_no_card_text_shows_an_underscore_id() -> void:
	var cat: ContentCatalog = catalog()
	for id: String in cat.card_ids():
		var def: CardDefinition = cat.card(id)
		var text: String = CardText.full_text(def, cat)
		assert_false(text.contains("_"), "%s text shows a raw id: %s" % [id, text])
