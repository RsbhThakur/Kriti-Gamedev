extends Node2D

@export var enemy_scene: PackedScene = preload("res://Enemy1.tscn")
@export var max_health := 100
@export var max_lives := 3
@export var base_spawn_interval := 2.8
@export var minimum_spawn_interval := 0.55
@export var spawn_acceleration := 0.04
@export var map_scale := 2.0
@export var wall_thickness := 96.0
@export var obstacle_count_min := 90
@export var obstacle_count_max := 140
@export var max_enemies := 38

const HOME_SCENE := "res://node_2d.tscn"

var health := 100
var lives := 3
var kills := 0
var elapsed_time := 0.0
var seconds_since_last_hit := 0.0
var regen_tick := 0.0
var game_over := false
var is_life_loss_pause := false
var is_pause_menu_open := false
var alert_audio_latched := false
var growl_cooldown := 0.0
var map_rect: Rect2

var obstacle_textures: Array[Texture2D] = []
var ground_texture: Texture2D
var ground_decal_textures: Array[Texture2D] = []

var spawn_timer: Timer
var bgm_player: AudioStreamPlayer
var zombie_alert_player: AudioStreamPlayer

var hud_health_bar: ProgressBar
var hud_health_label: Label
var hud_lives_label: Label
var hud_time_label: Label
var hud_kills_label: Label
var hud_game_over_label: Label
var hit_flash: ColorRect
var pause_panel: Panel

@onready var world := $World
@onready var ground_layer := $World/Ground
@onready var obstacles_layer := $World/Obstacles
@onready var enemies_layer := $World/Enemies
@onready var player = $World/CharacterBody2D
@onready var move_joystick = $UI/"movement joystick"
@onready var gun_joystick = $UI/"gun joystick"


func _ready() -> void:
	randomize()
	if OS.get_name() == "Android":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	var master_index = AudioServer.get_bus_index("Master")
	if master_index >= 0:
		AudioServer.set_bus_mute(master_index, false)
		AudioServer.set_bus_volume_db(master_index, 0.0)

	health = max_health
	lives = max_lives
	_load_vfx_assets()
	player.gun_joystick_path = gun_joystick.get_path()
	player.movement_joystick_path = move_joystick.get_path()
	player.set_joysticks(move_joystick, gun_joystick)

	_build_hud()
	_build_pause_menu()
	_build_audio_players()
	_build_bounded_map()
	_setup_spawn_timer()
	_spawn_enemy_near_player_front()
	for _index in range(8):
		spawn_enemy()
	_update_hud()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_toggle_pause_menu()

	if get_tree().paused:
		return

	if game_over:
		_update_hud()
		return

	elapsed_time += delta
	seconds_since_last_hit += delta
	growl_cooldown = max(growl_cooldown - delta, 0.0)
	_update_difficulty_for_enemies()

	if seconds_since_last_hit >= 1.0 and health < max_health:
		regen_tick += delta
		while regen_tick >= 1.0 and health < max_health:
			health += 1
			regen_tick -= 1.0

	_update_enemy_visibility()
	_update_alert_audio_state()
	_update_hud()


func _setup_spawn_timer() -> void:
	spawn_timer = Timer.new()
	spawn_timer.one_shot = true
	add_child(spawn_timer)
	spawn_timer.timeout.connect(_on_spawn_timeout)
	_schedule_next_spawn()


func _on_spawn_timeout() -> void:
	if game_over or is_life_loss_pause:
		_schedule_next_spawn()
		return

	if get_tree().get_nodes_in_group("enemies").size() < max_enemies:
		spawn_enemy()
		if elapsed_time > 50.0 and randf() < 0.45 and get_tree().get_nodes_in_group("enemies").size() < max_enemies:
			spawn_enemy()
	_schedule_next_spawn()


func _schedule_next_spawn() -> void:
	var interval = max(minimum_spawn_interval, base_spawn_interval - elapsed_time * spawn_acceleration)
	interval += randf_range(-0.6, 0.6)
	interval = max(interval, minimum_spawn_interval)
	spawn_timer.start(interval)


func _difficulty_multiplier() -> float:
	return clamp(1.0 + elapsed_time / 50.0, 1.0, 3.2)


func _update_difficulty_for_enemies() -> void:
	var difficulty = _difficulty_multiplier()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.call("set_difficulty_scale", difficulty)


