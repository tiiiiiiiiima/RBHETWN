extends RefCounted
## Free 3D sphere motion; DS input semantics, desktop integration coefficients.
const RADIUS: float = 0.44
const GRAVITY: float = 9.8
const STEP: float = 1.0 / 120.0
const MAX_SPEED: float = 13.0
const Profiles = preload("res://scripts/ds_sphere_profiles.gd")
var unit_profile: Dictionary = {"speed":2,"defense":2,"control":2,"steering":2,"magnet":1,"verified":false}
var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var elapsed: float = 0.0
var duration: float = 12.0
var grounded: bool = false
var lost: bool = false
var collision_count: int = 0
var travel_segments: Array[Dictionary] = []
var _rest_time: float = 0.0
var _accumulator: float = 0.0
var _support_velocity: Vector3 = Vector3.ZERO
var _jump_ready_time: float = 0.0
var field_events: Array[Dictionary] = []
var _pad_contacts: Dictionary = {}
var _pad_activated: Dictionary = {}
var _destroyed_objects: Dictionary = {}
var motion_scale: float = 1.0
var speed_limit: float = MAX_SPEED
var attribute: String = ""
var jump_count: int = 0
var _support_normal: Vector3 = Vector3.UP
const ROLLING_RESISTANCE: float = 0.50
const ROLLING_DRAG: float = 0.72
const REST_IMPACT_SPEED: float = 1.05
func configure_field(arena: Node3D) -> void:
	motion_scale = clampf(float(arena.throw_scale()),1.0,4.0) if arena.has_method("throw_scale") else 1.0
	speed_limit = MAX_SPEED*motion_scale*speed_factor()
func configure_unit(unit: Dictionary) -> void:
	unit_profile = unit.get("motion_profile", Profiles.resolve(unit)).duplicate(true)
	attribute = str(unit.get("attribute", ""))
	speed_limit = MAX_SPEED*motion_scale*speed_factor()
func speed_factor() -> float:
	return 0.65+float(clampi(int(unit_profile.get("speed",2)),1,5))*0.17
func magnet_margin() -> float:
	return float(clampi(int(unit_profile.get("magnet",1)),1,5)-1)*0.08
func launch(start: Vector3, target: Vector3, power: float, style: String = "lob", powered: bool = false) -> void:
	position = start if start.is_finite() else Vector3(0,0.5,5)
	var heading: Vector3 = target-position if target.is_finite() else Vector3.FORWARD
	heading.y = 0.0
	var fraction: float = clampf(power,0.0,1.0) if is_finite(power) else 0.0
	var vertical: float = lerpf(5.0,8.0,fraction) if style == "lob" else 0.25
	# Target determines heading only. A farther aim point must not manufacture
	# extra speed. Stat-to-coefficient curves remain documented desktop fits.
	if heading.length_squared()<0.000001:
		heading = Vector3.FORWARD
	var speed: float = speed_limit*lerpf(0.18,0.94,fraction)
	if powered:
		speed *= 1.22
	velocity = heading.normalized()*minf(speed,speed_limit)
	velocity.y = vertical
	elapsed = 0.0
	_accumulator = 0.0
	_rest_time = 0.0
	grounded = false
	lost = false
	collision_count = 0
	_support_velocity = Vector3.ZERO
	_jump_ready_time = 0.0
	jump_count = 0
	_support_normal = Vector3.UP
	_pad_contacts.clear()
	_pad_activated.clear()
	_destroyed_objects.clear()
	field_events.clear()
	travel_segments.clear()

func can_jump() -> bool:
	return grounded and not is_finished() and elapsed>=_jump_ready_time

func jump() -> bool:
	# Original DS microphone jump, mapped to a PC button. Height/cooldown
	# are desktop parameters; repeated air presses cannot make the ball fly.
	if not can_jump():
		return false
	velocity.y = maxf(velocity.y,_support_velocity.y+maxf(2.2,4.6*pow(0.82,jump_count)))
	jump_count += 1
	grounded = false
	_rest_time = 0.0
	_jump_ready_time = elapsed+0.55
	return true
