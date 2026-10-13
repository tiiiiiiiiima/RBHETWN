extends Node3D
## Decoded SetData positions; desktop interactions, no original game code.
const PATH: String = "res://assets/ds/field_objects/manifest.json"
const Catalog = preload("res://scripts/ds_arena_catalog.gd")
const MaterialMotion = preload("res://scripts/ds_material_motion.gd")
static var _manifest: Dictionary = {}
static var _scenes: Dictionary = {}
var items: Array[Dictionary] = []
var players: Array[Dictionary] = []
var material_motion = MaterialMotion.new()
var layout_id: String = ""
var clock: float = 0.0

static func manifest() -> Dictionary:
	if _manifest.is_empty() and FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_manifest = parsed
	return _manifest

static func layouts(theme: String) -> Array:
	return manifest().get("fields", {}).get(theme, [])

func configure(theme: String, variant: int) -> void:
	var available: Array = layouts(theme)
	if available.is_empty():
		return
	layout_id = str(available[clampi(variant,0,available.size()-1)])
	var entry: Dictionary = Catalog.manifest().get("groups",{}).get(theme.trim_prefix("ds_")+"_throw",{})
	var fit: Dictionary = entry.get("pc_fit",{})
	scale = Vector3.ONE*float(fit.get("uniform_scale",1.0))
	var offset: Array = fit.get("source_offset",[0,0,0])
	position = Vector3(float(offset[0]),float(offset[1]),float(offset[2]))*scale.x
	set_meta("native_placement_set",layout_id)
	set_meta("placement_source",manifest().sets[layout_id].source_path)
	for record: Dictionary in manifest().sets[layout_id].records:
		var kind: String = str(record.kind)
		var object: Dictionary = manifest().objects.get(kind,{})
		if kind=="breakable":
			var field_index: int=["toy","pyrus","aquos","subterra","haos","darkus","ventus","anime"].find(theme.trim_prefix("ds_"))
			object=manifest().objects.get("breakable_%d" % field_index,object)
		if object.is_empty():
			continue
		var path: String = str(object.path)
		if not _scenes.has(path):
			_scenes[path] = load(path) as PackedScene
		var packed: PackedScene = _scenes[path] as PackedScene
		if packed == null:
			continue
		var holder := Node3D.new()
		holder.name = "FieldItem%d" % int(record.index)
		var p: Array = record.position
		holder.position = Vector3(float(p[0]),float(p[1]),float(p[2]))
		var angles: Array = record.rotation_u16
		holder.basis = Basis(Vector3.BACK,float(angles[2])*TAU/65536.0)*Basis(Vector3.UP,float(angles[1])*TAU/65536.0)*Basis(Vector3.RIGHT,float(angles[0])*TAU/65536.0)
		add_child(holder)
		var scene: Node3D = packed.instantiate()
		holder.add_child(scene)
		Catalog._prepare(scene,false)
		holder.set_meta("kind",kind)
		holder.set_meta("source_object",object.id)
		holder.set_meta("source_record",record.index)
		if kind in ["g_power","s_power","s_power_small","experience","field_card"]:
			for mesh: MeshInstance3D in scene.find_children("*","MeshInstance3D",true,false):
				for surface: int in mesh.mesh.get_surface_count():
					var material: StandardMaterial3D = mesh.get_active_material(surface) as StandardMaterial3D
					if material != null:
						material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
						material.billboard_keep_scale = true
		for player: AnimationPlayer in scene.find_children("*","AnimationPlayer",true,false):
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			for clip: String in player.get_animation_list():
				if clip != "RESET" and player.get_animation(clip).length>0:
					player.play(clip)
					players.append({"player":player,"length":player.get_animation(clip).length})
					break
		material_motion.bind_component(scene,object.get("srt",{}))
		var extent: Array = record.extent
		if kind=="lava_pool":
			var ring:=MeshInstance3D.new(); var shape:=TorusMesh.new()
			shape.inner_radius=float(extent[0])*0.93; shape.outer_radius=float(extent[0])
			shape.rings=24; shape.ring_segments=8; ring.mesh=shape
			var glow:=StandardMaterial3D.new(); glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			glow.albedo_color=Color("ffbd50"); ring.material_override=glow
			ring.position.y=0.7; ring.set_meta("hazard_ring",true); holder.add_child(ring)
		items.append({"id":int(record.index),"kind":kind,"node":holder,
			"extent":Vector3(float(extent[0]),float(extent[1]),float(extent[2])),"collected":false})
	advance(0.0)

