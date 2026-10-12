extends "res://scripts/field_surface.gd"
## Original imported joint poses drive both the rendered field and sphere contacts.
## The animation clock belongs to gameplay: pausing stops geometry and contacts.
var clock: float = 0.0
var enabled: bool = true
var _players: Array[Dictionary] = []
var _meshes: Array[Dictionary] = []
var _refresh_time: float = 0.0
var refresh_count: int = 0
var material_motion: RefCounted
var _previous_pose: Dictionary = {}
var _vertex_velocities: Array[PackedVector3Array] = []
var _pose_time: float = 0.0
var collision_bounds: Vector2 = Vector2(24,24)
var collision_ceiling: float = 20.0
var motion_scale: float = 1.0

func reset_clock() -> void:
	clock = 0.0
	_refresh_time = 0.0
	_pose_time = 0.0
	_previous_pose.clear()
	advance(0.0,true)

func bind_stage(stage: Node3D, id: String) -> void:
	group_id = id
	var catalog = load("res://scripts/ds_arena_catalog.gd")
	motion_scale = maxf(1.0,float(stage.get_meta("pc_fit",{}).get("target_short_floor_span",18.0))/18.0)
	collision_bounds = (catalog.play_bounds(id)+Vector2(2,2)).max(Vector2.ONE*24.0*motion_scale)
	collision_ceiling = maxf(catalog.collision_height(id),20.0*motion_scale)
	for player: AnimationPlayer in stage.find_children("*", "AnimationPlayer", true, false):
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for name: String in player.get_animation_list():
			if name != "RESET" and player.get_animation(name).length > 0.0:
				player.play(name)
				_players.append({"player": player, "name": name, "length": player.get_animation(name).length})
				break
	for mesh: MeshInstance3D in stage.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh==null:
			continue
		var skeleton: Skeleton3D = mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
		var skin: Skin = mesh.skin
		for surface: int in mesh.mesh.get_surface_count():
			var data: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for index: int in vertices.size():
					indices.append(index)
			var bones: PackedInt32Array = data[Mesh.ARRAY_BONES] if data[Mesh.ARRAY_BONES]!=null else PackedInt32Array()
			var weights: PackedFloat32Array = data[Mesh.ARRAY_WEIGHTS] if data[Mesh.ARRAY_WEIGHTS]!=null else PackedFloat32Array()
			_meshes.append({"mesh": mesh, "surface": surface, "skeleton": skeleton, "skin": skin, "vertices": vertices, "indices": indices, "bones": bones, "weights": weights})
	material_motion = load("res://scripts/ds_material_motion.gd").new()
	material_motion.bind_stage(stage, id)
	advance(0.0, true)

func advance(delta: float, force: bool = false) -> void:
	if not enabled and not force:
		return
	if is_finite(delta) and delta > 0.0:
		clock += delta
	material_motion.advance(clock)
	_refresh_time += maxf(0.0, delta)
	if not force and _refresh_time < 1.0/60.0:
		return
	_refresh_time = 0.0
	for item: Dictionary in _players:
		item.player.seek(fposmod(clock, float(item.length)), true, true)
	_rebuild_pose()

