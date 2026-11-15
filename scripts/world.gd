extends Node2D

static var skip_menu: bool = false     # survives scene reloads, so Retry skips the menu

@export var ball: RigidBody2D
@export var menu_scene: PackedScene
@export var wrong_key_scene: PackedScene
@export var retry_scene: PackedScene
@export var backgrounds: Array[Texture2D] = []   # one per sky level, in order
@export var milestone_every: float = 100.0
@export var points_per_jump: int = 100
@export var points_per_star: int = 500
@export var finish_bonus: int = 5000

# start altitude (m), booster multiplier, name
const LEVELS: Array = [
	[0, 1.0, "Tropical"], [100, 1.15, "Clouds"], [250, 1.3, "Upper Sky"],
	[450, 1.5, "Stratosphere"], [700, 1.7, "Mesosphere"],
	[1000, 1.9, "Thermosphere"], [1400, 2.2, "Space"],
]

var stars: int = 0
var jumps: int = 0
var score: int = 0
var level_index: int = 0
var next_milestone: float = 100.0
var finished: bool = false

var hud: Label
var popup: Label
var bg: TextureRect
var screen_layer: CanvasLayer
var screen: Node
var waiting_retry: bool = false

func _ready() -> void:
	next_milestone = milestone_every
	_build_ui()
	ball.boosted.connect(_on_boosted)
	ball.altitude_changed.connect(_on_altitude)
	ball.wrong_key.connect(_on_wrong_key)
	ball.ball_full.connect(_on_ball_full)
	_apply_level(0)
	if not skip_menu and menu_scene != null:
		_show_screen(menu_scene, {})


func _build_ui() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	bg = TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_layer.add_child(bg)

	var hud_layer := CanvasLayer.new()
	add_child(hud_layer)
	hud = Label.new()
	hud.position = Vector2(20, 20)
	hud.add_theme_font_size_override("font_size", 26)
	hud_layer.add_child(hud)
	popup = Label.new()
	popup.position = Vector2(340, 250)
	popup.size = Vector2(600, 60)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.add_theme_font_size_override("font_size", 44)
	popup.modulate = Color(1.0, 0.85, 0.2)
	hud_layer.add_child(popup)

	screen_layer = CanvasLayer.new()
	screen_layer.layer = 20
	screen_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(screen_layer)


func _apply_level(i: int) -> void:
	level_index = i
	ball.boost_multiplier = float(LEVELS[i][1])
	if i < backgrounds.size():
		bg.texture = backgrounds[i]


func _on_boosted() -> void:
	jumps += 1
	score += int(points_per_jump * float(LEVELS[level_index][1]))
	_refresh_hud()


func _on_altitude(current: float, best: float) -> void:
	var new_level: int = 0
	for i in LEVELS.size():
		if best >= float(LEVELS[i][0]):
			new_level = i
	if new_level != level_index:
		_apply_level(new_level)
	while best >= next_milestone:
		stars += 1
		score += points_per_star
		_show_popup("STAR!  %d m" % int(next_milestone))
		next_milestone += milestone_every
	_refresh_hud(current, best)


func _refresh_hud(current: float = 0.0, best: float = -1.0) -> void:
	if best < 0.0:
		best = ball.best_altitude
	hud.text = "Alt %.0f m (best %.0f)\nStars %d   Score %d\nLevel %d: %s  Boost x%.2f\nSize %.0f / %.0f" % [
		current, best, stars, score, level_index + 1, LEVELS[level_index][2],
		LEVELS[level_index][1], ball.ball_radius, ball.max_radius]


func _show_popup(text: String) -> void:
	popup.text = text
	popup.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(popup, "modulate:a", 0.0, 0.5)


func _result(win: bool, reason: String) -> Dictionary:
	return {"win": win, "reason": reason, "score": score, "stars": stars,
		"jumps": jumps, "best_altitude": ball.best_altitude}


func _on_wrong_key() -> void:
	await get_tree().create_timer(0.8).timeout
	_show_screen(wrong_key_scene, _result(false, "Wrong key!"))


func _on_ball_full() -> void:
	if finished:
		return
	finished = true
	score += finish_bonus
	_show_popup("MAX SIZE!")
	await get_tree().create_timer(1.0).timeout
	_show_screen(retry_scene, _result(true, "Ball filled the screen"))


# ---------- custom screens ----------

func _show_screen(scene: PackedScene, data: Dictionary) -> void:
	if scene == null:
		_show_fallback(data)
		return
	if screen != null:
		screen.queue_free()
	screen = scene.instantiate()
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	screen_layer.add_child(screen)
	if screen.has_signal("play_pressed"):
		screen.connect("play_pressed", _on_play)
	if screen.has_signal("retry_pressed"):
		screen.connect("retry_pressed", _on_retry)
	if screen.has_signal("menu_pressed"):
		screen.connect("menu_pressed", _on_menu)
	if screen.has_method("show_result"):
		screen.call("show_result", data)
	get_tree().paused = true


func _on_play() -> void:
	get_tree().paused = false
	skip_menu = true
	if screen != null:
		screen.queue_free()
		screen = null


func _on_retry() -> void:
	skip_menu = true
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu() -> void:
	skip_menu = false
	get_tree().paused = false
	get_tree().reload_current_scene()


func _show_fallback(d: Dictionary) -> void:
	var l := Label.new()
	l.position = Vector2(190, 220)
	l.size = Vector2(900, 260)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 56)
	l.text = "%s\nScore %d   Stars %d\nPress R or click to retry" % [
		"YOU WIN!" if d.get("win", false) else "GAME OVER",
		d.get("score", 0), d.get("stars", 0)]
	hud.get_parent().add_child(l)
	waiting_retry = true


func _unhandled_input(e: InputEvent) -> void:
	if not waiting_retry:
		return
	var k := e as InputEventKey
	var m := e as InputEventMouseButton
	if (k != null and k.pressed and k.keycode == KEY_R) or (m != null and m.pressed):
		_on_retry()
