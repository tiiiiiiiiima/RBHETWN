extends SubViewportContainer
## Human avatars are accepted only with original imported joint animation.
const Models = preload("res://scripts/model_library.gd")
const MANIFEST = "res://assets/ds/avatars/manifest.json"
var viewport: SubViewport
var world: Node3D
var actor: Node3D
var player: AnimationPlayer
var avatar_id: String = ""
var animation_name: String = ""
var requested_id: String = ""
var explicitly_suspended: bool = false
static var _entries: Dictionary = {}

static func entries() -> Dictionary:
	if not _entries.is_empty(): return _entries
	if not FileAccess.file_exists(MANIFEST): return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	_entries=data.get("avatars",{}) if data is Dictionary else {}
	return _entries

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	viewport = SubViewport.new()
	viewport.size = Vector2i(256,256)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0,0,0,0)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.75
	env.environment = settings
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-25,0)
	light.light_energy = 1.0
	world.add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(0,1.35,4.0)
	world.add_child(camera)
	camera.look_at(Vector3(0,1.1,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.65
	camera.current = true

func show_avatar(id: String) -> bool:
	if avatar_id==id and is_instance_valid(actor): return true
	var entry: Dictionary = entries().get(id,{})
	if int(entry.get("animation_count",0))<=0: return false
	var path: String = str(entry.get("path",""))
	if not ResourceLoader.exists(path): return false
	requested_id=id
	if not is_visible_in_tree(): return true
	var packed: PackedScene = load(path) as PackedScene
	if packed==null: return false
	var next: Node3D = packed.instantiate() as Node3D
	var animator: AnimationPlayer = next.find_child("*",true,false) as AnimationPlayer
	for child: Node in next.find_children("*","AnimationPlayer",true,false):
		animator = child as AnimationPlayer
		break
	if animator==null:
		next.free()
		return false
	var clip: String = ""
	for name_value: StringName in animator.get_animation_list():
		if str(name_value)!="RESET" and animator.get_animation(name_value).length>0.0:
			clip = str(name_value)
			break
	if clip.is_empty():
		next.free()
		return false
	if is_instance_valid(actor):
		world.remove_child(actor)
		actor.queue_free()
	actor = next
	world.add_child(actor)
	var box: AABB = Models.visual_bounds(actor)
	var factor: float = 2.15/maxf(box.size.y,0.001)
	actor.scale = Vector3.ONE*factor
	actor.position = -Vector3(box.get_center().x,box.position.y,box.get_center().z)*factor
	player = animator
	# Duplicate the clip before changing looping; shared imports remain untouched.
	var source: Animation = player.get_animation(clip).duplicate()
	source.loop_mode = Animation.LOOP_LINEAR
	var library := AnimationLibrary.new()
	library.add_animation("portrait",source)
	player.add_animation_library("portrait",library)
	player.play("portrait/portrait")
	avatar_id = id
	animation_name = clip
	return true

func set_suspended(value: bool) -> void:
	explicitly_suspended=value
	_sync_activity()

func _process(_delta: float) -> void:
	if is_visible_in_tree() and requested_id!=avatar_id: show_avatar(requested_id)
	_sync_activity()

func _sync_activity() -> void:
	if viewport==null: return
	var stopped: bool=explicitly_suspended or not is_visible_in_tree()
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED if stopped else SubViewport.UPDATE_WHEN_VISIBLE
	if is_instance_valid(actor): actor.process_mode=Node.PROCESS_MODE_DISABLED if stopped else Node.PROCESS_MODE_INHERIT
	if is_instance_valid(player): player.speed_scale=0.0 if stopped else 1.0
