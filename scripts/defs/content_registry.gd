class_name ContentRegistry
extends Resource
## Explicit list of every definition (directory scanning is unreliable in exports).

@export var cards: Array[CardDefinition] = []
@export var territories: Array[TerritoryDefinition] = []
@export var default_config: MatchConfig
