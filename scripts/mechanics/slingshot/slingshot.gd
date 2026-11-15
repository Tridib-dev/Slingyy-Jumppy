
extends Node2D

@export var ball_path: NodePath
@export var max_pull_distance: float = 120.0
@export var launch_strength: float = 8.0
@export var ball_pick_radius: float = 35.0
@export var trajectory_points: int = 25
@export var trajectory_time_step: float = 0.08
@export var trajectory_gravity: float = 980.0

@onready var anchor: Marker2D = $Anchor
@onready var launch_point: Marker2D = $LaunchPoint
@onready var ball: RigidBody2D = get_node_or_null(ball_path)


var is_dragging := false
var launch_position: Vector2


func _ready() -> void:
	if ball == null:
		push_error("Slingshot: Assin the Ball node in the Inpector.")
		return

	launch_position = launch_point.global_position

	ball.freeze = true
	ball.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	ball.global_position = launch_position

	queue_redraw()


func _input(event: InputEvent) -> void:
	if ball == null:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:

			if event.pressed:
				if ball.global_position.distance_to(
					get_global_mouse_position()
				) <= ball_pick_radius:
					if ball.freeze:
						is_dragging = true

			elif is_dragging:
				launch_ball()

	elif event is InputEventMouseMotion and is_dragging:
		pull_ball()


func pull_ball() -> void:
	var mouse_position = get_global_mouse_position()
	var pull_vector = mouse_position - launch_position

	if pull_vector.length() > max_pull_distance:
		pull_vector = pull_vector.normalized() * max_pull_distance

	ball.global_position = launch_position + pull_vector

	queue_redraw()


func launch_ball() -> void:
	is_dragging = false

	var pull_vector = launch_position - ball.global_position

	if pull_vector.length() < 5.0:
		ball.global_position = launch_position
		queue_redraw()
		return

	ball.freeze = false

	ball.apply_central_impulse(
		pull_vector * launch_strength
	)
	print("🚀 BALL LAUNCHED!")
	print("Launch velocity: ", ball.linear_velocity)

	queue_redraw()



func _draw() -> void:
	if ball == null or not is_dragging:
		return

	var anchor_pos = to_local(anchor.global_position)
	var ball_pos = to_local(ball.global_position)	
	# Draw stretched elastic
	draw_line(
		anchor_pos,
		ball_pos,
		Color(0.18, 0.12, 0.08),
		5.0
	)	
	# Calculate predicted launch velocity
	var pull_vector = launch_position - ball.global_position
	var initial_velocity = (
		pull_vector * launch_strength / ball.mass
	)	
	# Draw predicted trajectory
	var points := PackedVector2Array()	
	for i in range(trajectory_points):
		var t = i * trajectory_time_step	
		var predicted_position = (
			launch_position
			+ initial_velocity * t
			+ Vector2.DOWN * 0.5 * trajectory_gravity * t * t
		)	
		points.append(to_local(predicted_position))	
	if points.size() > 1:
		draw_polyline(
			points,
			Color(1.0, 0.85, 0.25),
			3.0,
			true
		)	