func impulse(direction: Vector2, strength: float = 1.0) -> void:
	if not direction.is_finite() or not is_finite(strength):
		return
	var responsiveness: float = 0.65+float(int(unit_profile.get("steering",2)))*0.20
	var input: Vector2 = direction.limit_length(1.0) * clampf(strength,0.0,1.0)*2.4*motion_scale*responsiveness
	velocity += Vector3(input.x,0,input.y)
	var horizontal: Vector2 = Vector2(velocity.x,velocity.z).limit_length(speed_limit)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	_rest_time = 0.0
func step(delta: float, arena: Node3D, steering: Vector2 = Vector2.ZERO, braking: bool = false, advance_field: bool = true) -> Vector3:
	travel_segments.clear()
	field_events.clear()
	if not is_finite(delta) or delta <= 0 or is_finished():
		return position
	_accumulator += minf(delta,1.0)
	while _accumulator >= STEP-0.00000001 and not is_finished():
		_accumulator = maxf(0.0,_accumulator-STEP)
		if advance_field and arena.has_method("advance_field"):
			arena.advance_field(STEP)
		var previous: Vector3 = position
		var event_start: int = field_events.size()
		var safe_input: Vector2 = steering.limit_length(1.0) if steering.is_finite() else Vector2.ZERO
		var gravity: Vector3 = Vector3.DOWN * GRAVITY
		if grounded:
			# A solid rolling sphere accelerates at 5/7 of the slope component.
			gravity = gravity.slide(_support_normal)*(5.0/7.0)+_support_normal*gravity.dot(_support_normal)
		var responsiveness: float = 0.65+float(int(unit_profile.get("steering",2)))*0.20
		velocity += (Vector3(safe_input.x*4.0*motion_scale,0,safe_input.y*4.0*motion_scale)*responsiveness+gravity)*STEP
		var horizontal: Vector2 = Vector2(velocity.x,velocity.z).limit_length(speed_limit)
		velocity.x = horizontal.x
		velocity.z = horizontal.y
		var separated: Dictionary = arena.separate_sphere(position) if arena.has_method("separate_sphere") else {"position":position,"collided":false}
		position = separated.position
		if bool(separated.collided):
			_impact(separated.normal,separated.get("velocity",Vector3.ZERO) if advance_field else Vector3.ZERO)
		grounded = false
		_support_velocity = Vector3.ZERO
		var remaining: float = STEP
		for impact: int in 4:
			if remaining < 0.0000001: break
			var contact: Dictionary = arena.resolve_flight_segment(position,position+velocity*remaining)
			position = contact.position
			if not bool(contact.collided): break
			_support_velocity = contact.get("velocity",Vector3.ZERO) if advance_field else Vector3.ZERO
			_impact(contact.normal,_support_velocity)
			remaining *= 1.0-clampf(float(contact.get("fraction",1.0)),0.0,1.0)
			if contact.normal.y > 0.4 and (velocity-_support_velocity).dot(contact.normal) < 0.2:
				grounded = true
				_support_normal = contact.normal
		var support: Dictionary = arena.sphere_support(position,position.y-RADIUS+0.08) if arena.has_method("sphere_support") else {"height":0.0,"normal":Vector3.UP}
		var surface_velocity: Vector3 = support.get("velocity",Vector3.ZERO) if advance_field else Vector3.ZERO
		var clearance: float = RADIUS/maxf(0.4,support.normal.y)
		var gap: float = position.y-float(support.height)-clearance
		if is_finite(float(support.height)) and gap<=0.045 and gap>=-0.14 and (velocity-surface_velocity).dot(support.normal) <= 0.2:
			position.y = float(support.height)+clearance+0.001
			_support_velocity = surface_velocity
			velocity = (velocity-surface_velocity).slide(support.normal)+surface_velocity
			grounded = true
			_support_normal = support.normal
		if grounded:
			var relative: Vector3 = (velocity-_support_velocity).slide(_support_normal)
			var control: float = 0.7+float(int(unit_profile.get("control",2)))*0.20
			var drag: float = 4.2*control if braking else ROLLING_DRAG
			var resistance: float = 4.0*control if braking else ROLLING_RESISTANCE * _support_normal.y
			var speed: float = maxf(0.0,(relative.length()-resistance*STEP)*exp(-drag*STEP))
			velocity = relative.normalized()*speed+_support_velocity
		else:
			velocity.x *= exp(-0.03*STEP)
			velocity.z *= exp(-0.03*STEP)
		_apply_field_objects(previous,arena,advance_field)
		elapsed += STEP
		_rest_time = _rest_time+STEP if grounded and velocity.length() < 0.1 else 0.0
		var bounds: Vector2 = arena.traversal_bounds()+Vector2(4,4) if arena.has_method("traversal_bounds") else Vector2(28,28)
		if arena.get("native_surface")!=null:
			bounds = bounds.max(arena.native_surface.collision_bounds+Vector2(4,4))
		lost = position.y < -5.0 or absf(position.x)>bounds.x or absf(position.z)>bounds.y
		travel_segments.append({"from":previous,"to":position,"grounded":grounded,"speed":velocity.length(),"events":field_events.slice(event_start)})
	return position

