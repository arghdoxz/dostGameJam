class_name ActionFactory
extends RefCounted
## Rebuilds a GameAction from its to_dict() form (action logs, future network relay).


static func from_dict(d: Dictionary) -> GameAction:
	match String(d.get("type", "")):
		GameAction.DRAW:
			return DrawAction.from_dict(d)
		GameAction.PLAY_CARD:
			return PlayCardAction.from_dict(d)
		GameAction.RESERVE:
			return ReserveAction.from_dict(d)
		GameAction.REACT:
			return ReactAction.from_dict(d)
		GameAction.PASS_REACTION:
			return PassReactionAction.from_dict(d)
		GameAction.END_TURN:
			return EndTurnAction.from_dict(d)
	return null
