class_name TutorialCoach
extends Control
## The tutorial overlay on top of the match screen: a small instruction panel, an outline around
## the control to use, and Next / Skip step / Restart / Exit buttons. It watches the match through
## TutorialContext and moves on by itself when the learner does what the step asks. It never
## submits actions or changes state, so the real game underneath is unchanged.

signal exit_requested
signal restart_requested
signal start_match_requested

const PANEL_W: float = 390.0
const MARGIN: float = 12.0

var _screen: Control
var _controller: MatchController
var _steps: Array[TutorialStep] = []
var _index: int = 0
var _events: Array[GameEvent] = []
var _age: float = 0.0
var _last_success: String = ""
var _feedback: String = ""
var _feedback_age: float = 0.0
var _highlights: Array[Rect2] = []
var _view_key: String = ""
var _summary_seen: bool = false

var _panel: PanelContainer
var _counter: Label
var _title: Label
var _success: Label
var _body: Label
var _problem: Label
var _next: Button
var _skip: Button
var _row_final: HBoxContainer
var _row_nav: HBoxContainer


## screen is the MatchScreen: it answers tutorial_info() and highlight_rect(key).
func bind(p_screen: Control, p_controller: MatchController, p_steps: Array[TutorialStep]) -> void:
	_screen = p_screen
	_controller = p_controller
	_steps = p_steps
	_build()
	_controller.events_emitted.connect(_on_events)
	_controller.action_rejected.connect(_on_rejected)


func _exit_tree() -> void:
	if _controller == null:
		return
	if _controller.events_emitted.is_connected(_on_events):
		_controller.events_emitted.disconnect(_on_events)
	if _controller.action_rejected.is_connected(_on_rejected):
		_controller.action_rejected.disconnect(_on_rejected)


func current_step() -> TutorialStep:
	return _steps[clampi(_index, 0, _steps.size() - 1)]


func step_index() -> int:
	return _index


func step_count() -> int:
	return _steps.size()


func is_finished() -> bool:
	return _index >= _steps.size() - 1 and current_step().id == "finish"


# ---------------------------------------------------------------- building

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 400
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.1, 0.18, 1.0)
	sb.border_color = Color(1.0, 0.82, 0.25)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	_counter = UiTheme.small_label()
	_counter.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	box.add_child(_counter)
	_title = UiTheme.heading_label("")
	_title.add_theme_font_size_override("font_size", 22)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)
	_success = Label.new()
	_success.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55))
	_success.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_success)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(PANEL_W - 28.0, 0)
	box.add_child(_body)
	_problem = Label.new()
	_problem.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	_problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_problem)
	_row_nav = HBoxContainer.new()
	_row_nav.add_theme_constant_override("separation", 6)
	box.add_child(_row_nav)
	_next = Button.new()
	_next.text = "Next"
	_next.pressed.connect(func() -> void: _advance(false))
	_row_nav.add_child(_next)
	_skip = Button.new()
	_skip.text = "Skip step"
	_skip.tooltip_text = "Off script? Skip this step. Nothing in the game is changed."
	_skip.pressed.connect(func() -> void: _advance(false))
	_row_nav.add_child(_skip)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row_nav.add_child(spacer)
	var restart: Button = Button.new()
	restart.text = "Restart"
	restart.tooltip_text = "Restart the tutorial from the beginning."
	restart.pressed.connect(func() -> void: restart_requested.emit())
	_row_nav.add_child(restart)
	var exit: Button = Button.new()
	exit.text = "Exit tutorial"
	exit.pressed.connect(func() -> void: exit_requested.emit())
	_row_nav.add_child(exit)
	_row_final = HBoxContainer.new()
	_row_final.add_theme_constant_override("separation", 6)
	box.add_child(_row_final)
	var go: Button = Button.new()
	go.text = "Start a real match"
	go.pressed.connect(func() -> void: start_match_requested.emit())
	_row_final.add_child(go)
	var again: Button = Button.new()
	again.text = "Replay tutorial"
	again.pressed.connect(func() -> void: restart_requested.emit())
	_row_final.add_child(again)
	var menu: Button = Button.new()
	menu.text = "Main menu"
	menu.pressed.connect(func() -> void: exit_requested.emit())
	_row_final.add_child(menu)
	resized.connect(func() -> void: _view_key = "")


# ---------------------------------------------------------------- signals from the match

func _on_events(events: Array[GameEvent]) -> void:
	_events.append_array(events)


func _on_rejected(reason: String) -> void:
	_feedback = "That did not work: %s. Look at the outlined control." % reason
	_feedback_age = 0.0


# ---------------------------------------------------------------- progress

