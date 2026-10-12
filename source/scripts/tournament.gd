extends RefCounted

## A short prototype tournament. Opponents and rewards are original placeholders.
const STAGES = [
	{
		"title": "Отборочный раунд",
		"subtitle": "Учебный соперник — прототип турнира",
		"enemy_min": 70,
		"enemy_max": 125,
	},
	{
		"title": "Полуфинал",
		"subtitle": "Опытный соперник — прототип турнира",
		"enemy_min": 95,
		"enemy_max": 150,
	},
	{
		"title": "Финал",
		"subtitle": "Сильный соперник — прототип турнира",
		"enemy_min": 120,
		"enemy_max": 175,
	},
]

var stage: int = 0
var active: bool = false
var completed: bool = false


func get_stage() -> Dictionary:
	return STAGES[clampi(stage, 0, STAGES.size() - 1)].duplicate(true)


func start_new() -> void:
	stage = 0
	active = true
	completed = false


func record_result(won: bool) -> Dictionary:
	var advanced: bool = false
	if active and won:
		if stage < STAGES.size() - 1:
			stage += 1
			advanced = true
		else:
			completed = true
			active = false
	return {"advanced": advanced, "completed": completed, "stage": stage}


func to_dict() -> Dictionary:
	return {"stage": stage, "active": active, "completed": completed}


func load_dict(data: Dictionary) -> void:
	# Older saves without tournament state begin with a fresh inactive tournament.
	stage = 0
	active = false
	completed = false
	var saved_stage: Variant = data.get("stage", 0)
	if typeof(saved_stage) == TYPE_INT:
		if saved_stage >= 0 and saved_stage < STAGES.size():
			stage = int(saved_stage)
	elif typeof(saved_stage) == TYPE_FLOAT:
		# JSON represents numbers as floats. Accept whole, finite stages only.
		if is_finite(saved_stage) and saved_stage == floor(saved_stage):
			if saved_stage >= 0.0 and saved_stage < float(STAGES.size()):
				stage = int(saved_stage)
	var saved_active: Variant = data.get("active", false)
	if typeof(saved_active) == TYPE_BOOL:
		active = saved_active
	var saved_completed: Variant = data.get("completed", false)
	if typeof(saved_completed) == TYPE_BOOL:
		completed = saved_completed
	if completed:
		stage = STAGES.size() - 1
		active = false
