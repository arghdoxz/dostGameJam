class_name BackFan
extends Control
## A small fan of face-down cards (an opponent's hidden hand). Only the count is public.

const CARD: Vector2 = Vector2(34, 48)
const MAX_SHOWN: int = 9

var count: int = 0
var deck_kind: CardDefinition.DeckKind = CardDefinition.DeckKind.TOWN


func _init() -> void:
	custom_minimum_size = Vector2(110, 62)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_count(n: int) -> void:
	count = n
	queue_redraw()


func _draw() -> void:
	var shown: int = mini(count, MAX_SHOWN)
	if shown == 0:
		return
	var tex: Texture2D = AssetLibrary.get_texture("ui", "card_back_town")
	for i: int in range(shown):
		var off: float = float(i) - float(shown - 1) * 0.5
		var pivot: Vector2 = Vector2(size.x * 0.5 + off * 9.0, size.y - 2.0)
		draw_set_transform(pivot, deg_to_rad(off * 7.0), Vector2.ONE)
		var r: Rect2 = Rect2(Vector2(-CARD.x * 0.5, -CARD.y), CARD)
		draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.35))
		draw_texture_rect(tex, r, false)
		draw_rect(r, Color(0.05, 0.04, 0.06), false, 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
