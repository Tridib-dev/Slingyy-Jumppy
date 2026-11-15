extends Camera2D

@export var target: RigidBody2D
@export var follow_speed: float = 6.0
@export var ground_view_y: float = 360.0
@export var top_margin: float = 200.0   # ball is never allowed above this many px from the top

func _ready() -> void:
	make_current()
	global_position = Vector2(640.0, ground_view_y)

func _process(delta: float) -> void:
	if target == null:
		return
	var goal_y: float = minf(target.global_position.y - 60.0, ground_view_y)
	global_position.x = 640.0
	global_position.y = lerpf(global_position.y, goal_y, clampf(follow_speed * delta, 0.0, 1.0))

	# hard limit: if the ball is too high on screen, pull the camera up immediately
	var min_ball_y: float = global_position.y - 360.0 + top_margin
	if target.global_position.y < min_ball_y:
		global_position.y = target.global_position.y + 360.0 - top_margin