func spawn_enemy() -> void:
	if enemy_scene == null:
		return

	var enemy = enemy_scene.instantiate()
	enemy.global_position = _pick_random_spawn_point()
	enemies_layer.add_child(enemy)
	_register_enemy(enemy)


func _register_enemy(enemy: Node) -> void:
	enemy.add_to_group("enemies")
	enemy.call("set_player", player)
	enemy.call("set_difficulty_scale", _difficulty_multiplier())
	if not enemy.is_connected("enemy_attacked_player", _on_enemy_attacked_player):
		enemy.connect("enemy_attacked_player", _on_enemy_attacked_player)
	if not enemy.is_connected("enemy_died", _on_enemy_died):
		enemy.connect("enemy_died", _on_enemy_died)


func _pick_random_spawn_point() -> Vector2:
	var center = player.global_position
	var margin = wall_thickness + 36.0
	var min_x = map_rect.position.x + margin
	var max_x = map_rect.end.x - margin
	var min_y = map_rect.position.y + margin
	var max_y = map_rect.end.y - margin

	for _attempt in range(36):
		var angle = randf_range(0.0, TAU)
		var distance = randf_range(170.0, 360.0)
		var candidate = center + Vector2.RIGHT.rotated(angle) * distance
		candidate.x = clamp(candidate.x, min_x, max_x)
		candidate.y = clamp(candidate.y, min_y, max_y)
		if candidate.distance_to(center) > 140.0 and not _is_position_blocked(candidate):
			return candidate

	return Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))


func _is_position_blocked(pos: Vector2) -> bool:
	var state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result = state.intersect_point(query, 1)
	return not result.is_empty()


func _on_enemy_attacked_player(damage: int) -> void:
	if game_over or is_life_loss_pause:
		return

	health -= damage
	seconds_since_last_hit = 0.0
	regen_tick = 0.0

	if health > 0:
		flash_hit_overlay(0.14)
		return

	lives -= 1
	if lives <= 0:
		_trigger_game_over()
		return

	_start_life_loss_pause()


func _on_enemy_died() -> void:
	kills += 1


func _trigger_game_over() -> void:
	game_over = true
	spawn_timer.stop()
	player.set_can_control(false)
	hud_game_over_label.visible = true
	flash_hit_overlay(0.45)
	_update_hud()


func _start_life_loss_pause() -> void:
	is_life_loss_pause = true
	spawn_timer.stop()
	player.set_can_control(false)
	player.play_death_feedback()
	flash_hit_overlay(0.4)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.call("set_frozen", true)

	await get_tree().create_timer(3.0).timeout
	health = max_health
	player.global_position = player.global_position + Vector2(randf_range(-80, 80), randf_range(-80, 80))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.call("set_frozen", false)

	player.set_can_control(true)
	is_life_loss_pause = false
	if not game_over:
		_schedule_next_spawn()


func _update_enemy_visibility() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var distance = enemy.global_position.distance_to(player.global_position)
		var seen = player.is_point_in_torch(enemy.global_position) or distance <= 190.0
		enemy.call("set_seen", seen)


func _update_alert_audio_state() -> void:
	var has_alert = false
	var nearest_enemy_distance := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		nearest_enemy_distance = min(nearest_enemy_distance, enemy.global_position.distance_to(player.global_position))
		if enemy.call("get_is_alerted"):
			has_alert = true

	var enemy_is_close = nearest_enemy_distance <= 320.0

	if (has_alert or enemy_is_close) and growl_cooldown <= 0.0:
		if zombie_alert_player:
			zombie_alert_player.stop()
			zombie_alert_player.play()
		growl_cooldown = 2.8

	if has_alert or enemy_is_close:
		alert_audio_latched = true
	else:
		alert_audio_latched = false


func _build_bounded_map() -> void:
	for child in ground_layer.get_children():
		child.queue_free()
	for child in obstacles_layer.get_children():
		child.queue_free()

	var viewport_size = get_viewport().get_visible_rect().size
	map_rect = Rect2(Vector2.ZERO, viewport_size * map_scale)
	player.global_position = map_rect.get_center()

	var ground = Sprite2D.new()
	ground.texture = ground_texture
	ground.centered = false
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground.position = map_rect.position
	ground.scale = Vector2(map_rect.size.x / float(ground_texture.get_width()), map_rect.size.y / float(ground_texture.get_height()))
	ground_layer.add_child(ground)

	var fog_overlay = ColorRect.new()
	fog_overlay.position = map_rect.position
	fog_overlay.size = map_rect.size
	fog_overlay.color = Color(0.06, 0.13, 0.06, 0.04)
	ground_layer.add_child(fog_overlay)

	_create_map_walls()
	_populate_map_obstacles()


