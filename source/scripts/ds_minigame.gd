extends "res://scripts/ds_scratch.gd"
const Catalog = preload("res://scripts/ds_minigame_catalog.gd")
var mode: String = "scratch"
var clock: float = 0.0
var input_multiplier: float = 1.0
var blocked: float = 0.0
var _angle_pending: float = 0.0
var _angle: float = 0.0
var _spin_direction: int = 0
var _hit_ids: Dictionary = {}
var _pointer: Vector2 = Vector2.ZERO
var _bound_move: float = 0.0
var _bound_hold: float = 0.0
var _burst: float = 0.0
var hits: int = 0
var virtual_pointer: Vector2 = Vector2.ZERO
var show_virtual_pointer: bool = false
func configure(attribute: String, kind: String = "scratch") -> void:
	mode = kind if Catalog.MODES.has(kind) else "scratch"
	show_virtual_pointer=false
	clock=0.0; input_multiplier=1.0; blocked=0.0; _angle_pending=0.0
	_angle=0.0; _spin_direction=0; _hit_ids.clear(); _bound_move=0.0; _bound_hold=0.0; _burst=0.0; hits=0
	super.configure(attribute,kind)
func center() -> Vector2:
	var base := Vector2(size.x*0.5,size.y*0.61)
	if mode=="pop":
		var index: int = int(clock/0.8)
		return base+Vector2(sin(float(index)*2.4)*size.x*0.32,cos(float(index)*1.7)*size.y*0.14)
	if mode=="trace": return base+Vector2(sin(clock*1.7)*size.x*0.31,sin(clock*2.3)*size.y*0.14)
	if mode=="bound": return base+Vector2(sin(_bound_move*2.1)*size.x*0.32,cos(_bound_move*3.2)*size.y*0.14)
	return base
func inside_symbol(point: Vector2) -> bool:
	return point.distance_to(center())<=minf(size.y*0.32,70.0) if mode in ["scratch","spin"] else point.distance_to(center())<=24.0
func press(point: Vector2) -> void:
	_pointer=point
	if not running or blocked>0.0: return
	if mode=="timing":
		if point.distance_to(center())>26.0: return
		for side: int in [0,1]:
			var t: float = clock+float(side)*0.6
			var id: String = "%d:%d" % [side,int(t/1.2)]
			if absf(fmod(t,1.2)-1.0)<0.13 and not _hit_ids.has(id):
				_hit_ids[id]=true; _gain(65.0)
		return
	if mode=="pop":
		var id: String = str(int(clock/0.8))
		if fmod(clock,0.8)<0.62 and inside_symbol(point) and not _hit_ids.has(id):
			_hit_ids[id]=true; _gain(60.0)
		return
	if mode=="spin":
		_held=point.distance_to(center())<90.0
		_last=point; _inside=_held
		return
	if mode=="trace":
		_held=true; _last=point
		return
	super.press(point)
func motion(point: Vector2) -> void:
	_pointer=point
	if blocked>0.0:
		_last=point
		return
	if mode=="scratch": super.motion(point); return
	if mode=="spin" and running and _held and blocked<=0.0:
		var a: Vector2 = _last-center(); var b: Vector2 = point-center()
		if a.length()>18.0 and b.length()>18.0 and a.length()<100.0 and b.length()<100.0:
			var delta_angle: float = wrapf(b.angle()-a.angle(),-PI,PI)
			var direction: int = int(signf(delta_angle))
			if absf(delta_angle)<PI/2.0:
				# Require consistent circular movement; alternating the same arc
				# builds no more than its initial quarter turn.
				if _spin_direction==0: _spin_direction=direction
				_angle_pending += delta_angle*float(_spin_direction)
		_last=point
func release() -> void:
	super.release()
	_bound_hold=0.0
func set_running(value: bool) -> void:
	super.set_running(value)
	_angle_pending=0.0
func _notification(what: int) -> void:
	super._notification(what)
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT: _angle_pending=0.0
func _gain(amount: float) -> void:
	score=clampf(score+amount*input_multiplier,0.0,MAX_POINTS)
	hits+=1; _flash=0.12
