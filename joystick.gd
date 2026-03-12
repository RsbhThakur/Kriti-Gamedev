extends Control

@export var max_distance = 80

var touch_id = -1
var output = Vector2.ZERO

@onready var knob = $Knob
@onready var base = $Base

var center

func _ready():
	center = knob.position


func _input(event):

	# Finger touches screen
	if event is InputEventScreenTouch:
		if event.pressed:
			if base.get_rect().has_point(base.to_local(event.position)):
				touch_id = event.index

		else:
			if event.index == touch_id:
				touch_id = -1
				knob.position = center
				output = Vector2.ZERO


	# Finger dragging
	if event is InputEventScreenDrag and event.index == touch_id:

		var pos = base.to_local(event.position)

		var dist = pos.length()

		if dist > max_distance:
			pos = pos.normalized() * max_distance

		knob.position = center + pos

		output = pos / max_distance

		print("Joystick direction: ", output)
		
		
	
