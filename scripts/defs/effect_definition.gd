class_name EffectDefinition
extends Resource
## One effect from a small closed set, interpreted by the rules engine.

enum Kind { DAMAGE_REDUCTION, HEAL, REPAIR, DRAW, EXTRA_PLAY }

@export var kind: Kind = Kind.HEAL
@export var amount: int = 1
## For DAMAGE_REDUCTION only: limit to a disaster tag. Empty applies to all.
@export var tag: String = ""
