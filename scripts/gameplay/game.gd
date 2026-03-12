extends Node2D

@export var enemy_scene: PackedScene = preload("res://Enemy1.tscn")
@export var max_health := 100
@export var max_lives := 3
@export var base_spawn_interval := 10.0
@export var minimum_spawn_interval := 3.5
@export var spawn_acceleration := 0.008
@export var max_enemies := 22
@export var hidden_main_enemy_count := 4

const HOME_SCENE := "res://node_2d.tscn"
const SMALL_SPAWN_RATE_MULTIPLIER := 1.4
const BIG_SPAWN_RATE_MULTIPLIER := 1.2

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
var big_spawn_fractional_credit := 0.0
var map_rect: Rect2

var newmap_scene: PackedScene = preload("res://newmap.tscn")
var wall_tilemap: TileMap

var spawn_timer: Timer
var bgm_player: AudioStreamPlayer
var zombie_alert_player: AudioStreamPlayer

var hud_health_bar: ProgressBar
var hud_health_label: Label
var hud_lives_label: Label
var hud_time_label: Label
var hud_kills_label: Label
var hud_game_over_label: Label
var pause_button: Button
var hit_flash: ColorRect
var pause_panel: Panel
var pause_title_label: Label
var pause_stats_label: Label
var pause_resume_button: Button
var pause_restart_button: Button
var pause_home_button: Button

@onready var world := $World
@onready var ground_layer := $World/Ground
@onready var obstacles_layer := $World/Obstacles
@onready var enemies_layer := $World/Enemies
@onready var player = $World/CharacterBody2D
@onready var move_joystick = $UI/"movement joystick"
@onready var gun_joystick = $UI/"gun joystick"


func _ready() -> void:
	randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_name() == "Android":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	var master_index = AudioServer.get_bus_index("Master")
	if master_index >= 0:
		AudioServer.set_bus_mute(master_index, false)
		AudioServer.set_bus_volume_db(master_index, 0.0)

	health = max_health
	lives = max_lives
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.gun_joystick_path = gun_joystick.get_path()
	player.movement_joystick_path = move_joystick.get_path()
	player.set_joysticks(move_joystick, gun_joystick)

	_build_hud()
	_build_pause_menu()
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	_apply_ui_layout()
	_build_audio_players()
	_build_newmap()
	_spawn_hidden_main_enemies()
	_setup_spawn_timer()
	spawn_enemy()
	_update_hud()


func _on_viewport_resized() -> void:
	_apply_ui_layout()


func _apply_ui_layout() -> void:
	var viewport_size = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var min_dim = min(viewport_size.x, viewport_size.y)
	var joy_size = clamp(min_dim * 0.24, 190.0, 280.0)
	var joy_margin = clamp(min_dim * 0.07, 40.0, 90.0)

	move_joystick.anchor_left = 0.0
	move_joystick.anchor_right = 0.0
	move_joystick.anchor_top = 1.0
	move_joystick.anchor_bottom = 1.0
	move_joystick.offset_left = joy_margin
	move_joystick.offset_top = -joy_margin - joy_size
	move_joystick.offset_right = joy_margin + joy_size
	move_joystick.offset_bottom = -joy_margin

	gun_joystick.anchor_left = 1.0
	gun_joystick.anchor_right = 1.0
	gun_joystick.anchor_top = 1.0
	gun_joystick.anchor_bottom = 1.0
	gun_joystick.offset_left = -joy_margin - joy_size
	gun_joystick.offset_top = -joy_margin - joy_size
	gun_joystick.offset_right = -joy_margin
	gun_joystick.offset_bottom = -joy_margin

	if pause_button:
		pause_button.anchor_left = 1.0
		pause_button.anchor_right = 1.0
		pause_button.offset_left = -140
		pause_button.offset_right = -20
		pause_button.offset_top = 16
		pause_button.offset_bottom = 60

	if pause_panel:
		var panel_size = Vector2(
			clamp(viewport_size.x * 0.30, 320.0, 420.0),
			clamp(viewport_size.y * 0.48, 300.0, 380.0)
		)
		pause_panel.size = panel_size
		pause_panel.position = (viewport_size - panel_size) * 0.5

		if pause_title_label:
			pause_title_label.size = Vector2(panel_size.x, 36)
		if pause_stats_label:
			pause_stats_label.position = Vector2(24, 62)
			pause_stats_label.size = Vector2(panel_size.x - 48, 78)

		var button_width = 140.0
		var button_height = 40.0
		var button_x = (panel_size.x - button_width) * 0.5
		if pause_resume_button:
			pause_resume_button.position = Vector2(button_x, 154)
			pause_resume_button.size = Vector2(button_width, button_height)
		if pause_restart_button:
			pause_restart_button.position = Vector2(button_x, 204)
			pause_restart_button.size = Vector2(button_width, button_height)
		if pause_home_button:
			pause_home_button.position = Vector2(button_x, 254)
			pause_home_button.size = Vector2(button_width, button_height)

	# Sync joystick internal default positions after layout so _reset() snaps
	# back to the correct corner position instead of the stale startup position.
	call_deferred("_sync_joystick_defaults")


