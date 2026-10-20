class_name DrawAction
extends GameAction
## Draw one card from the chosen deck at the start of the turn (rule R1).

var deck: CardDefinition.DeckKind = CardDefinition.DeckKind.TOWN


func _init(p_player: int = 0, p_deck: CardDefinition.DeckKind = CardDefinition.DeckKind.TOWN) -> void:
	type = GameAction.DRAW
	player_id = p_player
	deck = p_deck


func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["deck"] = int(deck)
	return d


static func from_dict(d: Dictionary) -> DrawAction:
	var a: DrawAction = DrawAction.new()
	a._read_base(d)
	a.deck = int(d.get("deck", 0)) as CardDefinition.DeckKind
	return a
