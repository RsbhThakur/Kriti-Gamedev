extends Control

const MASTER_BUS := "Master"
var master_bus_index := -1
var previous_master_volume_db := 0.0

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
	_setup_visual_buttons()

	master_bus_index = AudioServer.get_bus_index(MASTER_BUS)
	if master_bus_index >= 0:
		AudioServer.set_bus_mute(master_bus_index, false)
		AudioServer.set_bus_volume_db(master_bus_index, 0.0)
		previous_master_volume_db = AudioServer.get_bus_volume_db(master_bus_index)
		sound_button.button_pressed = AudioServer.is_bus_mute(master_bus_index)
	$bgm.play()


func _setup_visual_buttons() -> void:
	# Let TextureButtons handle touch/click input directly
	play_button.mouse_filter = Control.MOUSE_FILTER_STOP
	help_button.mouse_filter = Control.MOUSE_FILTER_STOP
	sound_button.mouse_filter = Control.MOUSE_FILTER_STOP

	play_button.disabled = false
	help_button.disabled = false
	sound_button.disabled = false

	for btn in [play_button, help_button, sound_button]:
		btn.anchor_left = 0.0
		btn.anchor_top = 0.0
		btn.anchor_right = 0.0
		btn.anchor_bottom = 0.0
		btn.size = Vector2(308.0, 306.0)
		btn.scale = Vector2(0.35, 0.35)

	play_button.position = Vector2(572.0, 187.0)
	help_button.position = Vector2(760.0, 334.0)
	sound_button.position = Vector2(386.0, 331.0)

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
