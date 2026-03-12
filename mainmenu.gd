extends Control

var music_on = true

func _ready():
	$bgm.play()

# PLAY BUTTON
func _on_play_pressed():
	$playclick.play()
	await get_tree().create_timer(0.2).timeout
	get_tree().change_scene_to_file("res://game.tscn")

func _on_play_mouse_entered():
	$hoversound.play()


# HELP BUTTON
func _on_help_pressed():
	$helpsound.play()
	await get_tree().create_timer(0.2).timeout
	get_tree().change_scene_to_file("res://helpscene.tscn")

func _on_help_mouse_entered():
	$hoversound.play()


# SOUND TOGGLE
func _on_sound_pressed():
	if music_on:
		$bgm.stop()
		music_on = false
	else:
		$bgm.play()
		music_on = true

func _on_sound_mouse_entered():
	$hoversound.play()
