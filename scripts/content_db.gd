extends Node
## Autoload. Loads the content registry once and exposes a ContentCatalog.
## Core rules code never touches this node; it receives the catalog by injection.

const REGISTRY_PATH: String = "res://content/content_registry.tres"

var catalog: ContentCatalog
var load_errors: PackedStringArray = PackedStringArray()


func _ready() -> void:
	reload()


func reload() -> void:
	var reg: ContentRegistry = load(REGISTRY_PATH) as ContentRegistry
	if reg == null:
		push_error("ContentDB: cannot load " + REGISTRY_PATH + " (run tools/generate_content.gd)")
		catalog = ContentCatalog.new()
		load_errors = PackedStringArray(["Registry missing"])
		return
	catalog = ContentCatalog.from_registry(reg)
	load_errors = catalog.errors
	for e: String in load_errors:
		push_error("ContentDB: " + e)
