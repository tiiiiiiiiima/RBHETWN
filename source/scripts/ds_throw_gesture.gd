extends RefCounted
## DS tutorial: grab, quick upward stroke and lift; separate strokes steer.
var active: bool = false
var start: Vector2
var last: Vector2
var began: float = 0.0
var travel: float = 0.0
func begin(point: Vector2, time: float) -> void:
	active = point.is_finite() and is_finite(time)
	start = point
	last = point
	began = time
	travel = 0.0
func move(point: Vector2) -> void:
	if active and point.is_finite():
		travel += point.distance_to(last)
		last = point
func finish(point: Vector2, time: float, steering: bool = false) -> Dictionary:
	if not active:
		return {"valid":false}
	move(point)
	active = false
	var duration: float = maxf(0.016,time-began) if is_finite(time) else 99.0
	var delta: Vector2 = last-start
	var length: float = delta.length()
	var valid: bool = length>=18.0 and duration<=0.8 if steering else -delta.y>=40.0 and duration<=0.85 and -delta.y>absf(delta.x)*0.45
	return {"valid":valid,"direction":delta.normalized(),"power":clampf(length/duration/850.0,0.05,1.0),"duration":duration}
func cancel() -> void:
	active = false