func _sync_joystick_defaults() -> void:
	if is_instance_valid(move_joystick) and move_joystick._base != null:
		move_joystick._base_default_position = move_joystick._base.position
		move_joystick._tip_default_position = move_joystick._tip.position
	if is_instance_valid(gun_joystick) and gun_joystick._base != null:
		gun_joystick._base_default_position = gun_joystick._base.position
		gun_joystick._tip_default_position = gun_joystick._tip.position


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_on_pause_requested()

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
	spawn_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(spawn_timer)
	spawn_timer.timeout.connect(_on_spawn_timeout)
	_schedule_next_spawn()


func _on_spawn_timeout() -> void:
	if game_over or is_life_loss_pause:
		_schedule_next_spawn()
		return

	if get_tree().get_nodes_in_group("enemies").size() < max_enemies:
		spawn_enemy()
	_schedule_next_spawn()


func _schedule_next_spawn() -> void:
	var interval = max(minimum_spawn_interval, base_spawn_interval - elapsed_time * spawn_acceleration)
	interval += randf_range(-0.6, 0.6)
	interval = max(interval, minimum_spawn_interval)
	interval /= SMALL_SPAWN_RATE_MULTIPLIER
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
	enemy.call("configure_enemy", false)
	_register_enemy(enemy)


func _register_enemy(enemy: Node) -> void:
	enemy.add_to_group("enemies")
	enemy.call("set_player", player)
	enemy.call("set_difficulty_scale", _difficulty_multiplier())
	enemy.set("wall_check_callable", Callable(self, "_is_wall_between"))
	if not enemy.is_connected("enemy_attacked_player", _on_enemy_attacked_player):
		enemy.connect("enemy_attacked_player", _on_enemy_attacked_player)
	if not enemy.is_connected("enemy_died", _on_enemy_died):
		enemy.connect("enemy_died", _on_enemy_died)


func _pick_random_spawn_point() -> Vector2:
	var center = player.global_position
	var margin = 48.0
	var min_x = map_rect.position.x + margin
	var max_x = map_rect.end.x - margin
	var min_y = map_rect.position.y + margin
	var max_y = map_rect.end.y - margin

	for _attempt in range(50):
		var angle = randf_range(0.0, TAU)
		var distance = randf_range(280.0, 500.0)
		var candidate = center + Vector2.RIGHT.rotated(angle) * distance
		candidate.x = clamp(candidate.x, min_x, max_x)
		candidate.y = clamp(candidate.y, min_y, max_y)
		if candidate.distance_to(center) > 200.0 and not _is_position_blocked(candidate):
			return candidate

	# Fallback: still spawn near player, not randomly across entire map
	var fallback_angle = randf_range(0.0, TAU)
	var fallback_pos = center + Vector2.RIGHT.rotated(fallback_angle) * 350.0
	fallback_pos.x = clamp(fallback_pos.x, min_x, max_x)
	fallback_pos.y = clamp(fallback_pos.y, min_y, max_y)
	return fallback_pos


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
	health = max(health, 0)
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


func _on_enemy_died(kill_value: int = 1) -> void:
	kills += kill_value
	# If a big enemy died, respawn scaled big-enemy count elsewhere
	if kill_value >= 5:
		call_deferred("_spawn_scaled_heavy_on_death")


func _trigger_game_over() -> void:
	game_over = true
	spawn_timer.stop()
	player.set_can_control(false)
	hud_game_over_label.visible = false
	flash_hit_overlay(0.45)
	_show_game_over_menu()
	_update_hud()


func _start_life_loss_pause() -> void:
	is_life_loss_pause = true
	spawn_timer.stop()
	player.set_can_control(false)
	player.play_death_feedback()
	flash_hit_overlay(0.4)
	if pause_button:
		pause_button.visible = false

	_clear_all_enemies()

	await get_tree().process_frame
	# Instant respawn to center
	health = max_health
	seconds_since_last_hit = 0.0
	regen_tick = 0.0
	player.global_position = map_rect.get_center() -Vector2(450,0)
	await _reset_enemies_after_life_loss()
	# Now pause for 3 seconds after respawn
	await get_tree().create_timer(3.0).timeout

	player.set_can_control(true)
	is_life_loss_pause = false
	if pause_button:
		pause_button.visible = not is_pause_menu_open
	if not game_over:
		_schedule_next_spawn()