func _apply_field_objects(previous: Vector3, arena: Node3D, commit: bool = true) -> void:
	if not arena.has_method("field_response"):
		return
	var contacts: Dictionary = {}
	for item: Dictionary in arena.field_response(previous,position):
		var id: int = int(item.id)
		if _destroyed_objects.has(id): continue
		contacts[id] = true
		if _pad_contacts.has(id) or elapsed-float(_pad_activated.get(id,-INF))<0.45:
			continue
		var normal: Vector3 = item.normal
		if item.kind in ["lava","energy_orb"]:
			_pad_activated[id] = elapsed
			var immune: bool=attribute==("Pyrus" if item.kind=="lava" else "Haos")
			field_events.append({"id":id,"kind":item.kind,"fraction":float(item.fraction),"position":previous.lerp(position,float(item.fraction)),"time":elapsed,"damage":0 if immune else int(item.damage)})
			continue
		if item.kind=="breakable":
			var destroyed: bool=velocity.length()>=7.0*motion_scale
			if destroyed:
				_destroyed_objects[id]=true; velocity*=0.85
				if commit and is_instance_valid(arena.field_objects): arena.field_objects.collect(id)
			else:
				position=previous
				velocity=Vector3(-velocity.x*0.45,maxf(velocity.y,1.0),-velocity.z*0.45)
			_pad_activated[id]=elapsed
			field_events.append({"id":id,"kind":"breakable","destroyed":destroyed,"fraction":float(item.fraction),"position":previous.lerp(position,float(item.fraction)),"time":elapsed})
			continue
		if item.kind=="wind_jet":
			velocity+=item.direction*3.0*motion_scale+Vector3.UP*4.0
			grounded=false; _rest_time=0.0; _pad_activated[id]=elapsed
			field_events.append({"id":id,"kind":"wind_jet","fraction":float(item.fraction),"time":elapsed})
			continue
		if normal.y<0.3 or velocity.dot(normal)>0.3:
			continue
		if item.kind in ["trampoline","water_jet"]:
			velocity = velocity.slide(normal)+normal*(6.5 if item.kind=="trampoline" else 8.0)
			grounded = false
		else:
			var direction: Vector3 = item.direction
			velocity += direction*4.0*motion_scale
			var horizontal := Vector2(velocity.x,velocity.z).limit_length(speed_limit)
			velocity.x = horizontal.x
			velocity.z = horizontal.y
		_rest_time = 0.0
		_pad_activated[id] = elapsed
		field_events.append({"id":id,"kind":item.kind,"fraction":float(item.fraction),"position":previous.lerp(position,float(item.fraction)),"time":elapsed})
	_pad_contacts = contacts
func _impact(normal: Vector3,surface_velocity: Vector3 = Vector3.ZERO) -> void:
	var inward: float = (velocity-surface_velocity).dot(normal)
	if inward >= -0.0001: return
	var resting: bool = normal.y>0.4 and -inward<REST_IMPACT_SPEED
	velocity -= normal*inward*(1.0+(0.0 if resting else (0.26 if normal.y>0.4 else 0.48)))
	if not resting: collision_count += 1
func is_finished() -> bool:
	return lost or elapsed>=duration or _rest_time>=0.35
