extends RefCounted
## Profile-safe preferences. Normal difficulty preserves the earlier AI ranges.

const DIFFICULTIES = ["easy", "normal", "hard"]


static func normalize(data: Dictionary) -> Dictionary:
	var result: Dictionary = {"difficulty": "normal", "volume": 0.8, "reduced_motion": false, "music_volume": 0.65, "effects_volume": 0.8, "voice_volume": 1.0, "ds_auto_gates":true}
	var difficulty: Variant = data.get("difficulty", "normal")
	if typeof(difficulty) == TYPE_STRING and DIFFICULTIES.has(difficulty):
		result["difficulty"] = difficulty
	var volume: Variant = data.get("volume", 0.8)
	if (typeof(volume) == TYPE_INT or typeof(volume) == TYPE_FLOAT) and is_finite(float(volume)):
		result["volume"] = clampf(float(volume), 0.0, 1.0)
	for channel: String in ["music_volume", "effects_volume", "voice_volume"]:
		var value: Variant = data.get(channel,result[channel])
		if (typeof(value)==TYPE_INT or typeof(value)==TYPE_FLOAT) and is_finite(float(value)):
			result[channel] = clampf(float(value),0.0,1.0)
	var reduced_motion: Variant = data.get("reduced_motion", false)
	if typeof(reduced_motion) == TYPE_BOOL:
		result["reduced_motion"] = reduced_motion
	var automatic: Variant = data.get("ds_auto_gates",true)
	if automatic is bool:
		result.ds_auto_gates = automatic
	var minigame: Variant = data.get("ds_minigame","scratch")
	result.ds_minigame = minigame if minigame is String and minigame in ["cycle","scratch","spin","timing","pop","trace","bound"] else "scratch"
	result.bindings = preload("res://scripts/control_bindings.gd").normalize(data.get("bindings",{}))
	for key: String in ["vsync","subtitles","tutorial_completed"]:
		result[key] = data.get(key,key!="tutorial_completed") if data.get(key,key!="tutorial_completed") is bool else key!="tutorial_completed"
	for key: String in ["render_scale","camera_sensitivity","gamepad_deadzone"]:
		var value: Variant = data.get(key,{"render_scale":1.0,"camera_sensitivity":1.0,"gamepad_deadzone":0.18}[key])
		var bounds: Vector2 = {"render_scale":Vector2(0.5,1.0),"camera_sensitivity":Vector2(0.5,2.0),"gamepad_deadzone":Vector2(0.1,0.35)}[key]
		result[key]=clampf(float(value),bounds.x,bounds.y) if (value is int or value is float) and is_finite(float(value)) else {"render_scale":1.0,"camera_sensitivity":1.0,"gamepad_deadzone":0.18}[key]
	result.screen_mode = data.get("screen_mode","window") if data.get("screen_mode","window") in ["window","borderless","fullscreen"] else "window"
	result.frame_cap = data.get("frame_cap",60) if data.get("frame_cap",60) in [0,30,60,120] else 60
	result.msaa = data.get("msaa",0) if data.get("msaa",0) in [0,2,4] else 0
	var avatar: Variant = data.get("avatar","chara00")
	result.avatar = avatar if avatar is String and avatar in ["chara00","chara01","chara02","chara03","chara04","chara05","chara06","chara07","chara08","chara09","chara10","chara11","chara12","chara13","chara14","chara15","chara16","chara18"] else "chara00"
	return result


static func apply_graphics(viewport: Viewport, data: Dictionary) -> void:
	Engine.max_fps=int(data.frame_cap)
	viewport.scaling_3d_scale=float(data.render_scale)
	viewport.msaa_3d={0:Viewport.MSAA_DISABLED,2:Viewport.MSAA_2X,4:Viewport.MSAA_4X}[int(data.msaa)]
	if DisplayServer.get_name()=="headless": return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(data.vsync) else DisplayServer.VSYNC_DISABLED)
	var mode: String=str(data.screen_mode)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if mode=="fullscreen" else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,mode=="borderless")


static func enemy_range(base: Vector2i, difficulty: String) -> Vector2i:
	match difficulty:
		"easy":
			return Vector2i(maxi(base.x - 30, 0), maxi(base.y - 30, 0))
		"hard":
			return base + Vector2i(35, 35)
		_:
			return base
