extends Position3D


export(float) var speed = -0.25

onready var anim = $AnimationPlayer
var forward = true


func _ready():
	# anim.play("wave")
	pass


func _on_Timer_timeout():
	global_transform.origin.y += speed

	if global_transform.origin.y <= 0:
		global_transform.origin.y = 0


func _on_AnimationPlayer_animation_finished(_anim_name:String):
	forward = !forward
	if forward:
		anim.play("wave")
	else:
		anim.play_backwards("wave")
