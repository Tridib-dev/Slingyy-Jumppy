extends RigidBody2D

signal boosted
signal bounced
signal wrong_key
signal ball_full
signal size_changed(radius: float)
signal altitude_changed(current: float, best: float)

@export var window_height: float = 150.0
@export var cooldown: float = 1.5
@export var min_boost: float = 700.0
@export var max_boost: float = 1100.0
@export var pixels_per_metre: float = 50.0
@export var punish_outside_window: bool = false
@export var growth_per_bounce: float = 12.0   # radius gained per bounce
@export var max_radius: float = 300.0         # ball is "full" at this size
@export var bounce_gap: float = 0.25          # ignore contacts closer together than this

@onready var ray: RayCast2D = $GroundRay
@onready var shape_node: CollisionShape2D = $CollisionShape2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var stall_time: float = 0.0
var circle: CircleShape2D
var ball_radius: float = 20.0
var start_radius: float = 20.0
var sprite_base_scale: Vector2 = Vector2.ONE
var waiting_retry: bool = false
var boost_multiplier: float = 1.0
var cooldown_left: float = 0.0
var bounce_lock: float = 0.0
var start_y: float = 0.0
var best_altitude: float = 0.0
var start_y_set: bool = false

var prompt_keys: Array = [KEY_W, KEY_A, KEY_S, KEY_D]
var prompt_key: int = KEY_W
var started: bool = false
var is_over: bool = false

var prompt_label: Label
var hint_label: Label
var line: Line2D


func _ready() -> void:
	# own copy of the shape so resizing doesn't change the saved scene
	circle = (shape_node.shape as CircleShape2D).duplicate() as CircleShape2D
	shape_node.shape = circle
	ball_radius = circle.radius
	start_radius = ball_radius
	sprite_base_scale = sprite.scale

	ray.top_level = true
	ray.target_position = Vector2(0, 3000)
	ray.add_exception(self)
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	_build_ui()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	prompt_label = Label.new()
	prompt_label.position = Vector2(340, 40)
	prompt_label.size = Vector2(600, 110)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 72)
	layer.add_child(prompt_label)
	hint_label = Label.new()
	hint_label.position = Vector2(340, 150)
	hint_label.size = Vector2(600, 50)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 34)
	hint_label.modulate = Color(0.3, 1.0, 0.3)
	layer.add_child(hint_label)

	# the booster line, drawn in world space
	line = Line2D.new()
	line.top_level = true
	line.width = 6.0
	line.z_index = 5
	line.add_point(Vector2(0, 0))
	line.add_point(Vector2(1280, 0))
	line.visible = false
	add_child(line)


func _physics_process(delta: float) -> void:
	ray.global_position = global_position
	ray.global_rotation = 0.0
	cooldown_left = maxf(0.0, cooldown_left - delta)
	bounce_lock = maxf(0.0, bounce_lock - delta)

	var bottom: float = global_position.y + ball_radius
	if not start_y_set:
		start_y = bottom
		start_y_set = true
	var alt: float = (start_y - bottom) / pixels_per_metre
	best_altitude = maxf(best_altitude, alt)
	altitude_changed.emit(alt, best_altitude)

	if not started and not freeze:
		started = true
		_new_prompt()

	if started and not is_over:
		if height_above_ground() < 8.0 and linear_velocity.length() < 40.0:
			stall_time += delta
			if stall_time > 0.7:
				_fail()
		else:
			stall_time = 0.0
		var ok: bool = can_boost()
		prompt_label.modulate = Color(0.3, 1.0, 0.3) if ok else Color.WHITE
		hint_label.text = "THROW BOOSTER!" if ok else ""
		line.default_color = Color(0.2, 1.0, 0.2) if ok else Color(1, 1, 1, 0.35)
		line.visible = true
		if ray.is_colliding():
			var y: float = ray.get_collision_point().y - window_height
			line.set_point_position(0, Vector2(0, y))
			line.set_point_position(1, Vector2(1280, y))
	else:
		line.visible = false
		hint_label.text = ""


func height_above_ground() -> float:
	if ray.is_colliding():
		return ray.get_collision_point().y - global_position.y - ball_radius
	return INF


func can_boost() -> bool:
	if freeze or is_over:
		return false
	if cooldown_left > 0.0:
		return false
	if linear_velocity.y <= 0.0:
		return false
	return height_above_ground() <= window_height


func try_boost() -> void:
	if not can_boost():
		return
	var closeness: float = 1.0 - clampf(height_above_ground() / window_height, 0.0, 1.0)
	var strength: float = lerpf(min_boost, max_boost, closeness) * boost_multiplier
	linear_velocity.y = -strength
	cooldown_left = cooldown
	boosted.emit()
	_grow.call_deferred()
	_new_prompt()


func _new_prompt() -> void:
	var k: int = prompt_key
	while k == prompt_key:
		k = prompt_keys.pick_random()
	prompt_key = k
	prompt_label.text = "Press [%s]" % OS.get_keycode_string(prompt_key as Key)


func _on_body_entered(_body: Node) -> void:
	if freeze or is_over or not started:
		return
	if height_above_ground() < 15.0:
		_fail()

func _grow() -> void:
	if is_over:
		return
	ball_radius = minf(ball_radius + growth_per_bounce, max_radius)
	circle.radius = ball_radius
	sprite.scale = sprite_base_scale * (ball_radius / start_radius)
	global_position.y -= growth_per_bounce      # lift so it doesn't sink into the ground
	size_changed.emit(ball_radius)
	if ball_radius >= max_radius:
		is_over = true
		ball_full.emit()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if is_over or freeze or not started:
		return
	if int(k.keycode) == prompt_key:
		try_boost()
	elif punish_outside_window or can_boost():
		is_over = true
		wrong_key.emit()


func _fail() -> void:
	if is_over:
		return
	is_over = true
	wrong_key.emit()
