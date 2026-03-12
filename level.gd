extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_home_pressed() -> void:
	$helpsound.play()
	await get_tree().create_timer(0.2).timeout
	get_tree().change_scene_to_file("res://node_2d.tscn")
	pass # Replace with function body.


func _on_home_mouse_entered() -> void:
	$hoversound.play()
	pass # Replace with function body.


func _on_home_mouse_exited() -> void:
	pass # Replace with function body.
	
	
