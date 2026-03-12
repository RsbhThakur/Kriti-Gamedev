extends CharacterBody2D

signal enemy_attacked_player(damage: int)
signal enemy_died(kill_value: int)
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
var stuck_timer := 0.0
var last_position := Vector2.ZERO
const STUCK_CHECK_INTERVAL := 0.5
const STUCK_DISTANCE_THRESHOLD := 4.0
var stuck_direction := Vector2.ZERO
var stuck_dodge_timer := 0.0


var wall_check_callable: Callable


func _ready():
	current_health = max_health
	if is_heavy_enemy:
		is_active = false
		visible = false
	if player_path != NodePath():
		player = get_node_or_null(player_path)

	last_position = global_position

	heavy_growl_player = AudioStreamPlayer2D.new()
	heavy_growl_player.stream = load("res://assets/audio/bigzombie.mp3")
	heavy_growl_player.volume_db = 0
	heavy_growl_player.max_distance = 1400.0
	heavy_growl_player.process_mode = Node.PROCESS_MODE_ALWAYS
	heavy_growl_player.bus = "Master"
	add_child(heavy_growl_player)


func _physics_process(delta):
	if player == null or is_frozen:
		velocity = Vector2.ZERO
		return

	attack_timer = max(attack_timer - delta, 0.0)

	var to_player = player.global_position - global_position
	var distance = to_player.length()

	# Heavy enemy activation check
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

	# Once active, always stay alerted and chase
	if not is_alerted:
		is_alerted = true
		emit_signal("enemy_alerted")

	# Attack if close enough — but only if we have line of sight (no wall between us)
	if distance <= attack_radius:
		var can_hit = _has_line_of_sight_to_player()
		if can_hit:
			velocity = Vector2.ZERO
			try_attack_player()
			move_and_slide()
			return
		# Blocked by wall — keep moving toward player instead of standing still

	# Direct movement toward player with stuck detection
	var move_speed = walk_speed * difficulty_scale
	if distance <= boost_radius:
		move_speed = boost_speed * difficulty_scale

	# Stuck detection: if we haven't moved much, dodge sideways
	stuck_timer -= delta
	if stuck_timer <= 0.0:
		stuck_timer = STUCK_CHECK_INTERVAL
		if global_position.distance_to(last_position) < STUCK_DISTANCE_THRESHOLD:
			# Pick a perpendicular dodge direction
			var perp = Vector2(-to_player.y, to_player.x).normalized()
			if randf() > 0.5:
				perp = -perp
			stuck_direction = (to_player.normalized() * 0.4 + perp * 0.6).normalized()
			stuck_dodge_timer = 0.6
		else:
			stuck_direction = Vector2.ZERO
		last_position = global_position

	stuck_dodge_timer = max(stuck_dodge_timer - delta, 0.0)

	var direction: Vector2
	if stuck_dodge_timer > 0.0 and stuck_direction != Vector2.ZERO:
		direction = stuck_direction
	else:
		direction = to_player.normalized()

	velocity = direction * move_speed
	update_animation(direction)
	move_and_slide()


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


func _has_line_of_sight_to_player() -> bool:
	if player == null:
		return false
	# Use tile-based wall check instead of physics raycasts
	if wall_check_callable.is_valid():
		return not wall_check_callable.call(global_position, player.global_position)
	return true


func set_player(node: Node2D) -> void:
	player = node


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
	if heavy:
		max_health = 10
		current_health = max_health
		attack_damage = 30
		walk_speed = 48.0
		boost_speed = 82.0
		attack_cooldown = 1.25
		attack_radius = 90.0
		activation_radius = 230.0
		is_active = false
		visible = false
		scale = Vector2(4.0, 4.0)
	else:
		max_health = 1
		current_health = max_health
		attack_damage = 10
		walk_speed = 62.0
		boost_speed = 104.0
		attack_cooldown = 1.35
		is_active = true
		visible = true
		scale = Vector2(1.0, 1.0)


func can_be_seen() -> bool:
	if is_heavy_enemy and not is_active:
		return false
	return true


func take_damage(amount: int = 1) -> void:
	current_health -= amount
	if current_health > 0:
		return

	var kill_value = 5 if is_heavy_enemy else 1
	emit_signal("enemy_died", kill_value)
	queue_free()
