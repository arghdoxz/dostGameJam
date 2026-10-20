class_name UiTheme
extends RefCounted
## Applies the artist's fonts to the project theme and defines shared type variations.
## Fonts come from AssetLibrary.find_font(), so dropping assets/fonts/font_body.ttf and
## font_heading.ttf restyles every screen. Missing fonts leave the engine default.

const HEADING: StringName = &"HeadingLabel"
const SMALL: StringName = &"SmallLabel"


## Call once at startup (App._ready). Safe to call again; it only sets theme properties.
static func install() -> void:
	var theme: Theme = ThemeDB.get_project_theme()
	if theme == null:
		return
	theme.set_type_variation(HEADING, "Label")
	theme.set_font_size("font_size", HEADING, 26)
	theme.set_type_variation(SMALL, "Label")
	theme.set_font_size("font_size", SMALL, 13)
	var body: Font = AssetLibrary.find_font("body")
	if body != null:
		theme.default_font = body
	var heading: Font = AssetLibrary.find_font("heading")
	if heading != null:
		theme.set_font("font", HEADING, heading)


## Adds a full-screen background (AssetLibrary "backgrounds", with a dark scrim for legibility)
## as the bottom-most child of parent.
static func add_background(parent: Control, background_id: String) -> void:
	var tex: TextureRect = TextureRect.new()
	tex.texture = AssetLibrary.get_texture("backgrounds", background_id)
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tex)
	parent.move_child(tex, 0)
	var scrim: ColorRect = ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.45)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(scrim)
	parent.move_child(scrim, 1)


static func heading_label(text: String) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.theme_type_variation = HEADING
	return l


static func small_label(text: String = "") -> Label:
	var l: Label = Label.new()
	l.text = text
	l.theme_type_variation = SMALL
	return l
