extends SceneTree
const Arena = preload("res://scripts/arena.gd")
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
func _run() -> void:
	var arena: Node3D = Arena.new()
	root.add_child(arena)
	arena.setup()
	var model: Node3D = arena.make_creature("Mantris", "Darkus", "toy")
	var video: VideoStreamPlayer = model.get_node_or_null("TextureVideo") as VideoStreamPlayer
	_check(video != null, "Darkus Mantris has its actual animated skin")
	if video == null:
		quit(1)
		return
	await create_timer(0.3).timeout
	_check(video.is_playing() and video._bound, "Decoded texture video is playing and bound to the model")
	var first: PackedByteArray = video.get_video_texture().get_image().get_data()
	await create_timer(0.75).timeout
	var second: PackedByteArray = video.get_video_texture().get_image().get_data()
	_check(first != second, "Donor texture actually changes rather than remaining on its first frame")
	arena.set_reduced_motion(true)
	_check(video.paused, "Reduced motion pauses the native skin")
	var time_before: float = video.stream_position
	await create_timer(0.2).timeout
	_check(is_equal_approx(time_before, video.stream_position), "Reduced motion freezes video time")
	arena.set_reduced_motion(false)
	_check(not video.paused, "Restoring motion resumes the skin")
	paused = true
	await create_timer(0.08, true).timeout
	time_before = video.stream_position
	await create_timer(0.2, true).timeout
	_check(is_equal_approx(time_before, video.stream_position), "Game pause freezes texture playback")
	paused = false
	arena.queue_free()
	await process_frame
	print("TEXTURE VIDEO 0.17.2: 7 checks, %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
