extends SceneTree
const Catalog = preload("res://scripts/monster_batch_catalog.gd")
const Models = preload("res://scripts/model_library.gd")
var output: String = "/workspace/bakugan-pc/builds/qa-0.17.2/models"
var ability_pose: bool = false

func _initialize() -> void:
	ability_pose = OS.get_cmdline_user_args().has("--ability")
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 800)
	var entries: Array = Catalog.manifest().species
	for form: String in ["battle", "ball", "toy"]:
		if ability_pose and form != "battle":
			continue
		var cases: Array[Dictionary] = []
		for entry: Dictionary in entries:
			if entry.forms.has(form):
				cases.append(entry)
		for page: int in ceili(float(cases.size()) / 12.0):
			var panel: Control = Control.new()
			root.add_child(panel)
			for index: int in mini(12, cases.size() - page * 12):
				var entry: Dictionary = cases[page * 12 + index]
				var cell: SubViewportContainer = SubViewportContainer.new()
				cell.position = Vector2(index % 4 * 320, index / 4 * 264)
				cell.size = Vector2(320, 238)
				panel.add_child(cell)
				var view: SubViewport = SubViewport.new()
				view.size = Vector2i(320, 238)
				view.own_world_3d = true
				cell.add_child(view)
				var world: Node3D = Node3D.new()
				view.add_child(world)
				var env: WorldEnvironment = WorldEnvironment.new()
				env.environment = Environment.new()
				env.environment.background_mode = Environment.BG_COLOR
				env.environment.background_color = Color("172039")
				env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
				env.environment.ambient_light_energy = 0.85
				world.add_child(env)
				var light: DirectionalLight3D = DirectionalLight3D.new()
				light.rotation_degrees = Vector3(-35, -35, 0)
				world.add_child(light)
				var model: Node3D = Models.make_ball(world, str(entry.forms[form].native_attribute), 0, false, str(entry.name)) if form == "ball" else Models.make_creature(world, str(entry.name), str(entry.forms[form].native_attribute), true, form)
				assert(model != null)
				if ability_pose and Models.play_battle_animation(model, "attack"):
					var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
					var clip: String = player.current_animation
					player.seek(player.get_animation(clip).length * 0.5, true)
					player.pause()
				var floor_mesh: MeshInstance3D = MeshInstance3D.new()
				var plane: PlaneMesh = PlaneMesh.new()
				plane.size = Vector2(8, 8)
				floor_mesh.mesh = plane
				var material: StandardMaterial3D = StandardMaterial3D.new()
				material.albedo_color = Color("293248")
				floor_mesh.material_override = material
				if form == "ball":
					floor_mesh.position.y = -0.39
				world.add_child(floor_mesh)
				var camera: Camera3D = Camera3D.new()
				camera.fov = 37.0
				world.add_child(camera)
				camera.look_at_from_position(Vector3(1.4, 1.1, 1.5) if form == "ball" else Vector3(4.0, 2.7, 5.3), Vector3.ZERO if form == "ball" else Vector3(0, 1, 0))
				var label: Label = Label.new()
				label.position = cell.position + Vector2(5, 240)
				label.text = str(entry.name) + " · " + form
				panel.add_child(label)
			for frame: int in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(output.path_join(("ability" if ability_pose else form)+"-%d.png" % page)) == OK)
			panel.queue_free()
			await process_frame
	quit()