func advance(time: float) -> void:
	clock=time
	for item: Dictionary in items:
		if item.kind!="lava_pool": continue
		var status: String=hazard_status(item)
		for child: Node in item.node.get_children():
			if child is MeshInstance3D and child.has_meta("hazard_ring"):
				child.visible=status!="safe"
				child.material_override.albedo_color=Color("ff4e24") if status=="active" else Color("ffce63")
	material_motion.advance(clock)
	for item: Dictionary in players:
		item.player.seek(fposmod(clock,float(item.length)),true,true)

func reset_match() -> void:
	for item: Dictionary in items:
		item.collected = false
		item.node.visible = true
	advance(0.0)

func available_pickups() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Dictionary in items:
		if item.kind in ["g_power","s_power","s_power_small","experience","field_card"] and not item.collected:
			result.append({"id":item.id,"kind":item.kind,"position":item.node.global_position,
				"radius":item.extent.length()/sqrt(3.0)*scale.x+0.44,
				"node":item.node,"native":true,"collected":false})
	return result

func collect(id: int) -> void:
	for item: Dictionary in items:
		if int(item.id)==id and item.kind in ["g_power","s_power","s_power_small","experience","field_card","breakable"]:
			item.collected = true
			item.node.visible = false
			return

func hazard_status(item: Dictionary, query_clock: float=-1.0) -> String:
	# Cycle/phase offsets are documented desktop tuning, not decoded DS timers.
	var phase: float=fposmod((clock if query_clock<0.0 else query_clock)+float(item.id)*0.17,4.0)
	return "warning" if phase<0.9 else "active" if phase<2.4 else "safe"

func response(from: Vector3, to: Vector3, query_clock: float=-1.0) -> Array[Dictionary]:
	# Query only: previews must not collect items or animate/consume live pads.
	var result: Array[Dictionary] = []
	for item: Dictionary in items:
		if item.collected or item.kind not in ["speed_pad","trampoline","lava_pool","breakable","water_jet","energy_orb","wind_jet"]:
			continue
		if item.kind=="lava_pool" and hazard_status(item,query_clock)!="active": continue
		if item.kind=="energy_orb" and fposmod(clock+float(item.id)*0.31,3.0)<1.8: continue
		if item.kind=="water_jet" and fposmod(clock+float(item.id)*0.19,2.4)>1.1: continue
		var transform: Transform3D = item.node.global_transform
		var inverse: Transform3D = transform.affine_inverse()
		var a: Vector3 = inverse*from
		var b: Vector3 = inverse*to
		var radius: float = 0.44/scale.x
		var extent: Vector3 = item.extent
		# Original XY-plane markers are ground-facing XZ meshes. Restrict the
		# activation height to the visible pad, so passing high overhead misses.
		var box: Vector3 = Vector3(extent.x+radius,(minf(extent.y,2.0) if item.kind in ["speed_pad","trampoline","lava_pool"] else extent.y)+radius,extent.z+radius)
		var delta: Vector3 = b-a
		var low: float = 0.0
		var high: float = 1.0
		var intersects: bool = true
		for axis: int in 3:
			if absf(delta[axis])<0.000001:
				if absf(a[axis])>box[axis]:
					intersects = false
			else:
				var t0: float = (-box[axis]-a[axis])/delta[axis]
				var t1: float = (box[axis]-a[axis])/delta[axis]
				low = maxf(low,minf(t0,t1))
				high = minf(high,maxf(t0,t1))
		if intersects and low<=high and a.lerp(b,low).y>=-radius*0.25:
			result.append({"id":item.id,"kind":"lava" if item.kind=="lava_pool" else item.kind,"fraction":low,
				"normal":transform.basis.y.normalized(),"direction":-transform.basis.z.normalized(),"center":item.node.global_position,"damage":30 if item.kind=="lava_pool" else 25 if item.kind=="energy_orb" else 0})
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.fraction)<float(b.fraction))
	return result
