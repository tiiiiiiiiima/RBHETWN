extends Node3D
## Arena environments, imported source forms/card art, and procedural fallbacks.

const ArenaCatalog = preload("res://scripts/arena_catalog.gd")
const ModelLibrary = preload("res://scripts/model_library.gd")
const BoardLayout = preload("res://scripts/board_layout.gd")
const CardArt = preload("res://scripts/card_art.gd")
const DSCardArt = preload("res://scripts/ds_card_catalog.gd")
const GateCatalog = preload("res://scripts/gate_catalog.gd")
const SourceArena = preload("res://scripts/source_arena.gd")
const SFMField = preload("res://scripts/source_sfm_field.gd")
const DSArenaCatalog = preload("res://scripts/ds_arena_catalog.gd")
const LiveSurface = preload("res://scripts/ds_live_surface.gd")
const FieldSurface = preload("res://scripts/field_surface.gd")
const FieldObjects = preload("res://scripts/ds_field_objects.gd")

const SLOT_POSITIONS: Array[Vector3] = BoardLayout.POSITIONS
const CARD_FOOTPRINT_SCALE: float = BoardLayout.WII_CARD_SCALE

const ORANGE: Color = Color("ff9a35")
const CYAN: Color = Color("41d8f5")
const INK: Color = Color("111728")
const METAL: Color = Color("293245")

var camera: Camera3D
var environment_root: Node3D
var theme_id: String = "stadium"
var reduced_motion: bool = false
var target_highlight: Node3D
var legal_highlights: Node3D
var _world: WorldEnvironment
var _key: DirectionalLight3D
var _fill: DirectionalLight3D
var _warm: OmniLight3D
var _cold: OmniLight3D
var gates: Dictionary = {}
var _materials: Dictionary = {}
var _armor_meshes: Dictionary = {}
var _visual_states: Array[Dictionary] = []
var _unfold_players: Array[WeakRef] = []
var _texture_videos: Array[WeakRef] = []
var _setup_done: bool = false
var native_physics: bool = true
var native_surface: RefCounted
var field_surface: Variant = null
var view_quadrant: int = 0
var field_layout: int = 0
var field_objects: Node3D
var _camera_focus: Vector3 = Vector3.ZERO
var _camera_following: bool = false
var camera_zoom: float = 1.0
var board_profile: String = "wii"
var _throw_heading: Vector3 = Vector3.FORWARD
var _aim_camera: bool = false
var _aim_sphere: Vector3 = Vector3.ZERO
var _follow_sphere_point: Vector3 = Vector3.ZERO

func setup() -> void:
	if _setup_done:
		return
	_setup_done = true
	_world = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("080b1a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8093bc")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = 2
	_world.environment = environment
	add_child(_world)
	_key = DirectionalLight3D.new()
	_key.rotation_degrees = Vector3(-58.0, -30.0, 0.0)
	_key.light_energy = 1.7
	_key.shadow_enabled = true
	_key.directional_shadow_max_distance = 40.0
	add_child(_key)
	_fill = DirectionalLight3D.new()
	_fill.rotation_degrees = Vector3(-35.0, 135.0, 0.0)
	_fill.light_energy = 0.65
	add_child(_fill)
	_warm = OmniLight3D.new()
	_warm.position = Vector3(-7.0, 5.0, 4.0)
	_warm.light_energy = 2.0
	_warm.omni_range = 13.0
	add_child(_warm)
	_cold = OmniLight3D.new()
	_cold.position = Vector3(6.0, 4.0, -5.0)
	_cold.light_energy = 1.6
	_cold.omni_range = 13.0
	add_child(_cold)
	camera = Camera3D.new()
	camera.position = Vector3(10.4, 14.6, 18.7)
	camera.fov = 48.0
	camera.near = 0.1
	camera.far = 100.0
	add_child(camera)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.4, 0.0))
	camera.current = true
	set_theme(theme_id)

func set_theme(id: String) -> void:
	var normalized: String = ArenaCatalog.normalize_id(id)
	if not _setup_done:
		theme_id = normalized
		setup()
		return
	if is_instance_valid(environment_root) and theme_id == normalized:
		return
	if is_instance_valid(environment_root):
		environment_root.free()
	theme_id = normalized
	view_quadrant = 0
	_camera_focus = Vector3.ZERO
	_camera_following = false
	camera_zoom = 1.0
	field_surface = null
	native_surface = null
	field_objects = null
	camera.far = 100.0
	var palette: Dictionary = ArenaCatalog.get_entry(theme_id)["palette"]
	_world.environment.background_color = palette["background"]
	_world.environment.ambient_light_color = palette["ambient"]
	SourceArena.apply_sky(_world.environment, theme_id == "anime_board")
	_key.light_color = palette["key"]
	_fill.light_color = palette["fill"]
	_warm.light_color = palette["warm"]
	_cold.light_color = palette["cold"]
	environment_root = Node3D.new()
	camera.look_at_from_position(board_camera_position(), Vector3(0.0, 0.4, 0.0))
	environment_root.name = "EnvironmentDecor"
	environment_root.set_meta("theme_id", theme_id)
	add_child(environment_root)
	match theme_id:
		"canyon": _build_canyon(palette)
		"glacier": _build_glacier(palette)
		"anime_board": _build_source_board(palette)
		"sfm_battle_field": _build_sfm_field()
		"ds_toy", "ds_anime", "ds_pyrus", "ds_aquos", "ds_subterra", "ds_haos", "ds_darkus", "ds_ventus": _build_ds_field(palette)
		_: _build_stadium()
	restore_board_view()
	for slot: Variant in gates:
		if is_instance_valid(gates[slot]):
			gates[slot].position = slot_position(int(slot))
	var placement_slots: Array[int] = []
	if is_instance_valid(legal_highlights):
		placement_slots.assign(legal_highlights.get_meta("slots", []))
	if is_instance_valid(target_highlight):
		var selected_slot: int = int(target_highlight.get_meta("slot", -1))
		highlight_target(selected_slot)
	if not placement_slots.is_empty():
		highlight_legal_slots(placement_slots)


func _build_ds_field(palette: Dictionary) -> void:
	var field: Node3D = DSArenaCatalog.make_throw_stage(theme_id, not reduced_motion)
	if field == null:
		_build_themed_field(palette, "DS ASSET UNAVAILABLE")
		environment_root.set_meta("source_available", false)
		return
	environment_root.add_child(field)
	environment_root.set_meta("source_available", true)
	environment_root.set_meta("source_origin", "user_ds_nitrofs")
	environment_root.set_meta("ds_group_id", field.get_meta("ds_group_id"))
	field_surface = FieldSurface.for_group(str(field.get_meta("ds_group_id")))
	if native_physics:
		native_surface = LiveSurface.new()
		native_surface.bind_stage(field, str(field.get_meta("ds_group_id")))
		field.set_meta("source_joint_animation_frozen", false)
		field.set_meta("animated_collision", true)
		field.set_meta("throw_field_adaptation", "Source joint poses and native SRT UV curves; desktop 3D sphere integration")
		field_objects = FieldObjects.new()
		field_objects.name = "DSFieldObjects"
		environment_root.add_child(field_objects)
		field_objects.configure(theme_id,field_layout)
	environment_root.set_meta("visual_only_collision", field_surface == null)
	environment_root.set_meta("collision_adaptation", "source posed sphere collision and desktop integration" if native_physics else "source-skinned static rest triangles; PC analytic movement")
	camera.far = maxf(100.0, float(field.get_meta("ds_far_hint", 150.0)))
	for slot: int in range(slot_count()):
		var marker: MeshInstance3D = _box(environment_root, Vector3(2.38 * CARD_FOOTPRINT_SCALE, 0.025, 2.65 * CARD_FOOTPRINT_SCALE), slot_position(slot)+Vector3(0,0.015,0), _material(palette["slot"]))
		marker.name = "FieldSlot%d" % slot
		marker.set_meta("slot", slot)
		marker.visible = false

func surface_height(point: Vector3) -> float:
	if field_surface == null:
		return 0.0
	var measured: float = field_surface.surface_height(point)
	return measured if is_finite(measured) else 0.0


func ground_point(point: Vector3, clearance: float = 0.44) -> Vector3:
	if field_surface != null:
		return field_surface.ground_point(point, clearance)
	return Vector3(point.x, clearance, point.z)


func slot_position(slot: int) -> Vector3:
	var point: Vector3 = BoardLayout.position(slot,board_profile)
	if uses_large_ds_field():
		if board_profile=="ds": point *= 1.5
	return ground_point(point, 0.0)

func slot_count() -> int:
	return BoardLayout.slot_count(board_profile)

func set_board_profile(profile: String) -> void:
	board_profile = "ds" if profile=="ds" else "wii"

func uses_large_ds_field() -> bool:
	return native_physics and theme_id in DSArenaCatalog.PLAYABLE_FIELDS

func throw_scale() -> float:
	if not uses_large_ds_field():
		return 1.0
	var fit: Dictionary = DSArenaCatalog.manifest().groups[DSArenaCatalog.stage_id_for(theme_id)+"_throw"].pc_fit
	return float(fit.get("target_short_floor_span",18.0))/18.0

func traversal_bounds() -> Vector2:
	return DSArenaCatalog.play_bounds(theme_id) if uses_large_ds_field() else Vector2(8,8)

func aim_bounds() -> Vector2:
	return traversal_bounds()-Vector2(1,1) if uses_large_ds_field() else Vector2(4.2,4.1)

func clamp_aim(point: Vector3) -> Vector3:
	var bounds: Vector2 = aim_bounds()
	return Vector3(clampf(point.x,-bounds.x,bounds.x),0,clampf(point.z,-bounds.y,bounds.y)) if point.is_finite() else Vector3.ZERO

func aim_ground_point(point: Vector3, clearance: float = 0.44) -> Vector3:
	if not uses_large_ds_field() or native_surface==null:
		return ground_point(point,clearance)
	var result: Vector3 = clamp_aim(point)
	var support: Dictionary = native_surface.support(result,0.5)
	result.y = (float(support.height) if is_finite(float(support.height)) else 0.0)+clearance
	return result


func board_camera_position() -> Vector3:
	# The native Pyrus backdrop blocks the old view from +Z. A view from -Z
	# leaves the actual 16 card positions and both launch lanes unobscured.
	var base := Vector3(10.4, 14.6, -18.7 if theme_id == "ds_pyrus" else 18.7)
	var zoom: float = camera_zoom
	if uses_large_ds_field():
		zoom *= 1.45 if _camera_following else 1.85
	# Keep every view on the playable side of the native Pyrus backdrop.
	# L/R is source-confirmed; the four exact camera positions are PC fits.
	if view_quadrant==2:
		var overview: float = maxf(1.0,traversal_bounds().length()/28.0) if uses_large_ds_field() else 1.0
		return Vector3(base.x*0.65,22.0,base.z*0.65)*zoom*overview
	var angle: float = PI/4.0 if view_quadrant==1 else -PI/4.0 if view_quadrant==3 else 0.0
	var result: Vector3 = base.rotated(Vector3.UP,angle)
	if view_quadrant==1:
		result.y = 5.8
	return result*zoom

