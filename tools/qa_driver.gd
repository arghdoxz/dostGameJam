extends SceneTree
## QA driver: plays the real game through the real UI by sending synthesized mouse and keyboard
## events at screen positions, and saves screenshots. It never calls MatchController.submit, so
## Godot's own hit-testing, modal blocking and disabled states decide what a click does.
## Needs a real window (not --headless).
##
## Interactive mode (a person or an agent types commands into a file and reads the results):
##   godot --path . -s res://tools/qa_driver.gd -- --io C:/some/dir
##   writes commands to <dir>/cmd.txt, results go to <dir>/out.txt ("BATCH n DONE" ends a batch)
## Replay mode (a saved command list, used for regression runs and the demo video):
##   godot --path . -s res://tools/qa_driver.gd -- --script docs/demo/demo_commands.txt --shots C:/dir
## Options: --shots <dir> (default docs/qa/screenshots), --size WxH (default 1600x900), --keep (do not quit at the end)
##
## Commands (one per line, # starts a comment):
##   wait <frames> | wait_s <seconds>
##   click_text <button text> | click_card <name or index> | click_pile town|disaster
##   click_seat <player name> | click_region <player name> | click_xy <x> <y> | hover_card <name> | hover <x> <y>
##   key <KeyName> | type <text>
##   shot <name> | dump | audit | resize <w> <h> | caption <text> | caption_off | quit
##   auto <n> | auto_seed <n>   (play up to n UI actions with a simple heuristic, still by real clicks)
##   debug_give <pid> <card id> | debug_rp <pid> <rp> | debug_disaster <caster> <card id> <target>
##     (the debug_* commands bypass the rules; QA notes must label any run that uses them)

var _io_dir: String = ""
var _shots_dir: String = "res://docs/qa/screenshots"
var _queue: Array[String] = []
var _wait: int = 0
var _wait_until_ms: int = 0
var _batch: int = 0
var _batch_open: bool = false
var _out: FileAccess
var _replay: bool = false
var _keep: bool = false
var _caption: Label
var _caption_layer: CanvasLayer
const AUTO_SHOT_CAP: int = 40

var _auto_left: int = 0
var _auto_shots: int = 0
var _auto_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var size_arg: String = "1600x900"
	var script_path: String = ""
	var i: int = 0
	while i < args.size():
		match args[i]:
			"--io":
				_io_dir = args[i + 1]
				i += 1
			"--script":
				script_path = args[i + 1]
				i += 1
			"--shots":
				_shots_dir = args[i + 1]
				i += 1
			"--size":
				size_arg = args[i + 1]
				i += 1
			"--keep":
				_keep = true
		i += 1
	var parts: PackedStringArray = size_arg.split("x")
	root.size = Vector2i(int(parts[0]), int(parts[1]))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_shots_dir))
	if _io_dir != "":
		DirAccess.make_dir_recursive_absolute(_io_dir)
		_out = FileAccess.open(_io_dir + "/out.txt", FileAccess.WRITE)
		var f: FileAccess = FileAccess.open(_io_dir + "/cmd.txt", FileAccess.WRITE)
		f.close()
	if script_path != "":
		_replay = true
		var sf: FileAccess = FileAccess.open(ProjectSettings.globalize_path(script_path) if script_path.begins_with("res://") else script_path, FileAccess.READ)
		if sf == null:
			push_error("QA: cannot open script " + script_path)
			quit(1)
			return
		for line: String in sf.get_as_text().split("\n"):
			_queue.append(line)
	var app: Node = (load("res://scenes/boot/app.tscn") as PackedScene).instantiate()
	app.name = "App"
	root.add_child(app)
	_say("QA driver ready. window=%s shots=%s" % [str(root.size), ProjectSettings.globalize_path(_shots_dir)])


