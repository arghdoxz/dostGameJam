class_name MapView
extends Control
## The battle map at the center of the table. A parchment plane drawn as a trapezoid (perspective)
## with one region per player, placed toward that player's seat. Buildings stand on their region
## as tokens and forecasts as hazard tokens. Regions are click targets for disasters.
## Everything is placeholder art; REGION_SLOTS and the plane shape are the only layout data an
## artist's final map needs adjusted (see docs/ART_PIPELINE.md).

signal region_pressed(pid: int)

## Normalized plane coordinates (u across, v from far edge 0 to near edge 1) per seat slot:
## 0 = near (bottom, the acting player), 1 = left, 2 = far (top), 3 = right.
## Entries: [center_u, center_v, half_width_u, half_height_v].
const REGION_SLOTS: Array = [
	[0.5, 0.79, 0.19, 0.20],
	[0.16, 0.50, 0.15, 0.20],
	[0.5, 0.21, 0.19, 0.20],
	[0.84, 0.50, 0.15, 0.20],
]
const FAR_WIDTH_RATIO: float = 0.74
const BANDS: int = 8

var _regions: Dictionary = {}
var _slots: Dictionary = {}
var _notes: Dictionary = {}
var _targetable: Dictionary = {}
var _hit_uids: Array[int] = []
var _state: MatchState


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_layout)


## Maps plane coordinates to control coordinates (perspective: the far edge is narrower).
func project(u: float, v: float) -> Vector2:
	var margin: float = 4.0
	var top_w: float = size.x * FAR_WIDTH_RATIO
	var w: float = lerpf(top_w, size.x - margin * 2.0, v)
	var x: float = (size.x - w) * 0.5 + u * w
	var y: float = lerpf(margin, size.y - margin, v)
	return Vector2(x, y)


## Records which building uids were just damaged so their tokens pulse on the next refresh.
func note_damaged(uids: Array[int]) -> void:
	_hit_uids.append_array(uids)


## slots: pid -> seat slot (0 near, 1 left, 2 far, 3 right). notes: pid -> text for the region.
## targetable: pid -> true when clicking the region chooses it as a target.
func refresh(state: MatchState, slots: Dictionary, notes: Dictionary, targetable: Dictionary) -> void:
	_state = state
	_slots = slots
	_notes = notes
	_targetable = targetable
	for pid: int in _regions.keys():
		(_regions[pid] as Control).queue_free()
	_regions.clear()
	for p: PlayerState in state.players:
		var region: Control = _build_region(state, p)
		add_child(region)
		_regions[p.id] = region
	_hit_uids.clear()
	_layout()
	queue_redraw()


func _build_region(state: MatchState, p: PlayerState) -> Control:
	var terr: TerritoryDefinition = state.catalog.territory(p.territory_id)
	var r: Control = Control.new()
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	r.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed \
				and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			region_pressed.emit(p.id))
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(box)
	var title: Label = UiTheme.small_label("%s: %s" % [terr.display_name, p.display_name])
	title.clip_text = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	box.add_child(title)
	var note: String = String(_notes.get(p.id, ""))
	if p.eliminated:
		note = "ELIMINATED"
	var note_label: Label = UiTheme.small_label(note)
	note_label.clip_text = true
	note_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note_label.add_theme_color_override("font_color", Color(0.55, 0.05, 0.02))
	note_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	box.add_child(note_label)
	if not p.eliminated:
		var flow: HFlowContainer = HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 2)
		flow.add_theme_constant_override("v_separation", 0)
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(flow)
		var hall: BuildingToken = BuildingToken.new()
		hall.setup_town_hall()
		hall.mouse_filter = Control.MOUSE_FILTER_PASS
		flow.add_child(hall)
		for b: BuildingInstance in p.buildings:
			var t: BuildingToken = BuildingToken.new()
			t.setup(state, b)
			t.mouse_filter = Control.MOUSE_FILTER_PASS
			flow.add_child(t)
			if _hit_uids.has(b.uid):
				t.pulse()
		for f: PendingDisaster in state.forecasts:
			if f.targets.has(p.id):
				var m: ForecastMarker = ForecastMarker.new()
				m.setup(state, f, p.id)
				box.add_child(m)
	return r


