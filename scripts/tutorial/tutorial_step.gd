class_name TutorialStep
extends RefCounted
## One tutorial step. INFO steps wait for the Next button. ACTION steps finish by themselves when
## `done` returns true, and always offer "Skip step" so a mistake can never block the tutorial.

enum Kind { INFO, ACTION }

var id: String = ""
var title: String = ""
var body: String = ""
## Shown (green) at the top of the next step once this one is done.
var success: String = ""
## Which part of the screen to outline; resolved by MatchScreen.highlight_rect().
var highlight: String = ""
var kind: Kind = Kind.INFO
## Callable(ctx: TutorialContext) -> bool
var done: Callable = Callable()
## True when the step must stay visible while the hot-seat cover or the summary panel is open.
var over_cover: bool = false
var over_summary: bool = false
## Test support: the UI selection this step expects, and the engine actions that carry it out.
## Callable(state: MatchState) -> Array[GameAction]. The automated test plays these through
## RulesEngine to prove every step can be completed.
var ui_selected: String = ""
var ui_target: int = -1
var intent: Callable = Callable()


static func info(p_id: String, p_title: String, p_body: String, p_highlight: String = "") -> TutorialStep:
	var s: TutorialStep = TutorialStep.new()
	s.id = p_id
	s.title = p_title
	s.body = p_body
	s.highlight = p_highlight
	return s


static func action(p_id: String, p_title: String, p_body: String, p_highlight: String, p_done: Callable,
		p_success: String) -> TutorialStep:
	var s: TutorialStep = TutorialStep.new()
	s.id = p_id
	s.title = p_title
	s.body = p_body
	s.highlight = p_highlight
	s.kind = Kind.ACTION
	s.done = p_done
	s.success = p_success
	return s
