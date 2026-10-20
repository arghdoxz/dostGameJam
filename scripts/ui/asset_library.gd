class_name AssetLibrary
extends RefCounted
## The only place that knows where art lives. Everything else asks for (category, id).
## If the artist's file is missing a generated placeholder with the right aspect ratio is
## returned, and a single warning is logged. A missing asset never crashes the game.
## Final art path: res://assets/art/<category>/<prefix>_<id>.png (see docs/ART_PIPELINE.md).
## all_assets() lists every asset for assets/ASSET_MANIFEST.md (tools/generate_asset_manifest.gd).

## Per category: filename prefix, required pixel size (w, h), whether it needs transparency,
## and what placeholder shape to generate. Size is a hard requirement only for the aspect ratio.
const CATEGORIES: Dictionary = {
	"cards": {"prefix": "card", "w": 750, "h": 1050, "alpha": false, "shape": "card",
		"purpose": "Card face illustration"},
	"buildings": {"prefix": "building", "w": 512, "h": 512, "alpha": true, "shape": "token",
		"purpose": "Standing building token on the map"},
	"territories": {"prefix": "territory", "w": 512, "h": 512, "alpha": true, "shape": "region",
		"purpose": "Territory region tile on the map"},
	"hazards": {"prefix": "hazard", "w": 256, "h": 256, "alpha": true, "shape": "diamond",
		"purpose": "Forecast / hazard token on a threatened region"},
	"portraits": {"prefix": "portrait", "w": 256, "h": 256, "alpha": false, "shape": "token",
		"purpose": "Mayor portrait on a player mat"},
	"icons": {"prefix": "icon", "w": 128, "h": 128, "alpha": true, "shape": "token",
		"purpose": "Small UI icon"},
	"backgrounds": {"prefix": "background", "w": 1920, "h": 1080, "alpha": false, "shape": "plain",
		"purpose": "Full-screen or table background"},
	"ui": {"prefix": "ui", "w": 750, "h": 1050, "alpha": true, "shape": "plain",
		"purpose": "UI frame, card back or panel art"},
}

## Assets that are not derived from game content. [category, id, purpose, w, h]
## w/h of 0 means "use the category default".
const UI_ASSETS: Array = [
	["backgrounds", "menu", "Main menu and setup background", 0, 0],
	["backgrounds", "table", "Table surface behind the board", 0, 0],
	["backgrounds", "map_board", "Center map plane (drawn with a perspective skew)", 1600, 1000],
	["ui", "card_back_town", "Face-down Town card (decks, opponent hands)", 0, 0],
	["ui", "card_back_disaster", "Face-down Disaster card (deck, opponent hands)", 0, 0],
	["ui", "card_frame_resource", "Frame overlay for Resource cards", 0, 0],
	["ui", "card_frame_building", "Frame overlay for Building cards", 0, 0],
	["ui", "card_frame_preparedness", "Frame overlay for Preparedness cards", 0, 0],
	["ui", "card_frame_reaction", "Frame overlay for Reaction cards", 0, 0],
	["ui", "card_frame_disaster", "Frame overlay for Disaster cards", 0, 0],
	["ui", "seat_mat", "Player mat behind name, RP and card fan", 600, 200],
	["buildings", "town_hall", "Town Hall token (every town has one)", 0, 0],
	["portraits", "mayor_1", "Mayor portrait, seat 1", 0, 0],
	["portraits", "mayor_2", "Mayor portrait, seat 2", 0, 0],
	["portraits", "mayor_3", "Mayor portrait, seat 3", 0, 0],
	["portraits", "mayor_4", "Mayor portrait, seat 4", 0, 0],
	["icons", "rp", "Resilience Points", 0, 0],
	["icons", "durability", "Building durability", 0, 0],
	["icons", "reserve", "Reserve", 0, 0],
	["icons", "materials", "Materials resource", 0, 0],
	["icons", "funds", "Funds resource", 0, 0],
	["icons", "supplies", "Supplies resource", 0, 0],
	["icons", "forecast", "Forecast warning", 0, 0],
	["icons", "level_1", "Minor disaster (level 1)", 0, 0],
	["icons", "level_2", "Severe disaster (level 2)", 0, 0],
	["icons", "level_3", "Catastrophic disaster (level 3)", 0, 0],
	["icons", "eliminated", "Eliminated town", 0, 0],
	["icons", "turn_marker", "Active player / turn direction marker", 0, 0],
]

