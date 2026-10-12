extends RefCounted
## Data-only, bounded, checksummed snapshots. No nodes or executable objects.
const LEGACY_PATH: String="user://unfinished-match.bin"
const PATH: String="user://slots/free_1.bin"
static var active_slot: String="free_1"
static func valid_slot(id: String) -> bool:
	return id in ["campaign_1","campaign_2","campaign_3","free_1","free_2","free_3","anime_1","anime_2","anime_3"]
static func effective_path(path: String) -> String:
	return "user://slots/%s.bin" % active_slot if path.is_empty() and valid_slot(active_slot) else path
const PHASES: Array[String]=["opening","place","aim","ai","stay","double","flying","rolling","battle_ready","battle","ds_scene","result"]
const RULE_FIELDS: Array[String]=["scores","turn","gates","hands","abilities","spent_abilities","teams","winner","turn_serial","stay_markers","rules_profile","opening_placements","opening_active","gate_placed_this_turn","turn_action_taken"]
const MAIN_FIELDS: Array[String]=["phase","rules_profile","match_mode","match_token","campaign_chapter","enemy_tactic","enemy_power_range","selected_gate","selected_unit","aim_point","flight_owner","flight_unit","flight_start","flight_end","flight_time","flight_duration","flight_steer","roll_target","roll_time","roll_duration","roll_bonus","field_damage","s_power","battle_slot","battle_type","ds_sequence","ds_sequence_time","ds_resume_phase","ds_sequence_stage","ds_current_event","ds_selected_ability","ds_selected_chain","ds_ai_opportunities","ds_enemy_progress","ds_skip_pending","ds_ai_ability","ds_ai_ability_at","battle_time","battle_duration","battle_points","ability_points","ai_points","ai_target_points","ai_ability_used","used_battle_abilities","hit_cooldown","rhythm_phase","last_shake_key","battle_level","battle_streak","bonus_mode","timing_sequence","timing_window_active","timing_window_hit","circle_sequence","powered_throw","flight_powered","throw_style","flight_style","flight_charge","sphere_collision_slot","pending_double_slot","opening_resume_owner","shooting_attributes","shooting_positions","journal","last_throw_quality","last_battle_result","pending_action","ai_choice","experience_gained","preferences"]
const CAMERA_FIELDS: Array[String]=["_camera_focus","_camera_following","_aim_camera","_aim_sphere","_follow_sphere_point","_throw_heading"]
const SPHERE_FIELDS: Array[String]=["unit_profile","position","velocity","elapsed","duration","grounded","lost","collision_count","_rest_time","_accumulator","_support_velocity","_jump_ready_time","_pad_contacts","_pad_activated","_destroyed_objects","motion_scale","speed_limit","attribute","jump_count","_support_normal"]
const ROLL_FIELDS: Array[String]=["position","velocity","elapsed","duration","collision_count","_bounds"]
const EFFECT_FIELDS: Array[String]=["states","used","counts","played_ids","forced_type"]
const MINI_FIELDS: Array[String]=["score","advantage","mode","clock","input_multiplier","blocked","_angle","_spin_direction","_hit_ids","_pointer","_bound_move","_burst","hits"]
static func grab(object: Object, fields: Array[String]) -> Dictionary:
	var data: Dictionary={}
	for field: String in fields:
		var value: Variant=object.get(field)
		data[field]=value.duplicate(true) if value is Array or value is Dictionary else value
	return data
static func put(object: Object, data: Dictionary, fields: Array[String]) -> void:
	for field: String in fields:
		if not data.has(field): continue
		var existing: Variant=object.get(field)
		if existing is Array:
			existing.assign(data[field])
		else: object.set(field,data[field].duplicate(true) if data[field] is Dictionary else data[field])
static func compatible(object: Object, data: Dictionary, fields: Array[String]) -> bool:
	for field: String in fields:
		if not data.has(field): return false
		var value: Variant=data[field]; var existing: Variant=object.get(field)
		if typeof(value)!=typeof(existing) and not (typeof(existing)==TYPE_FLOAT and typeof(value)==TYPE_INT): return false
		if existing is Array and existing.is_typed():
			for item: Variant in value:
				if typeof(item)!=existing.get_typed_builtin(): return false
	return true