func step(delta: float) -> int:
	if not running or delta<=0.0 or not is_finite(delta): return int(score)
	clock+=delta; _burst=maxf(0.0,_burst-delta)
	var active: float = delta
	if blocked>0.0:
		active=maxf(0.0,delta-blocked)
		blocked=maxf(0.0,blocked-delta); _pending=0.0; _angle_pending=0.0
		if active<=0.0:
			queue_redraw(); return int(score)
	if mode=="scratch":
		var old: float = score
		super.step(active)
		score=minf(MAX_POINTS,old+(score-old)*input_multiplier)
	elif mode=="spin":
		var angle: float = clampf(_angle_pending,-active*16.0,active*16.0)
		_angle=maxf(0.0,_angle+angle)
		# Credit only newly completed circular travel, never oscillating arcs.
		var furthest: float = float(_hit_ids.get("angle",0.0))
		if _angle>furthest:
			_gain((_angle-furthest)/TAU*170.0); _hit_ids["angle"]=_angle
		_angle_pending=0.0
	elif mode=="trace":
		if _held and inside_symbol(_pointer): _gain(active*60.0)
	elif mode=="bound":
		var touching: bool = _held and inside_symbol(_pointer)
		_bound_move+=active/(1.0+_bound_hold*3.0)
		_bound_hold = _bound_hold+active if touching else 0.0
		if _bound_hold>=1.4:
			_gain(130.0); _burst=0.25; _bound_hold=0.0; _bound_move+=1.8; release()
	queue_redraw()
	return int(score)
func _draw() -> void:
	if mode=="scratch":
		super._draw()
		_draw_pointer()
		if blocked>0.0: draw_string(ThemeDB.fallback_font,Vector2(20,48),"TIME BREAKER",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("fff0a5"))
		return
	var bar := Rect2(Vector2(16,5),Vector2(size.x-32,18))
	draw_rect(bar,Color("ed3024")); draw_rect(Rect2(Vector2(bar.end.x-bar.size.x*advantage,5),Vector2(bar.size.x*advantage,18)),Color("28bfe9"))
	draw_rect(bar,Color("f5e4c1"),false,2.0)
	if mode=="timing":
		draw_arc(center(),27,0,TAU,48,Color("fff0a5"),2.0)
		for side: int in [0,1]:
			var phase: float = fmod(clock+float(side)*0.6,1.2)
			var x: float = (size.x*0.42)*(1.0-phase)*(1.0 if side==1 else -1.0)
			_draw_symbol(center()+Vector2(x,0),18)
	elif mode!="pop" or fmod(clock,0.8)<0.62:
		var radius: float = 42.0 if mode=="spin" else 22.0
		_draw_symbol(center(),radius)
		if mode=="spin": draw_arc(center(),radius+8,_angle,_angle+PI*1.5,48,Color("fff0a5"),3.0)
		if mode=="bound": draw_arc(center(),27,-PI/2,-PI/2+TAU*minf(1.0,_bound_hold/1.4),48,Color("fff0a5"),3.0)
	if _burst>0.0: draw_circle(center(),35,Color(1,0.9,0.4,_burst*2))
	if blocked>0.0: draw_string(ThemeDB.fallback_font,Vector2(20,48),"TIME BREAKER",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("fff0a5"))
	_draw_pointer()
func _draw_pointer() -> void:
	if not show_virtual_pointer: return
	draw_arc(virtual_pointer,8,0,TAU,24,Color("ffffff"),2.0)
	draw_line(virtual_pointer-Vector2(12,0),virtual_pointer+Vector2(12,0),Color("ffcb70"),1.5)
	draw_line(virtual_pointer-Vector2(0,12),virtual_pointer+Vector2(0,12),Color("ffcb70"),1.5)
func _draw_symbol(point: Vector2, radius: float) -> void:
	draw_circle(point,radius,Color("193e4d")); draw_arc(point,radius+2,0,TAU,48,Color("83e1e7"),2.0)
	if symbol!=null: draw_texture_rect(symbol,Rect2(point-Vector2.ONE*radius*.8,Vector2.ONE*radius*1.6),false)
