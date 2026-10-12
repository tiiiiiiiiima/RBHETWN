extends SceneTree
const Arena = preload("res://scripts/arena.gd")
const Field = preload("res://scripts/source_sfm_field.gd")
const Presentation = preload("res://scripts/ds_battle_presentation.gd")
const Sphere = preload("res://scripts/ds_sphere_motion.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var data: Dictionary = Field.manifest()
	_check(int(data.availability.arenas) == 1 and int(data.availability.cards) == 0 and int(data.availability.bakugan_models) == 0, "SFM donor inventory is a field, not the unrelated Monster batch set")
	var arena: Node3D = Arena.new()
	root.add_child(arena)
	arena.setup()
	await process_frame
	var gate: Node3D = arena.make_gate(2, 0, "Test")
	var gate_transform: Transform3D = gate.transform
	var camera_id: int = arena.camera.get_instance_id()
	arena.set_theme(Field.ID)
	await process_frame
	_check(arena.environment_root.get_meta("source_origin", "") == "source_sfm_workshop", "Source field is actually instantiated")
	_check(arena.camera.get_instance_id() == camera_id and gate.position.x == gate_transform.origin.x and gate.position.z == gate_transform.origin.z and gate.is_inside_tree(), "Arena switch retains the gameplay camera and gate slots while adapting floor height")
	var sphere: RefCounted = Sphere.new()
	sphere.launch(Vector3(0.0, 0.5, 5.0), Vector3(0.0, 0.0, -5.0), 0.5, "straight")
	for frame: int in 20:
		sphere.step(1.0 / 60.0, arena)
	_check(sphere.position.is_finite() and sphere.position.z < 5.0, "A DS-profile sphere advances on the new field without typed-response errors")
	var meshes: Array[Node] = arena.environment_root.find_children("*", "MeshInstance3D", true, false)
	_check(meshes.size() == 9, "All nine native material sections are visible geometry")
	for node: MeshInstance3D in meshes:
		_check(node.mesh != null and node.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV] != null, "Native UV mesh exists: " + str(node.name))
		var material: StandardMaterial3D = node.get_active_material(0) as StandardMaterial3D
		_check(material != null and material.albedo_texture != null, "Native texture is present: " + str(node.name))
		_check(node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Outer source shell does not shadow the entire play area")
	for index: int in 4:
		if index > 0:
			arena.rotate_view(1)
		var eye: Vector3 = arena.camera.position
		_check(absf(eye.x) < 27.0 and absf(eye.z) < 27.0 and eye.y < 24.0, "Gameplay camera remains inside the opaque source enclosure")
	arena.set_theme("ds_pyrus")
	await process_frame
	_check(arena.environment_root.get_meta("source_origin", "") != "source_sfm_workshop", "Switching back releases the new field")
	var view: Control = Presentation.new()
	root.add_child(view)
	view.configure(Field.ID, true)
	_check(view._stage != null and view._stage.get_meta("source_origin", "") == "source_sfm_workshop", "Separate card battle uses the same field")
	view.configure("ds_pyrus", true)
	_check(view._stage.get_meta("source_origin", "") != "source_sfm_workshop", "Separate battle can return to the native DS field")
	view.queue_free()
	arena.queue_free()
	await process_frame
	print("SFM FIELD 0.17.2: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
