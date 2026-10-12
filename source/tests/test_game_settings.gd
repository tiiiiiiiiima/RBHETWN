extends SceneTree

const Settings = preload("res://scripts/game_settings.gd")
var checks: int = 0
var failures: int = 0


func _init() -> void:
	_test_profile_normalization()
	_test_difficulty_ranges()
	if failures == 0:
		print("PASS: %d game settings checks" % checks)
		quit(0)
	else:
		push_error("FAIL: %d of %d game settings checks failed" % [failures, checks])
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _test_profile_normalization() -> void:
	var defaults: Dictionary = {"difficulty": "normal", "volume": 0.8, "reduced_motion": false,"music_volume":0.65,"effects_volume":0.8,"voice_volume":1.0}
	_check(defaults.keys().all(func(key): return Settings.normalize({})[key]==defaults[key]), "Older profile with no preferences keeps original normal gameplay and default volume")
	for difficulty: String in ["easy", "normal", "hard"]:
		_check(Settings.normalize({"difficulty": difficulty})["difficulty"] == difficulty, "Each supported difficulty survives profile normalization")
	for malformed: Variant in [null, 7, true, "NORMAL", "expert", {}, []]:
		_check(Settings.normalize({"difficulty": malformed})["difficulty"] == "normal", "Malformed difficulty falls back to original normal behavior")
	_check(Settings.normalize({"volume": -1.0})["volume"] == 0.0, "Volume below range is muted")
	_check(Settings.normalize({"volume": 2.0})["volume"] == 1.0, "Volume above range is clamped")
	_check(Settings.normalize({"volume": 0})["volume"] == 0.0 and typeof(Settings.normalize({"volume": 0})["volume"]) == TYPE_FLOAT, "Integer JSON volume becomes a valid normalized float")
	_check(Settings.normalize({"volume": 0.35})["volume"] == 0.35, "Fractional volume preference survives")
	for malformed: Variant in [null, true, "0.5", NAN, INF, -INF, {}, []]:
		_check(Settings.normalize({"volume": malformed})["volume"] == 0.8, "Invalid or nonfinite volume restores a finite default")
	_check(Settings.normalize({"reduced_motion": true})["reduced_motion"], "Reduced motion preference can be enabled")
	for malformed: Variant in [null, 1, "true", {}, []]:
		_check(not Settings.normalize({"reduced_motion": malformed})["reduced_motion"], "Only an actual boolean enables reduced motion")
	var source: Dictionary = {"difficulty": "hard", "volume": 0.45, "reduced_motion": true, "extra": [1, 2]}
	var before: Dictionary = source.duplicate(true)
	var normalized: Dictionary = Settings.normalize(source)
	_check(source == before, "Reading preferences does not mutate input profile")
	_check(normalized.size() == Settings.normalize({}).size() and not normalized.has("extra"), "Only supported preferences enter the normalized settings")
	normalized["volume"] = 1.0
	_check(source["volume"] == 0.45 and Settings.normalize({}) == Settings.normalize(defaults), "Normalized dictionaries are independent of inputs and shared defaults")


func _test_difficulty_ranges() -> void:
	for base: Vector2i in [Vector2i(90, 205), Vector2i(70, 125), Vector2i(95, 150), Vector2i(120, 175)]:
		_check(Settings.enemy_range(base, "normal") == base, "Normal difficulty preserves each earlier quick/tournament range exactly")
		_check(Settings.enemy_range(base, "easy") == base - Vector2i(30, 30), "Easy reduces both earlier range endpoints by 30")
		_check(Settings.enemy_range(base, "hard") == base + Vector2i(35, 35), "Hard increases both earlier range endpoints by 35")
		_check(Settings.enemy_range(base, "unknown") == base, "Unknown difficulty safely retains earlier base range")
	_check(Settings.enemy_range(Vector2i(10, 25), "easy") == Vector2i.ZERO, "Easy difficulty floors both low endpoints at zero")
	_check(Settings.enemy_range(Vector2i(25, 60), "easy") == Vector2i(0, 30), "Easy can clip just the lower endpoint without reversing range")
	_check(Settings.enemy_range(Vector2i(0, 0), "normal") == Vector2i.ZERO, "Normal preserves valid zero range")
	_check(Settings.enemy_range(Vector2i(0, 0), "hard") == Vector2i(35, 35), "Hard keeps a single-valued range well formed")
