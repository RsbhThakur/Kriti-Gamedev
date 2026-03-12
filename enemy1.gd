extends CharacterBody2D

@export var speed = 120
@export var player_path: NodePath
@export var bullet_scene: PackedScene

@export var detect_distance = 400
@export var shoot_distance = 350
@export var shoot_angle = 47.5

var player
var random_direction = Vector2.ZERO
var random_timer = 0

var fire_rate = 0.6
var fire_timer = 0

var facing_vector = Vector2.DOWN

@onready var sprite = $AnimatedSprite2D


func _ready():
	player = get_node(player_path)
	choose_random_direction()


func _physics_process(delta):

	fire_timer -= delta
	random_timer -= delta

	var direction = Vector2.ZERO
	var to_player = player.global_position - global_position
	var distance = to_player.length()

	# PLAYER DETECTED
	if distance < detect_distance:
		direction = to_player.normalized()
	else:
		# RANDOM WALK
		if random_timer <= 0:
			choose_random_direction()
		direction = random_direction

	velocity = direction * speed
	move_and_slide()

	update_animation(direction)

	# SHOOTING
	if distance < shoot_distance:
		try_shoot(to_player)


func choose_random_direction():

	random_timer = randf_range(2,4)

	random_direction = Vector2(
		randf_range(-1,1),
		randf_range(-1,1)
	).normalized()


func update_animation(dir):

	if dir == Vector2.ZERO:
		return

	if abs(dir.x) > abs(dir.y):
		if dir.x > 0:
			facing_vector = Vector2.RIGHT
			sprite.play("zombie_walkright")
		else:
			facing_vector = Vector2.LEFT
			sprite.play("zombie_walkleft")
	else:
		if dir.y > 0:
			facing_vector = Vector2.DOWN
			sprite.play("zombie_walkdown")
		else:
			facing_vector = Vector2.UP
			sprite.play("zombie_walkup")


func try_shoot(to_player):

	var aim = to_player.normalized()

	var angle = abs(facing_vector.angle_to(aim))

	if angle > deg_to_rad(shoot_angle):
		return

	if fire_timer <= 0:

		fire_timer = fire_rate

		var bullet = bullet_scene.instantiate()
		bullet.global_position = global_position
		bullet.direction = aim

		get_tree().current_scene.add_child(bullet)