func _update_enemy_visibility() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.call("can_be_seen"):
			enemy.call("set_seen", false)
			continue
		var in_torch = player.is_point_in_torch(enemy.global_position)
		if in_torch:
			# Check tile-based line-of-sight — don't reveal through walls
			if _is_wall_between(player.global_position, enemy.global_position):
				in_torch = false
			enemy.call("set_seen", in_torch)
		else:
			enemy.call("set_seen", false)


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


func _build_newmap() -> void:
	# Instance the pre-built newmap scene with background, walls, and obstacles
	var map_instance = newmap_scene.instantiate()
	ground_layer.add_child(map_instance)

	# Grab reference to the TileMap for tile-based wall checks
	wall_tilemap = map_instance.get_node("TileMap")

	# The TileMap in newmap is at position (7034, 2883) with scale (4,4)
	# Tile size is 16x16. The enclosed walled area is:
	#   Left wall column X=14, Right wall column X=43 (vertical walls, source 6)
	#   Top wall row Y=7, Bottom wall row Y=33 (horizontal walls, source 1)
	# Playable interior: tiles X=15..42, Y=8..32
	# World coord = tilemap_pos + tile_coord * tile_size * scale
	var tm_pos = Vector2(7034.0, 2883.0)
	var tile_world = 16.0 * 4.0  # 64 px per tile
	var interior_min = Vector2(tm_pos.x + 1.0 * tile_world, tm_pos.y + 1.0 * tile_world)
	var interior_max = Vector2(tm_pos.x + 70.0 * tile_world, tm_pos.y + 40.0 * tile_world)
	map_rect = Rect2(interior_min, interior_max - interior_min)

	# Place the player in the centre of the enclosed area
	player.global_position = map_rect.get_center() -Vector2(450,0)

	# Give the player a callable for ray-wall intersection (torch clipping)
	player.wall_ray_callable = Callable(self, "_ray_hit_wall_distance")

	# Build a NavigationRegion2D covering the playable interior
	_build_navigation_region()


func _build_audio_players() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.stream = load("res://assets/audio/level3.ogg")
	bgm_player.bus = "Master"
	bgm_player.volume_db =-2.0
	bgm_player.autoplay = true
	bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(bgm_player)
	bgm_player.play()
	bgm_player.stream.loop=true

	zombie_alert_player = AudioStreamPlayer.new()
	zombie_alert_player.stream = load("res://assets/audio/zombie.mp3")
	zombie_alert_player.bus = "Master"
	zombie_alert_player.volume_db = -12.0
	zombie_alert_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(zombie_alert_player)


# ---------- Tile-based line-of-sight helpers ----------

func _world_to_tile(world_pos: Vector2) -> Vector2i:
	# Convert a world position to TileMap cell coordinates.
	var local_pos = (world_pos - wall_tilemap.global_position) / wall_tilemap.scale
	return wall_tilemap.local_to_map(local_pos)


func _is_wall_at_tile(tile_pos: Vector2i) -> bool:
	# Only count a tile as a wall if it has physics collision polygons.
	for layer_id in range(wall_tilemap.get_layers_count()):
		var tile_data = wall_tilemap.get_cell_tile_data(layer_id, tile_pos)
		if tile_data != null and tile_data.get_collision_polygons_count(0) > 0:
			return true
	return false


func _is_wall_between(from_pos: Vector2, to_pos: Vector2) -> bool:
	# Bresenham line trace through the tile grid.
	# Returns true if any cell on the line contains a wall tile (layer 1).
	if wall_tilemap == null:
		return false

	var from_tile := _world_to_tile(from_pos)
	var to_tile := _world_to_tile(to_pos)

	var dx := absi(to_tile.x - from_tile.x)
	var dy := absi(to_tile.y - from_tile.y)
	var sx := 1 if from_tile.x < to_tile.x else -1
	var sy := 1 if from_tile.y < to_tile.y else -1
	var err := dx - dy

	var x := from_tile.x
	var y := from_tile.y

	while true:
		# Skip the start tile (player's own cell)
		if not (x == from_tile.x and y == from_tile.y):
			if _is_wall_at_tile(Vector2i(x, y)):
				return true

		if x == to_tile.x and y == to_tile.y:
			break

		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy

	return false


