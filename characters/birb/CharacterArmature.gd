extends Spatial


onready var skel = $Skeleton
# left shoulder: 8
# upper arm: 9
# lower arm: 10
# fingers: 11 - 21
# right shoulder: 22
# upper arm: 23
# lower arm: 24
# fingers: 25 - 35


var upperarm_angle = Vector3()
var lowerarm_angle = Vector3()
var upperarmL = "UpperArm.L"
var lowerarmL = "LowerArm.L"


# Called when the node enters the scene tree for the first time.
func _ready():
	var count = skel.get_bone_count()
	print("Bone count: ", count)


func set_bone_rot(bone, ang):
	var b = skel.find_bone(bone)
	#var rest = skel.get_bone_rest(b)
	var rest = Transform.IDENTITY
	# Setup transformation matrix
	var new_pos = rest.rotated(Vector3(1.0, 0.0, 0.0), ang.x)
	new_pos = new_pos.rotated(Vector3(0.0, 1.0, 0.0), ang.y)
	new_pos = new_pos.rotated(Vector3(0.0, 0.0, 1.0), ang.z)
	skel.set_bone_pose(b, new_pos)


var coordinate = 0
var bone = upperarmL

func _process(_delta):
	if Input.is_action_pressed("select_x"):
		coordinate = 0
	elif Input.is_action_pressed("select_y"):
		coordinate = 1
	elif Input.is_action_pressed("select_z"):
		coordinate = 2
	elif Input.is_action_pressed("select_upperarm"):
		bone = upperarmL
	elif Input.is_action_pressed("select_lowerarm"):
		bone = lowerarmL
	elif Input.is_action_pressed("increment"):
		if bone == lowerarmL:
			lowerarm_angle[coordinate] += 0.1
		elif bone == upperarmL:
			upperarm_angle[coordinate] += 0.1
	elif Input.is_action_pressed("decrement"):
		if bone == lowerarmL:
			lowerarm_angle[coordinate] -= 0.1
		elif bone == upperarmL:
			upperarm_angle[coordinate] -= 0.1
	set_bone_rot(lowerarmL, lowerarm_angle)
	set_bone_rot(upperarmL, upperarm_angle)