func restore_board_view() -> void:
	_camera_following = false
	_aim_camera = false
	_camera_focus = Vector3.ZERO
	if camera!=null:
		camera.look_at_from_position(board_camera_position(),Vector3(0,0.4,0))

func aim_sphere(start: Vector3, target: Vector3, delta: float = 0.0) -> void:
	if not uses_large_ds_field() or camera==null:
		return
	_aim_camera = true
	_camera_following = false
	_aim_sphere = start
	if view_quadrant!=0:
		camera.look_at_from_position(board_camera_position(),Vector3(0,0.4,0))
		return
	var direction: Vector3 = target-start
	direction.y = 0.0
	if direction.length_squared()>0.0001:
		_throw_heading = direction.normalized()
	var desired: Vector3 = start-_throw_heading*3.5*camera_zoom+Vector3.UP*1.35*camera_zoom
	var focus: Vector3 = start+_throw_heading*7.0+Vector3.UP*0.15
	_camera_focus=focus-Vector3.UP*0.15
	_place_throw_camera(desired,focus,delta)

func _place_throw_camera(desired: Vector3, focus: Vector3, delta: float) -> void:
	# Sweep behind the sphere against source geometry instead of looking
	# through an obstacle. Keep at least the sphere's visible clearance.
	var safe: Vector3 = desired
	if native_surface!=null:
		var contact: Dictionary = resolve_flight_segment(focus.lerp(desired,0.15),desired)
		if bool(contact.get("collided",false)):
			safe = contact.position+contact.normal*0.12
	var support: Dictionary = sphere_support(safe,safe.y)
	if is_finite(float(support.height)):
		safe.y = maxf(safe.y,float(support.height)+0.65)
	var alpha: float = 1.0 if delta<=0.0 or reduced_motion else 1.0-exp(-10.0*clampf(delta,0.0,0.25))
	var next: Vector3 = camera.position.lerp(safe,alpha)
	if delta>0.0 and not reduced_motion:
		next = camera.position.move_toward(next,150.0*minf(delta,0.25))
	camera.look_at_from_position(next,focus)

func follow_sphere(point: Vector3, delta: float, velocity: Vector3 = Vector3.ZERO) -> void:
	if not uses_large_ds_field() or camera==null or not point.is_finite():
		return
	_camera_following = true
	_follow_sphere_point = point
	if view_quadrant!=0:
		_camera_focus = point
		camera.look_at_from_position(point+board_camera_position(),point)
		return
	_aim_camera = false
	var heading := Vector3(velocity.x,0,velocity.z)
	if heading.is_finite() and heading.length_squared()>0.16:
		_throw_heading = _throw_heading.lerp(heading.normalized(),1.0-exp(-4.0*delta)).normalized()
	var anticipation: Vector3 = _throw_heading*1.6
	var desired := point+anticipation
	var alpha: float = 1.0-exp(-6.0*clampf(delta,0.0,0.25))
	_camera_focus = _camera_focus.lerp(desired,alpha)
	var desired_position: Vector3 = point-_throw_heading*4.4*camera_zoom+Vector3.UP*1.85*camera_zoom
	_place_throw_camera(desired_position,_camera_focus+Vector3.UP*0.15,delta)

func zoom_view(direction: int) -> void:
	if not uses_large_ds_field() or direction==0:
		return
	camera_zoom = clampf(camera_zoom*pow(1.12,direction),0.65,2.25)
	if view_quadrant==0:
		if _camera_following:
			follow_sphere(_follow_sphere_point,0.0)
			return
		if _aim_camera:
			aim_sphere(_aim_sphere,_aim_sphere+_throw_heading*7,0.0)
			return
	camera.look_at_from_position(_camera_focus+board_camera_position(),_camera_focus+Vector3(0,0.4,0))

func rotate_view(direction: int) -> void:
	if direction==0 or camera==null:
		return
	view_quadrant = posmod(view_quadrant+signi(direction),4)
	camera.look_at_from_position(_camera_focus+board_camera_position(),_camera_focus+Vector3(0.0,0.4,0.0))

func reset_match_field() -> void:
	view_quadrant = 0
	camera_zoom = 1.0
	if native_surface!=null:
		native_surface.reset_clock()
	if is_instance_valid(field_objects):
		field_objects.reset_match()
	restore_board_view()


func control_direction(input_direction: Vector2) -> Vector2:
	if field_surface == null or camera == null:
		return input_direction
	var right: Vector3 = camera.global_transform.basis.x
	var forward: Vector3 = -camera.global_transform.basis.z
	right.y = 0.0
	forward.y = 0.0
	var world: Vector3 = right.normalized() * input_direction.x - forward.normalized() * input_direction.y
	return Vector2(world.x, world.z)


func launch_position(owner: int = 0) -> Vector3:
	if uses_large_ds_field():
		var distance: float = DSArenaCatalog.floor_bounds(theme_id).y*0.68
		return ground_point(Vector3(0,0,distance if owner==0 else -distance),0.50)
	return ground_point(Vector3(0.0, 0.0, 5.0 if owner == 0 else -5.0), 0.50)


func configure_roll(motion: Variant) -> void:
	motion.configure_surface(field_surface)


func resolve_flight_segment(from: Vector3, to: Vector3) -> Dictionary:
	if native_physics and native_surface != null:
		return native_surface.resolve_flight_segment(from,to)
	if field_surface != null:
		return field_surface.resolve_flight_segment(from, to)
	return {"position": to, "collided": false, "normal": Vector3.ZERO}


func set_native_physics(enabled: bool) -> void:
	if native_physics == enabled:
		return
	native_physics = enabled
	if is_instance_valid(environment_root) and theme_id.begins_with("ds_"):
		environment_root.free()
		environment_root = null
		set_theme(theme_id)

func advance_field(delta: float) -> void:
	if native_surface != null and native_physics:
		native_surface.advance(delta)
		if is_instance_valid(field_objects):
			field_objects.advance(native_surface.clock)

func set_field_layout(variant: int) -> void:
	var value: int = clampi(variant,0,3)
	if field_layout==value:
		return
	field_layout = value
	if native_physics and is_instance_valid(environment_root) and theme_id.begins_with("ds_"):
		environment_root.free()
		environment_root = null
		set_theme(theme_id)

func preview_field_response(from: Vector3,to: Vector3,time: float) -> Array[Dictionary]:
	var responses: Array[Dictionary]=[]
	if native_physics and is_instance_valid(field_objects): responses.assign(field_objects.response(from,to,time))
	return responses

func field_response(from: Vector3,to: Vector3) -> Array[Dictionary]:
	var responses: Array[Dictionary] = []
	if native_physics and is_instance_valid(field_objects):
		responses.assign(field_objects.response(from,to))
	return responses

func separate_sphere(point: Vector3) -> Dictionary:
	if native_surface != null and native_physics:
		return native_surface.separate_ball(point)
	return {"position":point,"collided":false,"normal":Vector3.ZERO}

func sphere_support(point: Vector3, max_height: float) -> Dictionary:
	if native_surface != null and native_physics:
		return native_surface.support(point,max_height)
	var supported: bool = absf(point.x)<=5.2 and absf(point.z)<=4.9
	return {"height":0.0 if supported else -INF,"normal":Vector3.UP}

func _build_source_board(palette: Dictionary) -> void:
	var board: Node3D = SourceArena.make_board()
	if board == null:
		_build_themed_field(palette, "BAKUGAN  /  ANIME FIELD")
		environment_root.set_meta("source_available", false)
		return
	environment_root.add_child(board)
	environment_root.set_meta("source_available", true)
	environment_root.set_meta("source_origin", "source_table_board")
	# The source slab is the only floor. Slot nodes retain the shared layout,
	# while the source artwork stays visible beneath cards and placement hints.
	for slot: int in range(SLOT_POSITIONS.size()):
		var marker: MeshInstance3D = _box(environment_root, Vector3(2.38 * CARD_FOOTPRINT_SCALE, 0.025, 2.65 * CARD_FOOTPRINT_SCALE), BoardLayout.position(slot,"wii") + Vector3(0.0, 0.015, 0.0), _material(palette["slot"]))
		marker.name = "FieldSlot%d" % slot
		marker.set_meta("slot", slot)
		marker.visible = false
	_rect_outline(environment_root, Vector3(0.0, -0.04, 0.0), Vector2(12.86, 10.96), 0.035, _material(palette["edge"], 0.0, 0.7))

func _build_sfm_field() -> void:
	var field: Node3D = SFMField.make_stage()
	if field == null:
		environment_root.set_meta("source_available", false)
		return
	environment_root.add_child(field)
	environment_root.set_meta("source_available", true)
	environment_root.set_meta("source_origin", "source_sfm_workshop")
	camera.far = 120.0

