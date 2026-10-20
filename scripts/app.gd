extends Node
## Root of the game. Owns the current screen and the MatchController, and routes
## navigation: MainMenu -> MatchSetup -> Match -> GameOver.

const MAIN_MENU: PackedScene = preload("res://scenes/menu/main_menu.tscn")
const MATCH_SETUP: PackedScene = preload("res://scenes/setup/match_setup.tscn")
const MATCH: PackedScene = preload("res://scenes/match/match.tscn")
const GAME_OVER: PackedScene = preload("res://scenes/ui/game_over.tscn")

var controller: MatchController
var current_screen: Control
var last_seats: Array[Dictionary] = []


func _ready() -> void:
	UiTheme.install()
	controller = MatchController.new()
	controller.name = "MatchController"
	add_child(controller)
	show_main_menu()


## Takes the current screen out of the tree at once (so its _exit_tree runs and it stops
## listening to the controller) and frees it at the end of the frame.
func _release_screen() -> void:
	if current_screen != null:
		remove_child(current_screen)
		current_screen.queue_free()
		current_screen = null


func _swap(scene: PackedScene) -> Control:
	_release_screen()
	current_screen = scene.instantiate() as Control
	add_child(current_screen)
	return current_screen


func show_main_menu() -> void:
	var s: Control = _swap(MAIN_MENU)
	s.connect("start_pressed", show_setup)
	s.connect("tutorial_pressed", start_tutorial)
	s.connect("quit_pressed", func() -> void: get_tree().quit())


func show_setup() -> void:
	var s: Control = _swap(MATCH_SETUP)
	s.call("configure", ContentDB.catalog)
	s.connect("start_requested", start_match)
	s.connect("back_requested", show_main_menu)


## Starts a match and shows the Match screen. Returns an error string or "".
func start_match(seats: Array[Dictionary], seed_value: int) -> String:
	var check: ValidationResult = RulesEngine.validate_setup(ContentDB.catalog.config, ContentDB.catalog, seats)
	if not check.ok:
		return check.reason
	last_seats = seats
	_release_screen()
	var err: String = controller.start(ContentDB.catalog, seats, seed_value)
	if err != "":
		show_setup()
		return err
	var s: Control = _swap(MATCH)
	s.call("bind", controller)
	s.connect("quit_to_menu", show_main_menu)
	s.connect("restart_requested", func() -> void: start_match(last_seats, randi()))
	s.connect("match_finished", show_game_over)
	return ""


## Starts the guided hot-seat tutorial match (fixed hands) with the coach overlay.
func start_tutorial() -> String:
	_release_screen()
	var err: String = controller.start(ContentDB.catalog, TutorialScenario.seats(), TutorialScenario.SEED, TutorialScenario.arrange)
	if err != "":
		show_main_menu()
		return err
	last_seats = TutorialScenario.seats()
	var s: Control = _swap(MATCH)
	s.call("bind", controller)
	s.connect("quit_to_menu", show_main_menu)
	s.connect("restart_requested", start_tutorial)
	s.connect("match_finished", show_game_over)
	var coach: TutorialCoach = TutorialCoach.new()
	coach.name = "TutorialCoach"
	s.add_child(coach)
	coach.bind(s, controller, TutorialScript.build())
	coach.exit_requested.connect(_leave_tutorial)
	coach.restart_requested.connect(start_tutorial)
	coach.start_match_requested.connect(func() -> void:
		controller.abandon()
		show_setup())
	return ""


func _leave_tutorial() -> void:
	controller.abandon()
	show_main_menu()


func show_game_over() -> void:
	var s: Control = _swap(GAME_OVER)
	s.call("show_result", controller.state)
	s.connect("rematch_requested", func() -> void: start_match(last_seats, randi()))
	s.connect("setup_requested", show_setup)
	s.connect("menu_requested", show_main_menu)
