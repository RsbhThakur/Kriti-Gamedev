extends CharacterBody2D

signal enemy_attacked_player(damage: int)
signal enemy_died

@export var walk_speed = 85.0
@export var boost_speed = 170.0
@export var boost_radius = 200.0
@export var attack_radius = 42.0
@export var attack_damage = 20
@export var attack_cooldown = 1.2
@export var obstacle_probe_distance = 56.0
@export var max_health = 3
@export var player_path: NodePath

@onready var sprite = $AnimatedSprite2D

var player
var facing_vector = Vector2.DOWN
var current_health = 3
var attack_timer = 0.0
var is_seen = true


func _ready():
	current_health = max_health
	if player_path != NodePath():
		player = get_node_or_null(player_path)


func _physics_process(delta):
	if player == null:
		return

	attack_timer = max(attack_timer - delta, 0.0)

	var to_player = player.global_position - global_position
	var distance = to_player.length()
	if distance <= attack_radius:
		velocity = Vector2.ZERO
		try_attack_player()
	else:
		var move_speed = walk_speed
		if distance <= boost_radius:
			move_speed = boost_speed

		var direction = pick_clear_direction(to_player.normalized())
		velocity = direction * move_speed
		update_animation(direction)

	move_and_slide()


func pick_clear_direction(desired_direction: Vector2) -> Vector2:
	if desired_direction == Vector2.ZERO:
		return Vector2.ZERO

	var angle_offsets = [0.0, 22.5, -22.5, 45.0, -45.0, 70.0, -70.0, 95.0, -95.0, 140.0, -140.0, 180.0]
	for angle in angle_offsets:
		var test_direction = desired_direction.rotated(deg_to_rad(angle)).normalized()
		if not is_direction_blocked(test_direction):
			return test_direction

	return Vector2.ZERO


func is_direction_blocked(direction: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + direction * obstacle_probe_distance)
	query.exclude = [self, player]
	var result = space_state.intersect_ray(query)
	return not result.is_empty()


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


func try_attack_player() -> void:
	if attack_timer > 0.0:
		return

	attack_timer = attack_cooldown
	emit_signal("enemy_attacked_player", attack_damage)


func set_player(node: Node2D) -> void:
	player = node


func set_seen(seen: bool) -> void:
	is_seen = seen
	visible = seen


func take_damage(amount: int = 1) -> void:
	current_health -= amount
	if current_health > 0:
		return

	emit_signal("enemy_died")
	queue_free()
