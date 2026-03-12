extends CharacterBody2D

@export var speed = 200
@export var bullet_scene: PackedScene = preload("res://bullet.tscn")
@export var torch_angle_degrees: float = 90.0
@export var torch_range: float = 360.0

@onready var gun_joystick = $"../gun joystick"
@onready var sprite = $AnimatedSprite2D
@onready var shoot_sound = $ShootSound

var last_direction = "down"
var facing_vector = Vector2.DOWN

var fire_rate = 0.2
var fire_timer = 0


func _physics_process(delta):

	var direction = Input.get_vector("ui_left","ui_right","ui_up","ui_down")

	velocity = direction * speed
	move_and_slide()

	update_animation(direction)
	update_look_direction(direction)

	fire_timer -= delta
	shoot()
	queue_redraw()


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
	var aim = gun_joystick.output
	if aim.length() >= 0.2:
		facing_vector = aim.normalized()
		return

	if move_direction.length() > 0.1:
		facing_vector = move_direction.normalized()


func shoot():

	var aim = gun_joystick.output

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

		get_tree().current_scene.add_child(bullet)

		if shoot_sound:
			shoot_sound.play()


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


func _draw() -> void:
	var dir = get_torch_direction()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN

	var half_angle = deg_to_rad(torch_angle_degrees * 0.5)
	var steps = 20
	var points: PackedVector2Array = [Vector2.ZERO]

	for index in range(steps + 1):
		var t = float(index) / float(steps)
		var angle = lerp(-half_angle, half_angle, t)
		points.append(dir.rotated(angle) * torch_range)

	draw_colored_polygon(points, Color(1.0, 0.95, 0.55, 0.18))
	draw_line(Vector2.ZERO, dir.rotated(-half_angle) * torch_range, Color(1.0, 0.55, 0.45, 0.75), 3.0)
	draw_line(Vector2.ZERO, dir.rotated(half_angle) * torch_range, Color(1.0, 0.55, 0.45, 0.75), 3.0)
