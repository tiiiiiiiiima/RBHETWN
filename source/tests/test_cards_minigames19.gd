extends SceneTree
const Mini = preload("res://scripts/ds_minigame.gd")
const Catalog = preload("res://scripts/ds_playable_catalog.gd")
const Effects = preload("res://scripts/battle_effects.gd")
const Modes = preload("res://scripts/ds_minigame_catalog.gd")
const AnimeCards = preload("res://scripts/anime_card_catalog.gd")
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message); push_error(message)
func new_mini(mode: String):
	var node=Mini.new(); node.size=Vector2(412,146); root.add_child(node)
	node.configure("Pyrus",mode); node.set_running(true)
	return node
func rub(fps: int, multiplier: float=1.0) -> float:
	var node=new_mini("scratch"); node.input_multiplier=multiplier
	node.press(node.center()+Vector2(-28,0))
	for frame: int in fps*2:
		var t: float = float(frame+1)/fps
		var x: float = -28.0+56.0*(1.0-absf(fmod(t,0.2)*10.0-1.0))
		node.motion(node.center()+Vector2(x,0)); node.step(1.0/fps)
	var score: float = node.score; node.queue_free(); return score
func _input_checks() -> void:
	var scores: Array[float]=[rub(30),rub(60),rub(120)]
	check(scores[0]>80 and absf(scores[0]-scores[1])<0.05 and absf(scores[0]-scores[2])<0.05,"Scratch credits the same rubbing distance at 30/60/120 FPS")
	check(absf(rub(60,2.0)-scores[1]*2.0)<0.05,"Double Input doubles the credited rubbing")
	var node=new_mini("spin"); node.press(node.center()+Vector2(40,0))
	for i: int in 120:
		node.motion(node.center()+Vector2(40,0).rotated(float(i+1)*TAU/120.0)); node.step(1.0/60)
	check(node.score>165,"Spin credits a complete held circle")
	node.configure("Pyrus","spin"); node.set_running(true); node.press(node.center()+Vector2(40,0))
	for i: int in 120:
		node.motion(node.center()+Vector2(40,0).rotated(PI/3 if i%2==0 else 0.0)); node.step(.1)
	check(node.score<35,"Repeating the same arc cannot farm Spin points")
	node.motion(node.center()+Vector2(40,0).rotated(PI/2)); var before: float = node.score
	node.set_running(false); node.step(1); node.set_running(true); node.step(.1)
	check(node.score==before,"Pausing clears pending circular input")
	node.queue_free()
	node=new_mini("timing"); node.press(node.center()); check(node.score==0,"Timing rejects a tap before a symbol reaches the ring")
	node.step(1); node.press(node.center()); var hit: float=node.score; node.press(node.center())
	check(hit>0 and node.score==hit,"Timing credits a target only once")
	node.queue_free()
	node=new_mini("pop"); node.press(node.center()); hit=node.score; node.press(node.center())
	check(hit>0 and node.score==hit,"Pop credits each visible symbol once")
	node.step(.7); node.press(node.center()); check(node.score==hit,"Pop rejects a tap in the hidden gap")
	node.step(.11); node.press(node.center()); check(node.score>hit,"A new Pop symbol can be hit")
	node.queue_free()
	node=new_mini("trace"); node.press(node.center())
	for i: int in 30: node.motion(node.center()); node.step(1.0/60)
	check(node.score>25,"Trace rewards following the moving symbol")
	before=node.score; node.release(); node.step(.2); check(node.score==before,"Trace rejects released input")
	node.queue_free()
	node=new_mini("bound"); node.press(node.center())
	for i: int in 100: node.motion(node.center()); node.step(1.0/60)
	check(node.score>=130 and not node._held,"Bound bursts after sustained contact and needs a fresh press")
	node.queue_free()
	node=new_mini("scratch"); node.blocked=3; node.press(node.center()); node.motion(node.center()+Vector2(30,0))
	node.step(1); node.step(1); node.step(1)
	check(node.score==0 and node.blocked==0,"Time Breaker prevents credited input for its full active duration")
	node.motion(node.center()); node.step(.1); check(node.score==0,"Blocked input is not credited after Time Breaker expires")
	node.set_running(false); node.blocked=2; node.step(2)
	check(node.blocked==2,"A paused minigame freezes the Time Breaker timer")
	node.queue_free()
	for mode: String in Modes.MODES:
		node=new_mini(mode); node.set_running(false); node.press(node.center()); node.motion(node.center()+Vector2(20,0)); node.step(1)
		check(node.score==0 and node.clock==0,"Cinematic/paused input is inert: "+mode); node.queue_free()
