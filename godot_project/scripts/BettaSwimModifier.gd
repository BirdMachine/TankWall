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
var pivot_load := 0.0
var cadence_scale := 1.0
var rests: Array[Transform3D] = []
var lateral_axes: Array[Vector3] = []
var pitch_axes: Array[Vector3] = []
var cup_axes: Array[Vector3] = []
var rest_origins: Array[Vector3] = []
var ray_angles := PackedFloat32Array()
var spine: Array[int] = []
var fin_kind: Array[String] = []
var fin_depth: Array[int] = []
var angles := PackedFloat32Array()
var angular_velocities := PackedFloat32Array()
var cups := PackedFloat32Array()
var cup_velocities := PackedFloat32Array()
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
		rest_origins.append(global_rest.origin)
		var ray := global_rest.basis.y.normalized()
		ray_angles.append(atan2(ray.z, ray.y))
		lateral_axes.append((global_rest.basis.inverse() * Vector3(0, 0, 1)).normalized())
		pitch_axes.append((global_rest.basis.inverse() * Vector3(1, 0, 0)).normalized())
		cup_axes.append((global_rest.basis.inverse() * Vector3(0, 1, 0)).normalized())
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
	cups.resize(rests.size())
	cup_velocities.resize(rests.size())
	previous_spine.resize(spine.size())
	return true

func set_motion(speed_ratio: float, yaw_rate: float, pitch_rate: float, rate: float, pivot_bend := 0.0) -> void:
	effort = clampf(speed_ratio, 0.0, 1.8)
	turn_load = clampf(yaw_rate, -2.6, 2.6)
	pitch_load = clampf(pitch_rate, -1.0, 1.0)
	cadence_scale = rate
	pivot_load = clampf(pivot_bend, -1.9, 1.9)

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
	phase = fmod(phase + dt * TAU * (0.32 + 1.05 * effort) * cadence_scale, TAU)
	var drive := (0.055 + 0.52 * clampf(effort, 0.0, 1.4)) * (1.0 - 0.70 * clampf(absf(pivot_load), 0.0, 1.0))
	var absolute_yaw := PackedFloat32Array()
	for j in spine.size():
		var s := float(j) / float(spine.size() - 1)
		# A caudally travelling wave with a quiet head and progressively larger
		# posterior flexion. Steering adds sustained C curvature, not root yaw.
		var yaw := drive * (0.045 + pow(s, 1.55)) * sin(phase - s * 3.8)
		# A preparatory C bend exists before root yaw starts. It unwinds
		# through the pivot instead of being a side effect of angular speed.
		yaw -= turn_load * 0.16 * pow(s, 1.4) + pivot_load * pow(s, 1.10)
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
		# Fin margins have their own slower advection, rather than all following
		# one body sinusoid. Real footage shows a fan folding and reopening even
		# while the head barely moves. Distal rays lag the root by more phase.
		var point := rest_origins[i]
		var fin_phase := elapsed * (3.7 + effort * 1.6) * cadence_scale - depth * 0.95 - point.y * 0.7
		var target := 0.0
		var cup_target := 0.0
		var fold_angle := 0.0
		if kind == "gill":
			target = 0.018 * sin(elapsed * 4.5)
		elif kind == "pectoral":
			# These fins paddle while hovering and fold back somewhat at speed.
			var side := 1.0 if point.x >= 0.0 else -1.0
			target = side * (0.16 + 0.24 * sin(elapsed * 15.0 - depth * 0.85 + side * 0.7))
			target *= lerpf(1.0, 0.45, clampf(effort, 0.0, 1.0))
			target -= turn_load * 0.09
		else:
			var flutter := 0.14 if kind == "pelvic" else 0.20
			if kind == "caudal":
				flutter = 0.28
			# Fin rays have delayed response to the body stroke and steering;
			# unequal phase along the rays prevents a single rigid paddle.
			target = flutter * sin(fin_phase) * (0.75 + depth * 0.12)
			target -= spine_velocity * (0.02 + depth * 0.012)
			target += turn_load * (0.08 + depth * 0.07)
			cup_target = (0.10 + depth * 0.055) * sin(fin_phase * 0.83 + point.z * 0.7)
			cup_target -= turn_load * 0.07 * (1.0 + depth * 0.3)
			var fold := clampf(0.12 + effort * 0.20 + absf(turn_load) * 0.23 + 0.10 * sin(elapsed * 1.7 - point.y), 0.0, 0.65)
			var fold_weight := 0.48 if depth == 0 else 0.24
			if kind == "caudal":
				fold_weight = 0.0 if depth == 0 else 0.5 if depth == 1 else 0.1
			fold_angle = -ray_angles[i] * fold * fold_weight
		# Previous stiffness placed most fin motion above the response band,
		# suppressing it to tiny angles. Preserve a compliant visible response.
		var stiffness := 180.0 / (1.0 + depth * 0.6)
		var damping := 2.0 * sqrt(stiffness) * 0.68
		var steps := maxi(1, ceili(dt / (1.0 / 120.0)))
		var h := dt / steps
		for step in steps:
			angular_velocities[i] += (stiffness * (target - angles[i]) - damping * angular_velocities[i]) * h
			angles[i] = clampf(angles[i] + angular_velocities[i] * h, -0.95, 0.95)
			cup_velocities[i] += (stiffness * (cup_target - cups[i]) - damping * cup_velocities[i]) * h
			cups[i] = clampf(cups[i] + cup_velocities[i] * h, -0.8, 0.8)
		var rotation_delta := Quaternion(lateral_axes[i], angles[i])
		# Cupping and in-plane deployment are separate from lateral drag.
		if kind in ["caudal", "dorsal", "anal", "pelvic"]:
			rotation_delta *= Quaternion(cup_axes[i], cups[i])
			rotation_delta *= Quaternion(pitch_axes[i], fold_angle)
		skeleton.set_bone_pose_rotation(i, rests[i].basis.get_rotation_quaternion() * rotation_delta)