const FONT_SLOTS: Array[String] = ["body", "heading"]
const FONT_EXTENSIONS: Array[String] = ["ttf", "otf"]

static var _cache: Dictionary = {}
static var _missing: Dictionary = {}
static var _warned: bool = false


static func category_info(category: String) -> Dictionary:
	return CATEGORIES.get(category, {"prefix": category, "w": 256, "h": 256, "alpha": true,
		"shape": "plain", "purpose": "Unregistered category"}) as Dictionary


static func path_for(category: String, art_id: String) -> String:
	var prefix: String = String(category_info(category)["prefix"])
	return "res://assets/art/%s/%s_%s.png" % [category, prefix, art_id]


static func has_final_art(category: String, art_id: String) -> bool:
	return ResourceLoader.exists(path_for(category, art_id))


static func get_texture(category: String, art_id: String) -> Texture2D:
	var path: String = path_for(category, art_id)
	if _cache.has(path):
		return _cache[path] as Texture2D
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		_note_missing(path)
		tex = _make_placeholder(category, art_id)
	_cache[path] = tex
	return tex


## Paths of every placeholder that has been requested so far.
static func missing_paths() -> Array[String]:
	var out: Array[String] = []
	for k: Variant in _missing.keys():
		out.append(String(k))
	out.sort()
	return out


## Clears caches. Tests use this; the editor does too after the artist drops in new files.
static func reset() -> void:
	_cache.clear()
	_missing.clear()
	_warned = false


static func _note_missing(path: String) -> void:
	_missing[path] = true
	if not _warned:
		_warned = true
		push_warning("AssetLibrary: using placeholder art for missing files (first: %s). Run tools/generate_asset_manifest.gd for the full list." % path)


## Font for a slot ("body" or "heading") from assets/fonts/font_<slot>.ttf|otf, or null so the
## engine default font is used.
static func find_font(slot: String) -> Font:
	for ext: String in FONT_EXTENSIONS:
		var path: String = "res://assets/fonts/font_%s.%s" % [slot, ext]
		if ResourceLoader.exists(path):
			var f: Font = load(path) as Font
			if f != null:
				return f
	return null


## Stable color for an id. abs() keeps the hue valid for negative hashes.
static func color_for(art_id: String) -> Color:
	return Color.from_hsv(float(absi(art_id.hash()) % 360) / 360.0, 0.35, 0.75)


## Every asset slot in the game: content-derived and UI. Each entry is
## {category, id, path, w, h, alpha, purpose, status}. catalog may be null (UI assets only).
static func all_assets(catalog: ContentCatalog) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if catalog != null:
		for cid: String in _sorted(catalog.card_ids()):
			var def: CardDefinition = catalog.card(cid)
			out.append(_entry("cards", def.art_id, "Card art: " + def.display_name, 0, 0))
			if def is BuildingCardDef:
				out.append(_entry("buildings", def.art_id, "Building token: " + def.display_name, 0, 0))
			if def is DisasterCardDef:
				out.append(_entry("hazards", def.art_id, "Hazard token: " + def.display_name, 0, 0))
		for tid: String in _sorted(catalog.territory_ids()):
			var t: TerritoryDefinition = catalog.territory(tid)
			out.append(_entry("territories", t.art_id, "Map region: " + t.display_name, 0, 0))
	for row: Array in UI_ASSETS:
		out.append(_entry(String(row[0]), String(row[1]), String(row[2]), int(row[3]), int(row[4])))
	return out