func card(cid: int,owner: int=0) -> Dictionary:
	var value: Dictionary=Catalog.metadata(cid); value.id="p%d_%s" % [owner,value.key]; value.owner=owner; return value
func _card_checks() -> void:
	var player: Dictionary={"name":"Dragonoid","attribute":"Pyrus","g":300}
	var enemy: Dictionary={"name":"Gorem","attribute":"Subterra","g":400}
	var context: Dictionary={"owner":0,"gate_owner":0,"current_powers":[300,400],"gate_color":"gold","reserve_attributes":["Pyrus","Darkus"],"team_attributes":["Pyrus","Aquos","Haos"]}
	check(Catalog.can_play(card(623),player,enemy,"scratch",false,context),"Reserve combination accepts both required elements")
	context.reserve_attributes=["Pyrus"]; check(not Catalog.can_play(card(623),player,enemy,"scratch",false,context),"Reserve combination rejects a missing partner")
	check(Catalog.bonus_for(card(632),player,enemy,context)==400,"Three-element team combination grants its recovered native bonus")
	context.team_attributes=["Pyrus","Pyrus","Haos"]; check(not Catalog.can_play(card(632),player,enemy,"scratch",false,context),"Duplicate elements cannot replace the missing team element")
	check(Catalog.bonus_for(card(626),player,enemy,context)==200,"Opponent-element combination grants the native boost")
	enemy.attribute="Aquos"; check(not Catalog.can_play(card(626),player,enemy,"scratch",false,context),"Opponent combination rejects the wrong target element")
	var fx=Effects.new()
	check(fx.apply(0,card(502),player,enemy,"scratch",false,context),"No Trading installs a persistent opposing restriction")
	var enemy_context: Dictionary={"owner":1,"current_powers":[300,400],"blocked_families":fx.states[1].blocked_families}
	check(not fx.apply(1,card(402,1),enemy,player,"scratch",false,enemy_context),"A blocked Swap does not enter the played-card ledger")
	check(fx.counts[1]==0 and fx.played_ids[1].is_empty(),"A rejected card has no partial effects")
	fx.reset(); check(fx.apply(0,card(604),player,enemy,"scratch",false,context),"Native Blaze activates")
	var boosted: int=fx.states[0].power
	check(boosted==Catalog.bonus_for(card(604),player,enemy,context) and boosted>0 and fx.apply(1,card(506,1),enemy,player,"scratch",false,enemy_context) and fx.states[0].power==0,"Imbalance removes the existing ability boost")
	check(not fx.apply(0,card(604),player,enemy,"scratch",false,context),"A spent card cannot be applied twice")
	fx.reset(); check(fx.apply(0,card(424),player,enemy,"scratch",false,context) and 300+int(fx.states[0].power)==400+int(fx.states[1].power),"Level Field equalizes visible G before restarting")
	context.gate_color="silver"; check(not Catalog.can_play(card(508),player,enemy,"scratch",false,context),"Stolen Gold cannot skip a battle on Silver")
	check(Catalog.can_play(card(509),player,enemy,"scratch",false,context),"Stolen Silver accepts its matching gate")
	context.current_powers=[400,400]
	check(not Catalog.can_play(card(408),player,enemy,"scratch",false,context),"An equal-power Swap cannot consume a card")
	context.preview_chain=true
	check(Catalog.can_play(card(408),player,enemy,"scratch",true,context),"Preparation can queue a Swap after an earlier boost")
func sequence(game) -> void:
	for step: int in 12:
		if game.phase!="ds_scene": return
		game._step_ds_sequence(2.0)
func start(game,mode: String="scratch") -> void:
	game._start_practice(mode); sequence(game)
	game.ds_ai_ability=""
func ready_cards(game,ids: Array[int]) -> void:
	game.rules.abilities[0].clear()
	for cid: int in ids: game.rules.abilities[0].append(card(cid))
	game._battle_unit(0).attribute="Pyrus"; game._battle_unit(1).attribute="Aquos"
	for index: int in ids.size(): game._choose_card(index)
	game._start_battle_game(); sequence(game); game.ds_ai_ability=""
