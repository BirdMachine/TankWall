extends SkeletonModifier3D
## BlueMesh-specific, rest-relative swim rig. No baked root motion or skin changes.
## Skeleton coordinates: -Y nose, +Z dorsal, X lateral. Local axes are derived
## from global rests: the fin bones do NOT all share the body's local axes.

const SPINE_NAMES := ["Bone_Armature", "Bone.002_Armature", "Bone.003_Armature", "Bone.004_Armature", "Bone.005_Armature"]
const FIN_ROOTS := {
	"Bone.009_Armature": "pelvic", "Bone.010_Armature": "pectoral",
	"Bone.011_Armature": "pectoral", "Bone.018_Armature": "dorsal",
	"Bone.019_Armature": "dorsal", "Bone.020_Armature": "dorsal",
	"Bone.033_Armature": "anal", "Bone.034_Armature": "anal",
	"Bone.039_Armature": "caudal", "Bone.046_Armature": "gill",
	"Bone.047_Armature": "gill",
}

var phase := 0.0
var elapsed := 0.0
var effort := 0.5
var turn_load := 0.0
var pitch_load := 0.0
var cadence_scale := 1.0
var rests: Array[Transform3D] = []
var lateral_axes: Array[Vector3] = []
var pitch_axes: Array[Vector3] = []
var spine: Array[int] = []
var fin_kind: Array[String] = []
var fin_depth: Array[int] = []
var angles := PackedFloat32Array()
var angular_velocities := PackedFloat32Array()
var previous_spine := PackedFloat32Array()
var spine_velocity := 0.0

func configure(skeleton: Skeleton3D) -> bool:
	for bone_name in SPINE_NAMES:
		var bone := skeleton.find_bone(bone_name)
		if bone < 0:
			push_error("TankWall swim rig: missing body joint " + bone_name)
			return false
		spine.append(bone)
	for i in skeleton.get_bone_count():
		rests.append(skeleton.get_bone_rest(i))
		var global_rest := skeleton.get_bone_global_rest(i)
		lateral_axes.append((global_rest.basis.inverse() * Vector3(0, 0, 1)).normalized())
		pitch_axes.append((global_rest.basis.inverse() * Vector3(1, 0, 0)).normalized())
		var bone_name := skeleton.get_bone_name(i)
		var parent := skeleton.get_bone_parent(i)
		if FIN_ROOTS.has(bone_name):
			fin_kind.append(FIN_ROOTS[bone_name])
			fin_depth.append(0)
		elif parent >= 0:
			fin_kind.append(fin_kind[parent])
			fin_depth.append(fin_depth[parent] + 1)
		else:
			fin_kind.append("")
			fin_depth.append(0)
	angles.resize(rests.size())
	angular_velocities.resize(rests.size())
	previous_spine.resize(spine.size())
	return true

func set_motion(speed_ratio: float, yaw_rate: float, pitch_rate: float, rate: float) -> void:
	effort = clampf(speed_ratio, 0.0, 1.8)
	turn_load = clampf(yaw_rate, -2.6, 2.6)
	pitch_load = clampf(pitch_rate, -1.0, 1.0)
	cadence_scale = rate

func _process_modification() -> void:
	# _process_modification is supported by Godot 4.3–4.5 as well as newer builds.
	advance_swim(get_process_delta_time())

func advance_swim(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or rests.is_empty():
		return
	# Bound substeps for spring stability after pauses and at low frame rates.
	var dt := clampf(delta, 0.0, 0.1)
	elapsed += dt
	phase = fmod(phase + dt * TAU * (0.55 + 1.35 * effort) * cadence_scale, TAU)
	var drive := 0.075 + 0.40 * clampf(effort, 0.0, 1.4)
	var absolute_yaw := PackedFloat32Array()
	for j in spine.size():
		var s := float(j) / float(spine.size() - 1)
		# A caudally travelling wave with a quiet head and progressively larger
		# posterior flexion. Steering adds sustained C curvature, not root yaw.
		var yaw := drive * (0.045 + pow(s, 1.55)) * sin(phase - s * 3.8)
		yaw -= turn_load * 0.48 * pow(s, 1.25)
		absolute_yaw.append(yaw)
		var parent_yaw := 0.0 if j == 0 else absolute_yaw[j - 1]
		var bend := Quaternion(lateral_axes[spine[j]], yaw - parent_yaw)
		var pitch := Quaternion(pitch_axes[spine[j]], -pitch_load * 0.045 * s)
		skeleton.set_bone_pose_rotation(spine[j], rests[spine[j]].basis.get_rotation_quaternion() * bend * pitch)
	if dt > 0.0:
		spine_velocity = (absolute_yaw[-1] - previous_spine[-1]) / dt
	previous_spine = absolute_yaw
	for i in rests.size():
		if fin_kind[i].is_empty():
			continue
		var depth := float(fin_depth[i])
		var kind := fin_kind[i]
		var fin_phase := phase - 0.65 * depth
		var target := 0.0
		if kind == "gill":
			target = 0.018 * sin(elapsed * 4.5)
		elif kind == "pectoral":
			# These fins paddle while hovering and fold back somewhat at speed.
			var side := 1.0 if skeleton.get_bone_global_rest(i).origin.x >= 0.0 else -1.0
			target = side * (0.16 + 0.24 * sin(elapsed * 15.0 - depth * 0.85 + side * 0.7))
			target *= lerpf(1.0, 0.45, clampf(effort, 0.0, 1.0))
			target -= turn_load * 0.09
		else:
			var flutter := 0.07 if kind == "pelvic" else 0.10
			if kind == "caudal":
				flutter = 0.17
			# Fin rays have delayed response to the body stroke and steering;
			# unequal phase along the rays prevents a single rigid paddle.
			var root_y := skeleton.get_bone_global_rest(i).origin.y
			target = flutter * sin(fin_phase - root_y * 0.65) * (0.35 + effort)
			target -= spine_velocity * (0.012 + depth * 0.009)
			target += turn_load * (0.025 + depth * 0.035)
		var stiffness := 65.0 / (1.0 + depth * 0.55)
		var damping := 2.0 * sqrt(stiffness) * 0.82
		var steps := maxi(1, ceili(dt / (1.0 / 120.0)))
		var h := dt / steps
		for step in steps:
			angular_velocities[i] += (stiffness * (target - angles[i]) - damping * angular_velocities[i]) * h
			angles[i] = clampf(angles[i] + angular_velocities[i] * h, -0.65, 0.65)
		var rotation_delta := Quaternion(lateral_axes[i], angles[i])
		# Gentle out-of-plane cupping, strongest at soft distal fin rays.
		if kind in ["caudal", "dorsal", "anal", "pelvic"]:
			rotation_delta *= Quaternion(pitch_axes[i], 0.045 * sin(fin_phase - 0.8) * minf(depth, 2.0))
		skeleton.set_bone_pose_rotation(i, rests[i].basis.get_rotation_quaternion() * rotation_delta)
