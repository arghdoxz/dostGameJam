extends SceneTree
## Headless test runner (no addons needed).
## Run: godot --headless --path . -s res://tests/run_tests.gd
## Optional filter: ... -s res://tests/run_tests.gd -- test_damage
## Exit code is 0 only if every test passed.

const TEST_DIRS: Array[String] = ["res://tests/unit", "res://tests/integration"]


func _init() -> void:
	var filter: String = ""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]
	var passed: int = 0
	var failed: int = 0
	var failed_names: PackedStringArray = PackedStringArray()
	for dir_path: String in TEST_DIRS:
		var files: PackedStringArray = DirAccess.get_files_at(dir_path)
		files.sort()
		for f: String in files:
			if not f.begins_with("test_") or not f.ends_with(".gd"):
				continue
			if filter != "" and not f.contains(filter):
				continue
			var script: GDScript = load(dir_path + "/" + f) as GDScript
			if script == null:
				failed += 1
				failed_names.append(f + " (failed to load)")
				continue
			var methods: Array[String] = []
			for m: Dictionary in script.get_script_method_list():
				var mn: String = String(m["name"])
				if mn.begins_with("test_"):
					methods.append(mn)
			methods.sort()
			for mn: String in methods:
				var t: TestCase = script.new() as TestCase
				t.call(mn)
				var label: String = "%s::%s" % [f, mn]
				if t.assertion_count == 0:
					t.failures.append("no assertions ran (test may have aborted)")
				if t.failures.is_empty():
					passed += 1
					print("PASS  ", label, " (", t.assertion_count, " assertions)")
				else:
					failed += 1
					failed_names.append(label)
					print("FAIL  ", label)
					for msg: String in t.failures:
						print("      - ", msg)
	print("")
	print("Tests passed: %d, failed: %d" % [passed, failed])
	for n: String in failed_names:
		print("  FAILED: ", n)
	quit(0 if failed == 0 else 1)