static func capture(game: Node3D) -> Dictionary:
	if game.phase not in PHASES or game.match_mode in ["practice","training"]: return {}
	var collected: Array[int]=[]
	if is_instance_valid(game.arena.field_objects):
		for item: Dictionary in game.arena.field_objects.items:
			if item.collected: collected.append(int(item.id))
	var pickups: Array[Dictionary]=[]
	for item: Dictionary in game.pickups:
		var copy: Dictionary=item.duplicate(); copy.erase("node"); pickups.append(copy)
	var remaining: float=game.pending_timer.time_left if game.pending_timer!=null else 0.0
	return {"schema":1,"release":"0.20","main":grab(game,MAIN_FIELDS),"rules":grab(game.rules,RULE_FIELDS),"sphere":grab(game.ds_sphere,SPHERE_FIELDS),"roll":grab(game.roll_motion,ROLL_FIELDS),"effects":grab(game.battle_effects,EFFECT_FIELDS),"mini":grab(game.scratch,MINI_FIELDS),"stats":game.match_stats.totals.duplicate(true),"rng_state":game.rng.state,"rng_seed":game.rng.seed,"timer_remaining":remaining,
		"field":{"theme":game.arena.theme_id,"layout":game.arena.field_layout,"clock":game.arena.native_surface.clock if game.arena.native_surface!=null else 0.0,"collected":collected,"quadrant":game.arena.view_quadrant,"zoom":game.arena.camera_zoom,"camera":game.arena.camera.transform,"camera_state":grab(game.arena,CAMERA_FIELDS)},
		"pickups":pickups,"flight_transform":game.flight_ball.transform if is_instance_valid(game.flight_ball) else Transform3D.IDENTITY,"has_flight":is_instance_valid(game.flight_ball),"ui":{"phase":game.phase_text.text,"instruction":game.instruction.text,"banner":game.result_banner.text,"banner_visible":game.result_banner.visible},"presentation":game.ds_battle.snapshot.duplicate(true)}
static func _safe(value: Variant, depth: int=0) -> bool:
	if depth>14: return false
	match typeof(value):
		TYPE_NIL,TYPE_BOOL,TYPE_INT: return true
		TYPE_FLOAT: return is_finite(value)
		TYPE_STRING,TYPE_STRING_NAME: return str(value).length()<16000
		TYPE_VECTOR2,TYPE_VECTOR3: return value.is_finite()
		TYPE_VECTOR2I,TYPE_VECTOR3I: return true
		TYPE_TRANSFORM3D: return value.origin.is_finite() and value.basis.is_finite()
		TYPE_DICTIONARY:
			if value.size()>600: return false
			for key: Variant in value:
				if not _safe(key,depth+1) or not _safe(value[key],depth+1): return false
			return true
		TYPE_ARRAY:
			if value.size()>600: return false
			for child: Variant in value:
				if not _safe(child,depth+1): return false
			return true
	return false
static func valid(data: Variant) -> bool:
	if not data is Dictionary or not _safe(data) or data.get("schema",0)!=1: return false
	if data.get("mode","")=="save_slot":
		if not valid_slot(str(data.get("slot",""))) or typeof(data.get("saved_at"))!=TYPE_INT or int(data.saved_at)<0: return false
		if not data.get("progress") is Dictionary or not data.get("match") is Dictionary: return false
		if data.match.is_empty(): return true
		if data.match.get("mode","")=="save_slot" or not valid(data.match): return false
		var expected: String="anime" if data.match.get("mode","")=="anime" else "campaign" if data.match.main.get("match_mode","")=="campaign" else "free"
		return str(data.slot).begins_with(expected+"_")
	if data.get("mode","")=="anime":
		if not data.get("main") is Dictionary or not data.get("rules") is Dictionary: return false
		var state: Dictionary=data.rules
		if state.get("phase","") not in ["opening","turn","battle","chain"] or state.get("turn",-1) not in [0,1] or state.get("winner",-2)!=-1: return false
		if not state.get("teams") is Array or state.teams.size()!=2 or not state.get("gates") is Dictionary: return false
		for owner: int in 2:
			if not state.teams[owner] is Array or state.teams[owner].size()!=3: return false
		for slot: Variant in state.gates:
			var gate: Variant=state.gates[slot]
			if typeof(slot)!=TYPE_INT or slot<0 or slot>=16 or not gate is Dictionary or not gate.get("bakugan") is Array: return false
			for unit: Variant in gate.bakugan:
				if not unit is Dictionary or unit.get("owner",-1) not in [0,1] or int(unit.get("index",-1))<0 or (not bool(unit.get("temporary_clone",false)) and int(unit.index)>2): return false
		return typeof(data.get("rng_state"))==TYPE_INT and typeof(data.get("rng_seed"))==TYPE_INT and typeof(data.get("camera"))==TYPE_TRANSFORM3D
	for section: String in ["main","rules","sphere","roll","effects","mini","field","ui","presentation"]:
		if not data.get(section) is Dictionary: return false
	for pair: Array in [["main",MAIN_FIELDS],["rules",RULE_FIELDS],["sphere",SPHERE_FIELDS],["roll",ROLL_FIELDS],["effects",EFFECT_FIELDS],["mini",MINI_FIELDS]]:
		for field: String in pair[1]:
			if not data[pair[0]].has(field): return false
	var main: Dictionary=data.main; var rules: Dictionary=data.rules
	var environment: Dictionary=data.field
	for key: String in ["theme","layout","clock","collected","quadrant","zoom","camera"]:
		if not environment.has(key): return false
	if not environment.theme is String or typeof(environment.layout)!=TYPE_INT or environment.layout<0 or environment.layout>3 or not environment.collected is Array or typeof(environment.camera)!=TYPE_TRANSFORM3D: return false
	for id: Variant in environment.collected:
		if typeof(id)!=TYPE_INT or id<0 or id>4095: return false
	if typeof(main.campaign_chapter)!=TYPE_INT or main.campaign_chapter<0 or main.campaign_chapter>6: return false
	if not main.s_power is Array or main.s_power.size()!=2 or not main.ds_sequence is Array or main.ds_sequence.size()>20: return false
	if not main.match_token is String or main.match_token.length()>100: return false
	if main.phase not in PHASES or main.match_mode not in ["quick","tournament","campaign"] or main.rules_profile not in ["ds","wii"]: return false
	if rules.rules_profile!=main.rules_profile or rules.turn not in [0,1] or rules.winner not in [-1,0,1]: return false
	if not rules.scores is Array or rules.scores.size()!=2 or not rules.gates is Dictionary: return false
	for score: Variant in rules.scores:
		if typeof(score)!=TYPE_INT or score<0 or score>3: return false
	for field: String in ["teams","hands","abilities","spent_abilities","stay_markers","opening_placements"]:
		if not rules[field] is Array or rules[field].size()!=2: return false
	for owner: int in 2:
		if not rules.teams[owner] is Array or rules.teams[owner].size()!=3: return false
		for unit: Variant in rules.teams[owner]:
			if not unit is Dictionary or not unit.get("name") is String or not unit.get("attribute") is String or typeof(unit.get("g"))!=TYPE_INT or not unit.get("used") is bool: return false
		for field: String in ["hands","abilities","spent_abilities"]:
			if not rules[field][owner] is Array or rules[field][owner].size()>3: return false
	for slot: Variant in rules.gates:
		var gate: Variant=rules.gates[slot]
		if typeof(slot)!=TYPE_INT or slot<0 or slot>=(48 if main.rules_profile=="ds" else 16) or not gate is Dictionary or not gate.get("bakugan") is Array or gate.bakugan.size()>2: return false
		for unit: Variant in gate.bakugan:
			if not unit is Dictionary or unit.get("owner",-1) not in [0,1] or unit.get("index",-1) not in [0,1,2]: return false
	if main.phase in ["battle","battle_ready","ds_scene"] and (not rules.gates.has(main.battle_slot) or rules.gates[main.battle_slot].bakugan.size()!=2): return false
	if main.phase in ["flying","rolling"] and (not data.get("has_flight",false) or main.flight_owner not in [0,1] or main.flight_unit not in [0,1,2]): return false
	if main.battle_type not in ["scratch","spin","timing","pop","trace","bound","shooting","shaking"]: return false
	if not data.get("stats") is Array or data.stats.size()!=2 or not data.get("pickups") is Array or typeof(data.get("rng_state"))!=TYPE_INT or typeof(data.get("rng_seed"))!=TYPE_INT: return false
	return typeof(data.get("timer_remaining")) in [TYPE_INT,TYPE_FLOAT] and float(data.timer_remaining)>=0.0 and float(data.timer_remaining)<=5.0
