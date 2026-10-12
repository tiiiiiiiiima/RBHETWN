extends Node
## Bounded measurements; no simulated FPS or cross-platform inference.
var game: Node
var phases: Dictionary = {}
var marks: Array[Dictionary] = []
var started_usec: int = Time.get_ticks_usec()
var frame_count: int = 0

func mark(label: String, elapsed_ms: float = -1.0) -> void:
	marks.append({"label":label,"elapsed_ms":elapsed_ms,"at_ms":(Time.get_ticks_usec()-started_usec)/1000.0,"static_memory_bytes":OS.get_static_memory_usage(),"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))})

func _process(delta: float) -> void:
	if not is_instance_valid(game): return
	var phase: String = "paused" if game.paused else str(game.phase)
	if not phases.has(phase): phases[phase]={"frames":0,"seconds":0.0,"frame_ms":[],"cpu_peak_ms":0.0,"static_peak_bytes":0,"video_peak_bytes":0,"nodes_peak":0,"orphans_peak":0}
	var sample: Dictionary = phases[phase]
	sample.frames+=1; sample.seconds+=delta; frame_count+=1
	if sample.frame_ms.size()<12000: sample.frame_ms.append(delta*1000.0)
	sample.cpu_peak_ms=maxf(sample.cpu_peak_ms,float(Performance.get_monitor(Performance.TIME_PROCESS))*1000.0)
	sample.static_peak_bytes=maxi(sample.static_peak_bytes,OS.get_static_memory_usage())
	sample.video_peak_bytes=maxi(sample.video_peak_bytes,int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)))
	sample.nodes_peak=maxi(sample.nodes_peak,int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	sample.orphans_peak=maxi(sample.orphans_peak,int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)))

func report() -> Dictionary:
	var result: Dictionary={}
	for phase: String in phases:
		var sample: Dictionary=phases[phase].duplicate(true)
		var times: Array=sample.frame_ms; times.sort(); sample.erase("frame_ms")
		sample.fps=sample.frames/maxf(sample.seconds,0.001)
		sample.frame_p95_ms=times[mini(times.size()-1,int(times.size()*0.95))] if not times.is_empty() else 0.0
		sample.frame_p99_ms=times[mini(times.size()-1,int(times.size()*0.99))] if not times.is_empty() else 0.0
		result[phase]=sample
	return {"os":OS.get_name(),"windows_execution_tested":OS.get_name()=="Windows","engine":Engine.get_version_info(),"adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"physical_gamepad_tested":false,"frames":frame_count,"marks":marks.duplicate(true),"phases":result,"process_memory":process_memory()}

static func process_memory() -> Dictionary:
	# Sample after the run, outside FPS measurement. No security settings change.
	if OS.get_name()=="Linux" and FileAccess.file_exists("/proc/self/status"):
		var data: Dictionary={"available":false,"source":"proc/self/status"}
		var file: FileAccess=FileAccess.open("/proc/self/status",FileAccess.READ)
		if file==null: return data
		var status: String=file.get_buffer(65536).get_string_from_utf8(); file.close()
		var pattern:=RegEx.new(); pattern.compile("^(VmRSS|VmHWM):\\s+(\\d+)\\s+kB$")
		for line: String in status.split("\n"):
			var found: RegExMatch=pattern.search(line)
			if found!=null: data["working_set_bytes" if found.get_string(1)=="VmRSS" else "peak_working_set_bytes"]=int(found.get_string(2))*1024
		data.available=data.has("working_set_bytes") and data.has("peak_working_set_bytes")
		return data
	if OS.get_name()=="Windows":
		var output: Array=[]
		var command: String="Get-Process -Id %d | Select-Object WorkingSet64,PeakWorkingSet64 | ConvertTo-Json -Compress" % OS.get_process_id()
		var code: int=OS.execute("powershell.exe",["-NoProfile","-NonInteractive","-Command",command],output,false)
		var parsed: Variant=JSON.parse_string("".join(output)) if code==0 else null
		if parsed is Dictionary and parsed.has("WorkingSet64") and parsed.has("PeakWorkingSet64"):
			return {"available":true,"source":"Get-Process","working_set_bytes":int(parsed.WorkingSet64),"peak_working_set_bytes":int(parsed.PeakWorkingSet64)}
		return {"available":false,"source":"Get-Process","exit_code":code}
	return {"available":false}
