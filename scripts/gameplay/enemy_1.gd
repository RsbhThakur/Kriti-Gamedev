extends CharacterBody2D

signal enemy_attacked_player(damage: int)
signal enemy_died
signal enemy_alerted

@export var walk_speed = 65.0
@export var boost_speed = 110.0
@export var detect_radius = 1200.0
@export var boost_radius = 200.0
@export var attack_radius = 42.0
@export var attack_damage = 20
@export var attack_cooldown = 1.5
@export var obstacle_probe_distance = 56.0
@export var max_health = 3
@export var player_path: NodePath
@export var is_heavy_enemy := false
@export var activation_radius := 230.0

@onready var sprite = $AnimatedSprite2D
@onready var attack_sound: AudioStreamPlayer2D = $AttackSound

var player
var facing_vector = Vector2.DOWN
var current_health = 3
var attack_timer = 0.0
var is_seen = true
var is_alerted := false
var is_frozen := false
var difficulty_scale := 1.0
var is_active := true
var has_activation_roared := false
var heavy_growl_player: AudioStreamPlayer2D
var base_sprite_scale := Vector2.ONE
var base_collision_radius := 16.0


func _ready():
	current_health = max_health
	if sprite:
		base_sprite_scale = sprite.scale
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape is CircleShape2D:
		base_collision_radius = collision_shape.shape.radius
	if is_heavy_enemy:
		is_active = false
		visible = false
	if player_path != NodePath():
		player = get_node_or_null(player_path)

	heavy_growl_player = AudioStreamPlayer2D.new()
	heavy_growl_player.stream = load("res://assets/audio/zombie.mp3")
	heavy_growl_player.volume_db = 2.0
	heavy_growl_player.max_distance = 1400.0
	add_child(heavy_growl_player)


func _physics_process(delta):
	if player == null or is_frozen:
		velocity = Vector2.ZERO
		return

	attack_timer = max(attack_timer - delta, 0.0)

	var to_player = player.global_position - global_position
	var distance = to_player.length()

	if is_heavy_enemy and not is_active:
		if distance <= activation_radius:
			is_active = true
			if not has_activation_roared and heavy_growl_player:
				heavy_growl_player.play()
				has_activation_roared = true
			is_alerted = true
			emit_signal("enemy_alerted")
		else:
			velocity = Vector2.ZERO
			return

	var can_see_player = distance <= detect_radius and has_line_of_sight_to_player()
	var should_chase = distance <= detect_radius

	if can_see_player and not is_alerted:
		is_alerted = true
		emit_signal("enemy_alerted")
	elif not can_see_player:
		is_alerted = false

	if distance <= attack_radius:
		velocity = Vector2.ZERO
		try_attack_player()
	elif should_chase:
		var move_speed = walk_speed * difficulty_scale
		if distance <= boost_radius and can_see_player:
			move_speed = boost_speed * difficulty_scale

		var direction = pick_clear_direction(to_player.normalized())
		velocity = direction * move_speed
		update_animation(direction)
	else:
		velocity = Vector2.ZERO

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


func has_line_of_sight_to_player() -> bool:
	if player == null:
		return false

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	query.exclude = [self]
	var hit = space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	return hit.get("collider") == player


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
	if attack_sound:
		attack_sound.play()
	emit_signal("enemy_attacked_player", attack_damage)


func set_player(node: Node2D) -> void:
	player = node
	if player:
		add_collision_exception_with(player)
		player.add_collision_exception_with(self)


func set_seen(seen: bool) -> void:
	is_seen = seen
	if is_heavy_enemy and not is_active:
		visible = false
		return
	visible = seen


func set_frozen(value: bool) -> void:
	is_frozen = value
	if value:
		velocity = Vector2.ZERO


func set_difficulty_scale(value: float) -> void:
	difficulty_scale = max(value, 1.0)


func get_is_alerted() -> bool:
	return is_alerted


func configure_enemy(heavy: bool) -> void:
	is_heavy_enemy = heavy
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
	var nav_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D")
	if heavy:
		max_health = 10
		current_health = max_health
		attack_damage = 30
		walk_speed = 48.0
		boost_speed = 82.0
		attack_cooldown = 1.8
		activation_radius = 230.0
		is_active = false
		visible = false
		if sprite:
			sprite.scale = base_sprite_scale * 4.0
		if collision_shape and collision_shape.shape is CircleShape2D:
			collision_shape.shape.radius = base_collision_radius * 4.0
		if nav_agent:
			nav_agent.radius = 56.0
			nav_agent.neighbor_distance = 220.0
			
	else:
		max_health = 1
		current_health = max_health
		attack_damage = 10
		walk_speed = 62.0
		boost_speed = 104.0
		attack_cooldown = 1.35
		is_active = true
		visible = true
		if sprite:
			sprite.scale = base_sprite_scale
		if collision_shape and collision_shape.shape is CircleShape2D:
			collision_shape.shape.radius = base_collision_radius
		if nav_agent:
			nav_agent.radius = 14.0
			nav_agent.neighbor_distance = 140.0


func can_be_seen() -> bool:
	if is_heavy_enemy and not is_active:
		return false
	return true


func take_damage(amount: int = 1) -> void:
	current_health -= amount
	if current_health > 0:
		return

	emit_signal("enemy_died")
	queue_free()
