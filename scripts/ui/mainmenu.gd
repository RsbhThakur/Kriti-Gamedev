extends Control

const MASTER_BUS := "Master"
const MENU_BUTTON_SCALE := 0.35
var master_bus_index := -1
var previous_master_volume_db := 0.0
var play_hitbox: Button
var help_hitbox: Button
var sound_hitbox: Button

@onready var play_button: TextureButton = $play
@onready var help_button: TextureButton = $help
@onready var sound_button: TextureButton = $sound

func _ready():
	if OS.get_name() == "Android":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_PASS
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	_setup_visual_buttons()
	_apply_menu_layout()

	master_bus_index = AudioServer.get_bus_index(MASTER_BUS)
	if master_bus_index >= 0:
		AudioServer.set_bus_mute(master_bus_index, false)
		AudioServer.set_bus_volume_db(master_bus_index, 0.0)
		previous_master_volume_db = AudioServer.get_bus_volume_db(master_bus_index)
		sound_button.button_pressed = AudioServer.is_bus_mute(master_bus_index)
	$bgm.play()


func _on_viewport_resized() -> void:
	_apply_menu_layout()


func _setup_visual_buttons() -> void:
	play_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sound_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	play_button.disabled = false
	help_button.disabled = false
	sound_button.disabled = false

	play_button.scale = Vector2(MENU_BUTTON_SCALE, MENU_BUTTON_SCALE)
	help_button.scale = Vector2(MENU_BUTTON_SCALE, MENU_BUTTON_SCALE)
	sound_button.scale = Vector2(MENU_BUTTON_SCALE, MENU_BUTTON_SCALE)


func _apply_menu_layout() -> void:
	var viewport_size = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var play_tex_size = Vector2(308.0, 306.0)
	var help_tex_size = Vector2(307.0, 308.0)
	var sound_tex_size = Vector2(309.0, 309.0)

	var play_size = play_tex_size * MENU_BUTTON_SCALE
	var help_size = help_tex_size * MENU_BUTTON_SCALE
	var sound_size = sound_tex_size * MENU_BUTTON_SCALE

	var horizontal_gap = clamp(viewport_size.x * 0.03, 20.0, 48.0)
	var top_y = clamp(viewport_size.y * 0.22, 140.0, 240.0)
	var bottom_y = top_y + play_size.y + clamp(viewport_size.y * 0.03, 20.0, 40.0)
	var center_x = viewport_size.x * 0.5

	play_button.anchor_left = 0.0
	play_button.anchor_top = 0.0
	play_button.anchor_right = 0.0
	play_button.anchor_bottom = 0.0
	play_button.position = Vector2(center_x - play_size.x * 0.5, top_y)
	play_button.size = play_tex_size

	help_button.anchor_left = 0.0
	help_button.anchor_top = 0.0
	help_button.anchor_right = 0.0
	help_button.anchor_bottom = 0.0
	help_button.position = Vector2(center_x + horizontal_gap * 0.5, bottom_y)
	help_button.size = help_tex_size

	sound_button.anchor_left = 0.0
	sound_button.anchor_top = 0.0
	sound_button.anchor_right = 0.0
	sound_button.anchor_bottom = 0.0
	sound_button.position = Vector2(center_x - sound_size.x - horizontal_gap * 0.5, bottom_y)
	sound_button.size = sound_tex_size

	_setup_button_hitboxes()


func _setup_button_hitboxes() -> void:
	for child in get_children():
		if child.name.begins_with("Hitbox"):
			child.queue_free()

	play_hitbox = _create_hitbox_button("HitboxPlay", Rect2(play_button.position, play_button.size * play_button.scale), _on_play_pressed, _on_play_mouse_entered)
	help_hitbox = _create_hitbox_button("HitboxHelp", Rect2(help_button.position, help_button.size * help_button.scale), _on_help_pressed, _on_help_mouse_entered)
	sound_hitbox = _create_hitbox_button("HitboxSound", Rect2(sound_button.position, sound_button.size * sound_button.scale), _on_sound_pressed, _on_sound_mouse_entered)


func _create_hitbox_button(button_name: String, rect: Rect2, pressed_callback: Callable, hover_callback: Callable) -> Button:
	var hitbox = Button.new()
	hitbox.name = button_name
	hitbox.position = rect.position
	hitbox.size = rect.size
	hitbox.text = ""
	hitbox.focus_mode = Control.FOCUS_NONE
	hitbox.flat = true
	hitbox.modulate = Color(1, 1, 1, 0.02)
	hitbox.mouse_filter = Control.MOUSE_FILTER_STOP
	hitbox.pressed.connect(pressed_callback)
	hitbox.mouse_entered.connect(hover_callback)
	add_child(hitbox)
	move_child(hitbox, -1)
	return hitbox

# PLAY BUTTON
func _on_play_pressed():
	$playclick.play()
	_cleanup_menu_audio()
	get_tree().call_deferred("change_scene_to_file", "res://game.tscn")

func _on_play_mouse_entered():
	$hoversound.play()


# EXIT BUTTON (reuses help button slot)
func _on_help_pressed():
	$helpsound.play()
	get_tree().quit()

func _on_help_mouse_entered():
	$hoversound.play()


# SOUND TOGGLE
func _on_sound_pressed():
	if master_bus_index < 0:
		return

	var next_mute = not AudioServer.is_bus_mute(master_bus_index)
	AudioServer.set_bus_mute(master_bus_index, next_mute)
	if next_mute:
		previous_master_volume_db = AudioServer.get_bus_volume_db(master_bus_index)
		AudioServer.set_bus_volume_db(master_bus_index, -80.0)
	else:
		AudioServer.set_bus_volume_db(master_bus_index, previous_master_volume_db)
	sound_button.button_pressed = next_mute

func _on_sound_mouse_entered():
	$hoversound.play()


func _cleanup_menu_audio() -> void:
	$bgm.stop()
	$bgm.stream = null


func _on_play_mouse_exited() -> void:
	pass


func _on_help_mouse_exited() -> void:
	pass


func _on_sound_mouse_exited() -> void:
	pass
