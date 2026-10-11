extends SceneTree
func _initialize() -> void:
	root.size=Vector2i(640,360)
	root.show()
	call_deferred("run")
func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	var sphere:=MeshInstance3D.new(); sphere.mesh=SphereMesh.new(); world.add_child(sphere)
	var light:=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-45,-30,0); world.add_child(light)
	var camera:=Camera3D.new(); camera.position=Vector3(0,1,4); world.add_child(camera); camera.look_at(Vector3.ZERO)
	print("SMOKE ADAPTER ",RenderingServer.get_video_adapter_name()," · ",RenderingServer.get_current_rendering_method())
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	var report_dir: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report-dir="): report_dir=arg.trim_prefix("--report-dir=")
	var code: int=image.save_png(report_dir.path_join("renderer.png"))
	FileAccess.open(report_dir.path_join("renderer.json"),FileAccess.WRITE).store_string(JSON.stringify({"os":OS.get_name(),"adapter":RenderingServer.get_video_adapter_name(),"method":RenderingServer.get_current_rendering_method(),"image_saved":code==OK}))
	quit(0 if code==OK else 1)
