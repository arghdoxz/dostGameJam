extends SceneTree
## Windowed screenshot tool for checking layout (needs a real display, not --headless).
## Saves PNGs of the main screens to the folder given after "--" (default: user://screens).
## Run: godot --path . -s res://tools/capture_screens.gd -- C:/some/folder

var _app: Node
var _out_dir: String = "user://screens"
var _steps: Array[Callable] = []
var _step: int = 0
var _wait: int = 0
var _bot: RandomNumberGenerator = RandomNumberGenerator.new()


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
	_bot.seed = 11
	root.size = Vector2i(1600, 900)
	_app = (load("res://scenes/boot/app.tscn") as PackedScene).instantiate()
	root.add_child(_app)
	_steps = [
		func() -> void: _shot("01_menu"),
		func() -> void: _app.call("show_setup"),
		func() -> void: _shot("02_setup"),
		func() -> void: _start(2),
		func() -> void: _dismiss_cover(),
		func() -> void: _shot("03_board_2p_draw"),
		func() -> void: _play_until_phase(MatchState.Phase.PLAY),
		func() -> void: _shot("04_board_2p_play"),
		func() -> void: _select_first_card(),
		func() -> void: _shot("05_card_selected"),
		func() -> void: _play_until_phase(MatchState.Phase.REACTION),
		func() -> void: _dismiss_cover(),
		func() -> void: _shot("06_disaster_reaction"),
		func() -> void: _ctrl().submit(PassReactionAction.new(_ctrl().state.actor_id())),
		func() -> void: _dismiss_cover(),
		func() -> void: _shot("06b_summary"),
		func() -> void: _open_picker(),
		func() -> void: _shot("06c_payment_picker"),
		func() -> void: _start(4),
		func() -> void: _dismiss_cover(),
		func() -> void: _shot("07_board_4p"),
		func() -> void: _finish_match(),
		func() -> void: _app.call("show_game_over"),
		func() -> void: _shot("08_results"),
	]


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	if _step >= _steps.size():
		print("Screens saved to ", ProjectSettings.globalize_path(_out_dir))
		quit(0)
		return true
	(_steps[_step] as Callable).call()
	_step += 1
	_wait = 6
	return false


func _shot(name: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(_out_dir) + "/" + name + ".png")


func _ctrl() -> MatchController:
	return _app.get("controller") as MatchController


func _start(players: int) -> void:
	var seats: Array[Dictionary] = []
	var cat: ContentCatalog = root.get_node("ContentDB").get("catalog") as ContentCatalog
	var ids: Array[String] = cat.territory_ids()
	ids.sort()
	for i: int in range(players):
		seats.append({"name": "Mayor %d" % (i + 1), "territory_id": ids[i]})
	_app.call("start_match", seats, 7)


func _dismiss_cover() -> void:
	for n: Node in _all(_app):
		if n is PassDeviceScreen and (n as PassDeviceScreen).visible:
			(n as PassDeviceScreen).hide()
			(n as PassDeviceScreen).ready_pressed.emit()


func _all(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c: Node in n.get_children():
		out.append_array(_all(c))
	return out


func _play_until_phase(phase: MatchState.Phase) -> void:
	var ctrl: MatchController = _ctrl()
	for i: int in range(400):
		if ctrl.state.is_over() or ctrl.state.phase == phase:
			return
		var acts: Array[GameAction] = ctrl.legal_actions()
		var pick: GameAction = acts[_bot.randi_range(0, acts.size() - 1)]
		if phase == MatchState.Phase.PLAY and ctrl.state.phase == MatchState.Phase.DRAW:
			pick = acts[0]
		ctrl.submit(pick)


func _open_picker() -> void:
	var ctrl: MatchController = _ctrl()
	var s: MatchState = ctrl.state
	for i: int in range(200):
		if s.phase == MatchState.Phase.PLAY or s.is_over():
			break
		var acts: Array[GameAction] = ctrl.legal_actions()
		ctrl.submit(acts[0])
	var actor: int = s.actor_id()
	s.plays_remaining = 1
	for n: Node in _all(_app):
		if n is ResolutionSummary:
			(n as ResolutionSummary).hide()
	ctrl.debug_give_card(actor, "bld_seawall")
	ctrl.debug_give_card(actor, "res_materials")
	ctrl.debug_give_card(actor, "res_materials")
	_dismiss_cover()
	for a: GameAction in ctrl.legal_actions():
		if a is PlayCardAction and s.players[actor].find_in_hand((a as PlayCardAction).card_uid).def_id == "bld_seawall":
			for n: Node in _all(_app):
				if n is PaymentPicker:
					(n as PaymentPicker).open(s, a)
			return


func _select_first_card() -> void:
	for n: Node in _all(_app):
		if n is HandFan:
			var s: MatchState = _ctrl().state
			var hand: Array[CardInstance] = s.players[s.actor_id()].hand
			if not hand.is_empty():
				(n as HandFan).select(hand[0].uid)
				(n as HandFan).card_selected.emit(hand[0].uid)


func _finish_match() -> void:
	var ctrl: MatchController = _ctrl()
	for i: int in range(4000):
		if ctrl.state.is_over():
			return
		var acts: Array[GameAction] = ctrl.legal_actions()
		ctrl.submit(acts[_bot.randi_range(0, acts.size() - 1)])
