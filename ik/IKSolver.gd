extends Node
class_name IKSolver


# These are the names of the bones to move in the IK chain
export(String) var root_bone
export(String) var tip_bone
export(NodePath) var target_path
export(Array, NodePath) var bone_constraint_paths


onready var target_node = get_node(target_path) # contains a Vector3 position which is the end-effector
onready var skeleton: Skeleton = get_parent()


var root_transform = Transform.IDENTITY
var bone_chain = []
var bone_transforms = []
var length_chain = []
var constraint_chain = []
var break_enabled = false


# Called when the node enters the scene tree for the first time.
func _ready():
	var root_id = skeleton.find_bone(root_bone)
	var tip_id = skeleton.find_bone(tip_bone)
	root_transform = get_global_bone_transform(root_id)

	# Create our bone chain to perform IK on
	bone_chain.append(tip_id)
	var current_bone = skeleton.get_bone_parent(tip_id)
	while current_bone != root_id:
		bone_chain.append(current_bone)
		current_bone = skeleton.get_bone_parent(current_bone)
	bone_chain.append(root_id)
	
	
	for i in bone_chain.size():
		bone_transforms.append(get_global_bone_transform(bone_chain[i]))

	for i in range(1, bone_chain.size()):
		#print("Calculating length ", " to ", i+1, ": ", get_global_bone_position(i), " - ", get_global_bone_position(i+1))
		var length_i = (get_global_bone_position(bone_chain[i-1]).distance_to(get_global_bone_position(bone_chain[i])))
		length_chain.append(length_i)

		bone_transforms[i].looking_at(get_global_bone_position(bone_chain[i-1]) + skeleton.global_transform.origin, Vector3(0, 1, 0))
	
	print("Bone chain: ", bone_chain)
	print("Length chain: ", length_chain)


# FABRIK 3d IK solver
func solve():
	# Check if we even need to solve
	if get_global_bone_position(bone_chain[0]).distance_to(target_node.global_transform.origin) < 0.1:
		return

	# Iterate forward
	var dir = bone_transforms[1].basis.z.normalized()
	bone_transforms[0].origin = target_node.global_transform.origin + (dir * length_chain[0])

	for i in range(bone_chain.size() - 1):
		var current_origin = bone_transforms[i].origin
		var next_origin = bone_transforms[i+1].origin

		var r = (next_origin - current_origin)
		var length = length_chain[i] / r.length()

		bone_transforms[i+1].origin = current_origin.linear_interpolate(next_origin, length)

	# Iterate Backwards
	bone_transforms[-1].origin = root_transform.origin
	var cone_vec = (bone_transforms[-2].origin - bone_transforms[-1].origin).normalized()

	for i in range(bone_chain.size() - 1, 0, -1):
		var root_origin = bone_transforms[i].origin
		var current_origin = bone_transforms[i-1].origin

		var r = current_origin - root_origin
		var length = length_chain[i-1] / r.length()
		var pos = root_origin.linear_interpolate(current_origin, length)

		if bone_constraint_paths[i-1] != "":
			var my_constraint = get_node(bone_constraint_paths[i-1])

			if my_constraint.get("constrained"):
				# Setup transform
				var transform = Transform(Basis.IDENTITY, root_origin)
				transform = transform.looking_at(root_origin + cone_vec, Vector3.UP)

				var constrained = constrain_point(pos - root_origin, cone_vec, transform, my_constraint)
				pos = root_origin + constrained
		
		bone_transforms[i-1].origin = pos
		cone_vec = (bone_transforms[i-1].origin - bone_transforms[i].origin)

	# Bone Alignment
	for i in range(bone_chain.size()-1, 0, -1):
		align_bone(i, i-1)
	
	# TODO: Fix this end effector alignemtn it is weird
	# var bone_transform = skeleton.get_bone_global_pose(bone_chain[0]) # model space

	# # global space
	# var bone_target = bone_transforms[0]
	# var bone_target_two = bone_transforms[1]

	# # model space
	# bone_target.origin = skeleton.global_transform.xform_inv(bone_target.origin)
	# bone_target_two.origin = skeleton.global_transform.xform_inv(bone_target_two.origin)

	# dir = (target_node.global_transform.origin - bone_target_two.origin).normalized()
	# bone_transform = bone_transform.looking_at(bone_target.origin + dir, Vector3(0, 1, 0))

	# bone_transform.origin = bone_target.origin
	# set_global_bone_transform(bone_chain[0], bone_transform)


func align_bone(bone, target):
	var bone_transform = skeleton.get_bone_global_pose(bone_chain[bone]) # model space
	var x_axis = bone_transform.basis.x

	# global space
	var bone_target = bone_transforms[bone]
	var bone_target_two = bone_transforms[target]

	# model space
	bone_target.origin = skeleton.global_transform.xform_inv(bone_target.origin)
	bone_target_two.origin = skeleton.global_transform.xform_inv(bone_target_two.origin)

	var dir = (bone_target_two.origin - bone_target.origin).normalized()
	bone_transform = bone_transform.looking_at(bone_target.origin + dir, Vector3(0, 1, 0))

	# if bone == 2:
	# 	bone_transform = bone_transform.rotated(bone_transform.basis.z, deg2rad(90))

	bone_transform.origin = bone_target.origin

	if bone_constraint_paths[bone] != "":
		var my_constraint = get_node(bone_constraint_paths[bone])
		if my_constraint.get("fix_x"):
			bone_transform.basis.x = x_axis

	set_global_bone_transform(bone_chain[bone], bone_transform)


