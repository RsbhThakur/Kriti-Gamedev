extends CharacterBody2D

@export var speed: float = 300.0
@export var bullet_scene: PackedScene = preload("res://bullet.tscn") # Drag your Bullet.tscn here in the Inspector

func _physics_process(_delta: float) -> void:
	# 1. Handle Movement
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	move_and_slide()

	# 2. Handle Rotation (Look at Mouse)
	look_at(get_global_mouse_position())

	# 3. Handle Shooting
	if Input.is_action_just_pressed("ui_accept"): # Default is Spacebar
		shoot()

func shoot():
	if bullet_scene:
		var bullet = bullet_scene.instantiate()
		# Add to the root scene so the bullet doesn't move with the player
		add_child(bullet)
		
		# Set bullet position and rotation to match player
		bullet.global_position = global_position
		bullet.global_rotation = global_rotation
		
		
		

# make 2 maps of sizes 1.5 * screen and 2* screen
# add collision to required tilesets
# make a pause menu in game
# instantiate the player and enemy in the game scene
# make a light with a certain angle from the player