static func write(data: Dictionary, path: String="") -> Error:
	path=preload("res://scripts/save_files.gd").resolve(effective_path(path))
	if not valid(data): return ERR_INVALID_DATA
	var prepare_error: Error=preload("res://scripts/save_files.gd").prepare(path)
	if prepare_error!=OK: return prepare_error
	var bytes: PackedByteArray=var_to_bytes(data)
	var digest: String=_digest(bytes)
	var file: FileAccess=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: return FileAccess.get_open_error()
	file.store_32(0x424B3230); file.store_pascal_string(digest); file.store_buffer(bytes); file.flush()
	var write_error: Error=file.get_error()
	file.close()
	if write_error!=OK: return write_error
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path+".bak")
		var moved: Error=DirAccess.rename_absolute(path,path+".bak")
		if moved!=OK: return moved
	return DirAccess.rename_absolute(path+".tmp",path)
static func read(path: String="", unwrap: bool=true) -> Dictionary:
	path=preload("res://scripts/save_files.gd").resolve(effective_path(path))
	for candidate: String in [path,path+".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var file: FileAccess=FileAccess.open(candidate,FileAccess.READ)
		if file==null or file.get_length()<76 or file.get_length()>2097152: continue
		if file.get_32()!=0x424B3230: continue
		if file.get_32()!=64: continue
		var digest: String=file.get_buffer(64).get_string_from_utf8()
		var bytes: PackedByteArray=file.get_buffer(file.get_length()-file.get_position())
		file.close()
		if _digest(bytes)!=digest: continue
		var data: Variant=bytes_to_var(bytes)
		if valid(data): return data.get("match",{}).duplicate(true) if unwrap and data.get("mode","")=="save_slot" else data
	return {}
static func _digest(bytes: PackedByteArray) -> String:
	var context:=HashingContext.new()
	context.start(HashingContext.HASH_SHA256); context.update(bytes)
	return context.finish().hex_encode()
static func clear(path: String="") -> void:
	path=preload("res://scripts/save_files.gd").resolve(effective_path(path))
	for candidate: String in [path,path+".bak",path+".tmp"]:
		if FileAccess.file_exists(candidate): DirAccess.remove_absolute(candidate)