func _say(line: String) -> void:
	print("[QA] ", line)
	if _out != null:
		_out.store_line(line)


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	if _wait_until_ms > Time.get_ticks_msec():
		return false
	if _queue.is_empty() and not _replay:
		_poll_file()
	while not _queue.is_empty():
		var line: String = _queue.pop_front().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		_run(line)
		if _wait > 0 or _wait_until_ms > Time.get_ticks_msec():
			return false
	if _batch_open:
		_batch_open = false
		_say("BATCH %d DONE" % _batch)
		if _out != null:
			_out.flush()
	if _replay and _queue.is_empty() and not _keep:
		_say("Replay finished.")
		quit(0)
	return false


func _poll_file() -> void:
	var path: String = _io_dir + "/cmd.txt"
	if not FileAccess.file_exists(path):
		return
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var text: String = f.get_as_text()
	f.close()
	if text.strip_edges() == "":
		return
	var w: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	w.close()
	_batch += 1
	_batch_open = true
	for line: String in text.split("\n"):
		_queue.append(line)


# ---------------------------------------------------------------- helpers

func _all(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c: Node in n.get_children():
		out.append_array(_all(c))
	return out


func _first(script_class: Variant) -> Node:
	for n: Node in _all(root):
		if is_instance_of(n, script_class) and (n as CanvasItem).is_visible_in_tree():
			return n
	return null


func _app() -> Node:
	return root.get_node("App")


func _ctrl() -> MatchController:
	return _app().get("controller") as MatchController


func _to_pixels(canvas_pos: Vector2) -> Vector2:
	return root.get_final_transform() * canvas_pos


func _insert(cmds: Array[String]) -> void:
	for i: int in range(cmds.size() - 1, -1, -1):
		_queue.push_front(cmds[i])


## Real mouse input: move, wait a frame so hover state updates, press, release.
func _click_canvas(canvas_pos: Vector2) -> void:
	var px: Vector2 = _to_pixels(canvas_pos)
	_insert(["_motion %f %f" % [px.x, px.y], "wait 2", "_press %f %f" % [px.x, px.y], "wait 1",
		"_release %f %f" % [px.x, px.y], "wait 3"])


func _mouse_event(pos: Vector2, pressed: bool, button: bool) -> void:
	if button:
		var e: InputEventMouseButton = InputEventMouseButton.new()
		e.position = pos
		e.global_position = pos
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(e)
	else:
		var m: InputEventMouseMotion = InputEventMouseMotion.new()
		m.position = pos
		m.global_position = pos
		Input.parse_input_event(m)


func _centre(c: Control) -> Vector2:
	return c.get_global_transform() * (c.size * 0.5)


func _hand_cards() -> Array[CardView]:
	var out: Array[CardView] = []
	var hand: Node = _first(HandFan)
	if hand == null:
		return out
	for n: Node in _all(hand):
		if n is CardView and (n as CardView).uid >= 0:
			out.append(n as CardView)
	out.sort_custom(func(a: CardView, b: CardView) -> bool: return a.position.x < b.position.x)
	return out


func _card_point(c: CardView, last: bool) -> Vector2:
	var local: Vector2 = Vector2(c.size.x * 0.5, 70.0) if (last or c.selected) else Vector2(16.0, 70.0)
	return c.get_global_transform() * local


func _fail(msg: String) -> void:
	_say("ERROR: " + msg)


# ---------------------------------------------------------------- commands

func _run(line: String) -> void:
	var sp: int = line.find(" ")
	var cmd: String = line if sp < 0 else line.substr(0, sp)
	var arg: String = "" if sp < 0 else line.substr(sp + 1).strip_edges()
	match cmd:
		"wait":
			_wait = int(arg)
		"wait_s":
			_wait_until_ms = Time.get_ticks_msec() + int(float(arg) * 1000.0)
		"_motion":
			var p: PackedStringArray = arg.split(" ")
			_mouse_event(Vector2(float(p[0]), float(p[1])), false, false)
		"_press", "_release":
			var q: PackedStringArray = arg.split(" ")
			_mouse_event(Vector2(float(q[0]), float(q[1])), cmd == "_press", true)
		"click_text":
			_click_text(arg)
		"click_card":
			_click_card(arg, true)
		"hover_card":
			_click_card(arg, false)
		"click_pile":
			var board: BoardView = _first(BoardView) as BoardView
			if board == null:
				_fail("no board on screen")
				return
			if arg != "town" and arg != "disaster":
				_fail("click_pile needs 'town' or 'disaster', got '%s'" % arg)
				return
			var pile: DeckPile = board.pile(CardDefinition.DeckKind.TOWN if arg == "town" else CardDefinition.DeckKind.DISASTER)
			_say("click_pile %s (disabled=%s)" % [arg, str(pile.disabled)])
			_click_canvas(_centre(pile))
		"click_seat":
			_click_seat(arg)
		"click_region":
			_click_region(arg)
		"click_xy":
			var xy: PackedStringArray = arg.split(" ")
			_click_canvas(Vector2(float(xy[0]), float(xy[1])))
		"hover":
			var hv: PackedStringArray = arg.split(" ")
			var hp: Vector2 = _to_pixels(Vector2(float(hv[0]), float(hv[1])))
			_insert(["_motion %f %f" % [hp.x, hp.y], "wait 3"])
		"key":
			_key(arg)
		"type":
			_type(arg)
		"shot":
			_shot(arg)
		"dump":
			_dump()
		"audit":
			_audit()
		"resize":
			var wh: PackedStringArray = arg.split(" ")
			root.size = Vector2i(int(wh[0]), int(wh[1]))
			_wait = 8
			_say("resized window to %s" % str(root.size))
		"caption":
			_set_caption(arg)
		"caption_off":
			_set_caption("")
		"debug_give":
			var g: PackedStringArray = arg.split(" ")
			if g.size() < 2 or not _debug_ready() or _ctrl().state.catalog.card(g[1]) == null:
				_fail("debug_give <pid> <card id> needs a running match and a known card id")
				return
			_ctrl().debug_give_card(int(g[0]), g[1])
			_say("DEBUG give %s to %s" % [g[1], g[0]])
			_insert(["wait 3"])  # let the hand fan rebuild before the next command reads it
		"debug_rp":
			var r: PackedStringArray = arg.split(" ")
			if r.size() < 2 or not _debug_ready():
				_fail("debug_rp <pid> <rp> needs a running match")
				return
			_ctrl().debug_set_rp(int(r[0]), int(r[1]))
			_say("DEBUG rp of %s requested %s, now %d" % [r[0], r[1], _ctrl().state.players[int(r[0])].rp])
			_insert(["wait 3"])
		"debug_disaster":
			var d: PackedStringArray = arg.split(" ")
			if d.size() < 3 or not _debug_ready():
				_fail("debug_disaster <caster> <card id> <target> needs a running match")
				return
			var before_phase: int = _ctrl().state.phase
			_ctrl().debug_force_disaster(int(d[0]), d[1], int(d[2]))
			_say("DEBUG forced %s from %s onto %s (phase %s -> %s)" % [d[1], d[0], d[2],
				MatchState.Phase.keys()[before_phase], MatchState.Phase.keys()[_ctrl().state.phase]])
			_insert(["wait 3"])
		"auto":
			_auto_left = int(arg)
			_auto_tick()
		"auto_tick":
			_auto_tick()
		"auto_seed":
			_auto_rng.seed = int(arg)
		"quit":
			_say("Quit requested.")
			if _out != null:
				_out.flush()
			quit(0)
		_:
			_fail("unknown command: " + line)


## ---- auto: a simple player that still acts only through real clicks ----
## `auto N` plays up to N UI actions with a fixed heuristic (build, heal, strike, bank, else end
## turn). It reads the match state to decide WHAT to do, but every action is a synthesized click
## on the real controls, so the UI's own rules (cover, summary, dialogs, disabled buttons) apply.
## Used to play long matches to the end; QA notes must say which parts were played this way.
func _auto_tick() -> void:
	if _auto_left <= 0:
		_say("AUTO stopped (budget used)")
		return
	_auto_left -= 1
	var cmds: Array[String] = _auto_decide()
	if cmds.is_empty():
		_auto_left = 0
		return
	cmds.append("wait 5")
	cmds.append("auto_tick")
	_insert(cmds)


func _auto_decide() -> Array[String]:
	var s: MatchState = _ctrl().state
	var none: Array[String] = []
	if s == null:
		_say("AUTO: no match in progress")
		return none
	if s.is_over():
		_say("AUTO: the game is over (round %d, %s)" % [s.round_number, s.end_reason])
		_auto_left = 0
		return ["wait 20", _auto_shot("game-over-board")]
	if _first(PassDeviceScreen) != null:
		return ["click_text I am ready"]
	var dd: DiscardDialog = _first(DiscardDialog) as DiscardDialog
	if dd != null:
		var dcmds: Array[String] = [_auto_shot("hand-limit-dialog")]
		dcmds.append_array(_auto_discard(dd, s))
		return dcmds
	if _first(ResolutionSummary) != null:
		return [_auto_shot("summary"), "click_text Continue"]
	var actor: PlayerState = s.players[s.actor_id()]
	match s.phase:
		MatchState.Phase.DRAW:
			var disasters: int = 0
			for c: CardInstance in actor.hand:
				if s.catalog.card(c.def_id) is DisasterCardDef:
					disasters += 1
			var want_disaster: bool = disasters < 2 and DeckSystem.can_draw(s, CardDefinition.DeckKind.DISASTER)
			_say("AUTO %s draws from the %s deck" % [actor.display_name, "Disaster" if want_disaster else "Town"])
			return ["click_pile disaster" if want_disaster else "click_pile town"]
		MatchState.Phase.REACTION:
			return _auto_react(s, actor)
		MatchState.Phase.PLAY:
			return _auto_play(s, actor)
	return none


## A numbered screenshot command for the auto player, or a harmless wait once the cap is reached.
func _auto_shot(kind: String) -> String:
	if _auto_shots >= AUTO_SHOT_CAP:
		return "wait 1"
	_auto_shots += 1
	return "shot auto-%03d-%s" % [_auto_shots, kind]


func _auto_discard(dd: DiscardDialog, s: MatchState) -> Array[String]:
	var cmds: Array[String] = []
	var needed: int = int(dd.get("_needed"))
	var checks: Dictionary = dd.get("_checks") as Dictionary
	var picked: int = 0
	for want_resource: bool in [true, false]:
		for uid: Variant in checks.keys():
			if picked >= needed:
				break
			var cb: CheckBox = checks[uid] as CheckBox
			var card: CardInstance = s.players[s.actor_id()].find_in_hand(int(uid))
			var is_res: bool = card != null and s.catalog.card(card.def_id) is ResourceCardDef
			if is_res == want_resource and not cb.button_pressed:
				var c: Vector2 = _centre(cb)
				cmds.append("click_xy %d %d" % [c.x, c.y])
				picked += 1
	_say("AUTO %s discards %d card(s) at the hand limit" % [s.players[s.actor_id()].display_name, needed])
	cmds.append("click_text Discard selected")
	return cmds


func _auto_react(s: MatchState, actor: PlayerState) -> Array[String]:
	for a: GameAction in ActionEnumerator.legal_actions(s):
		if a is ReactAction and _auto_rng.randf() < 0.75:
			var card: CardInstance = actor.find_in_hand((a as ReactAction).card_uid)
			var nm: String = s.catalog.card(card.def_id).display_name
			_say("AUTO %s reacts with %s" % [actor.display_name, nm])
			return [_auto_shot("reaction-window"), "click_card " + nm, "click_text React with this card"]
	_say("AUTO %s does not react" % actor.display_name)
	return [_auto_shot("reaction-window"), "click_text Do not react"]


func _auto_play(s: MatchState, actor: PlayerState) -> Array[String]:
	var best: GameAction = null
	var best_score: float = -1.0
	for a: GameAction in ActionEnumerator.legal_actions(s):
		var score: float = _auto_rng.randf()
		if a is PlayCardAction:
			var def: CardDefinition = s.catalog.card(actor.find_in_hand((a as PlayCardAction).card_uid).def_id)
			if def is BuildingCardDef:
				score += 4.0 if not actor.has_building(def.id) else 1.0
			elif def is DisasterCardDef:
				score += 3.0
			elif def is PreparednessCardDef:
				score += 2.5 if actor.rp < s.config.starting_rp or (a as PlayCardAction).target_building_uid >= 0 else 0.5
		elif a is ReserveAction:
			score += 2.0
		elif a is EndTurnAction:
			score = 0.4
		if score > best_score:
			best_score = score
			best = a
	if best == null or best is EndTurnAction:
		_say("AUTO %s ends the turn" % actor.display_name)
		return ["click_text End Turn"]
	if best is ReserveAction:
		var rc: CardInstance = actor.find_in_hand((best as ReserveAction).card_uid)
		_say("AUTO %s banks Supplies" % actor.display_name)
		return ["click_card " + s.catalog.card(rc.def_id).display_name, "click_text Bank in Reserve"]
	var p: PlayCardAction = best as PlayCardAction
	var card: CardInstance = actor.find_in_hand(p.card_uid)
	var nm: String = s.catalog.card(card.def_id).display_name
	var cmds: Array[String] = ["click_card " + nm]
	if p.target_player_id >= 0:
		var tname: String = s.players[p.target_player_id].display_name
		cmds.append("click_seat " + tname)
		cmds.append("click_text Play on " + tname)
		_say("AUTO %s plays %s on %s" % [actor.display_name, nm, tname])
	elif p.target_building_uid >= 0:
		cmds.append("click_text Repair")
		_say("AUTO %s plays %s to repair" % [actor.display_name, nm])
	else:
		cmds.append("click_text Play  [pays" if not p.payment_uids.is_empty() else "click_text Play")
		_say("AUTO %s plays %s" % [actor.display_name, nm])
	return cmds


func _click_text(text: String) -> void:
	var exact: Array[Button] = []
	var partial: Array[Button] = []
	for n: Node in _all(root):
		if n is Button and (n as Button).is_visible_in_tree():
			var b: Button = n as Button
			if b.text == text:
				exact.append(b)
			elif b.text.contains(text):
				partial.append(b)
	var pool: Array[Button] = exact if not exact.is_empty() else partial
	if pool.is_empty():
		_fail("no visible button matching '%s'" % text)
		return
	var b2: Button = pool[pool.size() - 1]
	_say("click_text '%s' -> '%s' disabled=%s" % [text, b2.text.replace("\n", " / "), str(b2.disabled)])
	_click_canvas(_centre(b2))


func _click_card(name_or_index: String, click: bool) -> void:
	var cards: Array[CardView] = _hand_cards()
	if cards.is_empty():
		_fail("no cards in the hand fan")
		return
	var idx: int = -1
	if name_or_index.is_valid_int():
		idx = int(name_or_index)
	else:
		var want: String = name_or_index.to_lower()
		for i: int in range(cards.size()):
			if cards[i].def != null and cards[i].def.display_name.to_lower() == want:
				idx = i
				break
		if idx < 0:
			for i: int in range(cards.size()):
				if cards[i].def != null and cards[i].def.display_name.to_lower().begins_with(want):
					idx = i
					break
	if idx < 0 or idx >= cards.size():
		_fail("no hand card '%s'" % name_or_index)
		return
	var c: CardView = cards[idx]
	_say("%s card %d '%s' usable=%s" % ["click" if click else "hover", idx, c.def.display_name, str(c.playable)])
	var pt: Vector2 = _card_point(c, idx == cards.size() - 1)
	if click:
		_click_canvas(pt)
	else:
		var px: Vector2 = _to_pixels(pt)
		_insert(["_motion %f %f" % [px.x, px.y], "wait 4"])


func _click_seat(player_name: String) -> void:
	var board: BoardView = _first(BoardView) as BoardView
	if board == null or _ctrl().state == null:
		_fail("no board on screen")
		return
	for p: PlayerState in _ctrl().state.players:
		if p.display_name == player_name:
			var sv: SeatView = board.seat_view(p.id)
			_say("click_seat %s" % player_name)
			_click_canvas(_centre(sv))
			return
	_fail("no player named " + player_name)


func _click_region(player_name: String) -> void:
	var board: BoardView = _first(BoardView) as BoardView
	if board == null or _ctrl().state == null:
		_fail("no board on screen")
		return
	for p: PlayerState in _ctrl().state.players:
		if p.display_name == player_name:
			var region: Control = board.map._regions.get(p.id) as Control
			if region == null:
				_fail("no map region for " + player_name)
				return
			_say("click_region %s" % player_name)
			_click_canvas(region.get_global_transform() * Vector2(region.size.x * 0.5, region.size.y * 0.6))
			return
	_fail("no player named " + player_name)


func _key(key_name: String) -> void:
	var code: int = OS.find_keycode_from_string(key_name)
	if code == KEY_NONE:
		_fail("unknown key " + key_name)
		return
	for pressed: bool in [true, false]:
		var e: InputEventKey = InputEventKey.new()
		e.keycode = code as Key
		e.physical_keycode = code as Key
		e.pressed = pressed
		Input.parse_input_event(e)
	_wait = 3


func _type(text: String) -> void:
	for ch: String in text:
		for pressed: bool in [true, false]:
			var e: InputEventKey = InputEventKey.new()
			e.unicode = ch.unicode_at(0)
			e.keycode = OS.find_keycode_from_string(ch.to_upper()) as Key
			e.pressed = pressed
			Input.parse_input_event(e)
	_wait = 3


func _shot(name: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	var file: String = name if name.ends_with(".png") else name + ".png"
	var path: String = ProjectSettings.globalize_path(_shots_dir) + "/" + file
	var err: int = img.save_png(path)
	_say("SHOT %s %dx%d err=%d" % [path, img.get_width(), img.get_height(), err])


func _set_caption(text: String) -> void:
	if _caption_layer == null:
		_caption_layer = CanvasLayer.new()
		_caption_layer.layer = 128
		root.add_child(_caption_layer)
		var panel: PanelContainer = PanelContainer.new()
		panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
		panel.offset_bottom = -4
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_caption_layer.add_child(panel)
		_caption = Label.new()
		_caption.add_theme_font_size_override("font_size", 22)
		_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(_caption)
	_caption.text = text
	_caption.get_parent().visible = text != ""


## What a player could see: the screen, state summary, hand, every visible button and label.
## debug_* commands need a running match; without one they would dereference a null state.
func _debug_ready() -> bool:
	return _ctrl() != null and _ctrl().state != null


func _dump() -> void:
	var screen: Node = _app().get("current_screen") as Node
	var sp: String = String(screen.get_script().resource_path) if screen != null and screen.get_script() != null else "?"
	_say("SCREEN %s window=%s" % [sp.get_file(), str(root.size)])
	var s: MatchState = _ctrl().state
	if s != null:
		var parts: PackedStringArray = PackedStringArray()
		for p: PlayerState in s.players:
			parts.append("P%d %s rp=%d hand=%d reserve=%d bld=%d%s" % [p.id, p.display_name, p.rp, p.hand.size(),
				p.reserve.size(), p.buildings.size(), " ELIM" if p.eliminated else ""])
		_say("STATE phase=%s cur=%d actor=%d round=%d plays=%d forecasts=%d decks=%d/%d | %s" % [
			MatchState.Phase.keys()[s.phase], s.current_player, s.actor_id(), s.round_number, s.plays_remaining,
			s.forecasts.size(), s.town_deck.size(), s.disaster_deck.size(), " | ".join(parts)])
	var cards: Array[CardView] = _hand_cards()
	if not cards.is_empty():
		var names: PackedStringArray = PackedStringArray()
		for i: int in range(cards.size()):
			names.append("%d:%s%s" % [i, cards[i].def.display_name, "" if cards[i].playable else "(x)"])
		_say("HAND " + ", ".join(names))
	for n: Node in _all(root):
		if n is Button and not (n is DeckPile) and (n as Button).is_visible_in_tree():
			var b: Button = n as Button
			_say("BUTTON '%s' %s%s" % [b.text.replace("\n", " / "), _rect(b), " DISABLED" if b.disabled else ""])
		elif n is DeckPile and (n as DeckPile).is_visible_in_tree():
			var dp: DeckPile = n as DeckPile
			_say("PILE '%s' %s%s" % [dp.text.replace("\n", " / "), _rect(dp), " DISABLED" if dp.disabled else ""])
	var shown: int = 0
	for n: Node in _all(root):
		if n is Label and (n as Label).is_visible_in_tree() and (n as Label).text.strip_edges() != "" \
				and not _inside(n, CardView) and shown < 70:
			_say("LABEL '%s' %s" % [(n as Label).text.replace("\n", " / "), _rect(n as Control)])
			shown += 1


func _inside(n: Node, script_class: Variant) -> bool:
	var p: Node = n.get_parent()
	while p != null:
		if is_instance_of(p, script_class):
			return true
		p = p.get_parent()
	return false


func _rect(c: Control) -> String:
	var r: Rect2 = c.get_global_rect()
	return "[%d,%d %dx%d]" % [r.position.x, r.position.y, r.size.x, r.size.y]


## Compares what the screen shows with the match state and reports every disagreement.
func _audit() -> void:
	var s: MatchState = _ctrl().state
	var board: BoardView = _first(BoardView) as BoardView
	if s == null or board == null:
		_say("AUDIT skipped (no match on screen)")
		return
	var bad: int = 0
	for p: PlayerState in s.players:
		var sv: SeatView = board.seat_view(p.id)
		var rp: String = (sv.get("_rp_text") as Label).text
		var counts: String = (sv.get("_counts") as Label).text
		var nm: String = (sv.get("_name") as Label).text
		var want_rp: String = "RP %d/%d" % [p.rp, s.config.starting_rp]
		var want_counts: String = "Hand %d | Reserve %d" % [p.hand.size(), p.reserve.size()]
		if rp != want_rp or not counts.begins_with(want_counts) or nm != p.display_name:
			bad += 1
			_say("AUDIT MISMATCH seat %s: shows '%s' '%s' '%s', state says '%s' '%s'" % [p.display_name, nm, rp, counts, want_rp, want_counts])
	var info: String = ""
	for n: Node in _all(root):
		if n is TurnHeader:
			info = (n.get("_info") as Label).text
	if not s.is_over() and not info.contains("Round %d/%d" % [s.round_number, s.config.round_cap]):
		bad += 1
		_say("AUDIT MISMATCH header '%s' vs round %d" % [info, s.round_number])
	for kind: CardDefinition.DeckKind in [CardDefinition.DeckKind.TOWN, CardDefinition.DeckKind.DISASTER]:
		var pile: DeckPile = board.pile(kind)
		var want: String = "%d cards" % DeckSystem.deck_of(s, kind).size()
		var shown: String = " / " + pile.text.replace("\n", " / ") + " / "
		if not shown.contains(" / %s / " % want) and not DeckSystem.both_empty(s):
			bad += 1
			_say("AUDIT MISMATCH pile: shows '%s' wants '%s'" % [pile.text.replace("\n", " / "), want])
	if not s.is_over():
		var actor_hand: int = s.players[s.actor_id()].hand.size()
		if _hand_cards().size() != actor_hand:
			bad += 1
			_say("AUDIT MISMATCH hand fan shows %d cards, state has %d" % [_hand_cards().size(), actor_hand])
	_say("AUDIT %s (%d mismatches)" % ["OK" if bad == 0 else "FAILED", bad])