func _create_map_walls() -> void:
	var top = Rect2(map_rect.position.x, map_rect.position.y - wall_thickness, map_rect.size.x, wall_thickness)
	var bottom = Rect2(map_rect.position.x, map_rect.end.y, map_rect.size.x, wall_thickness)
	var left = Rect2(map_rect.position.x - wall_thickness, map_rect.position.y - wall_thickness, wall_thickness, map_rect.size.y + wall_thickness * 2.0)
	var right = Rect2(map_rect.end.x, map_rect.position.y - wall_thickness, wall_thickness, map_rect.size.y + wall_thickness * 2.0)

	for wall_rect in [top, bottom, left, right]:
		var wall = StaticBody2D.new()
		wall.global_position = wall_rect.position + wall_rect.size * 0.5
		obstacles_layer.add_child(wall)

		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = wall_rect.size
		collision.shape = shape
		wall.add_child(collision)


func _populate_map_obstacles() -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var count = rng.randi_range(obstacle_count_min, obstacle_count_max)
	var spawn_margin = wall_thickness + 60.0

	for _index in range(count):
		var position = Vector2(
			rng.randf_range(map_rect.position.x + spawn_margin, map_rect.end.x - spawn_margin),
			rng.randf_range(map_rect.position.y + spawn_margin, map_rect.end.y - spawn_margin)
		)

		if position.distance_to(player.global_position) < 260.0:
			continue

		_create_random_obstacle(obstacles_layer, position, rng)


func _spawn_enemy_near_player_front() -> void:
	if enemy_scene == null:
		return

	var preferred = player.global_position + Vector2(220, 0)
	var margin = wall_thickness + 36.0
	preferred.x = clamp(preferred.x, map_rect.position.x + margin, map_rect.end.x - margin)
	preferred.y = clamp(preferred.y, map_rect.position.y + margin, map_rect.end.y - margin)

	if _is_position_blocked(preferred):
		preferred = _pick_random_spawn_point()

	var enemy = enemy_scene.instantiate()
	enemy.global_position = preferred
	enemies_layer.add_child(enemy)
	_register_enemy(enemy)


func _create_random_obstacle(parent: Node2D, pos: Vector2, rng: RandomNumberGenerator) -> void:
	var body = StaticBody2D.new()
	body.global_position = pos
	parent.add_child(body)

	var type_roll = rng.randi_range(0, 2)
	var sprite = Sprite2D.new()
	sprite.texture = obstacle_textures[type_roll]
	sprite.scale = Vector2.ONE * rng.randf_range(2.4, 3.8)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(sprite)

	var silhouette = Polygon2D.new()
	silhouette.polygon = PackedVector2Array([
		Vector2(-22, -22),
		Vector2(22, -22),
		Vector2(22, 22),
		Vector2(-22, 22)
	])
	silhouette.color = Color(0.09, 0.23, 0.1, 0.75)
	silhouette.scale = Vector2.ONE * sprite.scale.x
	body.add_child(silhouette)

	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 10.5 * sprite.scale.x
	collision.shape = shape
	body.add_child(collision)


func _load_vfx_assets() -> void:
	ground_texture = load("res://images/tile_grass.png")
	obstacle_textures = [
		load("res://addons/virtual_joystick/Objects/Nature/Green/Tree_1_Spruce_Green.png"),
		load("res://addons/virtual_joystick/Objects/Nature/Green/Bush_2_Green.png"),
		load("res://addons/virtual_joystick/Objects/Nature/Flowers_Mashrooms_Other-nature-stuff/Rocks/Rock_4.png")
	]
	ground_decal_textures = [
		load("res://addons/virtual_joystick/Objects/Nature/Green/Bush_1_Green.png"),
		load("res://addons/virtual_joystick/Objects/Nature/Green/Bush_2_Green.png")
	]


func _create_ground_decal(parent: Node2D, rng: RandomNumberGenerator) -> void:
	if ground_decal_textures.is_empty():
		return
	if map_rect.size == Vector2.ZERO:
		return

	var decal = Sprite2D.new()
	decal.texture = ground_decal_textures[rng.randi_range(0, ground_decal_textures.size() - 1)]
	decal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	decal.modulate = Color(1, 1, 1, rng.randf_range(0.18, 0.33))
	decal.position = Vector2(
		rng.randf_range(20.0, map_rect.size.x - 20.0),
		rng.randf_range(20.0, map_rect.size.y - 20.0)
	)
	decal.scale = Vector2.ONE * rng.randf_range(0.4, 0.8)
	parent.add_child(decal)


