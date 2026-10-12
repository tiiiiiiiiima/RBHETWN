extends SceneTree

const Catalog = preload("res://scripts/ds_playable_catalog.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	var manifest: Dictionary = Catalog.manifest()
	check(manifest.get("counts", {}).get("gates", 0) == 27, "27 playable native gates")
	check(manifest.get("counts", {}).get("abilities", 0) == 85, "85 playable native abilities")
	check(manifest.get("native_parameters", []).size() == 212, "all native numeric rows retained")
	check(Catalog.cards("special").is_empty(), "unsupported special effects excluded")
	for kind: String in ["gate", "ability"]:
		var defaults: Array[int] = Catalog.default_selection(kind)
		check(defaults.size()==3, "complete default selection " + kind)
		var deck: Array[Dictionary] = Catalog.make_deck(kind, defaults, 0)
		check(deck.size() == 3, "full starter " + kind)
		var colors: Array = Catalog.GATE_COLORS if kind == "gate" else Catalog.ABILITY_COLORS
		for i in range(deck.size()):
			check(deck[i]["color_type"] == colors[i], "one per color " + kind + str(i))
			check(deck[i]["rules_profile"] == "ds", "profile " + kind + str(i))
			check(deck[i]["source_key"] == deck[i]["key"], "native artwork " + kind + str(i))
		for bad: Array in [[-1,0,3], [NAN,INF,2.5], ["0",null,{}], [], [3], [0,1,2,4]]:
			check(Catalog.normalize_selection(kind, bad).size() == 3, "invalid selection normalized " + kind)
		check(Catalog.make_deck(kind, defaults, 2).is_empty(), "invalid owner " + kind)
		for stage in range(3):
			check(Catalog.enemy_deck(kind,stage).size() == 3, "enemy legal deck " + kind + str(stage))
	var drago: Dictionary = {"name":"Dragonoid", "attribute":"Pyrus", "g":320}
	var opponent: Dictionary = {"name":"Hydranoid", "attribute":"Darkus", "g":350}
	var context: Dictionary = {"owner":0,"gate_owner":0,"captured_count":2,"current_powers":[640,420]}
	check(Catalog.metadata(101)["boosts"] == {"Pyrus":150,"Aquos":50,"Subterra":70,"Haos":30,"Darkus":50,"Ventus":40}, "native Drago differs from console")
	check(Catalog.metadata(136)["boosts"]["Pyrus"] == 100, "native Leonidas gate")
	check(Catalog.metadata(306)["boosts"]["Ventus"] == 110, "native Stand Your Ground")
	check(Catalog.metadata(217)["boosts"]["Aquos"] == 150, "native silver")
	for card: Dictionary in Catalog.cards():
		check(card["source_card_id"] > 0, "native ID")
		check(card["parameter_source"]["native_g_units"].size() == 6, "six-column provenance")
		check(card["boosts"].size() == 6, "six G values")
		check(FileAccess.file_exists(str(card["path"])), "original artwork exists")
	var boost: Dictionary = Catalog.metadata(511)
	check(Catalog.can_play(boost, drago, opponent), "species attack legal")
	check(Catalog.bonus_for(boost, drago, opponent) == 200, "species power exact")
	check(not Catalog.can_play(boost, opponent, drago), "species restriction")
	var blue: Dictionary = Catalog.metadata(602)
	check(Catalog.bonus_for(blue,drago,opponent) == 60, "native ordinary power")
	check(not Catalog.can_play(blue,{"attribute":"Aquos"},drago), "zero native attribute cannot use")
	var home: Dictionary = Catalog.metadata(605)
	var aquos: Dictionary = {"name":"Preyas","attribute":"Aquos","g":300}
	check(Catalog.can_play(home,aquos,drago,"",true,context), "own gate legal")
	check(Catalog.bonus_for(home,aquos,drago,context) == 50, "own gate bonus")
	context["gate_owner"] = 1
	check(not Catalog.can_play(home,aquos,drago,"",true,context), "enemy gate rejects home")
	var enemy_gate: Dictionary = Catalog.metadata(607)
	check(Catalog.bonus_for(enemy_gate,aquos,drago,context) == 140, "opponent gate native bonus")
	context["gate_owner"] = 0
	check(not Catalog.can_play(enemy_gate,aquos,drago,"",true,context), "own gate rejects enemy card")
	var triangle: Dictionary = Catalog.metadata(619)
	check(Catalog.bonus_for(triangle,drago,opponent,context) == 100, "captured gates scale")
	context["captured_count"] = 0
	check(not Catalog.can_play(triangle,drago,opponent,"",true,context), "captured zero cannot waste card")
	check(not Catalog.can_play(Catalog.metadata(618),drago,opponent,"",true,{"captured_count":2}), "score card native attribute restriction")
	check(Catalog.bonus_for(Catalog.metadata(620),drago,opponent) == 90, "higher printed power native bonus")
	check(not Catalog.can_play(Catalog.metadata(620),opponent,drago), "higher printed condition")
	check(Catalog.can_play(Catalog.metadata(408),drago,opponent,"",true,context), "counter swap diff attr")
	check(not Catalog.can_play(Catalog.metadata(407),drago,opponent,"",true,context), "twin swap requires same attr")
	check(not Catalog.can_play(Catalog.metadata(402),drago,opponent,"",true,context), "attribute swap requires Aquos")
	check(Catalog.can_play(Catalog.metadata(401),drago,opponent,"",true,context), "Pyrus swap")
	check(not Catalog.can_play(Catalog.metadata(401),drago,opponent), "swap requires actual powers")
	for powers: Variant in [[1],[1,1],["1",2],[NAN,2],[1.5,2],{}]:
		check(not Catalog.can_play(Catalog.metadata(401),drago,opponent,"",true,{"owner":0,"current_powers":powers}), "malformed or equal swap powers")
	check(Catalog.can_play(Catalog.metadata(417),drago,opponent), "native Scratch Redo is supported")
	check(not Catalog.can_play(Catalog.metadata(417),drago,opponent,"scratch",false,{"redo_used":true}), "redo can be used once per owner in this battle")
	print(JSON.stringify({"test":"ds_playable_catalog","checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
