extends Camera2D

@export var target: RigidBody2D
@export var follow_speed: float = 5.0
@export var ground_view_y: float = 360.0   # camera centre when the ball is low
@export var look_ahead: float = 100.0      # keeps the ball in the lower part of the screen

func _ready() -> void:
	make_current()
	global_position = Vector2(640.0, ground_view_y)

func _process(delta: float) -> void:
	if target == null:
		return
	var goal_y: float = minf(target.global_position.y - look_ahead, ground_view_y)
	global_position.x = 640.0
	global_position.y = lerpf(global_position.y, goal_y, clampf(follow_speed * delta, 0.0, 1.0))
