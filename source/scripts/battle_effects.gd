class_name BattleEffects
extends RefCounted
## Per-battle ability effects; the match hand controls availability.
## Cards can combine, but the same card cannot be applied twice in one battle.

const Catalog = preload("res://scripts/ability_catalog.gd")
const DSPlayableCatalog = preload("res://scripts/ds_playable_catalog.gd")
var states: Array[Dictionary] = []
var used: Array[bool] = []
var counts: Array[int] = []
var played_ids: Array[Dictionary] = []
var forced_type: String = ""


func _init() -> void:
	reset()


func reset() -> void:
	# Neutral compatibility fields keep the old HUD calculations valid. There
	# are no invented drain, shield or multiplier cards in this catalog.
	states = [
		{"power": 0, "drain": 0, "shield": false, "focus": 1.0, "g_bonus":0,"input_multiplier":1.0,"blocked_families":[],"input_block":0.0,"redo_used":false},
		{"power": 0, "drain": 0, "shield": false, "focus": 1.0, "g_bonus":0,"input_multiplier":1.0,"blocked_families":[],"input_block":0.0,"redo_used":false},
	]
	used = [false, false]
	counts = [0, 0]
	played_ids = [{}, {}]
	forced_type = ""


static func can_play(card: Dictionary, unit: Dictionary, opponent: Dictionary, battle_type: String, preparing: bool, context: Dictionary = {}) -> bool:
	if str(card.get("rules_profile", "")) == "ds":
		if not card.get("effect") is Dictionary:
			return false
		if str(card["effect"].get("type", "")) == "power_swap" and (not _valid_power_snapshot(context) or typeof(context.get("owner")) != TYPE_INT or int(context["owner"]) not in [0, 1]):
			return false
		return DSPlayableCatalog.can_play(card, unit, opponent, battle_type, preparing, context)
	return Catalog.can_play(card, unit, opponent, battle_type, preparing)


static func bonus_for(card: Dictionary, unit: Dictionary, opponent: Dictionary, context: Dictionary = {}) -> int:
	if str(card.get("rules_profile", "")) == "ds":
		return DSPlayableCatalog.bonus_for(card, unit, opponent, context)
	return Catalog.bonus_for(card, unit, opponent)


func apply(owner: int, card: Dictionary, unit: Dictionary = {}, opponent: Dictionary = {}, battle_type: String = "", preparing: bool = true, context: Dictionary = {}) -> bool:
	if owner < 0 or owner > 1 or not can_play(card, unit, opponent, battle_type, preparing, context):
		return false
	var identity: String = str(card.get("id", card.get("key", "")))
	if identity.is_empty() or played_ids[owner].has(identity):
		return false
	var effect: Dictionary = card["effect"]
	if str(effect["type"]) == "battle_type":
		forced_type = str(effect["battle_type"])
	elif str(effect["type"]) == "power_swap":
		if int(context.get("owner", -1)) != owner or not _valid_power_snapshot(context):
			return false
		var powers: Array = context["current_powers"]
		var delta: int = int(powers[1 - owner]) - int(powers[owner])
		if delta == 0:
			return false
		# Swap the complete visible snapshot once. Equal and opposite offsets
		# preserve all existing gate, landing, ability and minigame components.
		states[owner]["power"] = int(states[owner]["power"]) + delta
		states[1 - owner]["power"] = int(states[1 - owner]["power"]) - delta
	elif str(effect.type)=="double_input":
		states[owner].input_multiplier=2.0
	elif str(effect.type)=="time_break":
		states[1-owner].input_block=3.0
	elif str(effect.type)=="block_family":
		states[1-owner].blocked_families.append(str(effect.family))
	elif str(effect.type)=="cancel_boost":
		for side: int in [0,1] if str(effect.target)=="all" else [1-owner]:
			states[side].power-=int(states[side].g_bonus)
			states[side].g_bonus=0
	elif str(effect.type) in ["redo","level_field"]:
		states[owner].redo_used=true
		if str(effect.type)=="level_field":
			var powers: Array = context.get("current_powers",[0,0])
			var average: int = roundi(float(int(powers[0])+int(powers[1]))*0.5)
			for side: int in range(2): states[side].power+=average-int(powers[side])
	elif str(effect.type)=="skip_battle":
		pass # The controller resolves the visible G immediately after its scene.
	else:
		var bonus: int = bonus_for(card, unit, opponent, context)
		if str(card.get("rules_profile", "")) == "ds":
			bonus *= maxi(1, int(context.get("ability_multiplier", 1)))
		states[owner]["power"] = int(states[owner]["power"]) + bonus
		states[owner]["g_bonus"] = int(states[owner]["g_bonus"]) + bonus
	played_ids[owner][identity] = true
	counts[owner] += 1
	used[owner] = true
	return true


static func _valid_power_snapshot(context: Dictionary) -> bool:
	var powers: Variant = context.get("current_powers")
	if not powers is Array or powers.size() != 2:
		return false
	for power: Variant in powers:
		if typeof(power) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(power)) or float(power) != floor(float(power)) or absf(float(power)) > 2000000000.0:
			return false
	return true


func extra(owner: int, mini_points: int) -> int:
	if owner < 0 or owner > 1:
		return 0
	return int(states[owner]["power"]) + maxi(mini_points, 0)


func selected_battle_type(fallback: String) -> String:
	return fallback if forced_type.is_empty() else forced_type


func status(owner: int) -> String:
	if owner < 0 or owner > 1:
		return ""
	if counts[owner] == 0 and int(states[owner]["power"]) == 0:
		return "без способности"
	var parts: PackedStringArray = []
	var power: int = int(states[owner]["power"])
	if power != 0:
		parts.append(("+%d G" if power > 0 else "%d G") % power)
	if not forced_type.is_empty():
		parts.append({"shooting": "стрельба", "timing": "точность", "shaking": "встряхивание"}[forced_type])
	parts.append("карт: %d" % counts[owner])
	if float(states[owner].input_multiplier)>1.0: parts.append("ввод ×2")
	if float(states[owner].input_block)>0.0: parts.append("ввод остановлен: %.1f с" % float(states[owner].input_block))
	var blocked: PackedStringArray=[]
	for family: String in states[owner].blocked_families:
		blocked.append(str({"redo":"перезапуск","swap":"обмен G","time_break":"Time Breaker","double_input":"Double Input"}.get(family,family)))
	if not blocked.is_empty(): parts.append("запрет: "+", ".join(blocked))
	return " · ".join(parts)


func copy() -> BattleEffects:
	var result: BattleEffects = BattleEffects.new()
	result.states = states.duplicate(true)
	result.used = used.duplicate()
	result.counts = counts.duplicate()
	result.played_ids = played_ids.duplicate(true)
	result.forced_type = forced_type
	return result
