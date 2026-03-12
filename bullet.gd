extends CharacterBody2D

@export var speed = 600
var direction = Vector2.ZERO
var from_player: bool = false
var damage: int = 1

func _physics_process(delta):

	var collision = move_and_collide(direction * speed * delta)

	if collision:
		var collider = collision.get_collider()
		if from_player and collider and collider.has_method("take_damage"):
			collider.take_damage(damage)
		elif not from_player and collider and collider.has_method("receive_bullet_damage"):
			collider.receive_bullet_damage(damage)
		queue_free()
