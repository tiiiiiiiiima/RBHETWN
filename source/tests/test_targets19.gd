extends SceneTree
const Cards=preload("res://scripts/anime_card_catalog.gd")
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message); push_error(message)
func team(owner: int) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for index: int in 3:
		result.append({"id":"p%d_u%d" % [owner,index],"name":["Leonidas","Fourtress","Skyress"][index] if owner==0 else ["Hydranoid","Juggernoid","Gorem"][index],"attribute":["Pyrus","Haos","Ventus"][index] if owner==0 else ["Darkus","Aquos","Subterra"][index],"g":340 if index==0 else 300})
	return result
func passes(rules) -> void:
	rules.pass_response(int(rules.battle.priority)); rules.pass_response(int(rules.battle.priority))
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for frame: int in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/workspace/bakugan-pc/builds/qa-0.19/visual/"+label+".png")
func run() -> void:
	var scene=load("res://anime_duel.tscn").instantiate(); root.add_child(scene)
	await process_frame; scene.set_process(false); scene.auto_ai=false
	scene.audio.configure({"music":0,"sfx":0,"voice":0})
	check(scene.rules.new_match(team(0),team(1),123,[],[],[{"id":"scorpion","attribute":"Pyrus"},null]).ok,"Target fixture has an independently equipped anime trap")
	scene.rules.gate_hands[0]=[Cards.get_gate("pyrus_50")]; scene.rules.gate_hands[1]=[Cards.get_gate("aquos_50")]
	scene.rules.place_gate(0,0,5); scene.rules.place_gate(1,0,0)
	scene.rules.throw_unit(0,0,5); scene.rules.finish_turn(0)
	scene.rules.throw_unit(1,1,0); scene.rules.finish_turn(1)
	scene.rules.throw_unit(0,2,5); scene.rules.finish_turn(0); scene.rules.throw_unit(1,0,5)
	scene.rules.ability_hands[0]=[Cards.get_ability("fire_storm"),Cards.get_ability("correlation_ventus_pyrus")]
	scene.started=true; scene.visual_phase="idle"; scene.paused=false; scene._deck_panel.hide(); scene._modal_blocker.hide(); scene.battle_presentation.reset()
	scene.selected_caster=0; scene.selected_target=0; scene.selected_target_owner=1; scene._refresh_ui()
	scene._sync_field()
	var before: String=JSON.stringify(scene.rules.state_snapshot())
	var options: Array[Dictionary]=scene.rules.ability_options(0,0)
	check(options.size()==1 and int(options[0].caster_index)==2,"A species card exposes its eligible ally despite the currently wrong caster")
	check(before==JSON.stringify(scene.rules.state_snapshot()),"Previewing targets never changes battle state")
	scene._select_ability(0)
	check(scene.selected_caster==2 and scene._caster_select.item_count==1 and not scene._activate_button.disabled,"Selecting the card filters the caster menu to the compatible participant")
	check(scene.rules.spent_abilities[0].is_empty(),"Selecting a card spends nothing")
	await capture("anime-caster-choice")
	scene._activate_selected_ability()
	check(scene.rules.spent_abilities[0].size()==1 and scene.rules.battle.chain.size()==1 and scene.rules.battle.priority==1,"Explicit activation spends one card and gives the opponent an answer")
	passes(scene.rules)
	check(scene.rules.battle_unit_breakdown(0,2).ability==125 and scene.rules.battle_unit_breakdown(0,0).ability==0,"The chosen species boost affects only its selected caster")
	scene._select_ability(0)
	var own_target: int=-1
	for index: int in scene._target_select.item_count:
		var target: Dictionary=scene._target_select.get_item_metadata(index)
		if int(target.owner)==0 and int(target.index)==0: own_target=index
	check(own_target>=0,"Correlation makes its paired ally selectable")
	await capture("anime-correlation-choice")
	if own_target>=0:
		scene._target_select.select(own_target); scene._target_select.item_selected.emit(own_target)
		scene._activate_selected_ability(); passes(scene.rules)
		check(scene.rules.battle_unit_breakdown(0,0).ability==100 and scene.rules.battle_unit_breakdown(0,2).ability==225,"Explicit allied Correlation grants the two separate native bonuses")
	scene.selected_caster=2; scene._prepare_trap()
	check(scene.selected_ability.is_empty() and scene.selected_caster==0 and not scene._trap_button.disabled,"Trap preparation clears card filters and selects its compatible caster")
	scene._trap_button.pressed.emit()
	check(scene.rules.support_slots[0].status=="pending" and scene.rules.battle.priority==1,"A trap enters the answer chain before its effect resolves")
	await capture("anime-trap-response")
	scene.rules.ability_hands[1]=[Cards.get_ability("ability_counter")]
	scene.rules.teams[1][0].attribute="Haos"
	check(scene.rules.play_ability(1,0).ok,"The opposing player can counter a pending trap")
	passes(scene.rules)
	check(scene.rules.support_slots[0].status=="spent" and not scene.rules.can_deploy_trap(0,0),"A countered trap cannot be summoned a second time")
	scene._refresh_ui(); scene.queue_free(); await process_frame
	print("ANIME TARGETS 0.19: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
