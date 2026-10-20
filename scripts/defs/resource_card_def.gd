class_name ResourceCardDef
extends CardDefinition
## A resource card. It is the currency: costs are paid by discarding these.

const KIND_MATERIALS: String = "materials"
const KIND_FUNDS: String = "funds"
const KIND_SUPPLIES: String = "supplies"

@export var resource_kind: String = KIND_MATERIALS
