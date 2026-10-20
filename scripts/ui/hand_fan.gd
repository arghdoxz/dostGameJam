class_name HandFan
extends Control
## The active player's hand, fanned along an arc with tilt, overlap and shadows (the bottom of
## the table). Hover lifts a card; the selected card is raised and outlined. It only reports
## which card was clicked; ActionPanel decides what can be done with it.

signal card_selected(uid: int)

const TITLE_HEIGHT: float = 24.0
const MAX_TILT_DEG: float = 4.0
const TILT_MARGIN: float = 48.0

var _title: Label
var _cards: Array[CardView] = []
var _selected_uid: int = -1
var _hover_uid: int = -1


func _ready() -> void:
	custom_minimum_size = Vector2(0, 232)
	_title = Label.new()
	_title.position = Vector2(8, 0)
	_title.z_index = 200  # a lifted card must not cover the hand count (BUG-015)
	add_child(_title)
	resized.connect(_layout)


func selected_uid() -> int:
	return _selected_uid


## Screen rectangle of the first card with this definition id (for the tutorial outline), or an empty Rect2.
func card_rect(def_id: String) -> Rect2:
	for c: CardView in _cards:
		if c.def != null and c.def.id == def_id:
			return c.get_global_rect()
	return Rect2()


func select(uid: int) -> void:
	_selected_uid = uid
	for c: CardView in _cards:
		c.selected = c.uid == uid
		c.setup(c.def, c.uid, c.playable, c.selected)
	_layout()


## reasons maps card uid -> why it cannot be used right now ("" or missing when it can).
func refresh(state: MatchState, actor_id: int, reasons: Dictionary) -> void:
	for c: CardView in _cards:
		c.queue_free()
	_cards.clear()
	if state == null or actor_id < 0 or state.is_over():
		_title.text = ""
		return
	var player: PlayerState = state.players[actor_id]
	_title.text = "%s's hand: %d card(s), limit %d" % [player.display_name, player.hand.size(), state.config.hand_limit]
	var still_here: bool = false
	for card: CardInstance in player.hand:
		if card.uid == _selected_uid:
			still_here = true
		var reason: String = String(reasons.get(card.uid, ""))
		var cv: CardView = CardView.new()
		add_child(cv)
		cv.setup(state.catalog.card(card.def_id), card.uid, reason == "", card.uid == _selected_uid)
		if reason != "":
			cv.tooltip_text += "\nNot usable: " + reason
		cv.card_pressed.connect(_on_pressed)
		cv.card_hovered.connect(_on_hovered)
		_cards.append(cv)
	if not still_here:
		_selected_uid = -1
	_layout()


func _on_pressed(uid: int) -> void:
	_selected_uid = -1 if uid == _selected_uid else uid
	card_selected.emit(_selected_uid)


func _on_hovered(uid: int, hovering: bool) -> void:
	_hover_uid = uid if hovering else -1
	_layout(true)


func _layout(animate: bool = false) -> void:
	var n: int = _cards.size()
	if n == 0:
		return
	var w: float = size.x
	var card_w: float = CardView.CARD_SIZE.x
	# The outer cards tilt up to MAX_TILT_DEG * 3 about their bottom centre, which swings their top
	# corners about TILT_MARGIN pixels past the fan's ends. Keep that room free (BUG-014).
	var step: float = minf(card_w * 0.82, (w - card_w - 2.0 * TILT_MARGIN) / maxf(1.0, float(n - 1)))
	var total: float = step * float(n - 1) + card_w
	var x0: float = (w - total) * 0.5
	var base_y: float = size.y - CardView.CARD_SIZE.y - 30.0
	for i: int in range(n):
		var c: CardView = _cards[i]
		var off: float = float(i) - float(n - 1) * 0.5
		var lift: float = 0.0
		if c.uid == _selected_uid:
			lift = 34.0
		elif c.uid == _hover_uid:
			lift = 18.0
		var target: Vector2 = Vector2(x0 + step * float(i), base_y + off * off * 0.8 - lift)
		var rot: float = deg_to_rad(clampf(off * 2.4, -MAX_TILT_DEG * 3.0, MAX_TILT_DEG * 3.0))
		c.z_index = 100 if (c.uid == _hover_uid or c.uid == _selected_uid) else i
		if animate:
			var tw: Tween = c.create_tween()
			tw.set_parallel(true)
			tw.tween_property(c, "position", target, 0.09)
			tw.tween_property(c, "rotation", rot, 0.09)
		else:
			c.position = target
			c.rotation = rot
