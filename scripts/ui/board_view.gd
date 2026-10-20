class_name BoardView
extends Control
## The table: seat mats around a central MapView, the two deck piles, and the acting player at
## the bottom. Seats are placed by their position relative to the actor, so whoever must act sits
## at the near edge (their hand is fanned directly below the board). Pure layout and rendering:
## it forwards clicks and never changes state.

signal draw_requested(kind: CardDefinition.DeckKind)
signal target_chosen(pid: int)

const SEAT_SIZE: Vector2 = SeatView.SEAT_SIZE
## Seat slots by player count, in turn order after the actor: 0 near, 1 left, 2 far, 3 right.
const SLOT_ORDER: Dictionary = {2: [0, 2], 3: [0, 1, 3], 4: [0, 1, 2, 3]}

var map: MapView
var last_play: LastPlayView
var _bg: TextureRect
var _seats: Dictionary = {}
var _town_pile: DeckPile
var _disaster_pile: DeckPile
var _state: MatchState
var _slots: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_bg = TextureRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.texture = AssetLibrary.get_texture("backgrounds", "table")
	add_child(_bg)
	map = MapView.new()
	map.region_pressed.connect(func(pid: int) -> void: target_chosen.emit(pid))
	add_child(map)
	last_play = LastPlayView.new()
	add_child(last_play)
	_town_pile = DeckPile.new()
	_town_pile.setup(CardDefinition.DeckKind.TOWN)
	_town_pile.draw_pressed.connect(func(k: CardDefinition.DeckKind) -> void: draw_requested.emit(k))
	add_child(_town_pile)
	_disaster_pile = DeckPile.new()
	_disaster_pile.setup(CardDefinition.DeckKind.DISASTER)
	_disaster_pile.draw_pressed.connect(func(k: CardDefinition.DeckKind) -> void: draw_requested.emit(k))
	add_child(_disaster_pile)
	resized.connect(_layout)


## statuses: pid -> status line for the seat. hints: pid -> transient line (preview text).
## targetable: pid -> bool. notes: pid -> text on the map region.
func refresh(state: MatchState, actor_id: int, statuses: Dictionary, hints: Dictionary,
		targetable: Dictionary, notes: Dictionary, last_card: CardDefinition, last_text: String) -> void:
	_state = state
	if _seats.is_empty():
		for p: PlayerState in state.players:
			var sv: SeatView = SeatView.new()
			sv.setup(p.id)
			sv.seat_pressed.connect(func(pid: int) -> void: target_chosen.emit(pid))
			add_child(sv)
			_seats[p.id] = sv
	_slots = slots_for(state, actor_id)
	for p: PlayerState in state.players:
		(_seats[p.id] as SeatView).refresh(state, String(statuses.get(p.id, "")), String(hints.get(p.id, "")),
			bool(targetable.get(p.id, false)))
	map.refresh(state, _slots, notes, targetable)
	last_play.show_play(last_card, last_text)
	_town_pile.refresh(state)
	_disaster_pile.refresh(state)
	_layout()


## Seat slot per player id, with the actor at slot 0 and the rest following in turn order.
static func slots_for(state: MatchState, actor_id: int) -> Dictionary:
	var out: Dictionary = {}
	var n: int = state.players.size()
	var order: Array = SLOT_ORDER.get(n, [0, 1, 2, 3]) as Array
	var anchor: int = maxi(0, actor_id)
	for k: int in range(n):
		out[(anchor + k) % n] = int(order[k % order.size()])
	return out


func seat_view(pid: int) -> SeatView:
	return _seats.get(pid) as SeatView


func pile(kind: CardDefinition.DeckKind) -> DeckPile:
	return _town_pile if kind == CardDefinition.DeckKind.TOWN else _disaster_pile


func _layout() -> void:
	if _state == null:
		return
	var w: float = size.x
	var h: float = size.y
	var side_w: float = SEAT_SIZE.x
	var band: float = SEAT_SIZE.y + 6.0
	map.position = Vector2(side_w + 8.0, band)
	map.size = Vector2(maxf(200.0, w - 2.0 * (side_w + 8.0)), maxf(160.0, h - 2.0 * band))
	last_play.position = Vector2(12.0, 8.0)
	last_play.size = last_play.custom_minimum_size
	for pid: int in _seats.keys():
		var sv: SeatView = _seats[pid] as SeatView
		sv.size = SEAT_SIZE
		match int(_slots.get(pid, 0)):
			0:
				sv.position = Vector2((w - SEAT_SIZE.x) * 0.5, h - SEAT_SIZE.y - 2.0)
			1:
				sv.position = Vector2(4.0, (h - SEAT_SIZE.y) * 0.5)
			2:
				sv.position = Vector2((w - SEAT_SIZE.x) * 0.5, 2.0)
			3:
				sv.position = Vector2(w - SEAT_SIZE.x - 4.0, (h - SEAT_SIZE.y) * 0.5)
	_town_pile.position = Vector2(8.0, h - _town_pile.custom_minimum_size.y - 4.0)
	_disaster_pile.position = Vector2(w - _disaster_pile.custom_minimum_size.x - 8.0, h - _disaster_pile.custom_minimum_size.y - 4.0)
