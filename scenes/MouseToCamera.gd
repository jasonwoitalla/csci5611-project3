extends Node

export(float) var speed = 12.0
export(NodePath) var target

onready var camera = get_parent()


func _ready():
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	# Convert mouse to world coordinates and set the targets position
	var mouse_to_world = camera.project_local_ray_normal(get_viewport().get_mouse_position()) * speed
	mouse_to_world.z = 1
	# get_node(target).transform.origin.y = mouse_to_world.y + 13