func _build_stadium() -> void:
	# Layered platform: the illuminated edge is visible even on low-end renderers.
	_beveled_slab(environment_root, Vector2(16.4, 13.2), 0.55, Vector3(0.0, -0.62, 0.0), _material(Color("080f20"), 0.45), 0.9)
	_box(environment_root, Vector3(15.6, 0.10, 12.4), Vector3(0.0, -0.31, 0.0), _material(Color("344b74"), 0.5))
	_box(environment_root, Vector3(15.4, 0.23, 12.2), Vector3(0.0, -0.20, 0.0), _material(INK, 0.35))
	_box(environment_root, Vector3(12.7, 0.06, 9.65), Vector3(0.0, -0.065, 0.0), _material(Color("222a3c"), 0.28))
	_box(environment_root, Vector3(11.9, 0.04, 8.8), Vector3(0.0, -0.025, 0.0), _material(Color("202a3e"), 0.25))
	_rect_outline(environment_root, Vector3.ZERO, Vector2(12.35, 9.18), 0.045, _material(Color("576790"), 0.3, 0.5))
	_rect_outline(environment_root, Vector3(0.0, -0.04, 0.0), Vector2(15.72, 12.5), 0.04, _material(Color("765df1"), 0.0, 1.5))
	# Thin grid lines and corner hazard markings leave the play area easy to read.
	for grid_x: int in range(-5, 6):
		_box(environment_root, Vector3(0.012, 0.007, 8.75), Vector3(float(grid_x), 0.004, 0.0), _material(Color("2d3953")))
	for grid_z: int in range(-4, 5):
		_box(environment_root, Vector3(11.9, 0.007, 0.012), Vector3(0.0, 0.004, float(grid_z)), _material(Color("2d3953")))
	for side: int in [-1, 1]:
		for stripe: int in range(11):
			var marker: MeshInstance3D = _box(environment_root, Vector3(0.28, 0.011, 0.12), Vector3(-5.4 + float(stripe) * 1.08, 0.014, float(side) * 4.65), _material(Color("667391")))
			marker.rotation.y = -0.55
		_box(environment_root, Vector3(12.0, 0.09, 0.13), Vector3(0.0, 0.02, float(side) * 5.53), _material(ORANGE if side == 1 else CYAN, 0.2, 1.2))
	for slot: int in range(SLOT_POSITIONS.size()):
		var at: Vector3 = BoardLayout.position(slot,"wii")
		var marker: MeshInstance3D = _box(environment_root, Vector3(2.38 * CARD_FOOTPRINT_SCALE, 0.025, 2.65 * CARD_FOOTPRINT_SCALE), at + Vector3(0.0, 0.015, 0.0), _material(Color("172032"), 0.4))
		marker.name = "FieldSlot%d" % slot
		marker.set_meta("slot", slot)
		_rect_outline(environment_root, at + Vector3(0.0, 0.034, 0.0), Vector2(2.38, 2.65) * CARD_FOOTPRINT_SCALE, 0.022, _material(Color("445574"), 0.4))
		var number: Label3D = _flat_label(environment_root, str(slot + 1), at + Vector3(0.0, 0.044, 0.0), 100, 0.004, Color("566583"))
		number.modulate.a = 0.75
	# Stadium architecture sits behind the field, so it never hides a thrown sphere.
	for side: int in [-1, 1]:
		var tint: Color = CYAN if side == -1 else ORANGE
		for tier: int in range(3):
			_box(environment_root, Vector3(16.7 + float(tier) * 0.8, 0.4, 0.8), Vector3(0.0, 0.10 + float(tier) * 0.42, float(side) * (7.1 + float(tier) * 0.9)), _material(Color("18213a"), 0.15))
			_box(environment_root, Vector3(16.6 + float(tier) * 0.8, 0.045, 0.065), Vector3(0.0, 0.33 + float(tier) * 0.42, float(side) * (6.71 + float(tier) * 0.9)), _material(tint.darkened(0.3), 0.0, 1.0))
	for side: int in [-1, 1]:
		for z: float in [-5.9, 0.0, 5.9]:
			var p: Vector3 = Vector3(float(side) * 8.45, 0.0, z)
			_box(environment_root, Vector3(0.48, 3.8, 0.48), p + Vector3(0.0, 1.7, 0.0), _material(Color("202943"), 0.65))
			_box(environment_root, Vector3(0.05, 2.7, 0.53), p + Vector3(-float(side) * 0.26, 1.9, 0.0), _material(Color("7863f6"), 0.0, 1.7))
			_box(environment_root, Vector3(0.85, 0.20, 0.85), p + Vector3(0.0, 3.65, 0.0), _material(Color("414c6b"), 0.7))
	# Crowd lights use a single draw call instead of hundreds of independent nodes.
	var crowd: MultiMeshInstance3D = MultiMeshInstance3D.new()
	var crowd_mesh: SphereMesh = SphereMesh.new()
	crowd_mesh.radius = 0.065
	crowd_mesh.height = 0.13
	crowd_mesh.radial_segments = 6
	crowd_mesh.rings = 3
	crowd_mesh.material = _material(Color("6078c8"), 0.0, 0.9)
	var instances: MultiMesh = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = crowd_mesh
	instances.instance_count = 240
	for index: int in range(240):
		var side: int = -1 if index < 120 else 1
		var local_index: int = index % 120
		var row: int = int(float(local_index) / 40.0)
		var column: int = local_index % 40
		var position3: Vector3 = Vector3(-8.2 + float(column) * 0.42, 0.40 + float(row) * 0.42, float(side) * (7.2 + float(row) * 0.9))
		instances.set_instance_transform(index, Transform3D(Basis.IDENTITY, position3))
		instances.set_instance_color(index, Color("6891b5") if index % 4 != 0 else Color("ab6c98"))
	crowd.multimesh = instances
	environment_root.add_child(crowd)
	_flat_label(environment_root, "BATTLE FIELD", Vector3(0.0, 0.04, -4.2), 80, 0.006, Color("5b6d94"))
	_flat_label(environment_root, "NEON STADIUM  /  01", Vector3(0.0, 0.04, 4.1), 48, 0.004, Color("8896b6"))
	# A faceted canopy and cylindrical beacons provide the stadium silhouette.
	for side: int in [-1, 1]:
		var at: Vector3 = Vector3(float(side) * 7.5, 0.0, -9.6)
		_cylinder(environment_root, 0.42, 4.2, at + Vector3(0.0, 2.0, 0.0), _material(Color("263b5e"), 0.6), 8)
		_torus(environment_root, 0.47, 0.55, at + Vector3(0.0, 4.1, 0.0), _material(CYAN, 0.25, 1.5))
		_cylinder(environment_root, 0.75, 0.16, at + Vector3(0.0, 4.32, 0.0), _material(Color("39496d"), 0.6), 8)
	_beveled_slab(environment_root, Vector2(16.6, 1.4), 0.35, Vector3(0.0, 4.48, -9.6), _material(Color("202a45"), 0.45), 0.55)
	_capsule(environment_root, Vector3(-7.0, 4.5, -8.94), Vector3(7.0, 4.5, -8.94), 0.045, _material(Color("7863f6"), 0.0, 1.8))
	_flat_label(environment_root, "BAKUGAN  /  ARENA", Vector3(0.0, 4.68, -9.6), 90, 0.006, Color("99c7ef"))

func _build_themed_field(palette: Dictionary, subtitle: String) -> void:
	# All environments share the same orthogonal field and rolling surface.
	_beveled_slab(environment_root, Vector2(16.4, 13.2), 0.64, Vector3(0.0, -0.66, 0.0), _material(palette["base"], 0.2), 1.05)
	_beveled_slab(environment_root, Vector2(15.6, 12.4), 0.16, Vector3(0.0, -0.31, 0.0), _material(palette["stone"], 0.18), 0.95)
	_beveled_slab(environment_root, Vector2(12.7, 9.65), 0.06, Vector3(0.0, -0.065, 0.0), _material(palette["floor"], 0.15), 0.45)
	_beveled_slab(environment_root, Vector2(11.9, 8.8), 0.04, Vector3(0.0, -0.025, 0.0), _material(palette["floor"], 0.28), 0.3)
	_rect_outline(environment_root, Vector3.ZERO, Vector2(12.35, 9.18), 0.045, _material(palette["edge"], 0.15, 0.75))
	for grid_x: int in range(-5, 6):
		_box(environment_root, Vector3(0.012, 0.007, 8.75), Vector3(float(grid_x), 0.004, 0.0), _material(palette["grid"]))
	for grid_z: int in range(-4, 5):
		_box(environment_root, Vector3(11.9, 0.007, 0.012), Vector3(0.0, 0.004, float(grid_z)), _material(palette["grid"]))
	for slot: int in range(SLOT_POSITIONS.size()):
		var at: Vector3 = BoardLayout.position(slot,"wii")
		var marker: MeshInstance3D = _box(environment_root, Vector3(2.38 * CARD_FOOTPRINT_SCALE, 0.025, 2.65 * CARD_FOOTPRINT_SCALE), at + Vector3(0.0, 0.015, 0.0), _material(palette["slot"], 0.25))
		marker.name = "FieldSlot%d" % slot
		marker.set_meta("slot", slot)
		_rect_outline(environment_root, at + Vector3(0.0, 0.034, 0.0), Vector2(2.38, 2.65) * CARD_FOOTPRINT_SCALE, 0.022, _material(palette["grid"], 0.25))
		_flat_label(environment_root, str(slot + 1), at + Vector3(0.0, 0.044, 0.0), 100, 0.004, palette["grid"])
	_flat_label(environment_root, subtitle, Vector3(0.0, 0.04, -4.2), 64, 0.0048, palette["crystal"])
	_flat_label(environment_root, "BATTLE FIELD  /  %02d" % (2 if theme_id == "canyon" else 3), Vector3(0.0, 0.04, 4.1), 48, 0.004, palette["crystal"])

func _build_canyon(palette: Dictionary) -> void:
	_build_themed_field(palette, "PYRUS  /  CRIMSON CANYON")
	# Lava occupies recessed channels outside the playable rectangle.
	for side: int in [-1, 1]:
		var z: float = float(side) * 5.67
		_beveled_slab(environment_root, Vector2(13.8, 0.75), 0.045, Vector3(0.0, -0.25, z), _material(Color("9f2e1c"), 0.0, 0.6), 0.3)
		for stripe: int in range(5):
			_capsule(environment_root, Vector3(-6.4 + float(stripe) * 2.45, -0.205, z - 0.18), Vector3(-5.1 + float(stripe) * 2.45, -0.205, z + 0.18), 0.045, _material(palette["edge"], 0.0, 1.65))
		for pillar: int in range(6):
			var at: Vector3 = Vector3(-6.7 + float(pillar) * 2.65, -0.23, float(side) * 6.22)
			_cylinder(environment_root, 0.37, 0.55 + float(pillar % 2) * 0.16, at + Vector3(0.0, 0.23, 0.0), _material(palette["base"], 0.12), 6)
			_torus(environment_root, 0.36, 0.4, at + Vector3(0.0, 0.45, 0.0), _material(palette["edge"], 0.0, 0.8))
	# Uneven ring meshes form distant mesas; tall terrain stays behind the field.
	for rock: int in range(9):
		var x: float = -14.0 + float(rock) * 3.6
		var height: float = 3.4 + float((rock * 7) % 5) * 0.68
		var terrain: MeshInstance3D = _faceted_rock(environment_root, Vector3(x, -1.25, -12.4 - float(rock % 2) * 1.9), 3.1 + float(rock % 3) * 0.55, height, palette["stone"], rock, 7)
		terrain.name = "CanyonMesa%d" % rock
	for side: int in [-1, 1]:
		for rock: int in range(3):
			_faceted_rock(environment_root, Vector3(float(side) * (10.2 + float(rock) * 0.7), -0.65, -6.1 + float(rock) * 4.0), 1.2, 1.6 + float(rock) * 0.35, palette["stone"], rock + side + 20, 6)
	for side: int in [-1, 1]:
		var beacon: Vector3 = Vector3(float(side) * 7.3, 0.0, -7.4)
		_cylinder(environment_root, 0.65, 0.3, beacon + Vector3(0.0, 0.1, 0.0), _material(palette["base"]), 8)
		_faceted_rock(environment_root, beacon + Vector3(0.0, 0.25, 0.0), 0.34, 1.6, palette["edge"], 12, 5)
		_torus(environment_root, 0.54, 0.60, beacon + Vector3(0.0, 0.31, 0.0), _material(palette["edge"], 0.0, 1.6))

