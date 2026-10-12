extends SceneTree
const Avatar = preload("res://scripts/avatar_view.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var layer := Control.new()
	root.add_child(layer)
	var background := ColorRect.new()
	background.color = Color("161d30")
	background.size = Vector2(1440,900)
	layer.add_child(background)
	var index: int = 0
	for id: String in Avatar.entries():
		var view := Avatar.new()
		view.position = Vector2(20+(index%6)*238,10+floori(float(index)/6)*295)
		view.size = Vector2(218,252)
		layer.add_child(view)
		view.show_avatar(id)
		var label := Label.new()
		label.position = view.position+Vector2(45,250)
		label.text = id
		label.add_theme_font_size_override("font_size",20)
		layer.add_child(label)
		index+=1
	await create_timer(1.0).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/qa-0.21/visual/avatars-grid.png")
	quit()