func _ray_hit_wall_distance(origin: Vector2, ray_dir: Vector2, max_dist: float) -> float:
	# Walk along the ray in tile-sized steps and return the distance
	# to the first wall tile hit.  Returns -1.0 if no wall is hit.
	if wall_tilemap == null:
		return -1.0

	var tile_world := 16.0 * wall_tilemap.scale.x   # 64 px per tile
	var step := tile_world * 0.45                     # slightly less than half a tile for accuracy
	var dist := 0.0

	while dist <= max_dist:
		var sample_pos := origin + ray_dir * dist
		var tile_pos := _world_to_tile(sample_pos)
		if _is_wall_at_tile(tile_pos):
			return dist
		dist += step

	return -1.0


func _build_navigation_region() -> void:
	# Create a simple navigation polygon covering the playable area.
	# The TileMap's own physics collisions will act as obstacles that
	# NavigationAgent2D avoids via avoidance, but we need a walkable
	# region that the nav system can path through.
	var nav_region = NavigationRegion2D.new()
	nav_region.name = "NavRegion"
	world.add_child(nav_region)

	var nav_poly = NavigationPolygon.new()
	# Outer boundary = the full playable interior rect
	var outline = PackedVector2Array([
		map_rect.position,
		Vector2(map_rect.end.x, map_rect.position.y),
		map_rect.end,
		Vector2(map_rect.position.x, map_rect.end.y)
	])
	nav_poly.add_outline(outline)
	nav_poly.make_polygons_from_outlines()
	nav_region.navigation_polygon = nav_poly


func _spawn_hidden_main_enemies() -> void:
	if enemy_scene == null:
		return

	var scaled_hidden_count = int(round(float(hidden_main_enemy_count) * BIG_SPAWN_RATE_MULTIPLIER))
	scaled_hidden_count = max(scaled_hidden_count, 1)
	for _index in range(scaled_hidden_count):
		_spawn_one_heavy_enemy()


func _spawn_scaled_heavy_on_death() -> void:
	if enemy_scene == null:
		return

	var total = BIG_SPAWN_RATE_MULTIPLIER + big_spawn_fractional_credit
	var spawn_count = int(floor(total))
	big_spawn_fractional_credit = total - float(spawn_count)
	spawn_count = max(spawn_count, 1)

	for _index in range(spawn_count):
		_spawn_one_heavy_enemy()


func _clear_all_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()


func _reset_enemies_after_life_loss() -> void:
	_clear_all_enemies()
	await get_tree().process_frame
	_spawn_hidden_main_enemies()
	spawn_enemy()


func _spawn_one_heavy_enemy() -> void:
	if enemy_scene == null:
		return
	var enemy = enemy_scene.instantiate()
	enemy.global_position = _pick_hidden_main_enemy_spawn()
	enemies_layer.add_child(enemy)
	enemy.call("configure_enemy", true)
	_register_enemy(enemy)


func _pick_hidden_main_enemy_spawn() -> Vector2:
	var margin = 48.0
	var min_x = map_rect.position.x + margin
	var max_x = map_rect.end.x - margin
	var min_y = map_rect.position.y + margin
	var max_y = map_rect.end.y - margin

	for _attempt in range(60):
		var candidate = Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))
		if candidate.distance_to(player.global_position) < 320.0:
			continue
		if _is_position_blocked(candidate):
			continue
		return candidate

	return Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))


func _build_hud() -> void:
	var hud_root = Control.new()
	hud_root.name = "HUD"
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_PASS
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

	pause_button = Button.new()
	pause_button.name = "PauseButton"
	pause_button.text = "Pause"
	pause_button.anchor_left = 1.0
	pause_button.anchor_right = 1.0
	pause_button.offset_left = -140
	pause_button.offset_right = -20
	pause_button.offset_top = 16
	pause_button.offset_bottom = 60
	pause_button.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_button.pressed.connect(_on_pause_button_pressed)
	hud_root.add_child(pause_button)

	hud_game_over_label = Label.new()
	hud_game_over_label.position = Vector2(500, 280)
	hud_game_over_label.size = Vector2(560, 180)
	hud_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_game_over_label.add_theme_font_size_override("font_size", 34)
	hud_game_over_label.visible = false
	hud_root.add_child(hud_game_over_label)

	hit_flash = ColorRect.new()
	hit_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit_flash.color = Color(1, 0.1, 0.1, 0.0)
	hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(hit_flash)


