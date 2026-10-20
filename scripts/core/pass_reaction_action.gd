class_name PassReactionAction
extends GameAction
## Decline to react in the current Reaction window.


func _init(p_player: int = 0) -> void:
	type = GameAction.PASS_REACTION
	player_id = p_player


static func from_dict(d: Dictionary) -> PassReactionAction:
	var a: PassReactionAction = PassReactionAction.new()
	a._read_base(d)
	return a