func run() -> void:
	_input_checks(); _card_checks()
	var game=load("res://main.tscn").instantiate(); root.add_child(game)
	await process_frame; game.set_process(false); game.muted=true
	game._load_profile("user://cards19-empty.cfg"); game._set_rules_profile("ds")
	game.preferences.ds_minigame="bound"; game._save_profile("user://cards19-save.cfg")
	game.preferences.ds_minigame="scratch"; game._load_profile("user://cards19-save.cfg")
	check(game.preferences.ds_minigame=="bound","The selected DS minigame survives saving and loading")
	game.preferences.ds_minigame="scratch"
	for mode: String in Modes.MODES:
		start(game,mode)
		check(game.phase=="battle_ready" and game.battle_type==mode and game.scratch.mode==mode,"Practice prepares the correct native input kind: "+mode)
		game._start_battle_game(); sequence(game); game.ds_ai_ability=""
		check(game.phase=="battle" and game.scratch.running and not game.timing_track.visible,"Each DS mode reaches playable input without the old Wii widget: "+mode)
	start(game); ready_cards(game,[425,502,604])
	check(game.ds_selected_chain.size()==3 and game.rules.spent_abilities[0].is_empty(),"A three-card preparation queue spends no cards")
	check(not game._play_ability(0,2),"A future queued card cannot jump ahead")
	check(game._play_ability(0,0),"The first queued ability activates")
	sequence(game); check(game.scratch.input_multiplier==2 and game.rules.spent_abilities[0].size()==1,"Double Input survives its scene and consumes one card")
	check(game._play_ability(0,0),"The next queued card uses its new hand index")
	sequence(game); check(game.battle_effects.states[1].blocked_families.has("swap"),"The queue can combine an input boost with an opposing restriction")
	var enemy_swap: Dictionary=card(402,1); game.rules.abilities[1]=[enemy_swap]
	check(not game._play_ability(1,0) and game.rules.abilities[1].size()==1,"A blocked enemy Swap remains unspent")
	check(game._play_ability(0,0),"A third queued card activates after both prior scenes")
	sequence(game); check(game.ds_selected_chain.is_empty() and game.rules.spent_abilities[0].size()==3,"The chain finishes without a duplicate activation")
	start(game); ready_cards(game,[409,502,604]); game.ds_enemy_progress=0; game.ai_target_points=300
	check(game._play_ability(0,0),"Time Breaker can interrupt an actual DS battle")
	sequence(game); game._update_battle(3.0)
	check(game.ds_enemy_progress==0,"Time Breaker suppresses the enemy's actual progress rather than only changing its label")
	game._update_battle(.2); check(game.ds_enemy_progress>0,"The opponent resumes gaining progress after Time Breaker expires")
	start(game); ready_cards(game,[418,502,604]); game.battle_time=4; game.scratch.score=130; game.ds_enemy_progress=90
	check(game._play_ability(0,0),"Spin Redo activates during a different minigame")
	sequence(game); check(game.battle_type=="spin" and game.scratch.mode=="spin" and game.battle_time==0 and game.scratch.score==0 and game.ds_enemy_progress==0,"Redo changes the mode and resets both sides' progress")
	check(game.rules.spent_abilities[0].size()==1 and game.battle_effects.states[0].redo_used,"Redo retains its spent card and per-battle usage limit")
	var remaining: int=game.rules.abilities[0].size(); game._skip_ds_chain_card()
	check(game.rules.abilities[0].size()==remaining and game.ds_selected_chain.size()==1,"Skipping a queued card does not spend it")
	start(game); ready_cards(game,[423,507,604]); game._skip_ds_chain_card()
	check(game._play_ability(0,1) and game.phase=="ds_scene","Prevention shows its source card before resolving")
	sequence(game); check(game.phase=="finished" and game.rules.scores[0]+game.rules.scores[1]==1 and game.last_battle_result.display_powers==[game.last_battle_result.player_g,game.last_battle_result.enemy_g],"Skipping the minigame resolves visible G and captures exactly one gate")
	game.queue_free(); await process_frame
	print("CARDS / SIX DS GAMES 0.19: ",checks," checks; ",failures.size()," failures")
	FileAccess.open("/workspace/bakugan-pc/builds/qa-0.19/cards-minigames.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)