func _build_pause_menu() -> void:
	pause_panel = Panel.new()
	pause_panel.name = "PausePanel"
	pause_panel.position = Vector2(580, 150)
	pause_panel.size = Vector2(360, 320)
	pause_panel.visible = false
	pause_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	$UI.add_child(pause_panel)

	pause_title_label = Label.new()
	pause_title_label.text = "Paused"
	pause_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title_label.position = Vector2(0, 18)
	pause_title_label.size = Vector2(360, 36)
	pause_title_label.add_theme_font_size_override("font_size", 26)
	pause_panel.add_child(pause_title_label)

	pause_stats_label = Label.new()
	pause_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_stats_label.position = Vector2(24, 62)
	pause_stats_label.size = Vector2(312, 78)
	pause_panel.add_child(pause_stats_label)

	pause_resume_button = Button.new()
	pause_resume_button.text = "Resume"
	pause_resume_button.position = Vector2(110, 154)
	pause_resume_button.size = Vector2(140, 40)
	pause_resume_button.pressed.connect(_on_resume_pressed)
	pause_resume_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	pause_panel.add_child(pause_resume_button)

	pause_restart_button = Button.new()
	pause_restart_button.text = "Restart"
	pause_restart_button.position = Vector2(110, 204)
	pause_restart_button.size = Vector2(140, 40)
	pause_restart_button.pressed.connect(_on_restart_pressed)
	pause_restart_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	pause_panel.add_child(pause_restart_button)

	pause_home_button = Button.new()
	pause_home_button.text = "Home"
	pause_home_button.position = Vector2(110, 254)
	pause_home_button.size = Vector2(140, 40)
	pause_home_button.pressed.connect(_on_home_pressed)
	pause_home_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	pause_panel.add_child(pause_home_button)

	_refresh_pause_menu(false)


func _toggle_pause_menu() -> void:
	if game_over or is_life_loss_pause:
		return

	if is_pause_menu_open:
		_close_pause_menu()
	else:
		_open_pause_menu()


func _on_pause_requested() -> void:
	_toggle_pause_menu()


func _open_pause_menu() -> void:
	is_pause_menu_open = true
	_refresh_pause_menu(false)
	pause_panel.visible = true
	if pause_button:
		pause_button.visible = false
	_set_game_paused_visual_state(true)
	get_tree().paused = true


func _close_pause_menu() -> void:
	if game_over:
		return

	is_pause_menu_open = false
	pause_panel.visible = false
	if pause_button:
		pause_button.visible = true
	get_tree().paused = false
	_set_game_paused_visual_state(false)


func _show_game_over_menu() -> void:
	is_pause_menu_open = true
	_refresh_pause_menu(true)
	pause_panel.visible = true
	if pause_button:
		pause_button.visible = false
	_set_game_paused_visual_state(true)
	get_tree().paused = true


func _set_game_paused_visual_state(paused: bool) -> void:
	world.visible = not paused
	move_joystick.visible = not paused
	gun_joystick.visible = not paused
	alert_audio_latched = false
	if paused and zombie_alert_player:
		zombie_alert_player.stop()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.call("set_frozen", paused)


func _refresh_pause_menu(show_game_over: bool) -> void:
	if pause_title_label == null or pause_stats_label == null:
		return

	pause_title_label.text = "Game Over" if show_game_over else "Paused"
	pause_stats_label.text = "Time: %s\nKills: %d\nLives Left: %d" % [_format_time(elapsed_time), kills, max(lives, 0)]
	pause_resume_button.visible = not show_game_over


func _on_pause_button_pressed() -> void:
	_on_pause_requested()


func _on_resume_pressed() -> void:
	_close_pause_menu()


func _on_restart_pressed() -> void:
	is_pause_menu_open = false
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_home_pressed() -> void:
	is_pause_menu_open = false
	get_tree().paused = false
	get_tree().change_scene_to_file(HOME_SCENE)


func _update_hud() -> void:
	hud_health_bar.value = health
	hud_health_label.text = "Health: %d / %d" % [health, max_health]
	hud_lives_label.text = "Lives: %d" % lives
	hud_time_label.text = "Time: %s" % _format_time(elapsed_time)
	hud_kills_label.text = "Kills: %d" % kills
	hud_game_over_label.visible = false

	if is_pause_menu_open:
		_refresh_pause_menu(game_over)


func flash_hit_overlay(alpha: float) -> void:
	hit_flash.color = Color(1.0, 0.15, 0.15, alpha)
	var tween = create_tween()
	tween.tween_property(hit_flash, "color", Color(1.0, 0.15, 0.15, 0.0), 0.22)


func _format_time(total_seconds: float) -> String:
	var seconds = int(total_seconds)
	var minutes = seconds / 60
	var remainder = seconds % 60
	return "%02d:%02d" % [minutes, remainder]