func _rebuild_pose() -> void:
	var packed: Array = []
	var current_pose: Dictionary = {}
	_vertex_velocities.clear()
	var pose_delta: float = clock-_pose_time
	for mesh_index: int in _meshes.size():
		var item: Dictionary = _meshes[mesh_index]
		var skeleton: Skeleton3D = item.skeleton
		var skin: Skin = item.skin
		var transforms: Array[Transform3D] = []
		if skeleton != null and skin != null:
			skeleton.force_update_all_bone_transforms()
			for bind: int in skin.get_bind_count():
				var bone: int = skin.get_bind_bone(bind)
				if bone < 0:
					bone = skeleton.find_bone(skin.get_bind_name(bind))
				transforms.append(skeleton.global_transform * skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(bind))
		var vertices: PackedVector3Array = item.vertices
		var weights: PackedFloat32Array = item.weights
		var bones: PackedInt32Array = item.bones
		var points := PackedVector3Array()
		var width: int = weights.size() / vertices.size() if not vertices.is_empty() else 0
		for index: int in vertices.size():
			var point := Vector3.ZERO
			var total: float = 0.0
			if width > 0 and not transforms.is_empty():
				for influence: int in width:
					var offset: int = index * width + influence
					var weight: float = weights[offset]
					if weight > 0.0:
						point += (transforms[bones[offset]] * vertices[index]) * weight
						total += weight
			points.append(point if total > 0.0 else item.mesh.global_transform * vertices[index])
		var indices: PackedInt32Array = item.indices
		for index: int in range(0, indices.size() - 2, 3):
			var a: Vector3 = points[indices[index]]
			var b: Vector3 = points[indices[index+1]]
			var c: Vector3 = points[indices[index+2]]
			var low: Vector3 = a.min(b).min(c)
			var high: Vector3 = a.max(b).max(c)
			if high.x < -collision_bounds.x or low.x > collision_bounds.x or high.z < -collision_bounds.y or low.z > collision_bounds.y or high.y < -12 or low.y > collision_ceiling:
				continue
			if (b-a).cross(c-a).length_squared()<0.00000001:
				continue
			var id: Vector2i = Vector2i(mesh_index,index)
			var triangle := PackedVector3Array([a,b,c])
			current_pose[id] = triangle
			var velocities := PackedVector3Array([Vector3.ZERO,Vector3.ZERO,Vector3.ZERO])
			if pose_delta>0.000001 and _previous_pose.has(id):
				var old: PackedVector3Array = _previous_pose[id]
				for vertex: int in 3:
					# Clip discontinuities must not impart an unlimited impulse.
					velocities[vertex] = ((triangle[vertex]-old[vertex])/pose_delta).limit_length(20.0*motion_scale)
			_vertex_velocities.append(velocities)
			packed.append([a.x,a.y,a.z,b.x,b.y,b.z,c.x,c.y,c.z])
	load_profile(group_id, {"center_bounds": [collision_bounds.x,collision_bounds.y], "triangles": packed})
	_previous_pose = current_pose
	_pose_time = clock
	refresh_count += 1

func support(point: Vector3, max_height: float) -> Dictionary:
	var height: float = -INF
	var normal: Vector3 = Vector3.UP
	var velocity: Vector3 = Vector3.ZERO
	for index: int in _cells.get(_cell_key(point), []):
		var p: PackedVector3Array = triangles[index]
		var n: Vector3 = (p[1]-p[0]).cross(p[2]-p[0]).normalized()
		if absf(n.y) < 0.4:
			continue
		var y: float = _height_at(point,p[0],p[1],p[2])
		if is_finite(y) and y <= max_height and y > height:
			height = y
			normal = n if n.y > 0 else -n
			velocity = _point_velocity(index,Vector3(point.x,y,point.z))
	return {"height": height, "normal": normal, "velocity": velocity}

func resolve_flight_segment(from: Vector3,to: Vector3) -> Dictionary:
	var contact: Dictionary = super.resolve_flight_segment(from,to)
	contact["velocity"] = _point_velocity(int(contact.get("triangle_index",-1)),contact.position) if bool(contact.collided) else Vector3.ZERO
	return contact

func _point_velocity(index: int,point: Vector3) -> Vector3:
	if index<0 or index>=_vertex_velocities.size():
		return Vector3.ZERO
	var p: PackedVector3Array = triangles[index]
	var closest: Vector3 = _closest_triangle(point,p[0],p[1],p[2])
	var ab: Vector3 = p[1]-p[0]
	var ac: Vector3 = p[2]-p[0]
	var ap: Vector3 = closest-p[0]
	var denominator: float = ab.dot(ab)*ac.dot(ac)-ab.dot(ac)*ab.dot(ac)
	if absf(denominator)<0.00000001:
		return Vector3.ZERO
	var b: float = (ac.dot(ac)*ap.dot(ab)-ab.dot(ac)*ap.dot(ac))/denominator
	var c: float = (ab.dot(ab)*ap.dot(ac)-ab.dot(ac)*ap.dot(ab))/denominator
	var v: PackedVector3Array = _vertex_velocities[index]
	return v[0]*(1.0-b-c)+v[1]*b+v[2]*c

func separate_ball(point: Vector3) -> Dictionary:
	var position: Vector3 = point
	var normal: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	for iteration: int in range(4):
		var adjusted: bool = false
		for index: int in _cells.get(_cell_key(position), []):
			if _box_distance_squared(position,index) >= RADIUS*RADIUS:
				continue
			var p: PackedVector3Array = triangles[index]
			var closest: Vector3 = _closest_triangle(position,p[0],p[1],p[2])
			var diff: Vector3 = position-closest
			var distance: float = diff.length()
			if distance < RADIUS-SKIN:
				var n: Vector3 = diff.normalized() if distance > 0.00001 else Vector3.UP
				position += n * (RADIUS-distance+SKIN)
				normal = n
				velocity = _point_velocity(index,closest)
				adjusted = true
		if not adjusted:
			break
	return {"position":position,"normal":normal,"collided":normal.length_squared()>0.1,"velocity":velocity}
