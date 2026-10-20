class_name BuildingToken
extends Control
## A standing building mini on the map: token art, drop shadow and a durability readout
## ("2/3"). The Town Hall is the same component without durability.

const TOKEN_SIZE: Vector2 = Vector2(66, 84)

var _art: TextureRect
var _label: Label


func _init() -> void:
	custom_minimum_size = TOKEN_SIZE
	size = TOKEN_SIZE
	_art = TextureRect.new()
	_art.position = Vector2(9, 0)
	_art.size = Vector2(48, 48)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	_label = UiTheme.small_label()
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", Color(0.1, 0.07, 0.04))
	_label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.5))
	_label.position = Vector2(0, 50)
	_label.size = Vector2(TOKEN_SIZE.x, 32)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.clip_text = true
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func setup(state: MatchState, b: BuildingInstance) -> void:
	var def: CardDefinition = state.catalog.card(b.def_id)
	var max_dur: int = state.catalog.building(b.def_id).durability
	_art.texture = AssetLibrary.get_texture("buildings", def.art_id)
	_label.text = "%s\n%d/%d" % [_short(def.display_name), b.durability, max_dur]
	tooltip_text = "%s: durability %d of %d\n%s" % [def.display_name, b.durability, max_dur,
		CardText.rules_text(def, state.catalog)]


func setup_town_hall() -> void:
	_art.texture = AssetLibrary.get_texture("buildings", "town_hall")
	_label.text = "Town Hall"
	tooltip_text = "Town Hall: every town has one. It gives no damage reduction."


## Brief scale pulse so a hit building is noticeable. Text still states the new durability.
func pulse() -> void:
	pivot_offset = TOKEN_SIZE * 0.5
	var tw: Tween = create_tween()
	tw.tween_property(self, "scale", Vector2(1.3, 1.3), 0.12)
	tw.tween_property(self, "scale", Vector2.ONE, 0.18)


func _draw() -> void:
	draw_set_transform(Vector2(TOKEN_SIZE.x * 0.5, 48), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _short(n: String) -> String:
	return n if n.length() <= 10 else n.substr(0, 9) + "."
