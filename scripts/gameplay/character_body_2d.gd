extends CharacterBody2D

@export var speed = 200
@export var bullet_scene: PackedScene = preload("res://bullet.tscn")
@export var torch_angle_degrees: float = 70.0
@export var torch_range: float = 360.0
@export var gun_joystick_path: NodePath
@export var movement_joystick_path: NodePath

@onready var sprite = $AnimatedSprite2D
@onready var shoot_sound = $ShootSound

var last_direction = "down"
var facing_vector = Vector2.DOWN
var gun_joystick: Node
var movement_joystick: Node
var can_control := true

var fire_rate = 0.2
var fire_timer = 0
var wall_ray_callable: Callable  # Returns distance to first wall along a ray


func _ready() -> void:
	_bind_joysticks()


func _physics_process(delta):
	if not can_control:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction = _get_move_input()

	velocity = direction * speed
	move_and_slide()

	update_animation(direction)
	update_look_direction(direction)

	fire_timer -= delta
	shoot()
	queue_redraw()


func _bind_joysticks() -> void:
	if gun_joystick_path != NodePath():
		gun_joystick = get_node_or_null(gun_joystick_path)
	if movement_joystick_path != NodePath():
		movement_joystick = get_node_or_null(movement_joystick_path)


func _get_move_input() -> Vector2:
	var move_output := Vector2.ZERO
	if movement_joystick:
		move_output = movement_joystick.get("output")
	if move_output.length() >= 0.15:
		return move_output.normalized()
	return Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")


func update_animation(dir):

	if dir == Vector2.ZERO:
		sprite.play("idle_" + last_direction)
		return

	if abs(dir.x) > abs(dir.y):
		if dir.x > 0:
			last_direction = "right"
			facing_vector = Vector2.RIGHT
			sprite.play("walk_right")
		else:
			last_direction = "left"
			facing_vector = Vector2.LEFT
			sprite.play("walk_left")
	else:
		if dir.y > 0:
			last_direction = "down"
			facing_vector = Vector2.DOWN
			sprite.play("walk_down")
		else:
			last_direction = "up"
			facing_vector = Vector2.UP
			sprite.play("walk_up")


func update_look_direction(move_direction: Vector2) -> void:
	var aim = _get_aim_output()
	if aim.length() >= 0.2:
		facing_vector = aim.normalized()
		return

	if move_direction.length() > 0.1:
		facing_vector = move_direction.normalized()


func shoot():
	var aim = _get_aim_output()

	if aim.length() < 0.2:
		return

	var angle = facing_vector.angle_to(aim)
	var max_angle = deg_to_rad(torch_angle_degrees * 0.5)

	if abs(angle) > max_angle:
		return

	var final_direction = facing_vector.rotated(angle).normalized()

	if fire_timer <= 0:
		fire_timer = fire_rate

		if bullet_scene == null:
			return

		var bullet = bullet_scene.instantiate()
		bullet.global_position = global_position + final_direction * 40
		bullet.direction = final_direction
		bullet.from_player = true
		bullet.damage = 1

		bullet.add_collision_exception_with(self)

		get_parent().add_child(bullet)

		if shoot_sound:
			shoot_sound.play()


func _get_aim_output() -> Vector2:
	if gun_joystick:
		var aim = gun_joystick.get("output")
		if aim != null:
			return aim
	return Vector2.ZERO


func set_joysticks(move_node: Node, gun_node: Node) -> void:
	movement_joystick = move_node
	gun_joystick = gun_node


func set_can_control(value: bool) -> void:
	can_control = value
	if not value:
		velocity = Vector2.ZERO


func play_death_feedback() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.45, 0.45, 1.0), 0.12)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)
	tween.tween_property(self, "modulate", Color(1.0, 0.45, 0.45, 1.0), 0.12)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)


func get_torch_direction() -> Vector2:
	return facing_vector.normalized()


func is_point_in_torch(point: Vector2) -> bool:
	var to_point = point - global_position
	if to_point.length() > torch_range:
		return false

	var dir = get_torch_direction()
	var half_angle = deg_to_rad(torch_angle_degrees * 0.5)
	var angle_to_point = abs(dir.angle_to(to_point.normalized()))
	return angle_to_point <= half_angle


func _get_ray_reach(ray_dir: Vector2) -> float:
	# Returns the distance this ray can travel before hitting a wall.
	if wall_ray_callable.is_valid():
		var d = wall_ray_callable.call(global_position, ray_dir, torch_range)
		if d >= 0.0:
			return d
	return torch_range


func _draw() -> void:
	var dir = get_torch_direction()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN

	var half_angle = deg_to_rad(torch_angle_degrees * 0.5)
	var steps = 28
	var points: PackedVector2Array = [Vector2.ZERO]

	for index in range(steps + 1):
		var t = float(index) / float(steps)
		var angle = lerp(-half_angle, half_angle, t)
		var ray_dir = dir.rotated(angle)
		var reach = _get_ray_reach(ray_dir)
		points.append(ray_dir * reach)

	draw_colored_polygon(points, Color(1.0, 0.95, 0.55, 0.18))

	var left_dir = dir.rotated(-half_angle)
	var right_dir = dir.rotated(half_angle)
	draw_line(Vector2.ZERO, left_dir * _get_ray_reach(left_dir), Color(1.0, 0.55, 0.45, 0.75), 3.0)
	draw_line(Vector2.ZERO, right_dir * _get_ray_reach(right_dir), Color(1.0, 0.55, 0.45, 0.75), 3.0)
