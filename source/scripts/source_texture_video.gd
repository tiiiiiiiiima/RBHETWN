extends VideoStreamPlayer
## A donor MP4 skin, converted to Theora; this is texture motion, not a rig.
var target_materials: Array = []
var _bound: bool = false

func _ready() -> void:
	audio_track = -1
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	finished.connect(play)
	play()

func _process(_delta: float) -> void:
	if _bound:
		return
	var texture: Texture2D = get_video_texture()
	if texture == null or texture.get_width() <= 0:
		return
	for material: StandardMaterial3D in target_materials:
		material.albedo_texture = texture
	_bound = true
