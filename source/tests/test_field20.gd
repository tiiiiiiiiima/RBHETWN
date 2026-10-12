extends SceneTree
const Arena=preload("res://scripts/arena.gd")
const Sphere=preload("res://scripts/ds_sphere_motion.gd")
const Store=preload("res://scripts/match_checkpoint.gd")
var checks: int=0
var failures: Array[String]=[]
var exercised: Dictionary={}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func run() -> void:
	var arena=Arena.new(); root.add_child(arena); arena.setup(); arena.set_board_profile("ds"); arena.set_native_physics(true)
	for theme: String in ["ds_toy","ds_pyrus","ds_aquos","ds_subterra","ds_haos","ds_darkus","ds_ventus","ds_anime"]:
		arena.set_theme(theme)
		for layout: int in 3:
			arena.set_field_layout(layout)
			for item: Dictionary in arena.field_objects.items:
				var kind: String=str(item.kind)
				if exercised.has(kind): continue
				if kind in ["g_power","s_power","s_power_small","experience"]:
					var available: Array[Dictionary]=arena.field_objects.available_pickups()
					arena.field_objects.collect(int(item.id))
					check(item.collected and not item.node.visible,"Pickup hides after collection: "+kind)
					check(arena.field_objects.available_pickups().size()==available.size()-1,"Collected pickup cannot be collected twice: "+kind)
					arena.field_objects.reset_match(); check(not item.collected and item.node.visible,"New match resets pickup: "+kind)
				else:
					if kind=="energy_orb": arena.field_objects.advance(fposmod(3.0-float(item.id)*0.31,3.0)+2.2)
					if kind=="water_jet": arena.field_objects.advance(fposmod(2.4-float(item.id)*0.19,2.4)+0.5)
					var motion=Sphere.new(); motion.configure_field(arena); motion.configure_unit({"name":"Serpenoid","attribute":"Aquos","g":190})
					motion.position=item.node.global_position+Vector3.UP*0.44
					var before: Vector3=motion.position-Vector3(0.02,0,0)
					motion.velocity=Vector3(0,0,-2.0)
					if kind=="breakable": motion.velocity=Vector3(0,0,-motion.motion_scale*8.0)
					var old_speed: float=motion.velocity.length()
					motion._apply_field_objects(before,arena,false)
					check(not motion.field_events.is_empty(),"Visible object's contact volume activates: "+kind)
					match kind:
						"speed_pad": check(motion.velocity.length()>old_speed,"Speed pad changes actual sphere velocity")
						"trampoline","water_jet","wind_jet": check(motion.velocity.y>3.0,"Mechanism changes actual air trajectory: "+kind)
						"lava_pool","energy_orb":
							check(not motion.field_events.is_empty() and motion.field_events[0].damage>0,"Hazard applies G damage: "+kind)
							var immune=Sphere.new(); immune.configure_field(arena); immune.configure_unit({"attribute":"Pyrus" if kind=="lava_pool" else "Haos"})
							immune.position=motion.position; immune._apply_field_objects(before,arena,false)
							check(not immune.field_events.is_empty() and immune.field_events[0].damage==0,"Matching element is immune: "+kind)
						"breakable":
							check(not item.collected and item.node.visible,"Trajectory preview cannot destroy a live obstacle")
							var live=Sphere.new(); live.configure_field(arena); live.position=item.node.global_position+Vector3.UP*0.44
							live.velocity=Vector3(0,0,-live.motion_scale*8.0); live._apply_field_objects(before,arena,true)
							check(item.collected and not item.node.visible,"Fast live contact destroys an obstacle")
							check(not live.field_events.is_empty() and live.field_events[0].destroyed,"Destruction produces a controller event")
							arena.field_objects.reset_match()
				exercised[kind]={"theme":theme,"layout":layout,"id":item.id}
	check(exercised.size()==11,"All eleven runtime object kinds are exercised")
	arena.queue_free(); await process_frame
	var report: Dictionary={"checks":checks,"failures":failures,"exercised":exercised}
	FileAccess.open("res://builds/qa-0.20/field.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")); print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
