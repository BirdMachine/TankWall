extends RefCounted
## Optional, pinned Bone Cloth backend. Never rewrites authored binds or scales.
var skeleton: Skeleton3D
var simulators: Array[SkeletonModifier3D] = []
var capsules: Array[Node3D] = []
var neck := -1
var tail := -1
var enabled := false
var profile := -1.0
static func available() -> bool:
	return ClassDB.class_exists("BoneClothSimulator3D") and ClassDB.class_exists("BoneClothCollisionCapsule3D")
func configure(target: Skeleton3D, rays: Array) -> void:
	skeleton=target
	if not available() or rays.size()!=6:
		return
	neck=skeleton.find_bone("Neck")
	tail=skeleton.find_bone("end")
	# Each membrane links its own two rays, never unrelated upper/lower fins.
	for pair in [[0,1],[2,3],[4,5]]:
		var simulator=ClassDB.instantiate("BoneClothSimulator3D") as SkeletonModifier3D
		simulator.active=false
		skeleton.add_child(simulator)
		simulator.set("chain_count",2)
		for i in 2:
			var ray: Array=rays[pair[i]]
			simulator.call("set_root_bone_name",i,str(skeleton.get_bone_name(ray[0])))
			simulator.call("set_end_bone_name",i,str(skeleton.get_bone_name(ray[-1])))
		simulator.set("ticks_per_second",120)
		simulator.set("gravity/value",0.0)
		simulator.set("drag/value",0.2)
		simulator.set("stiffness/velocity_damping",0.45)
		simulator.set("joint_speed_limit",3.5)
		simulator.set("link_mode",1)
		simulator.set("link_stiffness",0.3)
		simulator.set("link_bending",0.3)
		var capsule=ClassDB.instantiate("BoneClothCollisionCapsule3D") as Node3D
		capsule.set("radius",0.62)
		simulator.add_child(capsule)
		simulators.append(simulator)
		capsules.append(capsule)
func update(active: bool, freedom: float, delta: float) -> void:
	if simulators.is_empty():
		return
	var switched := active!=enabled
	enabled=active
	if not is_equal_approx(profile,freedom):
		profile=freedom
		var u:=clampf((freedom-0.5)/1.7,0,1)
		for simulator in simulators:
			simulator.set("stiffness/value",lerpf(0.22,0.055,u))
			simulator.set("limit_angle/value",lerpf(0.6,1.7,u))
	for simulator in simulators:
		simulator.active=active
		if active and (switched or delta>0.15):
			simulator.call("reset")
	if not active or neck<0 or tail<0:
		return
	var a:=skeleton.get_bone_global_pose(neck).origin
	var b:=skeleton.get_bone_global_pose(tail).origin
	var axis:Vector3=(b-a).normalized()
	var basis:=Basis(Quaternion(Vector3.UP,axis)) if axis.length_squared()>0.5 else Basis.IDENTITY
	for capsule in capsules:
		capsule.transform=Transform3D(basis,(a+b)*0.5)
		capsule.set("height",a.distance_to(b)+1.24)