func _build_audio_players() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.stream = load("res://assets/audio/bgm.mp3")
	bgm_player.bus = "Master"
	bgm_player.autoplay = true
	add_child(bgm_player)
	bgm_player.play()

	zombie_alert_player = AudioStreamPlayer.new()
	zombie_alert_player.stream = load("res://assets/audio/zombie.mp3")
	zombie_alert_player.bus = "Master"
	zombie_alert_player.volume_db = 4.0
	add_child(zombie_alert_player)


func _build_hud() -> void:
	var hud_root = Control.new()
	hud_root.name = "HUD"
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(hud_root)

	hud_health_bar = ProgressBar.new()
	hud_health_bar.position = Vector2(20, 16)
	hud_health_bar.size = Vector2(280, 24)
	hud_health_bar.max_value = max_health
	hud_health_bar.show_percentage = false
	hud_root.add_child(hud_health_bar)

	hud_health_label = Label.new()
	hud_health_label.position = Vector2(24, 42)
	hud_root.add_child(hud_health_label)

	hud_lives_label = Label.new()
	hud_lives_label.position = Vector2(340, 16)
	hud_root.add_child(hud_lives_label)

	hud_time_label = Label.new()
	hud_time_label.position = Vector2(500, 16)
	hud_root.add_child(hud_time_label)

	hud_kills_label = Label.new()
	hud_kills_label.position = Vector2(660, 16)
	hud_root.add_child(hud_kills_label)

	hud_game_over_label = Label.new()
	hud_game_over_label.position = Vector2(360, 280)
	hud_game_over_label.size = Vector2(560, 180)
	hud_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_game_over_label.add_theme_font_size_override("font_size", 34)
	hud_game_over_label.visible = false
	hud_root.add_child(hud_game_over_label)

	hit_flash = ColorRect.new()
	hit_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit_flash.color = Color(1, 0.1, 0.1, 0.0)
	hud_root.add_child(hit_flash)


func _build_pause_menu() -> void:
	pause_panel = Panel.new()
	pause_panel.name = "PausePanel"
	pause_panel.position = Vector2(480, 180)
	pause_panel.size = Vector2(320, 240)
	pause_panel.visible = false
	pause_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	$UI.add_child(pause_panel)

	var title = Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 20)
	title.size = Vector2(320, 36)
	pause_panel.add_child(title)

	var restart_btn = Button.new()
	restart_btn.text = "Restart"
	restart_btn.position = Vector2(90, 90)
	restart_btn.size = Vector2(140, 40)
	restart_btn.pressed.connect(_on_restart_pressed)
	restart_btn.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	pause_panel.add_child(restart_btn)

	var home_btn = Button.new()
	home_btn.text = "Home"
	home_btn.position = Vector2(90, 144)
	home_btn.size = Vector2(140, 40)
	home_btn.pressed.connect(_on_home_pressed)
	home_btn.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	pause_panel.add_child(home_btn)


func _toggle_pause_menu() -> void:
	is_pause_menu_open = not is_pause_menu_open
	pause_panel.visible = is_pause_menu_open
	get_tree().paused = is_pause_menu_open


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_home_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(HOME_SCENE)


func _update_hud() -> void:
	hud_health_bar.value = health
	hud_health_label.text = "Health: %d / %d" % [health, max_health]
	hud_lives_label.text = "Lives: %d" % lives
	hud_time_label.text = "Time: %s" % _format_time(elapsed_time)
	hud_kills_label.text = "Kills: %d" % kills

	if game_over:
		hud_game_over_label.visible = true
		hud_game_over_label.text = "GAME OVER\nTime: %s\nKills: %d\nPress Esc for menu" % [_format_time(elapsed_time), kills]


func flash_hit_overlay(alpha: float) -> void:
	hit_flash.color = Color(1.0, 0.15, 0.15, alpha)
	var tween = create_tween()
	tween.tween_property(hit_flash, "color", Color(1.0, 0.15, 0.15, 0.0), 0.22)


func _format_time(total_seconds: float) -> String:
	var seconds = int(total_seconds)
	var minutes = seconds / 60
	var remainder = seconds % 60
	return "%02d:%02d" % [minutes, remainder]