func reset_bone_transforms():
	for i in bone_chain.size():
		bone_transforms[i] = get_global_bone_transform(bone_chain[i])


func constrain_point(calc, line, transform, constraint):
	var scalar = calc.dot(line) / line.length()
	var proj = scalar * line.normalized()

	# Find the proper up and right vector
	var top_dir = transform.basis.y
	var bottom_dir = -transform.basis.y
	var right_dir = -transform.basis.x
	var left_dir = transform.basis.x

	var up_vec = bottom_dir
	var right_vec = left_dir

	if (calc.distance_to(top_dir)) < calc.distance_to(bottom_dir): # pick the top
		up_vec = top_dir
	if calc.distance_to(right_dir) < calc.distance_to(left_dir): # pick the right
		right_vec = right_dir

	# get the vector from the projection to the calculated vector
	var adjust = calc - proj
	if scalar < 0:
		proj = -proj

	var x_aspect = adjust.dot(right_vec)
	var y_aspect = adjust.dot(up_vec)

	var left = -(proj.length() * tan(deg2rad(constraint.get("left"))))
	var right = proj.length() * tan(deg2rad(constraint.get("right")))
	var up = proj.length() * tan(deg2rad(constraint.get("up")))
	var down = -(proj.length() * tan(deg2rad(constraint.get("down"))))

	var x_bound = left
	if x_aspect >= 0:
		x_bound = right

	var y_bound = down
	if y_aspect >= 0:
		y_bound = up

	var f = calc;
	var ellipse = (pow(x_aspect, 2) / pow(x_bound, 2)) + (pow(y_aspect, 2) / pow(y_bound, 2))

	# we have to constrain this bone
	if not ellipse <= 1 and scalar >= 0:
		var a = atan2(y_aspect, x_aspect)
		var x = x_bound * cos(a)
		var y = y_bound * sin(a)

		# print("Constraining point")
		if break_enabled:
			breakpoint
		f = (proj + right_vec * x + up_vec * y).normalized() * calc.length()
	
	return f


var init = false
var forward_node = null

func _process(_delta):
	if not init:
		#make_debug_nodes(debug_nodes, Color(1, 0, 0))
		#forward_node = get_debug_node("debug", get_global_bone_transform(bone_chain[-1]), Color(0, 1, 0), 0.15)
		# make_debug_nodes(debug_nodes_green, Color(0, 1, 0))
		init = true
	
	var root_id = skeleton.find_bone(root_bone)
	root_transform = get_global_bone_transform(root_id)

	for i in 5:
		solve()
	reset_bone_transforms()
	# print_lengths()
	# for d in debug_nodes.size():
	# 	debug_nodes_green[d].global_transform = bone_transforms[d]


func get_global_bone_transform(bone_id):
	var transform = skeleton.get_bone_global_pose(bone_id)
	transform.origin = skeleton.global_transform.xform(transform.origin) # convert from bone space to world space
	return transform


func get_global_bone_position(bone_id):
	return get_global_bone_transform(bone_id).origin


func get_local_bone_position(bone_id):
	return (skeleton.get_bone_rest(bone_id) * skeleton.get_bone_pose(bone_id)).origin


func set_global_bone_transform(bone_id, transform):
	skeleton.set_bone_global_pose_override(bone_id, transform, 1.0, true)


func get_target_position():
	return skeleton.global_transform.xform_inv(target_node.global_transform.origin)


func get_limited_angle_vector(limit, baseline, angle):
	var angleBetween = baseline.angle_to(limit)
	if angle < angleBetween:
		var axis = baseline.normalized().cross(limit.normalized()).normalized()
		return baseline.rotated(axis, angle).normalized()
	else:
		return limit.normalized()


###############################################
# DEBUG METHODS
###############################################

func print_lengths():
	var temp = []
	for i in range(bone_chain.size()-1):
		var length_i = (get_global_bone_position(bone_chain[i]) - get_global_bone_position(bone_chain[i+1])).length()
		temp.append(length_i)
	
	print(temp)


var debug_nodes = []
var debug_nodes_green = []
func make_debug_nodes(list, color):
	for i in bone_chain.size():
		var my_node = get_debug_node(String(i), get_global_bone_transform(bone_chain[i]), color)
		list.append(my_node)


func get_debug_node(name, transform, color, radius=0.1):
	var new_node = Spatial.new()
	new_node.name = name
	new_node.global_transform = transform
	
	# Add sphere mesh
	var sphere = SphereMesh.new()
	sphere.radial_segments = 4
	sphere.rings = 4
	sphere.radius = radius
	sphere.height = radius * 2

	var material = SpatialMaterial.new()
	material.albedo_color = color
	material.flags_unshaded = true
	sphere.surface_set_material(0, material)

	var node = MeshInstance.new()
	node.mesh = sphere
	new_node.add_child(node)
	add_child(new_node)
	return new_node


func _input(event):
	if event is InputEventKey and event.scancode == KEY_B:
		break_enabled = true
