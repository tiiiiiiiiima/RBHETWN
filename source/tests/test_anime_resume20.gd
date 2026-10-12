extends SceneTree
const Store=preload("res://scripts/match_checkpoint.gd")
const Save=preload("res://scripts/anime_checkpoint.gd")
const Cards=preload("res://scripts/anime_card_catalog.gd")
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func team(owner: int) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for index: int in 3:
		result.append({"id":"p%d_u%d" % [owner,index],"name":["Leonidas","Fourtress","Skyress"][index] if owner==0 else ["Hydranoid","Juggernoid","Gorem"][index],"attribute":["Pyrus","Haos","Ventus"][index] if owner==0 else ["Darkus","Aquos","Subterra"][index],"g":340 if index==0 else 300})
	return result
func run() -> void:
	var duel=load("res://anime_duel.tscn").instantiate(); root.add_child(duel); await process_frame
	duel.set_process(false); duel.auto_ai=false
	check(duel.rules.new_match(team(0),team(1),123,[],[],[{"id":"scorpion","attribute":"Pyrus"},null]).ok,"Trap-equipped anime fixture starts")
	duel.rules.gate_hands[0]=[Cards.get_gate("pyrus_50")]; duel.rules.gate_hands[1]=[Cards.get_gate("aquos_50")]
	duel.rules.place_gate(0,0,5); duel.rules.place_gate(1,0,0)
	duel.rules.throw_unit(0,0,5); duel.rules.finish_turn(0)
	duel.rules.throw_unit(1,1,0); duel.rules.finish_turn(1)
	duel.rules.throw_unit(0,2,5); duel.rules.finish_turn(0); duel.rules.throw_unit(1,0,5)
	duel.started=true; duel.visual_phase="idle"; duel._deck_panel.hide(); duel._modal_blocker.hide()
	check(duel.rules.deploy_trap(0,0,0).ok,"Trap enters the pending response chain")
	var before: Dictionary=Save.capture(duel)
	check(Store.valid(before),"Pending trap response can be saved")
	check(Store.write(before,"user://qa-anime20.bin")==OK,"Anime snapshot uses the atomic file store")
	var second=load("res://anime_duel.tscn").instantiate(); root.add_child(second); await process_frame
	second.set_process(false); second.auto_ai=false
	check(Save.restore(second,Store.read("user://qa-anime20.bin")),"A new duel scene restores the file")
	check(second.rules.state_snapshot()==duel.rules.state_snapshot(),"Teams, hands, effects, chain and pending trap survive")
	check(second.rules._random.state==duel.rules._random.state,"Deterministic rule RNG is restored")
	second.rules.teams[0][0].g+=1
	check(second.rules.gates[5].bakugan[0].g==second.rules.teams[0][0].g,"Gate occupant retains shared team identity after deserialization")
	second.rules.teams[0][0].g-=1
	for scene: Node3D in [duel,second]:
		scene.rules.pass_response(int(scene.rules.battle.priority)); scene.rules.pass_response(int(scene.rules.battle.priority))
	check(second.rules.state_snapshot()==duel.rules.state_snapshot(),"The saved response chain produces the same trap outcome")
	check(second.rules.support_slots[0].used and not second.rules.can_deploy_trap(0,0),"Used trap cannot be spent twice after resume")
	Store.clear("user://qa-anime20.bin")
	duel.queue_free(); second.queue_free(); await process_frame
	var report: String="anime-resume-packed.json" if "--packed" in OS.get_cmdline_user_args() else "anime-resume.json"
	FileAccess.open("/workspace/bakugan-pc/builds/qa-0.20/"+report,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print(JSON.stringify({"checks":checks,"failures":failures})); quit(0 if failures.is_empty() else 1)