func _layout() -> void:
	if _state == null:
		return
	for pid: int in _regions.keys():
		var slot: Array = REGION_SLOTS[int(_slots.get(pid, 0)) % REGION_SLOTS.size()]
		var cu: float = float(slot[0])
		var cv: float = float(slot[1])
		var hu: float = float(slot[2])
		var hv: float = float(slot[3])
		var tl: Vector2 = project(cu - hu, cv - hv)
		var br: Vector2 = project(cu + hu, cv + hv)
		var bl: Vector2 = project(cu - hu, cv + hv)
		var tr: Vector2 = project(cu + hu, cv - hv)
		var x0: float = maxf(tl.x, bl.x) + 4.0
		var x1: float = minf(tr.x, br.x) - 4.0
		var region: Control = _regions[pid] as Control
		region.position = Vector2(x0, tl.y + 3.0)
		region.size = Vector2(maxf(40.0, x1 - x0), maxf(40.0, br.y - tl.y - 6.0))
		var s: float = lerpf(0.82, 1.0, cv)
		region.pivot_offset = Vector2(region.size.x * 0.5, 0.0)
		region.scale = Vector2(s, s)
	queue_redraw()


func _draw() -> void:
	# Plane shadow, then the textured plane in bands so the perspective squash looks even.
	var shadow: PackedVector2Array = PackedVector2Array([
		project(0, 0) + Vector2(8, 10), project(1, 0) + Vector2(8, 10),
		project(1, 1) + Vector2(8, 10), project(0, 1) + Vector2(8, 10)])
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.38))
	_textured_quad(0.0, 0.0, 1.0, 1.0, AssetLibrary.get_texture("backgrounds", "map_board"), Color(1, 1, 1), BANDS)
	draw_polyline(PackedVector2Array([project(0, 0), project(1, 0), project(1, 1), project(0, 1), project(0, 0)]),
		Color(0.32, 0.22, 0.1), 3.0)
	if _state == null:
		return
	for p: PlayerState in _state.players:
		var slot: Array = REGION_SLOTS[int(_slots.get(p.id, 0)) % REGION_SLOTS.size()]
		var u0: float = float(slot[0]) - float(slot[2])
		var u1: float = float(slot[0]) + float(slot[2])
		var v0: float = float(slot[1]) - float(slot[3])
		var v1: float = float(slot[1]) + float(slot[3])
		var terr: TerritoryDefinition = _state.catalog.territory(p.territory_id)
		var tint: Color = Color(0.55, 0.55, 0.55, 0.85) if p.eliminated else Color(1, 1, 1, 0.9)
		_textured_quad(u0, v0, u1, v1, AssetLibrary.get_texture("territories", terr.art_id), tint, 4)
		var flagged: bool = _targetable.get(p.id, false) or String(_notes.get(p.id, "")) != ""
		var line_color: Color = Color(0.85, 0.2, 0.1) if flagged else Color(0.35, 0.25, 0.12)
		draw_polyline(PackedVector2Array([project(u0, v0), project(u1, v0), project(u1, v1), project(u0, v1), project(u0, v0)]),
			line_color, 5.0 if flagged else 2.0)


## Draws a plane rectangle [u0,u1]x[v0,v1] using texture uv 0..1 across it, in horizontal bands.
## For the whole plane (0..1) the texture maps one to one.
func _textured_quad(u0: float, v0: float, u1: float, v1: float, tex: Texture2D, tint: Color, bands: int) -> void:
	for i: int in range(bands):
		var ta: float = float(i) / float(bands)
		var tb: float = float(i + 1) / float(bands)
		var va: float = lerpf(v0, v1, ta)
		var vb: float = lerpf(v0, v1, tb)
		var pts: PackedVector2Array = PackedVector2Array([
			project(u0, va), project(u1, va), project(u1, vb), project(u0, vb)])
		var uvs: PackedVector2Array = PackedVector2Array([
			Vector2(0, ta), Vector2(1, ta), Vector2(1, tb), Vector2(0, tb)])
		draw_colored_polygon(pts, tint, uvs, tex)
