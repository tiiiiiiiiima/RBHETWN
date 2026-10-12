extends SceneTree
const Sphere = preload("res://scripts/ds_sphere_motion.gd")
const Surface = preload("res://scripts/field_surface.gd")
const Arena = preload("res://scripts/arena.gd")
const Assets = preload("res://scripts/asset_catalog.gd")
const DS = preload("res://scripts/ds_model_catalog.gd")
const Doc = preload("res://scripts/doc_model_catalog.gd")
const Models = preload("res://scripts/model_library.gd")
const Rules = preload("res://scripts/match_rules.gd")
var failures: Array[String] = []
var checks: int = 0
var evidence: Dictionary = {}

class Ramp extends Node3D:
	var surface = Surface.new()
	var slope: float = 0.0
	func sphere_support(point: Vector3, _height: float) -> Dictionary:
		return {"height":point.x*slope,"normal":Vector3(-slope,1,0).normalized()}
	func resolve_flight_segment(a: Vector3,b: Vector3) -> Dictionary:
		return surface.resolve_flight_segment(a,b)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	for entry: Dictionary in DS.species():
		var resolved: Dictionary = Assets.resolve(str(entry.name),"battle",str(entry.native_attribute))
		check(str(resolved.get("path",""))==str(DS.resolve(str(entry.name),str(entry.native_attribute)).path),"Animated DS wins over static skins: "+str(entry.name))
	check(Assets.resolve("Neo Dragonoid","battle","Pyrus").path.begins_with("res://assets/doc/"),"Animated DoC remains the next choice")
	check(Assets.resolve("Fortress","battle","Darkus").path.begins_with("res://assets/doc/"),"Trap identity stays separate from Fourtress")
	check(Assets.get_entry("Dragonoid").forms.battle.path.begins_with("res://assets/ds/"),"Collection and live battle agree about selected source")
	var opening_count: int = 0
	var role_count: int = 0
	for entry: Dictionary in Doc.manifest().species + Doc.manifest().support:
		if entry.forms.has("ball"):
			var ball: Node3D = Models.make_ball(stage,str(entry.forms.ball.native_attribute),0,true,str(entry.name))
			var bounds: AABB = Models.visual_bounds(ball)
			check(absf(maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))-2.0*Sphere.RADIUS)<0.001 and bounds.get_center().length()<0.001,"Closed sphere matches physics: "+str(entry.name))
			check(is_equal_approx(float(entry.forms.ball.transform.scale),float(entry.forms.toy.transform.scale)),"DoC closed/open forms share a scale: "+str(entry.name))
			ball.free()
			var toy: Node3D = Models.make_creature(stage,str(entry.name),str(entry.forms.toy.native_attribute),false,"toy")
			if str(toy.get_meta("asset_path","")).begins_with("res://assets/doc/"):
				opening_count += 1
				var player: AnimationPlayer = Models._form_player(toy)
				var clip: String = str(player.current_animation)
				check(clip.begins_with("doc_desktop/") or Models._named_position_track(player.get_animation(clip),"sphere")<0,"Native unfolding has stationary root: "+str(entry.name))
				var lowest: float = INF
				for sample: int in 21:
					player.seek(player.get_animation(clip).length*sample/20.0,true)
					for skeleton: Skeleton3D in toy.find_children("*","Skeleton3D",true,false): skeleton.force_update_all_bone_transforms()
					lowest = minf(lowest,Models.visual_bounds(toy).position.y)
				check(lowest>=-0.002,"Unfolding remains above card: "+str(entry.name))
			toy.free()
		if entry.forms.has("battle"):
			var actor: Node3D = Models.make_creature(stage,str(entry.name),str(entry.forms.battle.native_attribute),false,"battle")
			var player: AnimationPlayer = Models._form_player(actor)
			for role: String in entry.forms.battle.get("desktop_role_floor",{}):
				check(Models.play_battle_animation(actor,role),"Native DoC role plays: "+str(entry.name)+"/"+role)
				var clip: String = str(player.current_animation)
				var lowest: float = INF
				for sample: int in 31:
					player.seek(player.get_animation(clip).length*sample/30.0,true)
					for skeleton: Skeleton3D in actor.find_children("*","Skeleton3D",true,false): skeleton.force_update_all_bone_transforms()
					lowest = minf(lowest,Models.visual_bounds(actor).position.y)
				check(lowest>=-0.008,"Adapted DoC role stays above floor: "+str(entry.name)+"/"+role+" "+str(lowest))
				role_count += 1
			actor.free()
	evidence["doc"] = {"openings":opening_count,"battle_roles":role_count}
	stage.free()
	var ramp := Ramp.new()
	root.add_child(ramp)
	ramp.slope = 0.30
	ramp.surface.load_profile("slope",{"center_bounds":[50,50],"triangles":[[-50,-15,-50,50,15,-50,50,15,50],[-50,-15,-50,50,15,50,-50,-15,50]]})
	var positions: Array[Vector3] = []
	for fps: int in [30,60,120]:
		var motion = Sphere.new()
		motion.launch(Vector3(0,Sphere.RADIUS*sqrt(1+ramp.slope*ramp.slope)+0.001,0),Vector3.ZERO,0,"straight")
		motion.velocity = Vector3.ZERO
		for frame: int in fps*2: motion.step(1.0/fps,ramp)
		check(motion.position.x < -1.0 and motion.grounded,"Sphere rolls down native-style incline at %d FPS"%fps)
		check(absf(motion.position.y-ramp.slope*motion.position.x-Sphere.RADIUS*sqrt(1+ramp.slope*ramp.slope))<0.01,"Incline clearance follows sphere radius")
		positions.append(motion.position)
	check(positions[0].distance_to(positions[2])<0.002 and positions[1].distance_to(positions[2])<0.002,"Incline path is frame rate independent")
	ramp.slope=0.0
	ramp.surface.load_profile("flat",{"center_bounds":[50,50],"triangles":[[-50,0,-50,50,0,-50,50,0,50],[-50,0,-50,50,0,50,-50,0,50]]})
	var rolling = Sphere.new()
	rolling.launch(Vector3(0,0.441,0),Vector3(10,0,0),0,"straight")
	rolling.velocity=Vector3(4,0,0)
	for frame: int in 120*10: rolling.step(1.0/120,ramp)
	check(rolling.is_finished() and rolling.grounded and rolling.velocity.length()<0.1,"Rolling resistance reaches a stable rest")
	check(rolling.collision_count==0,"Resting floor contact does not spam impacts")
	var jumping = Sphere.new()
	jumping.launch(Vector3(0,0.441,0),Vector3.ZERO,0,"straight")
	jumping.velocity=Vector3.ZERO
	jumping.step(1.0/120,ramp)
	check(jumping.jump() and not jumping.jump(),"Jump requires ground contact")
	var first_jump: float = jumping.velocity.y
	for frame: int in 120: jumping.step(1.0/120,ramp)
	check(jumping.jump() and jumping.velocity.y<first_jump,"Repeated DS-style jumps become weaker")
	ramp.free()
	var arena = Arena.new()
	root.add_child(arena)
	arena.set_theme("ds_pyrus")
	var pools: Array = arena.field_objects.items.filter(func(item:Dictionary)->bool:return item.kind=="lava_pool")
	check(pools.size()>0,"Pyrus lava hazards come from source placement records")
	var centers: Array[Vector3] = []
	for pool: Dictionary in pools:
		centers.append(pool.node.global_position+Vector3.UP*0.441)
	check(not centers.is_empty(),"Native lava has reachable horizontal surfaces")
	if centers.is_empty(): quit(1); return
	var point: Vector3 = centers[0]
	evidence["pyrus"]={"lava_pools":pools.size(),"sample_contact":str(point),"placement_source":arena.field_objects.get_meta("placement_source")}
	check(not arena.field_response(point,point).filter(func(item:Dictionary)->bool:return item.kind=="lava").is_empty(),"Visible lava surface emits contact")
	check(arena.field_response(point+Vector3.UP*3,point+Vector3.UP*3).filter(func(item:Dictionary)->bool:return item.kind=="lava").is_empty(),"Flying over lava is safe")
	for attribute: String in ["Aquos","Pyrus"]:
		var motion = Sphere.new()
		motion.attribute=attribute
		motion.launch(point,point,0,"straight")
		motion.velocity=Vector3.ZERO
		var damage: int = 0
		for frame: int in 12:
			motion.step(1.0/120,arena,Vector2.ZERO,false,false)
			for event: Dictionary in motion.field_events:
				if event.kind=="lava": damage+=int(event.damage)
		check(damage==(30 if attribute=="Aquos" else 0),"One lava entry per contact; Pyrus immunity: "+attribute+" "+str(damage))
	var position_before: Vector3 = arena.camera.position
	arena.follow_sphere(arena.launch_position(),1.0/60,Vector3(8,0,0))
	check(arena.camera.position.distance_to(position_before)<3.0,"Follow camera starts smoothly")
	for frame: int in 60: arena.follow_sphere(Vector3(8,1,6),1.0/60,Vector3(8,0,0))
	check(arena.camera.position.is_finite() and arena.camera.position.y>1.8,"Follow camera maintains height and finite framing")
	arena.reset_match_field()
	check(arena.native_surface.clock==0 and arena.view_quadrant==0 and not arena._camera_following,"New match resets field and camera")
	arena.free()
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.muted=true
	game._set_rules_profile("ds")
	game.selected_arena="ds_pyrus"
	game.start_match()
	game._launch_ball(0,0,game.arena.slot_position(19))
	game.field_damage=60
	game.flight_ball.position=game.arena.ground_point(game.arena.slot_position(19))
	game._land_ball()
	var landed: Dictionary = game.rules.gates[19].bakugan[0]
	check(int(landed.field_damage)==60 and game.rules._standing_base_power(landed)==maxi(0,int(landed.g)+int(landed.roll_bonus)-60),"Lava loss survives landing and enters actual battle totals")
	landed.name="Neo Dragonoid"
	for node: Node3D in game.unit_nodes.values(): node.free()
	game.unit_nodes.clear()
	game._sync_units()
	var stand: Node3D = game.unit_nodes[game._unit_key(0,0)]
	var board_toy: Node3D = stand.get_child(0)
	var board_player: AnimationPlayer = Models._form_player(board_toy)
	board_player.seek(0,true)
	for skeleton: Skeleton3D in board_toy.find_children("*","Skeleton3D",true,false): skeleton.force_update_all_bone_transforms()
	var board_size: Vector3 = Models.visual_bounds(stand).size
	check(absf(maxf(board_size.x,maxf(board_size.y,board_size.z))-2*Sphere.RADIUS)<0.002,"Actual board unfolding retains the thrown DoC sphere diameter")
	game.start_match()
	game._launch_ball(0,0,Vector3.ZERO)
	check(game.field_damage==0,"New throw clears previous lava loss")
	for after_gate: bool in [false,true]:
		game.start_match()
		game._launch_ball(0,0,game.arena.slot_position(19))
		var card: Vector3 = game.arena.slot_position(19)
		var edge: Vector3 = card-Vector3(2.38*0.82*0.5,0,0)
		var lava := Node3D.new()
		game.arena.field_objects.add_child(lava)
		lava.global_position=edge+Vector3(0.48 if after_gate else 0.36,0,0)
		game.arena.field_objects.items.assign([{"id":999,"kind":"lava_pool","node":lava,"extent":Vector3(0.05,1,0.05),"collected":false}])
		game.ds_sphere.position=edge+Vector3(-0.08,0.441,0)
		game.ds_sphere.velocity=Vector3(20,0,0)
		game.ds_sphere.grounded=true
		game.ds_sphere.attribute="Aquos"
		game._update_ds_sphere(1.0/120)
		check(game.rules.gates[19].bakugan.size()==1 and int(game.rules.gates[19].bakugan[0].field_damage)==(0 if after_gate else 30),"Substep orders lava and card contacts: "+str(after_gate))
	game.queue_free()
	await process_frame
	Models.clear_caches()
	evidence["checks"]=checks
	evidence["failures"]=failures
	FileAccess.open("res://builds/qa-0.19/release-tests.json",FileAccess.WRITE).store_string(JSON.stringify(evidence,"\t"))
	print("DS REGRESSIONS 0.19: %d checks; %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