func _build_glacier(palette: Dictionary) -> void:
	_build_themed_field(palette, "AQUOS  /  FROZEN FRONTIER")
	for side: int in [-1, 1]:
		var z: float = float(side) * 5.62
		_beveled_slab(environment_root, Vector2(13.8, 0.9), 0.10, Vector3(0.0, -0.22, z), _material(palette["base"], 0.25), 0.36)
		_capsule(environment_root, Vector3(-6.5, -0.12, z), Vector3(6.5, -0.12, z), 0.075, _material(palette["crystal"], 0.2, 0.9))
		for crystal: int in range(7):
			var at: Vector3 = Vector3(-7.1 + float(crystal) * 2.35, -0.25, float(side) * 6.7)
			var spike: MeshInstance3D = _faceted_rock(environment_root, at, 0.34, 0.75 + float(crystal % 3) * 0.23, palette["crystal"], crystal, 5)
			spike.rotation.z = (float(crystal % 3) - 1.0) * 0.18
	for ridge: int in range(8):
		var x: float = -15.5 + float(ridge) * 4.4
		var terrain: MeshInstance3D = _faceted_rock(environment_root, Vector3(x, -1.5, -13.0 - float(ridge % 3)), 3.6, 4.0 + float((ridge * 3) % 4) * 0.9, palette["stone"], ridge + 7, 6)
		terrain.name = "IceRidge%d" % ridge
	for side: int in [-1, 1]:
		var at: Vector3 = Vector3(float(side) * 9.2, -0.3, -7.2)
		for crystal: int in range(4):
			var offset: Vector3 = Vector3(float(crystal % 2) * float(side) * 0.75, 0.0, -float(crystal / 2) * 0.75)
			var shard: MeshInstance3D = _faceted_rock(environment_root, at + offset, 0.55, 2.3 + float(crystal) * 0.6, palette["crystal"], crystal + 19, 5)
			shard.rotation.z = float(side) * (0.08 + float(crystal) * 0.07)
			shard.name = "GlacierCrystal%d_%d" % [side, crystal]
		_torus(environment_root, 1.25, 1.33, at + Vector3(0.0, 0.03, 0.0), _material(palette["edge"], 0.1, 1.4))
	# Fine irregular ice seams remain below the cards and rolling balls.
	for seam: int in range(6):
		var start: Vector3 = Vector3(-5.4 + float(seam) * 2.15, 0.008, -3.8)
		var midpoint: Vector3 = start + Vector3(-0.5, 0.0, 0.48)
		_capsule(environment_root, start, midpoint, 0.012, _material(palette["grid"], 0.15, 0.1))
		_capsule(environment_root, midpoint, midpoint + Vector3(0.28, 0.0, 0.52), 0.012, _material(palette["grid"], 0.15, 0.1))

func highlight_target(slot: int) -> void:
	clear_highlights()
	if slot < 0 or slot >= slot_count():
		return
	var palette: Dictionary = ArenaCatalog.get_entry(theme_id)["palette"]
	target_highlight = Node3D.new()
	target_highlight.name = "TargetHighlight"
	target_highlight.position = slot_position(slot)+Vector3(0,0.145,0)
	target_highlight.set_meta("slot", slot)
	target_highlight.set_meta("theme_id", theme_id)
	add_child(target_highlight)
	var color: Color = palette["crystal"]
	var footprint_scale: float=BoardLayout.DS_CARD_SCALE if board_profile=="ds" else BoardLayout.WII_CARD_SCALE
	_rect_outline(target_highlight, Vector3.ZERO, BoardLayout.card_size(board_profile)+Vector2(0.08,0.12), 0.048, _material(color, 0.0, 1.4))
	for side: int in [-1, 1]:
		_wing_mesh(target_highlight, PackedVector3Array([
			Vector3(float(side) * 1.52 * footprint_scale, 0.0, 0.0),
			Vector3(float(side) * 1.74 * footprint_scale, 0.0, -0.14 * footprint_scale),
			Vector3(float(side) * 1.74 * footprint_scale, 0.0, 0.14 * footprint_scale),
		]), _material(color, 0.0, 1.4))

func highlight_legal_slots(slots: Array[int]) -> void:
	if is_instance_valid(legal_highlights):
		legal_highlights.free()
	legal_highlights = null
	if slots.is_empty():
		return
	legal_highlights = Node3D.new()
	legal_highlights.name = "LegalPlacementHighlights"
	legal_highlights.set_meta("slots", slots.duplicate())
	legal_highlights.set_meta("theme_id", theme_id)
	add_child(legal_highlights)
	var palette: Dictionary = ArenaCatalog.get_entry(theme_id)["palette"]
	for slot: int in slots:
		if slot < 0 or slot >= slot_count():
			continue
		_rect_outline(legal_highlights, slot_position(slot)+Vector3(0,0.105,0), BoardLayout.card_size(board_profile), 0.035, _material(palette["crystal"], 0.0, 0.8))

func clear_highlights() -> void:
	if is_instance_valid(target_highlight):
		target_highlight.free()
	target_highlight = null
	if is_instance_valid(legal_highlights):
		legal_highlights.free()
	legal_highlights = null

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	for reference: WeakRef in _texture_videos:
		var video: VideoStreamPlayer = reference.get_ref() as VideoStreamPlayer
		if video != null:
			video.paused = enabled
	if not enabled:
		return
	# Only visual tracks registered here are affected. Match timers and physics
	# belong to the caller and continue independently.
	for state: Dictionary in _visual_states:
		var tween: Tween = state["tween"]
		if tween.is_valid():
			tween.kill()
		var node: Node3D = state["node"].get_ref() as Node3D
		if is_instance_valid(node):
			for property: String in state["final"]:
				node.set_indexed(NodePath(property), state["final"][property])
	_visual_states.clear()
	for reference: WeakRef in _unfold_players:
		ModelLibrary.finish_unfold(reference.get_ref() as AnimationPlayer)

func _watch_visual(tween: Tween, node: Node3D, final_values: Dictionary) -> void:
	var active: Array[Dictionary] = []
	for state: Dictionary in _visual_states:
		if state["tween"].is_valid() and state["node"].get_ref() != null:
			active.append(state)
	_visual_states = active
	_visual_states.append({"tween": tween, "node": weakref(node), "final": final_values})

func _adopt_model_visuals(node: Node3D) -> void:
	_texture_videos = _texture_videos.filter(func(reference: WeakRef) -> bool: return reference.get_ref() != null)
	var video: VideoStreamPlayer = node.get_node_or_null("TextureVideo") as VideoStreamPlayer
	if video != null:
		_texture_videos.append(weakref(video))
	var active_players: Array[WeakRef] = []
	for reference: WeakRef in _unfold_players:
		if reference.get_ref() != null:
			active_players.append(reference)
	_unfold_players = active_players
	if node.has_meta("unfold_player"):
		_unfold_players.append(node.get_meta("unfold_player") as WeakRef)
	for state: Dictionary in node.get_meta("visual_states", []):
		var target: Node3D = state["node"].get_ref() as Node3D
		if is_instance_valid(target):
			_watch_visual(state["tween"], target, state["final"])