## completed is true when the learner did what the step asked (shows its success line next).
func _advance(completed: bool = false) -> void:
	if _index >= _steps.size() - 1:
		return
	_last_success = current_step().success if completed else ""
	_index += 1
	_events.clear()
	_age = 0.0
	_summary_seen = false
	_feedback = ""
	_view_key = ""


func _context() -> TutorialContext:
	var c: TutorialContext = TutorialContext.new()
	c.state = _controller.state
	c.events = _events
	c.age = _age
	var info: Dictionary = _screen.call("tutorial_info") as Dictionary
	c.selected_def = String(info.get("selected_def", ""))
	c.chosen_target = int(info.get("chosen_target", -1))
	c.cover_visible = bool(info.get("cover_visible", false))
	c.summary_visible = bool(info.get("summary_visible", false))
	if c.summary_visible:
		_summary_seen = true
	c.summary_seen = _summary_seen
	return c


func _process(delta: float) -> void:
	if _controller == null or _controller.state == null:
		return
	_age += delta
	if _feedback != "":
		_feedback_age += delta
		if _feedback_age > 7.0:
			_feedback = ""
	var step: TutorialStep = current_step()
	var ctx: TutorialContext = _context()
	if step.kind == TutorialStep.Kind.ACTION and step.done.is_valid() and bool(step.done.call(ctx)):
		_advance(true)
		return
	_update_view(step, ctx)
	queue_redraw()


## Chooses what to say: the hot-seat hand-off and the summary panel take priority over the step
## text unless the step is about them.
func _update_view(step: TutorialStep, ctx: TutorialContext) -> void:
	var title: String = step.title
	var body: String = step.body
	var key: String = step.highlight
	var show_success: bool = _last_success != ""
	if ctx.cover_visible and not step.over_cover:
		title = "Pass the device"
		body = "The dark screen hides a player's cards while the device changes hands. Give the device to the next mayor and press \"I am ready\"."
		key = "cover_ready"
		show_success = _last_success != ""
	elif ctx.summary_visible and not step.over_summary:
		title = "Read the summary"
		body = "This panel lists what just happened. Press Continue to close it."
		key = "summary"
	var finished: bool = step.id == "finish"
	var sig: String = "%d|%s|%s|%s|%s|%s" % [_index, title, key, _feedback, _last_success, str(finished)]
	_highlights = _screen.call("highlight_rects", key) as Array[Rect2]
	if sig == _view_key:
		_place_panel()
		return
	_view_key = sig
	_counter.text = "Tutorial: step %d of %d" % [_index + 1, _steps.size()]
	_title.text = title
	_success.text = ("OK - " + _last_success) if show_success else ""
	_success.visible = show_success
	_body.text = body
	_problem.text = _feedback
	_problem.visible = _feedback != ""
	var is_action: bool = step.kind == TutorialStep.Kind.ACTION
	_next.visible = not is_action and not finished
	_skip.visible = is_action
	_row_nav.visible = not finished
	_row_final.visible = finished
	_panel.reset_size()
	_place_panel()


func _place_panel() -> void:
	var w: float = _panel.size.x
	var h: float = _panel.size.y
	var candidates: Array[Vector2] = [
		Vector2(size.x - w - MARGIN, 52.0),
		Vector2(MARGIN, 52.0),
		Vector2(size.x - w - MARGIN, size.y * 0.30),
		Vector2(MARGIN, size.y * 0.30),
		Vector2(size.x - w - MARGIN, size.y - h - MARGIN),
		Vector2(MARGIN, size.y - h - MARGIN),
	]
	# First candidate that does not cover any highlighted control; otherwise the one covering least.
	var pick: Vector2 = candidates[0]
	var best_overlap: float = INF
	for pos: Vector2 in candidates:
		var rect: Rect2 = Rect2(pos, Vector2(w, h))
		var overlap: float = 0.0
		for hl: Rect2 in _highlights:
			var local_hl: Rect2 = Rect2(hl.position - global_position, hl.size).grow(4.0)
			if rect.intersects(local_hl):
				var inter: Rect2 = rect.intersection(local_hl)
				overlap += inter.size.x * inter.size.y
		if overlap < best_overlap:
			best_overlap = overlap
			pick = pos
		if overlap == 0.0:
			break
	_panel.position = pick


func _draw() -> void:
	var pulse: float = 0.65 + 0.35 * sin(float(Time.get_ticks_msec()) / 220.0)
	for hl: Rect2 in _highlights:
		var r: Rect2 = Rect2(hl.position - global_position, hl.size).grow(6.0)
		draw_rect(r.grow(3.0), Color(0, 0, 0, 0.55), false, 3.0)
		draw_rect(r, Color(1.0, 0.82, 0.25, pulse), false, 4.0)