static func _entry(category: String, art_id: String, purpose: String, w: int, h: int) -> Dictionary:
	var info: Dictionary = category_info(category)
	return {
		"category": category, "id": art_id, "path": path_for(category, art_id),
		"w": w if w > 0 else int(info["w"]), "h": h if h > 0 else int(info["h"]),
		"alpha": bool(info["alpha"]), "purpose": purpose,
		"status": "final" if has_final_art(category, art_id) else "placeholder",
	}


static func _sorted(items: Array[String]) -> Array[String]:
	var copy: Array[String] = items.duplicate()
	copy.sort()
	return copy


## Placeholder size is a tenth of the real size (min 16 px) so it keeps the aspect ratio
## but stays cheap. The size of a few UI assets is overridden by UI_ASSETS.
static func _placeholder_size(category: String, art_id: String) -> Vector2i:
	var w: int = int(category_info(category)["w"])
	var h: int = int(category_info(category)["h"])
	for row: Array in UI_ASSETS:
		if String(row[0]) == category and String(row[1]) == art_id and int(row[3]) > 0:
			w = int(row[3])
			h = int(row[4])
	return Vector2i(maxi(16, w / 10), maxi(16, h / 10))


static func _make_placeholder(category: String, art_id: String) -> Texture2D:
	var info: Dictionary = category_info(category)
	var size: Vector2i = _placeholder_size(category, art_id)
	var img: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var base: Color = color_for(art_id)
	if category == "backgrounds":
		base = base.darkened(0.7)
	var edge: Color = base.darkened(0.5)
	var shape: String = String(info["shape"])
	img.fill(Color(0, 0, 0, 0) if bool(info["alpha"]) else base)
	match shape:
		"card":
			_border(img, edge, 2)
		"plain":
			if art_id == "map_board":
				_parchment(img)
			elif art_id.begins_with("card_frame"):
				img.fill(Color(0, 0, 0, 0))
				_border(img, edge, 2)
			elif bool(info["alpha"]):
				img.fill(base)
				_border(img, edge, 2)
			else:
				_border(img, edge, 2)
		"token":
			_ellipse(img, base, edge)
		"region":
			_ellipse(img, base.lightened(0.15), edge)
		"diamond":
			_diamond(img, base, edge)
	return ImageTexture.create_from_image(img)


static func _border(img: Image, c: Color, t: int) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	for x: int in range(w):
		for k: int in range(t):
			img.set_pixel(x, k, c)
			img.set_pixel(x, h - 1 - k, c)
	for y: int in range(h):
		for k: int in range(t):
			img.set_pixel(k, y, c)
			img.set_pixel(w - 1 - k, y, c)


static func _ellipse(img: Image, fill: Color, edge: Color) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var cx: float = (w - 1) * 0.5
	var cy: float = (h - 1) * 0.5
	for y: int in range(h):
		for x: int in range(w):
			var dx: float = (x - cx) / (w * 0.48)
			var dy: float = (y - cy) / (h * 0.48)
			var d: float = dx * dx + dy * dy
			if d <= 1.0:
				img.set_pixel(x, y, edge if d > 0.82 else fill)


static func _diamond(img: Image, fill: Color, edge: Color) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var cx: float = (w - 1) * 0.5
	var cy: float = (h - 1) * 0.5
	for y: int in range(h):
		for x: int in range(w):
			var d: float = absf(x - cx) / (w * 0.48) + absf(y - cy) / (h * 0.48)
			if d <= 1.0:
				img.set_pixel(x, y, edge if d > 0.82 else fill)


static func _parchment(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var paper: Color = Color(0.86, 0.78, 0.6)
	var line: Color = Color(0.62, 0.52, 0.36)
	img.fill(paper)
	for x: int in range(0, w, maxi(1, w / 16)):
		for y: int in range(h):
			img.set_pixel(x, y, line)
	for y: int in range(0, h, maxi(1, h / 10)):
		for x: int in range(w):
			img.set_pixel(x, y, line)
	_border(img, line.darkened(0.3), 2)