func capture_effect(at: Vector3, color: Color) -> void:
	if reduced_motion:
		return
	var effect: Node3D = Node3D.new()
	effect.name = "CaptureEffect"
	effect.position = at + Vector3(0.0, 0.14, 0.0)
	add_child(effect)
	for index: int in range(3):
		var ring: MeshInstance3D = _torus(effect, 0.48 + float(index) * 0.3, 0.52 + float(index) * 0.3, Vector3.ZERO, _material(color, 0.0, 2.0))
		var pulse: Tween = effect.create_tween().set_parallel(true)
		pulse.tween_property(ring, "scale", Vector3(2.7, 0.05, 2.7), 0.5 + float(index) * 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pulse.tween_property(ring, "position:y", 0.3 + float(index) * 0.18, 0.5 + float(index) * 0.12)
		_watch_visual(pulse, ring, {"scale": Vector3(2.7, 0.05, 2.7), "position:y": 0.3 + float(index) * 0.18})
	var lifetime: Tween = effect.create_tween()
	lifetime.tween_interval(0.9)
	lifetime.tween_callback(effect.queue_free)

func make_gate(slot_index: int, owner: int, title: String, revealed: bool = false, color_type: String = "", source_card_key: String = "") -> Node3D:
	remove_gate(slot_index)
	var gate: Node3D = Node3D.new()
	gate.name = "Gate%d" % slot_index
	gate.position = slot_position(slot_index)
	add_child(gate)
	gates[slot_index] = gate
	gate.set_meta("revealed", revealed)
	# Art fits the narrower grid while the root keeps its animation scale.
	var artwork: Node3D = Node3D.new()
	artwork.name = "CardArtwork"
	var card_scale: float=BoardLayout.DS_CARD_SCALE if board_profile=="ds" else BoardLayout.WII_CARD_SCALE
	artwork.scale = Vector3(card_scale, 1.0, card_scale)
	gate.add_child(artwork)
	var accent: Color = ORANGE if owner == 0 else CYAN
	var background: Color = Color("593020") if owner == 0 else Color("153d54")
	if revealed:
		match color_type.to_lower():
			"gold": accent = Color("f5cc67")
			"silver": accent = Color("c6d4e5")
			"copper": accent = Color("cf8651")
		background = accent.darkened(0.48)
	_box(artwork, Vector3(2.27, 0.046, 2.55), Vector3(0.0, 0.063, 0.0), _material(background, 0.45))
	_rect_outline(artwork, Vector3(0.0, 0.091, 0.0), Vector2(2.23, 2.51), 0.045, _material(accent, 0.4, 0.45))
	_rect_outline(artwork, Vector3(0.0, 0.094, 0.0), Vector2(2.03, 2.30), 0.012, _material(accent.lightened(0.2), 0.35))
	# Dark header and footer maintain contrast for the card's number and name.
	_box(artwork, Vector3(2.05, 0.008, 0.44), Vector3(0.0, 0.096, -0.97), _material(Color("101827")))
	_box(artwork, Vector3(2.05, 0.008, 0.47), Vector3(0.0, 0.096, 0.98), _material(Color("101827")))
	var header: String = color_type.to_upper() if revealed and not color_type.is_empty() else "GATE"
	_flat_label(artwork, "%s  %02d" % [header, slot_index + 1], Vector3(0.0, 0.113, -0.97), 48, 0.0044, Color("f3e6d2"))
	_flat_label(artwork, title.to_upper() if revealed else "КАРТА ЗАКРЫТА", Vector3(0.0, 0.113, 0.98), 42, 0.0035, Color("fff4e6"))
	var medallion: MeshInstance3D = _cylinder(artwork, 0.63, 0.018, Vector3(0.0, 0.100, -0.02), _material(background.darkened(0.5), 0.5), 6)
	medallion.rotation.y = PI / 6.0
	_torus(artwork, 0.53, 0.565, Vector3(0.0, 0.118, -0.02), _material(accent, 0.5, 0.5))
	_flat_label(artwork, "B", Vector3(0.0, 0.128, -0.035), 128, 0.0043, accent.lightened(0.30))
	for angle: int in range(4):
		var theta: float = float(angle) * PI / 2.0 + PI / 4.0
		var rivet: Vector3 = Vector3(cos(theta) * 0.89, 0.122, sin(theta) * 0.89)
		_cylinder(artwork, 0.055, 0.012, rivet, _material(accent, 0.8), 8)
	var card_index: int = -1
	for index in range(GateCatalog.CARDS.size()):
		if str(GateCatalog.CARDS[index].title) == title:
			card_index = index
			break
	var face: Texture2D = CardArt.gate_texture(card_index) if revealed else CardArt.back_texture()
	if not source_card_key.is_empty():
		face = DSCardArt.texture(source_card_key) if revealed else DSCardArt.back_texture()
	if face != null:
		var metadata: Dictionary = CardArt.gate_metadata(card_index) if revealed else {}
		if revealed and not source_card_key.is_empty():
			metadata = DSCardArt.metadata(source_card_key)
			metadata["display_mode"] = "source_face"
		var full_face: bool = not revealed or str(metadata.get("display_mode", "")) == "source_face"
		var card_surface := MeshInstance3D.new()
		card_surface.name = "SourceCardFace" if revealed else "SourceCardBack"
		var plane := PlaneMesh.new()
		plane.size = Vector2(1.87, 2.49) if full_face else Vector2(2.01, 1.42)
		card_surface.mesh = plane
		card_surface.position = Vector3(0.0, 0.151, 0.0)
		var face_material := StandardMaterial3D.new()
		face_material.albedo_texture = face
		face_material.roughness = 1.0
		face_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		card_surface.material_override = face_material
		artwork.add_child(card_surface)
		gate.set_meta("card_art", metadata if revealed else {"display_mode": "source_back", "revealed": false})
	if not reduced_motion:
		gate.scale = Vector3(0.8, 0.8, 0.8)
		var reveal_tween: Tween = gate.create_tween()
		reveal_tween.tween_property(gate, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_watch_visual(reveal_tween, gate, {"scale": Vector3.ONE})
	return gate

func remove_gate(slot_index: int) -> void:
	if gates.has(slot_index):
		var existing: Node3D = gates[slot_index] as Node3D
		if is_instance_valid(existing):
			existing.queue_free()
		gates.erase(slot_index)

func make_ball(attribute: String, owner: int, species: String = "") -> Node3D:
	var modeled_ball: Node3D = ModelLibrary.make_ball(self, attribute, owner, reduced_motion, species)
	if modeled_ball != null:
		_adopt_model_visuals(modeled_ball)
		return modeled_ball
	var ball: Node3D = Node3D.new()
	ball.name = "MechanicalSphere"
	add_child(ball)
	var shell: Color = _attribute_color(attribute)
	var shell_material: StandardMaterial3D = _material(shell, 0.62)
	_sphere(ball, 0.38, Vector3.ZERO, shell_material, 24, 12)
	# The three dark seams make the folded sphere visibly mechanical as it rolls.
	for axis: int in range(3):
		var seam: MeshInstance3D = _torus(ball, 0.361, 0.394, Vector3.ZERO, _material(Color("151b28"), 0.6))
		if axis == 1:
			seam.rotation.x = PI / 2.0
		elif axis == 2:
			seam.rotation.z = PI / 2.0
	var hinge_material: StandardMaterial3D = _material(Color("e8b66e"), 0.75)
	for axis: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var panel: MeshInstance3D = _cylinder(ball, 0.142, 0.025, axis * 0.368, hinge_material, 8)
		panel.basis = _axis_basis(axis)
		var inset: MeshInstance3D = _cylinder(ball, 0.104, 0.012, axis * 0.389, _material(shell.darkened(0.3), 0.6), 8)
		inset.basis = _axis_basis(axis)
	var owner_accent: Color = ORANGE if owner == 0 else CYAN
	_torus(ball, 0.292, 0.311, Vector3(0.0, 0.232, 0.0), _material(owner_accent, 0.4, 0.8))
	return ball

func make_creature(species: String, attribute: String, form: String = "toy") -> Node3D:
	var imported: Node3D = ModelLibrary.make_creature(self, species, attribute, reduced_motion, form)
	if imported == null and form == "toy":
		# A newly imported battle-only species keeps its own geometry on the
		# board. Its unavailable toy form is not replaced by another Bakugan.
		imported = ModelLibrary.make_creature(self, species, attribute, true, "battle")
		if imported != null:
			imported.set_meta("missing_toy_fallback", true)
	if imported != null:
		_adopt_model_visuals(imported)
		return imported
	var creature: Node3D
	var canonical: String
	match species.to_lower():
		"leonidas":
			canonical = "Leonidas"
			creature = _make_leonidas(attribute)
		"griffon":
			canonical = "Griffon"
			creature = _make_griffon(attribute)
		"hydranoid":
			canonical = "Hydranoid"
			creature = _make_hydranoid(attribute)
		"preyas":
			canonical = "Preyas"
			creature = _make_preyas(attribute)
		"gorem":
			canonical = "Gorem"
			creature = _make_gorem(attribute)
		_:
			canonical = "Dragonoid"
			creature = ModelLibrary.make_creature(self, canonical, attribute, reduced_motion)
			if creature != null:
				_adopt_model_visuals(creature)
			else:
				creature = _make_dragonoid(attribute)
	creature.name = canonical
	creature.set_meta("species", canonical)
	creature.set_meta("attribute", attribute)
	var parts: int = _count_meshes(creature)
	creature.set_meta("part_count", parts)
	creature.set_meta("mesh_count", parts)
	return creature

func make_dragon(attribute: String) -> Node3D:
	# Retained for callers using the prototype's original creature API.
	return make_creature("Dragonoid", attribute)

func _make_dragonoid(attribute: String) -> Node3D:
	var dragon: Node3D = Node3D.new()
	dragon.name = "MechanicalDragon"
	add_child(dragon)
	var shell: Color = _attribute_color(attribute)
	var armor: StandardMaterial3D = _material(shell, 0.62)
	var deep_armor: StandardMaterial3D = _material(shell.darkened(0.36), 0.55)
	var hinge: StandardMaterial3D = _material(Color("f1c485"), 0.78)
	var joints: StandardMaterial3D = _material(Color("18202d"), 0.65)
	var glow: StandardMaterial3D = _material(Color("9cf5dd"), 0.15, 2.0)
	var torso: MeshInstance3D = _sphere(dragon, 0.47, Vector3(0.0, 0.84, 0.0), armor, 16, 8)
	torso.scale = Vector3(0.84, 1.31, 0.88)
	var breast: MeshInstance3D = _sphere(dragon, 0.35, Vector3(0.0, 1.01, 0.27), hinge, 12, 6)
	breast.scale = Vector3(0.77, 1.10, 0.34)
	for side: int in [-1, 1]:
		var s: float = float(side)
		# Rear legs, claw tips and the visible gold pivots of the folding toy.
		_capsule(dragon, Vector3(s * 0.25, 0.77, 0.0), Vector3(s * 0.49, 0.39, 0.17), 0.16, deep_armor)
		_capsule(dragon, Vector3(s * 0.49, 0.39, 0.17), Vector3(s * 0.53, 0.15, 0.49), 0.13, armor)
		_sphere(dragon, 0.135, Vector3(s * 0.46, 0.40, 0.17), hinge, 10, 5)
		var foot: MeshInstance3D = _sphere(dragon, 0.23, Vector3(s * 0.54, 0.13, 0.59), deep_armor, 12, 6)
		foot.scale = Vector3(0.85, 0.48, 1.30)
		for toe: int in range(3):
			_spike(dragon, Vector3(s * 0.54 + float(toe - 1) * 0.09, 0.15, 0.71), Vector3(s * 0.54 + float(toe - 1) * 0.1, 0.11, 0.91), 0.055, hinge)
		# Shoulder sockets and articulated front limbs.
		_sphere(dragon, 0.19, Vector3(s * 0.4, 1.13, 0.05), joints, 10, 5)
		_capsule(dragon, Vector3(s * 0.44, 1.10, 0.16), Vector3(s * 0.72, 0.91, 0.34), 0.11, armor)
		_capsule(dragon, Vector3(s * 0.72, 0.91, 0.34), Vector3(s * 0.79, 0.97, 0.60), 0.08, deep_armor)
		_sphere(dragon, 0.09, Vector3(s * 0.72, 0.91, 0.34), hinge, 8, 4)
		for finger: int in range(2):
			_spike(dragon, Vector3(s * 0.79 + float(finger) * s * 0.07, 0.97, 0.6), Vector3(s * 0.83 + float(finger) * s * 0.07, 0.89, 0.76), 0.045, hinge)
	_capsule(dragon, Vector3(0.0, 1.10, 0.06), Vector3(0.0, 1.56, 0.35), 0.20, deep_armor)
	var head: MeshInstance3D = _sphere(dragon, 0.31, Vector3(0.0, 1.70, 0.47), armor, 12, 6)
	head.scale = Vector3(1.0, 0.76, 1.30)
	var muzzle: MeshInstance3D = _armor_box(dragon, Vector3(0.38, 0.20, 0.35), Vector3(0.0, 1.61, 0.80), deep_armor)
	muzzle.rotation.x = -0.09
	_armor_box(dragon, Vector3(0.34, 0.06, 0.31), Vector3(0.0, 1.49, 0.81), hinge)
	for side: int in [-1, 1]:
		var s: float = float(side)
		var eye: MeshInstance3D = _sphere(dragon, 0.07, Vector3(s * 0.249, 1.77, 0.67), glow, 10, 5)
		eye.scale = Vector3(0.43, 0.64, 1.20)
		_spike(dragon, Vector3(s * 0.19, 1.84, 0.35), Vector3(s * 0.31, 2.16, 0.12), 0.105, hinge)
		_spike(dragon, Vector3(s * 0.13, 1.58, 0.9), Vector3(s * 0.13, 1.46, 0.9), 0.035, hinge)
	# Segmented curved tail, tapering into a metallic arrow tip.
	var tail_points: Array[Vector3] = [Vector3(0.0, 0.66, -0.25), Vector3(0.0, 0.41, -0.67), Vector3(0.20, 0.28, -1.09), Vector3(0.45, 0.34, -1.39), Vector3(0.54, 0.57, -1.57)]
	for index: int in range(tail_points.size() - 1):
		_capsule(dragon, tail_points[index], tail_points[index + 1], 0.115 - float(index) * 0.022, armor)
		_sphere(dragon, 0.09 - float(index) * 0.012, tail_points[index + 1], joints, 8, 4)
	_spike(dragon, tail_points[-1], Vector3(0.58, 0.81, -1.69), 0.115, hinge)
	for index: int in range(3):
		_spike(dragon, Vector3(0.0, 1.04 - float(index) * 0.22, -0.35 - float(index) * 0.15), Vector3(0.0, 1.22 - float(index) * 0.22, -0.58 - float(index) * 0.15), 0.105, hinge)
	# Wings deploy from actual pivot nodes, rather than scaling a static silhouette.
	for side: int in [-1, 1]:
		var s: float = float(side)
		var pivot: Node3D = Node3D.new()
		pivot.position = Vector3(s * 0.32, 1.17, -0.09)
		dragon.add_child(pivot)
		var points: PackedVector3Array = PackedVector3Array([
			Vector3.ZERO, Vector3(s * 0.68, 0.75, -0.16), Vector3(s * 1.46, 0.70, -0.29),
			Vector3(s * 1.29, 0.17, -0.30), Vector3(s * 0.98, -0.12, -0.32), Vector3(s * 0.58, -0.33, -0.18)
		])
		var membrane: MeshInstance3D = _wing_mesh(pivot, points, _material(shell.lightened(0.08), 0.28, 0.10))
		membrane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		for index: int in [1, 2, 3, 4, 5]:
			_capsule(pivot, Vector3.ZERO, points[index], 0.027, hinge)
		for index: int in range(1, points.size() - 1):
			_capsule(pivot, points[index], points[index + 1], 0.033, deep_armor)
		_sphere(pivot, 0.135, Vector3.ZERO, hinge, 10, 5)
		pivot.rotation.z = s * 0.12
		if not reduced_motion:
			pivot.rotation.z = s * 1.25
			pivot.rotation.y = -s * 0.40
			var deploy: Tween = pivot.create_tween()
			deploy.set_parallel(true)
			deploy.tween_property(pivot, "rotation:z", s * 0.12, 0.50).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			deploy.tween_property(pivot, "rotation:y", 0.0, 0.45)
			_watch_visual(deploy, pivot, {"rotation:z": s * 0.12, "rotation:y": 0.0})
	_reveal_creature(dragon)
	return dragon

func _creature_root(species: String) -> Node3D:
	var creature: Node3D = Node3D.new()
	creature.name = species
	add_child(creature)
	return creature

func _creature_materials(attribute: String) -> Dictionary:
	var color: Color = _attribute_color(attribute)
	return {
		"armor": _material(color, 0.48),
		"dark": _material(color.darkened(0.38), 0.35),
		"light": _material(color.lightened(0.28), 0.25),
		"gold": _material(Color("f1c485"), 0.68),
		"joint": _material(Color("152234"), 0.55),
		"eye": _material(Color("a8ffe0"), 0.1, 2.0)
	}

func _count_meshes(parent: Node) -> int:
	var count: int = 1 if parent is MeshInstance3D else 0
	for child: Node in parent.get_children():
		count += _count_meshes(child)
	return count

func _reveal_creature(creature: Node3D) -> void:
	if reduced_motion:
		creature.scale = Vector3.ONE
		return
	creature.scale = Vector3.ONE * 0.18
	var unfold: Tween = creature.create_tween()
	unfold.tween_property(creature, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_watch_visual(unfold, creature, {"scale": Vector3.ONE})

func _joint(parent: Node3D, at: Vector3, closed: Vector3, opened: Vector3 = Vector3.ZERO) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = "RevealJoint"
	pivot.position = at
	parent.add_child(pivot)
	pivot.rotation = opened
	if not reduced_motion:
		pivot.rotation = closed
		var reveal: Tween = pivot.create_tween()
		reveal.tween_property(pivot, "rotation", opened, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_watch_visual(reveal, pivot, {"rotation": opened})
	return pivot

func _eyes(parent: Node3D, center: Vector3, spread: float, materials: Dictionary) -> void:
	for side: int in [-1, 1]:
		var eye: MeshInstance3D = _sphere(parent, 0.065, center + Vector3(float(side) * spread, 0.0, 0.0), materials.eye, 10, 5)
		eye.scale = Vector3(0.7, 0.65, 1.1)

func _claws(parent: Node3D, at: Vector3, materials: Dictionary, width: float = 0.10) -> void:
	for toe: int in range(3):
		var start: Vector3 = at + Vector3(float(toe - 1) * width, 0.0, 0.0)
		_spike(parent, start, start + Vector3(0.0, -0.035, 0.21), 0.045, materials.gold)

func _make_leonidas(attribute: String) -> Node3D:
	var creature: Node3D = _creature_root("Leonidas")
	var m: Dictionary = _creature_materials(attribute)
	# Broad angular armor and heavy arms give Leonidas a muscular silhouette.
	var chest: MeshInstance3D = _armor_box(creature, Vector3(0.83, 0.72, 0.48), Vector3(0.0, 1.02, 0.0), m.armor)
	chest.rotation.z = 0.05
	_armor_box(creature, Vector3(0.55, 0.42, 0.10), Vector3(0.0, 1.04, 0.29), m.gold)
	_armor_box(creature, Vector3(0.47, 0.28, 0.38), Vector3(0.0, 0.60, 0.0), m.dark)
	for side: int in [-1, 1]:
		var s: float = float(side)
		_capsule(creature, Vector3(s * 0.20, 0.62, 0.0), Vector3(s * 0.36, 0.27, 0.09), 0.17, m.armor)
		_armor_box(creature, Vector3(0.32, 0.22, 0.52), Vector3(s * 0.36, 0.13, 0.22), m.dark)
		_claws(creature, Vector3(s * 0.36, 0.16, 0.45), m)
		var arm: Node3D = _joint(creature, Vector3(s * 0.48, 1.24, 0.0), Vector3(0.0, 0.0, s * 1.1))
		_sphere(arm, 0.24, Vector3.ZERO, m.armor, 10, 5)
		_capsule(arm, Vector3.ZERO, Vector3(s * 0.12, -0.37, 0.19), 0.17, m.dark)
		_armor_box(arm, Vector3(0.27, 0.27, 0.24), Vector3(s * 0.14, -0.50, 0.23), m.armor)
		_spike(arm, Vector3(s * 0.09, 0.14, 0.0), Vector3(s * 0.23, 0.40, -0.05), 0.09, m.gold)
		var wing: Node3D = _joint(creature, Vector3(s * 0.33, 1.29, -0.18), Vector3(0.0, -s * 0.7, s * 1.1))
		var points: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3(s * 0.48, 0.85, -0.16), Vector3(s * 1.16, 0.45, -0.22), Vector3(s * 0.89, -0.20, -0.25), Vector3(s * 0.35, -0.38, -0.12)])
		_wing_mesh(wing, points, m.dark)
		for i: int in range(1, points.size()):
			_capsule(wing, Vector3.ZERO, points[i], 0.04, m.gold)
			_spike(wing, points[i], points[i] + Vector3(s * 0.10, 0.13, 0.0), 0.055, m.armor)
	var head: Node3D = _joint(creature, Vector3(0.0, 1.47, 0.13), Vector3(-0.6, 0.0, 0.0))
	_armor_box(head, Vector3(0.48, 0.38, 0.46), Vector3(0.0, 0.11, 0.0), m.armor)
	_armor_box(head, Vector3(0.36, 0.13, 0.30), Vector3(0.0, -0.05, 0.26), m.dark)
	_eyes(head, Vector3(0.0, 0.18, 0.23), 0.19, m)
	for side: int in [-1, 1]:
		var s: float = float(side)
		_spike(head, Vector3(s * 0.18, 0.27, -0.08), Vector3(s * 0.34, 0.62, -0.25), 0.115, m.gold)
	_capsule(creature, Vector3(0.0, 0.57, -0.18), Vector3(0.28, 0.34, -0.82), 0.105, m.dark)
	_spike(creature, Vector3(0.28, 0.34, -0.82), Vector3(0.38, 0.43, -1.18), 0.12, m.armor)
	_reveal_creature(creature)
	return creature

func _make_griffon(attribute: String) -> Node3D:
	var creature: Node3D = _creature_root("Griffon")
	var m: Dictionary = _creature_materials(attribute)
	var body: MeshInstance3D = _sphere(creature, 0.44, Vector3(0.0, 0.75, -0.11), m.armor)
	body.scale = Vector3(0.88, 0.90, 1.65)
	# Four taloned legs, a bird's beak and separate feathers distinguish the griffin.
	for side: int in [-1, 1]:
		var s: float = float(side)
		for z: float in [-0.52, 0.41]:
			_capsule(creature, Vector3(s * 0.28, 0.65, z), Vector3(s * 0.34, 0.17, z + 0.12), 0.10, m.dark)
			_sphere(creature, 0.11, Vector3(s * 0.34, 0.14, z + 0.12), m.gold, 10, 5)
			_claws(creature, Vector3(s * 0.34, 0.13, z + 0.20), m, 0.075)
		var wing: Node3D = _joint(creature, Vector3(s * 0.25, 0.98, -0.12), Vector3(0.0, -s * 0.8, s * 1.2))
		_capsule(wing, Vector3.ZERO, Vector3(s * 0.60, 0.38, -0.12), 0.13, m.armor)
		for feather: int in range(7):
			var start: Vector3 = Vector3(s * (0.25 + float(feather) * 0.095), 0.20 + float(feather) * 0.042, -0.08)
			var end: Vector3 = start + Vector3(s * (0.43 + float(feather) * 0.045), 0.10 - float(feather) * 0.045, -0.45)
			var plume: MeshInstance3D = _capsule(wing, start, end, 0.075, m.light if feather % 2 == 0 else m.armor)
			plume.scale.z = 0.72
	var neck: Node3D = _joint(creature, Vector3(0.0, 0.93, 0.35), Vector3(-0.7, 0.0, 0.0))
	_capsule(neck, Vector3.ZERO, Vector3(0.0, 0.42, 0.16), 0.18, m.light)
	_sphere(neck, 0.24, Vector3(0.0, 0.51, 0.22), m.light, 12, 6)
	_spike(neck, Vector3(0.0, 0.47, 0.37), Vector3(0.0, 0.34, 0.72), 0.145, m.gold)
	_eyes(neck, Vector3(0.0, 0.57, 0.38), 0.19, m)
	for feather: int in range(3):
		_spike(neck, Vector3(0.0, 0.69, 0.18 - float(feather) * 0.08), Vector3(0.0, 0.91, 0.01 - float(feather) * 0.12), 0.07, m.armor)
	_capsule(creature, Vector3(0.0, 0.74, -0.67), Vector3(0.24, 0.76, -1.09), 0.07, m.dark)
	_sphere(creature, 0.14, Vector3(0.24, 0.76, -1.12), m.light, 10, 5)
	_reveal_creature(creature)
	return creature

func _make_hydranoid(attribute: String) -> Node3D:
	var creature: Node3D = _creature_root("Hydranoid")
	var m: Dictionary = _creature_materials(attribute)
	# One serpent head: the later multiheaded evolutions are separate creatures.
	var body: MeshInstance3D = _sphere(creature, 0.42, Vector3(0.0, 0.69, -0.16), m.dark)
	body.scale = Vector3(0.95, 1.2, 1.35)
	var neck: Node3D = _joint(creature, Vector3(0.0, 0.91, 0.05), Vector3(-1.0, 0.0, 0.0))
	var points: Array[Vector3] = [Vector3.ZERO, Vector3(0.0, 0.30, 0.15), Vector3(0.0, 0.62, 0.03), Vector3(0.0, 0.94, 0.19)]
	for i: int in range(points.size() - 1):
		_capsule(neck, points[i], points[i + 1], 0.19 - float(i) * 0.018, m.armor)
		_spike(neck, points[i] + Vector3(0.0, 0.0, -0.14), points[i] + Vector3(0.0, 0.14, -0.42), 0.075, m.gold)
	var head: MeshInstance3D = _sphere(neck, 0.26, Vector3(0.0, 0.96, 0.34), m.armor, 10, 5)
	head.name = "SingleSerpentHead"
	head.scale = Vector3(0.9, 0.65, 1.8)
	_armor_box(neck, Vector3(0.32, 0.10, 0.40), Vector3(0.0, 0.81, 0.55), m.gold)
	_eyes(neck, Vector3(0.0, 1.02, 0.48), 0.20, m)
	for side: int in [-1, 1]:
		var s: float = float(side)
		_spike(neck, Vector3(s * 0.16, 1.07, 0.22), Vector3(s * 0.30, 1.35, -0.04), 0.085, m.gold)
		_capsule(creature, Vector3(s * 0.24, 0.65, -0.10), Vector3(s * 0.54, 0.22, 0.28), 0.15, m.armor)
		_claws(creature, Vector3(s * 0.54, 0.15, 0.45), m)
		var arm: Node3D = _joint(creature, Vector3(s * 0.33, 1.02, 0.0), Vector3(0.0, 0.0, s * 1.0))
		_capsule(arm, Vector3.ZERO, Vector3(s * 0.37, -0.23, 0.27), 0.08, m.armor)
		_claws(arm, Vector3(s * 0.38, -0.23, 0.27), m, 0.06)
		for i: int in range(3):
			var at: Vector3 = Vector3(s * 0.31, 0.93 - float(i) * 0.18, -0.13 - float(i) * 0.12)
			_spike(creature, at, at + Vector3(s * 0.30, 0.12, -0.14), 0.105, m.gold)
	var tail: Array[Vector3] = [Vector3(0.0, 0.64, -0.45), Vector3(0.0, 0.27, -0.89), Vector3(0.30, 0.19, -1.30), Vector3(0.68, 0.28, -1.59), Vector3(0.95, 0.54, -1.75)]
	for i: int in range(tail.size() - 1):
		_capsule(creature, tail[i], tail[i + 1], 0.16 - float(i) * 0.03, m.armor)
		_spike(creature, tail[i], tail[i] + Vector3(0.0, 0.22, -0.16), 0.065, m.gold)
	_spike(creature, tail[-1], Vector3(1.05, 0.84, -1.80), 0.07, m.gold)
	_reveal_creature(creature)
	return creature

func _make_preyas(attribute: String) -> Node3D:
	var creature: Node3D = _creature_root("Preyas")
	var m: Dictionary = _creature_materials(attribute)
	var body: MeshInstance3D = _sphere(creature, 0.45, Vector3(0.0, 0.88, 0.0), m.armor)
	body.scale = Vector3(0.93, 1.27, 0.80)
	_sphere(creature, 0.30, Vector3(0.0, 0.86, 0.23), m.light, 12, 6).scale = Vector3(0.80, 1.16, 0.33)
	# Round chameleon eyes, webbed hands, head fin and curled aquatic tail.
	for side: int in [-1, 1]:
		var s: float = float(side)
		_capsule(creature, Vector3(s * 0.23, 0.55, 0.0), Vector3(s * 0.35, 0.17, 0.16), 0.13, m.dark)
		_armor_box(creature, Vector3(0.29, 0.15, 0.39), Vector3(s * 0.35, 0.10, 0.29), m.armor)
		var arm: Node3D = _joint(creature, Vector3(s * 0.38, 1.09, 0.0), Vector3(0.0, 0.0, s * 1.1))
		_capsule(arm, Vector3.ZERO, Vector3(s * 0.25, -0.22, 0.14), 0.115, m.dark)
		var palm: MeshInstance3D = _sphere(arm, 0.22, Vector3(s * 0.31, -0.38, 0.22), m.armor, 12, 6)
		palm.scale = Vector3(1.20, 0.85, 0.60)
		for finger: int in range(3):
			_capsule(arm, Vector3(s * 0.18 + float(finger) * s * 0.12, -0.39, 0.22), Vector3(s * 0.20 + float(finger) * s * 0.14, -0.63, 0.25), 0.06, m.light)
		_wing_mesh(arm, PackedVector3Array([Vector3(s * 0.15, -0.44, 0.23), Vector3(s * 0.48, -0.44, 0.23), Vector3(s * 0.48, -0.63, 0.25), Vector3(s * 0.20, -0.63, 0.25)]), m.light)
		_wing_mesh(creature, PackedVector3Array([Vector3(s * 0.29, 0.50, 0.0), Vector3(s * 0.61, 0.75, -0.11), Vector3(s * 0.31, 0.95, -0.10)]), m.light)
	var head: Node3D = _joint(creature, Vector3(0.0, 1.42, 0.11), Vector3(-0.8, 0.0, 0.0))
	_sphere(head, 0.31, Vector3(0.0, 0.13, 0.0), m.armor, 12, 6).scale = Vector3(1.13, 0.82, 1.0)
	_armor_box(head, Vector3(0.39, 0.05, 0.09), Vector3(0.0, 0.04, 0.29), m.dark)
	for side: int in [-1, 1]:
		var s: float = float(side)
		_sphere(head, 0.14, Vector3(s * 0.26, 0.22, 0.15), m.light, 12, 6)
		_sphere(head, 0.07, Vector3(s * 0.29, 0.24, 0.26), m.eye, 10, 5)
	_wing_mesh(head, PackedVector3Array([Vector3(0.0, 0.23, -0.25), Vector3(0.0, 0.68, -0.18), Vector3(0.0, 0.61, 0.08), Vector3(0.0, 0.36, 0.12)]), m.light)
	var tail: Array[Vector3] = [Vector3(0.0, 0.63, -0.20), Vector3(0.0, 0.37, -0.61), Vector3(0.22, 0.44, -0.91), Vector3(0.42, 0.67, -0.79), Vector3(0.29, 0.78, -0.61)]
	for i: int in range(tail.size() - 1):
		_capsule(creature, tail[i], tail[i + 1], 0.10 - float(i) * 0.014, m.armor)
	_reveal_creature(creature)
	return creature

func _make_gorem(attribute: String) -> Node3D:
	var creature: Node3D = _creature_root("Gorem")
	var m: Dictionary = _creature_materials(attribute)
	_armor_box(creature, Vector3(0.92, 0.74, 0.62), Vector3(0.0, 1.08, 0.0), m.armor)
	_armor_box(creature, Vector3(0.56, 0.22, 0.44), Vector3(0.0, 0.60, 0.0), m.dark)
	_armor_box(creature, Vector3(0.55, 0.36, 0.08), Vector3(0.0, 1.07, 0.35), m.gold)
	_armor_box(creature, Vector3(0.16, 0.35, 0.09), Vector3(0.0, 1.07, 0.41), m.dark)
	# Stacked stone limbs and massive shoulder armor, with no dragon wings/tail.
	for side: int in [-1, 1]:
		var s: float = float(side)
		_armor_box(creature, Vector3(0.32, 0.35, 0.38), Vector3(s * 0.27, 0.39, 0.0), m.armor)
		_sphere(creature, 0.12, Vector3(s * 0.27, 0.23, 0.0), m.joint, 8, 4)
		_armor_box(creature, Vector3(0.43, 0.22, 0.60), Vector3(s * 0.32, 0.12, 0.17), m.dark)
		_armor_box(creature, Vector3(0.45, 0.07, 0.63), Vector3(s * 0.32, 0.045, 0.17), m.gold)
		var arm: Node3D = _joint(creature, Vector3(s * 0.58, 1.35, 0.0), Vector3(0.0, 0.0, s * 0.95))
		_armor_box(arm, Vector3(0.47, 0.36, 0.58), Vector3(s * 0.08, 0.06, 0.0), m.dark)
		_armor_box(arm, Vector3(0.50, 0.12, 0.63), Vector3(s * 0.08, 0.29, 0.0), m.gold)
		_armor_box(arm, Vector3(0.28, 0.32, 0.29), Vector3(s * 0.12, -0.29, 0.04), m.armor)
		_sphere(arm, 0.11, Vector3(s * 0.12, -0.44, 0.05), m.joint, 8, 4)
		_armor_box(arm, Vector3(0.36, 0.37, 0.39), Vector3(s * 0.15, -0.62, 0.12), m.dark)
		for knuckle: int in range(3):
			_armor_box(arm, Vector3(0.08, 0.12, 0.05), Vector3(s * 0.15 + float(knuckle - 1) * 0.11, -0.66, 0.33), m.gold)
	var head: Node3D = _joint(creature, Vector3(0.0, 1.53, 0.0), Vector3(-0.65, 0.0, 0.0))
	_armor_box(head, Vector3(0.37, 0.30, 0.35), Vector3(0.0, 0.12, 0.0), m.dark)
	_armor_box(head, Vector3(0.42, 0.10, 0.42), Vector3(0.0, 0.31, 0.0), m.armor)
	_armor_box(head, Vector3(0.28, 0.055, 0.04), Vector3(0.0, 0.17, 0.20), m.eye)
	_armor_box(head, Vector3(0.16, 0.09, 0.08), Vector3(0.0, 0.04, 0.20), m.gold)
	_reveal_creature(creature)
	return creature

func make_pickup(at: Vector3, amount: int = 20) -> Node3D:
	var pickup: Node3D = Node3D.new()
	pickup.name = "GPowerPickup"
	pickup.position = at
	pickup.set_meta("amount", amount)
	add_child(pickup)
	var crystal: Node3D = Node3D.new()
	crystal.name = "Crystal"
	pickup.add_child(crystal)
	var blue: StandardMaterial3D = _material(CYAN, 0.3, 1.8)
	var gold: StandardMaterial3D = _material(ORANGE.lightened(0.3), 0.5, 1.2)
	_spike(crystal, Vector3(0.0, 0.34, 0.0), Vector3(0.0, 0.82, 0.0), 0.20, blue)
	_spike(crystal, Vector3(0.0, 0.34, 0.0), Vector3(0.0, 0.12, 0.0), 0.20, blue)
	_torus(crystal, 0.26, 0.30, Vector3(0.0, 0.34, 0.0), gold)
	var label: Label3D = Label3D.new()
	label.text = "+%d G" % amount
	label.font_size = 44
	label.pixel_size = 0.007
	label.position = Vector3(0.0, 1.0, 0.0)
	label.modulate = Color("b8efff")
	label.outline_modulate = Color("102443")
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	pickup.add_child(label)
	# Bound to the pickup: collection stops both finite animation tracks safely.
	if not reduced_motion:
		var turn: Tween = pickup.create_tween()
		turn.tween_property(crystal, "rotation:y", TAU * 24.0, 48.0)
		_watch_visual(turn, crystal, {"rotation:y": 0.0})
		var pulse: Tween = pickup.create_tween().set_loops(48)
		pulse.tween_property(crystal, "scale", Vector3.ONE * 1.12, 0.5).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(crystal, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_SINE)
		_watch_visual(pulse, crystal, {"scale": Vector3.ONE})
	return pickup

func landing_flash(at: Vector3, color: Color) -> void:
	if reduced_motion:
		return
	var effect: Node3D = Node3D.new()
	effect.position = at + Vector3(0.0, 0.13, 0.0)
	add_child(effect)
	var ring: MeshInstance3D = _torus(effect, 0.46, 0.50, Vector3.ZERO, _material(color, 0.0, 2.0))
	var rays: Node3D = Node3D.new()
	effect.add_child(rays)
	for index: int in range(12):
		var angle: float = float(index) * TAU / 12.0
		var ray: MeshInstance3D = _box(rays, Vector3(0.045, 0.055, 0.31), Vector3(cos(angle) * 0.75, 0.0, sin(angle) * 0.75), _material(color, 0.0, 1.5))
		ray.rotation.y = PI / 2.0 - angle
	var flash: Tween = effect.create_tween()
	flash.set_parallel(true)
	flash.tween_property(ring, "scale", Vector3(3.1, 0.1, 3.1), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flash.tween_property(rays, "scale", Vector3(1.5, 0.02, 1.5), 0.32)
	_watch_visual(flash, ring, {"scale": Vector3(3.1, 0.1, 3.1)})
	_watch_visual(flash, rays, {"scale": Vector3(1.5, 0.02, 1.5)})
	var lifetime: Tween = effect.create_tween()
	lifetime.tween_interval(0.5)
	lifetime.tween_callback(effect.queue_free)

func _attribute_color(attribute: String) -> Color:
	match attribute.to_lower():
		"pyrus", "пирус": return Color("c9432e")
		"aquos", "аквос": return Color("297bce")
		"ventus", "вентус": return Color("36a37a")
		"haos", "хаос": return Color("e2d7aa")
		"darkus", "даркус": return Color("7151ba")
		"subterra", "сабтерра": return Color("b78346")
		_: return Color("c9432e")

func _material(color: Color, metallic: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	var key: String = "%s/%s/%s" % [color.to_html(), str(metallic), str(emission)]
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.46
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[key] = material
	return material

func _box(parent: Node3D, size3: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size3
	return _mesh(parent, mesh, at, material)

func _armor_box(parent: Node3D, size3: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	# Cached chamfered armor retains the exact original box extents. The bevel
	# catches light on toy panels without adding nodes or altering their pivots.
	var key: String = str(size3)
	var instance: MeshInstance3D
	if _armor_meshes.has(key):
		instance = _mesh(parent, _armor_meshes[key], at, material)
	else:
		var half: Vector3 = size3 * 0.5
		var bevel: float = minf(size3.x, minf(size3.y, size3.z)) * 0.12
		var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
		var vertices: PackedVector3Array = PackedVector3Array()
		# Six broad faces, twelve sloped edge faces and eight corner caps.
		for axis: int in range(3):
			var first: int = (axis + 1) % 3
			var second: int = (axis + 2) % 3
			var u: Vector3 = axes[first] * (half[first] - bevel)
			var v: Vector3 = axes[second] * (half[second] - bevel)
			for side: int in [-1, 1]:
				var center: Vector3 = axes[axis] * half[axis] * float(side)
				_append_armor_face(vertices, [center - u - v, center + u - v, center + u + v, center - u + v])
			for sign_a: int in [-1, 1]:
				for sign_b: int in [-1, 1]:
					var outer_a: Vector3 = axes[first] * half[first] * float(sign_a) + axes[second] * (half[second] - bevel) * float(sign_b)
					var outer_b: Vector3 = axes[first] * (half[first] - bevel) * float(sign_a) + axes[second] * half[second] * float(sign_b)
					var along: Vector3 = axes[axis] * (half[axis] - bevel)
					_append_armor_face(vertices, [outer_a - along, outer_a + along, outer_b + along, outer_b - along])
		for sx: int in [-1, 1]:
			for sy: int in [-1, 1]:
				for sz: int in [-1, 1]:
					_append_armor_face(vertices, [
						Vector3(half.x * sx, (half.y - bevel) * sy, (half.z - bevel) * sz),
						Vector3((half.x - bevel) * sx, half.y * sy, (half.z - bevel) * sz),
						Vector3((half.x - bevel) * sx, (half.y - bevel) * sy, half.z * sz),
					])
		instance = _triangle_mesh(parent, vertices, at, material)
		_armor_meshes[key] = instance.mesh
	instance.set_meta("armor_part", true)
	return instance

func _append_armor_face(vertices: PackedVector3Array, points: Array[Vector3]) -> void:
	for index: int in range(1, points.size() - 1):
		var first: Vector3 = points[0]
		var second: Vector3 = points[index]
		var third: Vector3 = points[index + 1]
		var normal: Vector3 = (second - first).cross(third - first)
		if normal.dot((first + second + third) / 3.0) < 0.0:
			vertices.append_array(PackedVector3Array([first, third, second]))
		else:
			vertices.append_array(PackedVector3Array([first, second, third]))

func _beveled_slab(parent: Node3D, size2: Vector2, height: float, at: Vector3, material: Material, bevel: float = 0.4) -> MeshInstance3D:
	var hx: float = size2.x * 0.5
	var hz: float = size2.y * 0.5
	var b: float = minf(bevel, minf(hx, hz) * 0.8)
	var outline: Array[Vector2] = [
		Vector2(-hx + b, -hz), Vector2(hx - b, -hz),
		Vector2(hx, -hz + b), Vector2(hx, hz - b),
		Vector2(hx - b, hz), Vector2(-hx + b, hz),
		Vector2(-hx, hz - b), Vector2(-hx, -hz + b),
	]
	var vertices: PackedVector3Array = PackedVector3Array()
	for index: int in range(outline.size()):
		var next: int = (index + 1) % outline.size()
		var top_a: Vector3 = Vector3(outline[index].x, height * 0.5, outline[index].y)
		var top_b: Vector3 = Vector3(outline[next].x, height * 0.5, outline[next].y)
		var low_a: Vector3 = top_a - Vector3.UP * height
		var low_b: Vector3 = top_b - Vector3.UP * height
		vertices.append_array(PackedVector3Array([
			Vector3(0.0, height * 0.5, 0.0), top_b, top_a,
			Vector3(0.0, -height * 0.5, 0.0), low_a, low_b,
			top_a, top_b, low_b, top_a, low_b, low_a,
		]))
	return _triangle_mesh(parent, vertices, at, material)

func _faceted_rock(parent: Node3D, at: Vector3, radius: float, height: float, color: Color, seed: int, sides: int = 7) -> MeshInstance3D:
	var rings: Array[PackedVector3Array] = []
	for level: int in range(3):
		var ring: PackedVector3Array = PackedVector3Array()
		for side: int in range(sides):
			var angle: float = float(side) * TAU / float(sides) + float(seed) * 0.11
			var variation: float = 0.86 + float(posmod(side * 3 + seed, 5)) * 0.065
			var r: float = radius * variation * [1.0, 0.68, 0.08][level]
			var y: float = height * [0.0, 0.55, 1.0][level]
			if level > 0:
				y *= 0.86 + float(posmod(side + seed, 4)) * 0.055
			ring.append(Vector3(cos(angle) * r, y, sin(angle) * r))
		rings.append(ring)
	var vertices: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	for level: int in range(2):
		for side: int in range(sides):
			var next: int = (side + 1) % sides
			vertices.append_array(PackedVector3Array([
				rings[level][side], rings[level + 1][side], rings[level + 1][next],
				rings[level][side], rings[level + 1][next], rings[level][next],
			]))
			var low: Color = color.darkened(0.36 if level == 0 else 0.04)
			var high: Color = color.lightened(0.04 if level == 0 else 0.3)
			colors.append_array(PackedColorArray([low, high, high, low, high, low]))
	for side: int in range(sides):
		var next: int = (side + 1) % sides
		vertices.append_array(PackedVector3Array([Vector3(0.0, height * 0.93, 0.0), rings[2][next], rings[2][side]]))
		colors.append_array(PackedColorArray([color.lightened(0.35), color.lightened(0.3), color.lightened(0.3)]))
	var gradient: StandardMaterial3D
	if _materials.has("arena_gradient"):
		gradient = _materials["arena_gradient"] as StandardMaterial3D
	else:
		gradient = StandardMaterial3D.new()
		gradient.vertex_color_use_as_albedo = true
		gradient.roughness = 0.76
		gradient.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials["arena_gradient"] = gradient
	return _triangle_mesh(parent, vertices, at, gradient, colors)

func _triangle_mesh(parent: Node3D, vertices: PackedVector3Array, at: Vector3, material: Material, colors: PackedColorArray = PackedColorArray()) -> MeshInstance3D:
	var normals: PackedVector3Array = PackedVector3Array()
	for index: int in range(0, vertices.size(), 3):
		var normal: Vector3 = (vertices[index + 1] - vertices[index]).cross(vertices[index + 2] - vertices[index]).normalized()
		normals.append_array(PackedVector3Array([normal, normal, normal]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	if not colors.is_empty():
		arrays[Mesh.ARRAY_COLOR] = colors
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _mesh(parent, mesh, at, material)

func _sphere(parent: Node3D, radius: float, at: Vector3, material: Material, segments: int = 16, rings: int = 8) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	return _mesh(parent, mesh, at, material)

func _cylinder(parent: Node3D, radius: float, height: float, at: Vector3, material: Material, segments: int = 24) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	return _mesh(parent, mesh, at, material)

func _torus(parent: Node3D, inner_radius: float, outer_radius: float, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 32
	mesh.ring_segments = 8
	return _mesh(parent, mesh, at, material)

func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _rect_outline(parent: Node3D, at: Vector3, size2: Vector2, width: float, material: Material) -> void:
	for side: int in [-1, 1]:
		_box(parent, Vector3(size2.x, 0.012, width), at + Vector3(0.0, 0.0, float(side) * size2.y * 0.5), material)
		_box(parent, Vector3(width, 0.012, size2.y), at + Vector3(float(side) * size2.x * 0.5, 0.0, 0.0), material)

func _flat_label(parent: Node3D, value: String, at: Vector3, font_size: int, pixel_size: float, color: Color) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = value
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_modulate = Color("09101d")
	label.outline_size = 5
	label.position = at
	label.rotation.x = -PI / 2.0
	label.shaded = false
	label.double_sided = true
	parent.add_child(label)
	return label

func _axis_basis(direction: Vector3) -> Basis:
	var y_axis: Vector3 = direction.normalized()
	var x_axis: Vector3 = y_axis.cross(Vector3.FORWARD)
	if x_axis.length_squared() < 0.01:
		x_axis = y_axis.cross(Vector3.RIGHT)
	x_axis = x_axis.normalized()
	return Basis(x_axis, y_axis, x_axis.cross(y_axis).normalized())

func _capsule(parent: Node3D, start: Vector3, end: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = start.distance_to(end) + radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 3
	var instance: MeshInstance3D = _mesh(parent, mesh, (start + end) * 0.5, material)
	instance.basis = _axis_basis(end - start)
	return instance

func _spike(parent: Node3D, start: Vector3, end: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = start.distance_to(end)
	mesh.radial_segments = 10
	var instance: MeshInstance3D = _mesh(parent, mesh, (start + end) * 0.5, material)
	instance.basis = _axis_basis(end - start)
	return instance

func _wing_mesh(parent: Node3D, points: PackedVector3Array, material: Material) -> MeshInstance3D:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	for index: int in range(1, points.size() - 1):
		var normal: Vector3 = (points[index] - points[0]).cross(points[index + 1] - points[0]).normalized()
		for point: Vector3 in [points[0], points[index], points[index + 1]]:
			vertices.append(point)
			normals.append(normal)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance: MeshInstance3D = _mesh(parent, mesh, Vector3.ZERO, material)
	instance.set_meta("membrane", true)
	return instance
