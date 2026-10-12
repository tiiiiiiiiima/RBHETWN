extends SceneTree
## Controlled real Scratch inputs and native cards; no claim of original DS formulas.
const Scratch=preload("res://scripts/ds_minigame.gd")
const Rules=preload("res://scripts/match_rules.gd")
const Effects=preload("res://scripts/battle_effects.gd")
const Cards=preload("res://scripts/ds_playable_catalog.gd")
const Roster=preload("res://scripts/roster.gd")
const Profiles=preload("res://scripts/ds_sphere_profiles.gd")
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); push_error(label)
func input_score(amplitude: float, fps: int=60, source: Script=Scratch) -> int:
	var input=source.new(); input.size=Vector2(240,180)
	input.configure("Pyrus","scratch"); input.set_running(true); input.press(input.center())
	var event_index: int=0
	for frame: int in fps*10:
		while event_index<300 and float(event_index+1)/30.0<=float(frame+1)/float(fps)+0.000001:
			input.motion(input.center()+Vector2(amplitude if event_index%2==0 else -amplitude,0)); event_index+=1
		input.step(1.0/float(fps))
	var score: int=int(input.score); input.free(); return score
func battle(gate_id: int, player_points: int, enemy_points: int, blaze: bool) -> Dictionary:
	var rules=Rules.new(); rules.new_match("ds")
	rules.teams[0]=Profiles.apply_team(Roster.make_team([Profiles.starter_indices(Roster.CREATURES)[0],Profiles.starter_indices(Roster.CREATURES)[1],Profiles.starter_indices(Roster.CREATURES)[2]],["Pyrus","Ventus","Aquos"],0,true))
	rules.teams[1]=Profiles.apply_team(Roster.make_team([Profiles.starter_indices(Roster.CREATURES)[1],Profiles.starter_indices(Roster.CREATURES)[0],Profiles.starter_indices(Roster.CREATURES)[2]],["Ventus","Pyrus","Aquos"],1,true))
	var gate: Dictionary=Cards.metadata(gate_id); gate.id="benchmark_gate"; gate.owner=0; gate.bakugan=[]; gate.revealed=false
	rules.hands[0][0]=gate
	check(rules.place_gate(0,0,19,true) and rules.place_gate(1,0,28,true),"Native opening is legal")
	check(rules.land(0,0,19).event=="stand" and rules.finish_turn() and rules.land(1,0,19).event=="battle","Native units reach a legal opposed gate")
	var effects=Effects.new(); var card: Dictionary=Cards.metadata(604); card.id="benchmark_blaze"; card.owner=0
	if blaze:
		rules.abilities[0][0]=card
		var context: Dictionary=rules.battle_context(19,0)
		check(effects.apply(0,card,rules.teams[0][0],rules.teams[1][0],"scratch",false,context),"Native Blaze effect is legal")
		check(not rules.use_ability(0,0,19,"scratch",false,context).is_empty(),"Blaze consumes its real hand slot")
	var printed: Array[int]=[rules._battle_base_power(19,rules.teams[0][0])+rules.gate_unit_bonus(19,rules.teams[0][0])+effects.extra(0,0),rules._battle_base_power(19,rules.teams[1][0])+rules.gate_unit_bonus(19,rules.teams[1][0])+effects.extra(1,0)]
	var result: Dictionary=rules.resolve_battle(19,effects.extra(0,player_points),effects.extra(1,enemy_points))
	check(result.event=="capture","Battle resolves through the real rules engine")
	return {"gate":gate_id,"title":gate.title,"blaze":blaze,"display_g":printed,"mini":[player_points,enemy_points],"decision_values":[result.player_g,result.enemy_g],"winner":result.owner}
func run() -> void:
	var scores: Dictionary={}; var rows: Array[Dictionary]=[]
	var baseline: Script
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--baseline-script="): baseline=load(arg.trim_prefix("--baseline-script="))
	var frequency: Dictionary={}
	for item: Array in [["none",0.0],["weak",2.0],["ordinary",6.0],["strong",30.0]]:
		scores[item[0]]=input_score(float(item[1]))
		frequency[item[0]]={}
		for fps: int in [15,30,60,120]:
			frequency[item[0]][str(fps)]={"after":input_score(float(item[1]),fps)}
			if baseline!=null: frequency[item[0]][str(fps)]["before"]=input_score(float(item[1]),fps,baseline)
		for fps: int in [15,30,120]: check(absi(input_score(float(item[1]),fps)-int(scores[item[0]]))<=1,"Equal pointer events preserve scoring at %d FPS" % fps)
	check(scores.none==0 and scores.weak<scores.ordinary and scores.ordinary<scores.strong and scores.strong==600,"Actual controlled input spans zero through the existing cap")
	for gate: int in [136,119,111,217]:
		for ability: bool in [false,true]:
			for player: String in scores:
				for enemy: String in scores:
					var row: Dictionary=battle(gate,int(scores[player]),int(scores[enemy]),ability)
					row.player_input=player; row.enemy_input=enemy; rows.append(row)
	var equal: Dictionary=battle(136,int(scores.strong),int(scores.strong),false)
	var ability: Dictionary=battle(136,int(scores.strong),int(scores.strong),true)
	var gate_change: Dictionary=battle(119,int(scores.strong),int(scores.strong),false)
	var skill: Dictionary=battle(136,int(scores.strong),int(scores.ordinary),false)
	check(equal.winner==1 and ability.winner==0,"Blaze can change the winner even when both Scratch scores reach 600")
	check(equal.winner==1 and gate_change.winner==0,"Changing the native gate changes the winner at equal input")
	check(skill.winner==0 and equal.display_g[0]<equal.display_g[1],"Superior input can overcome a weaker displayed G")
	var report: Dictionary={"version":ProjectSettings.get_setting("application/config/version"),"passed":failures.is_empty(),"checks":checks,"failures":failures,"controlled_input":true,"full_physical_matches":false,"original_ds_formula_verified":false,"nominal_weights_and_cap_changed":false,"frame_frequency_fix":true,"frequency_comparison":frequency,"input_event_rate":30,"duration_seconds":10,"scores":scores,"scenarios":rows,"examples":{"equal_input":equal,"ability_changes_winner":ability,"gate_changes_winner":gate_change,"skill_overcomes_g":skill},"limitations":["A controlled benchmark is not a human win-rate study.","Campaign AI and all six original minigame formulas require additional gameplay observations."]}
	var output: String="res://builds/qa-0.23/minigame-balance.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.trim_prefix("--report=")
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("MINIGAME AUDIT ",JSON.stringify({"checks":checks,"failures":failures,"scores":scores,"examples":report.examples})); quit(0 if failures.is_empty() else 1)
