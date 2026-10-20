class_name DisasterDefinition
extends Resource
## Static disaster data. A DisasterCardDef points to one of these.

enum Targeting { ALL_OPPONENTS, SINGLE_OPPONENT, OPPONENTS_WITHOUT_BUILDING }
enum SecondaryKind { NONE, EXTRA_BUILDING_DAMAGE, DISCARD_RESERVE, DISCARD_RANDOM_HAND }

@export var id: String = ""
@export var level: int = 1
@export var damage_min: int = 2
@export var damage_max: int = 3
@export var tags: PackedStringArray = PackedStringArray()
@export var targeting: Targeting = Targeting.ALL_OPPONENTS
## For OPPONENTS_WITHOUT_BUILDING: building id that exempts a player.
@export var condition_building_id: String = ""
@export var secondary_kind: SecondaryKind = SecondaryKind.NONE
@export var secondary_amount: int = 1
