extends Spatial


onready var anim = $AnimationPlayer


# Called when the node enters the scene tree for the first time.
func _ready():
	pass
	

func _on_Timer_timeout():
	anim.play("walk")
