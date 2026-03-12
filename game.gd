extends CanvasLayer

@export var enemy_scene: PackedScene = preload("res://Enemy1.tscn")
@export var max_health := 100
@export var max_lives := 3
@export var base_spawn_interval := 3.2
@export var minimum_spawn_interval := 0.8
@export var spawn_acceleration := 0.05

var health := 100
var lives := 3
var kills := 0
var elapsed_time := 0.0
var seconds_since_last_hit := 0.0
var regen_tick := 0.0
var game_over := false

var spawn_timer: Timer
var hud_health_bar: ProgressBar
var hud_health_label: Label
var hud_lives_label: Label
var hud_time_label: Label
var hud_kills_label: Label
var hud_game_over_label: Label

@onready var player = $"CharacterBody2D"


func _ready() -> void:
	randomize()

	health = max_health
	lives = max_lives

	_build_hud()
	_build_obstacles()
	_setup_existing_enemies()
	_setup_spawn_timer()
	_update_hud()


func _process(delta: float) -> void:
	if game_over:
		return

	elapsed_time += delta
	seconds_since_last_hit += delta

	if seconds_since_last_hit >= 1.0 and health < max_health:
		regen_tick += delta
		while regen_tick >= 1.0 and health < max_health:
			health += 1
			regen_tick -= 1.0

	_update_enemy_visibility()
	_update_hud()


func _setup_spawn_timer() -> void:
	spawn_timer = Timer.new()
	spawn_timer.one_shot = true
	add_child(spawn_timer)
	spawn_timer.timeout.connect(_on_spawn_timeout)
	_schedule_next_spawn()


func _on_spawn_timeout() -> void:
	if game_over:
		return

	spawn_enemy()
	_schedule_next_spawn()


func _schedule_next_spawn() -> void:
	var interval = max(minimum_spawn_interval, base_spawn_interval - elapsed_time * spawn_acceleration)
	interval += randf_range(-0.25, 0.25)
	interval = max(interval, minimum_spawn_interval)
	spawn_timer.start(interval)


func spawn_enemy() -> void:
	if enemy_scene == null:
		return

	var enemy = enemy_scene.instantiate()
	enemy.global_position = _pick_spawn_point()
	add_child(enemy)
	_register_enemy(enemy)


func _setup_existing_enemies() -> void:
	for child in get_children():
		if child == player:
			continue
		if child.has_method("set_player"):
			_register_enemy(child)


func _register_enemy(enemy: Node) -> void:
	enemy.add_to_group("enemies")
	enemy.call("set_player", player)
	if not enemy.is_connected("enemy_attacked_player", _on_enemy_attacked_player):
		enemy.connect("enemy_attacked_player", _on_enemy_attacked_player)
	if not enemy.is_connected("enemy_died", _on_enemy_died):
		enemy.connect("enemy_died", _on_enemy_died)


func _pick_spawn_point() -> Vector2:
	var screen_size = get_viewport().get_visible_rect().size
	var spawn_margin = 60.0
	var side = randi() % 4

	match side:
		0:
			return Vector2(randf_range(spawn_margin, screen_size.x - spawn_margin), spawn_margin)
		1:
			return Vector2(randf_range(spawn_margin, screen_size.x - spawn_margin), screen_size.y - spawn_margin)
		2:
			return Vector2(spawn_margin, randf_range(spawn_margin, screen_size.y - spawn_margin))
		_:
			return Vector2(screen_size.x - spawn_margin, randf_range(spawn_margin, screen_size.y - spawn_margin))


func _on_enemy_attacked_player(damage: int) -> void:
	if game_over:
		return

	health -= damage
	seconds_since_last_hit = 0.0
	regen_tick = 0.0

	if health > 0:
		return

	lives -= 1
	if lives <= 0:
		_trigger_game_over()
		return

	health = max_health
	player.global_position = get_viewport().get_visible_rect().size * 0.5


func _on_enemy_died() -> void:
	kills += 1


func _trigger_game_over() -> void:
	game_over = true
	if spawn_timer:
		spawn_timer.stop()

	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()

	if player:
		player.set_physics_process(false)

	hud_game_over_label.visible = true
	_update_hud()


func _update_enemy_visibility() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var seen = player.is_point_in_torch(enemy.global_position)
		enemy.call("set_seen", seen)


func _build_hud() -> void:
	var hud_root = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_root)

	hud_health_bar = ProgressBar.new()
	hud_health_bar.position = Vector2(20, 16)
	hud_health_bar.size = Vector2(260, 24)
	hud_health_bar.max_value = max_health
	hud_health_bar.show_percentage = false
	hud_root.add_child(hud_health_bar)

	hud_health_label = Label.new()
	hud_health_label.position = Vector2(24, 42)
	hud_health_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	hud_root.add_child(hud_health_label)

	hud_lives_label = Label.new()
	hud_lives_label.position = Vector2(356, 16)
	hud_lives_label.add_theme_color_override("font_color", Color(1, 0.95, 0.75, 1))
	hud_root.add_child(hud_lives_label)

	var life_icon = ColorRect.new()
	life_icon.position = Vector2(322, 14)
	life_icon.size = Vector2(22, 22)
	life_icon.color = Color(0.95, 0.4, 0.4, 1.0)
	hud_root.add_child(life_icon)

	hud_time_label = Label.new()
	hud_time_label.position = Vector2(480, 16)
	hud_time_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1, 1))
	hud_root.add_child(hud_time_label)

	hud_kills_label = Label.new()
	hud_kills_label.position = Vector2(640, 16)
	hud_kills_label.add_theme_color_override("font_color", Color(1, 0.86, 0.86, 1))
	hud_root.add_child(hud_kills_label)

	hud_game_over_label = Label.new()
	hud_game_over_label.position = Vector2(360, 300)
	hud_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_game_over_label.size = Vector2(560, 120)
	hud_game_over_label.add_theme_font_size_override("font_size", 32)
	hud_game_over_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5, 1))
	hud_game_over_label.visible = false
	hud_root.add_child(hud_game_over_label)


func _update_hud() -> void:
	hud_health_bar.value = health
	hud_health_label.text = "Health: %d / %d" % [health, max_health]
	hud_lives_label.text = "Lives: %d" % lives
	hud_time_label.text = "Time: %s" % _format_time(elapsed_time)
	hud_kills_label.text = "Kills: %d" % kills

	if game_over:
		hud_game_over_label.text = "GAME OVER\nTime: %s   Kills: %d" % [_format_time(elapsed_time), kills]


func _format_time(total_seconds: float) -> String:
	var seconds = int(total_seconds)
	var minutes = seconds / 60
	var remainder = seconds % 60
	return "%02d:%02d" % [minutes, remainder]


func _build_obstacles() -> void:
	_create_obstacle(Vector2(400, 220), Vector2(140, 70))
	_create_obstacle(Vector2(780, 310), Vector2(180, 80))
	_create_obstacle(Vector2(560, 520), Vector2(120, 120))
	_create_obstacle(Vector2(980, 560), Vector2(170, 70))


func _create_obstacle(center: Vector2, size: Vector2) -> void:
	var body = StaticBody2D.new()
	body.global_position = center
	add_child(body)

	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

	var visual = Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, size.y * 0.5),
		Vector2(-size.x * 0.5, size.y * 0.5)
	])
	visual.color = Color(0.2, 0.3, 0.18, 0.95)
	body.add_child(visual)
