extends SceneTree
const Shots=preload("res://scripts/ds_special_shots.gd")
const Cards=preload("res://scripts/ds_field_cards.gd")
const Sphere=preload("res://scripts/ds_sphere_motion.gd")
const Store=preload("res://scripts/match_checkpoint.gd")
const Saves=preload("res://scripts/save_files.gd")
var game: Node3D
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); push_error(label)
func fixture() -> void:
	game.rules.new_match("ds"); game.rules.opening_active=false
	game.rules.gates[19]=game.rules.hands[0].pop_front()
	game.rules.gates[20]=game.rules.hands[1].pop_front()
	game.phase="flying"; game.flight_owner=0; game.flight_unit=0; game.selected_gate=0
	game.flight_special=""; game.field_effects=Cards.initial(); game.extra_throw_owner=-1
	game.roll_bonus=40; game.field_damage=0; game.s_power.assign([0,0]); game.sphere_collision_slot=19
	game.rules.gates[19].bakugan=[{"owner":1,"index":0,"name":"Hydranoid","attribute":"Darkus","g":350,"roll_bonus":40,"pickup_base":40}]
func run() -> void:
	Saves.diagnostic_mode=true
	game=load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.set_process(false); game.muted=true; game._set_rules_profile("ds"); game.selected_arena="ds_pyrus"; game.start_match()
	var evidence: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Shots.PATH))
	for index: int in 6:
		var attribute: String=Shots.ATTRIBUTES[index]
		check(evidence.shots[index].name==Shots.TITLES[index],"Shot name matches native MES: "+attribute)
		check(not Shots.available({"attribute":attribute,"level":1},100,"campaign"),"Campaign level condition: "+attribute)
		check(Shots.available({"attribute":attribute,"level":3},100,"campaign"),"Campaign level 3 available: "+attribute)
		check(not Shots.available({"attribute":attribute,"level":3},99,"quick"),"S cannot be overspent: "+attribute)
		fixture(); game.rules.teams[0][0].attribute=attribute; game.s_power[0]=100; game.powered_throw=true
		game._launch_ball(0,0,game.arena.slot_position(19))
		check(game.flight_special==attribute and game.ds_sphere.special_shot==attribute and game.s_power[0]==0,"Real launch selects matching shot and spends S once: "+attribute)
		if is_instance_valid(game.flight_ball): game.flight_ball.free(); game.flight_ball=null
	var ordinary=Sphere.new(); ordinary.configure_unit({"attribute":"Pyrus"}); ordinary.launch(Vector3.ZERO,Vector3.FORWARD,0.8,"straight")
	var fire=Sphere.new(); fire.configure_unit({"attribute":"Pyrus"}); fire.launch(Vector3.ZERO,Vector3.FORWARD,0.8,"straight",false,"Pyrus")
	check(fire.velocity.length()>ordinary.velocity.length(),"Pyrus has actual additional launch speed")
	var earth=Sphere.new(); earth.configure_unit({"attribute":"Subterra"}); earth.launch(Vector3.ZERO,Vector3.FORWARD,0.8,"straight",false,"Subterra")
	check(earth.velocity.y>ordinary.velocity.y,"Quake is a high launch even with straight style selected")
	var water=Sphere.new(); water.configure_unit({"attribute":"Aquos"}); water.launch(Vector3.ZERO,Vector3.FORWARD,0.4,"straight",false,"Aquos")
	ordinary.launch(Vector3.ZERO,Vector3.FORWARD,0.4,"straight"); water.impulse(Vector2.RIGHT); ordinary.impulse(Vector2.RIGHT)
	check(water.velocity.x>ordinary.velocity.x,"Aquos changes steering response")
	for id: int in Cards.IDS:
		check(not Cards.metadata("ds_card_%d" % id).is_empty(),"Native field card has explicit gameplay availability: %d" % id)
	fixture(); game._activate_field_card(701); check(game.extra_throw_owner==0,"Another Throw schedules one owner-specific extra throw")
	fixture(); game._activate_field_card(702); check(game.field_effects.get("restart",false),"Second Chance requests a restart without refunding pickups")
	fixture(); var prior: String=game.rules.gates[19].id; game._activate_field_card(703); game._field_card_landing_slot(19)
	check(game.rules.gates[19].id!=prior and game.rules.gates[19].bakugan.size()==1,"Sleight of Hand swaps real gate data and preserves occupants")
	fixture(); game._activate_field_card(704); game._field_card_landing_slot(19)
	check(game.flight_unit==1 and not game.rules.teams[0][0].used,"Trickster selects an available other unit and returns original")
	fixture(); game._activate_field_card(705); check(game.field_effects.early,"Early Victory waits for a successful stand")
	fixture(); game._activate_field_card(706); check(game._field_card_landing_slot(20)==19,"Surprise Attack targets actual opposing standing Bakugan")
	fixture(); game._activate_field_card(707); check(game.rules.gates.has(game._field_card_landing_slot(19)),"Road Trip selects an existing gate")
	fixture(); game._activate_field_card(708); var event: Dictionary=game.rules.land(0,0,20,40,0,game.field_effects)
	game.rules.turn_action_taken=false; game.rules.turn=1
	var attack: Dictionary=game.rules.apply_sphere_attack(1,20,10000)
	check(attack.event=="sphere_attack" and attack.remaining_g==1,"Invulnerable prevents Critical K.O. without negating all damage")
	game.rules.gates[20].bakugan[0].field_damage=10000; attack=game.rules.apply_sphere_attack(1,20,10000)
	check(attack.event=="sphere_attack" and game.rules.gates.has(20),"Invulnerable also prevents Critical K.O. when earlier hazards left zero G")
	fixture(); game._activate_field_card(709); game.rules.land(0,0,20,120,0,game.field_effects)
	check(game.rules.gates[20].bakugan[0].roll_bonus==240,"All For One doubles pickups above the ordinary 120 cap")
	game.roll_bonus=120; check(game._effective_pickup_g()==240,"Flight indicator/statistic uses the same doubled G as landing")
	fixture(); game._activate_field_card(710); check(game.s_power[0]==100,"Fill'er Up fills the real S meter")
	fixture(); game._activate_field_card(711); check(game.roll_bonus==0 and game.rules.gates[19].bakugan[0].roll_bonus==0,"Subtraction clears current and standing pickup boosts")
	fixture(); game._activate_field_card(712); game._activate_field_card(712)
	check(game.field_effects.multiplier==2 and game.rules.gates[19].bakugan[0].roll_bonus==80,"Addition doubles each original pickup value without compounding")
	fixture(); game.rules.remove_field_units([19]); check(game.rules.gates[19].bakugan.is_empty() and game.rules.scores==[0,0],"Removal leaves the gate and awards no victory")
	fixture(); game.rules.gates[19].bakugan[0]["removal_protected"]=true; game.rules.remove_field_units([19]); check(game.rules.gates[19].bakugan.size()==1,"Darkus standing protection blocks removal")
	fixture(); game.flight_special="Ventus"; check(not game._special_landing(19) and game.rules.gates[19].bakugan.is_empty(),"Ventus contact displaces a real opponent")
	fixture(); game.flight_special="Subterra"; check(game._special_landing(19) and game.rules.gates[19].bakugan.is_empty() and game.rules.scores==[0,0],"Quake removes occupants without capturing gates")
	fixture(); game.flight_special="Haos"; check(game._special_landing(19) and game.rules.gates[19].bakugan.is_empty(),"Haos contact empties the field")
	fixture(); game.flight_special="Darkus"; check(not game._special_landing(19) and game.field_effects.invulnerable and game.field_effects.removal_protected,"Darkus passes without Sphere Attack and retains standing protection")
	game.match_id+=1; fixture(); game.rules.teams[0][0].attribute="Aquos"; game.s_power[0]=100; game.powered_throw=true
	game._launch_ball(0,0,game.arena.slot_position(19)); game._update_ds_sphere(0.08)
	game.field_effects.multiplier=2; game.extra_throw_owner=0
	var saved: Dictionary=Store.capture(game); check(Store.valid(saved),"Shot and field-card checkpoint validates")
	check(Store.write(saved)==OK and Store.read().special==saved.special,"New mechanics round-trip through disk without losing typed state")
	game.saved_match=saved; game._resume_match(); game.set_process(false)
	check(game.flight_special=="Aquos" and game.ds_sphere.special_shot=="Aquos" and game.field_effects.multiplier==2 and game.extra_throw_owner==0,"Main controller restores active shot, field effects and extra throw")
	check(game.ds_sphere.position==saved.sphere.position and game.ds_sphere.velocity==saved.sphere.velocity,"Active special flight restores exact position and velocity")
	check(is_instance_valid(game.flight_ball) and game.flight_ball.get_node_or_null("SpecialAura")!=null,"Resumed special sphere restores its visual aura")
	fixture(); var ghost_from: Vector3=game.arena.slot_position(19)+Vector3(0,0.44,1); var ghost_to: Vector3=game.arena.slot_position(19)+Vector3(0,0.44,-1)
	check(game._ds_shot_gate_contact(ghost_from,ghost_to,"Darkus",8,0,0)==-1,"Moving Darkus passes the opponent instead of colliding")
	check(game._ds_shot_gate_contact(ghost_from,ghost_to,"Pyrus",8,0,0)==19,"Other shots still contact the same occupied gate")
	var legacy: Dictionary=saved.duplicate(true); legacy.erase("special"); legacy.release="0.20"
	check(Store.valid(legacy),"Older match format remains accepted")
	var bad: Dictionary=saved.duplicate(true); bad.special.sphere.special_shot=17; check(not Store.valid(bad),"Malformed new state is rejected before restore")
	var objects: Node3D=game.arena.field_objects; var pool: Dictionary={}; var wall: Dictionary={}
	for item: Dictionary in objects.items:
		if item.kind=="lava_pool": pool=item
		if item.kind=="breakable": wall=item
	check(not pool.is_empty() and not wall.is_empty(),"Real Pyrus source includes hazards and breakables")
	check(objects.available_pickups().any(func(item:Dictionary)->bool:return item.kind=="field_card"),"Native type 3 produces collectible original card models")
	objects.advance(0.2-float(pool.id)*0.17+8.0); check(objects.hazard_status(pool)=="warning","Lava warns before activation")
	objects.advance(1.3-float(pool.id)*0.17+8.0); var active_clock: float=objects.clock
	check(objects.hazard_status(pool)=="active","Lava is dangerous during its marked active phase")
	var point: Vector3=pool.node.global_position
	check(objects.response(point,point).any(func(item:Dictionary)->bool:return item.kind=="lava"),"Active real lava collider returns damage event")
	objects.advance(3.0-float(pool.id)*0.17+8.0)
	check(not objects.response(point,point).any(func(item:Dictionary)->bool:return item.kind=="lava"),"Quiet lava crossing does not damage")
	var before: float=objects.clock; objects.response(point,point,active_clock)
	check(objects.clock==before and not pool.collected,"Preview uses future hazard time without changing live state")
	objects.collect(int(wall.id)); check(wall.collected and not wall.node.visible,"Destruction changes collision availability and visibility")
	var clock: float=game.arena.native_surface.clock; game.arena.advance_field(0.2)
	check(game.arena.native_surface.clock>clock,"Pyrus moving support uses the same live animation clock")
	game.match_id+=1; await create_timer(1.2).timeout; game.queue_free(); await process_frame
	var report: Dictionary={"version":ProjectSettings.get_setting("application/config/version"),"checks":checks,"failures":failures,"passed":failures.is_empty(),"real_pyrus_resources":true,"prescribed_rule_fixture":true,"full_physical_match":false}
	var path: String="res://builds/qa-0.24/release24-tests.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.trim_prefix("--report=")
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RELEASE 0.24 ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
