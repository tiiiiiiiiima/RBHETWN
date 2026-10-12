extends SceneTree
## Actual GL field/collision capture. Requires a real display/compatibility GL.
## godot --path . --script tools/capture_ds_fields11.gd -- /tmp/ds-fields11
const Arena = preload("res://scripts/arena.gd")
const Catalog = preload("res://scripts/ds_arena_catalog.gd")
const RollMotion = preload("res://scripts/roll_motion.gd")
var output_directory: String = "/tmp/ds-fields11"
var records: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		output_directory = args[0]
	DirAccess.make_dir_recursive_absolute(output_directory)
	root.size = Vector2i(1440,900)
	var field: Node3D = Arena.new()
	root.add_child(field)
	field.setup()
	field.set_reduced_motion(true)
	for id: String in Catalog.PLAYABLE_FIELDS:
		field.set_theme(id)
		assert(field.environment_root.get_meta("ds_group_id") == Catalog.stage_id_for(id) + "_throw")
		assert(field.field_surface != null)
		field.make_gate(5,0,"Gate Power",true,"gold")
		field.make_gate(10,1,"Character",false,"silver")
		var ball: Node3D = field.make_ball("Pyrus",0,"Dragonoid")
		ball.position = field.ground_point(Vector3(0,0,4.5))
		var line := ImmediateMesh.new()
		line.surface_begin(Mesh.PRIMITIVE_LINES)
		var roll: RefCounted = RollMotion.new()
		field.configure_roll(roll)
		roll.begin(Vector3(4.2,0,2.8) if id == "ds_pyrus" else Vector3(0,0,4.5), Vector3(5.1,0,4.9) if id == "ds_pyrus" else Vector3(1.0,0,-4.0), 4.0, 2.5)
		for sample: int in 150:
			roll.step(1.0 / 60.0)
			for segment: Dictionary in roll.travel_segments:
				line.surface_add_vertex(segment.from + Vector3(0,0.05,0))
				line.surface_add_vertex(segment.to + Vector3(0,0.05,0))
		line.surface_end()
		var trace := MeshInstance3D.new()
		trace.mesh = line
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("ffcc33")
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		trace.material_override = material
		field.add_child(trace)
		await process_frame
		await RenderingServer.frame_post_draw
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		assert(image != null and not image.is_empty())
		var file_name: String = output_directory.path_join(id + ".png")
		assert(image.save_png(file_name) == OK)
		records.append({"theme":id,"throw_group":field.environment_root.get_meta("ds_group_id"),"collision_profile":field.field_surface.group_id,"collision_count":roll.collision_count,"image":file_name,"floor_supported":is_finite(field.field_surface.surface_height(roll.position)),"far":field.camera.far})
		ball.queue_free()
		trace.queue_free()
		field.remove_gate(5)
		field.remove_gate(10)
		await process_frame
	var report: FileAccess = FileAccess.open(output_directory.path_join("fields-gl.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify(records,"\t"))
	print("DS field GL captures: ",records.size()," -> ",output_directory)
	quit()
