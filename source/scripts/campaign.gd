extends RefCounted
## An authored PC campaign; dialogue, progression prices and tactics are local.
const Roster = preload("res://scripts/roster.gd")
const Cards = preload("res://scripts/ds_playable_catalog.gd")
const Profiles = preload("res://scripts/ds_sphere_profiles.gd")
const STARTERS: Array[String] = ["serpenoid","falconeer","juggernoid"]
const EVOLUTIONS: Dictionary = {
	"dragonoid":{"to":"delta_dragonoid","chapter":4},
	"delta_dragonoid":{"to":"ultimate_dragonoid","chapter":6},
	"gorem":{"to":"hammer_gorem","chapter":4},
	"skyress":{"to":"storm_skyress","chapter":5},
	"tigrerra":{"to":"blade_tigrerra","chapter":3},
	"hydranoid":{"to":"dual_hydranoid","chapter":6},
}
const STAGES: Array[Dictionary] = [
	{"title":"Первый вызов","opponent":"Дэн","arena":"ds_toy","tactic":"balanced","team":["serpenoid","falconeer","juggernoid"],"attributes":["Pyrus","Ventus","Aquos"],"range":[45,80],"reward":"dragonoid","coins":90,"before":"Дэн: Начнём на знакомом поле. Сначала поймай карту, потом думай о силе.\nТы: Проверим, чей бросок точнее!","after":"Дэн: Хорошее начало. Драго присоединится к твоей команде — береги его и развивай."},
	{"title":"Течение меняет путь","opponent":"Маручо","arena":"ds_aquos","tactic":"control","team":["preyas","juggernoid","siege"],"attributes":["Aquos","Aquos","Aquos"],"range":[70,100],"reward":"preyas","coins":110,"before":"Маручо: Скорость без контроля ничего не решает. Я приберегу карты для выгодного боя.\nТы: Тогда заставлю тебя раскрыть их первым.","after":"Маручо: Ты умеешь менять план. Аквос открыт для свободных боёв, а Прейас готов помочь."},
	{"title":"Свет и натиск","opponent":"Руно","arena":"ds_haos","tactic":"pressure","team":["tigrerra","tentaclear","griffon"],"attributes":["Haos","Haos","Haos"],"range":[85,120],"reward":"tigrerra","coins":130,"before":"Руно: Я атакую сразу. Подготовь цепь способностей до начала мини-игры!\nТы: Отвечу в нужный момент.","after":"Руно: Отличная цепь. Тигрерра присоединяется к команде; её эволюция станет доступна после тренировки."},
	{"title":"Две сферы — одна карта","opponent":"Джули","arena":"ds_subterra","tactic":"double","team":["gorem","juggernoid","cycloid"],"attributes":["Subterra","Subterra","Subterra"],"range":[100,140],"reward":"gorem","coins":150,"before":"Джули: Зачем спорить о G, если можно захватить карту двойной постановкой?\nТы: Постараюсь занять её раньше.","after":"Джули: Ты следишь за всем полем. Горем и Субтерра открыты; теперь можно усилить Драго."},
	{"title":"Путь ветра","opponent":"Шун","arena":"ds_ventus","tactic":"precision","team":["skyress","falconeer","ravenoid"],"attributes":["Ventus","Ventus","Ventus"],"range":[115,155],"reward":"skyress","coins":180,"before":"Шун: Один точный бросок лучше трёх поспешных. Используй тормоз и обходи препятствия.\nТы: Учту направление ускорителей.","after":"Шун: Хороший контроль. Скайресс готова лететь с тобой; путь к огненной арене открыт."},
	{"title":"Испытание огнём","opponent":"Дэн","arena":"ds_pyrus","tactic":"offense","team":["delta_dragonoid","gorem","saurus"],"attributes":["Pyrus","Pyrus","Pyrus"],"range":[130,180],"reward":"hydranoid","coins":210,"before":"Дэн: Лава наказывает за низкую траекторию. Пайрус защищён, остальные могут перепрыгнуть очаг.\nТы: Выберу команду под поле.","after":"Дэн: Ты готов к финалу. Доступны новые эволюции и тёмная арена."},
	{"title":"Последняя маска","opponent":"Маскарад","arena":"ds_darkus","tactic":"counter","team":["alpha_hydranoid","reaper","laserman"],"attributes":["Darkus","Darkus","Darkus"],"range":[145,200],"reward":"leonidas","coins":250,"before":"Маскарад: Я дождусь твоих способностей и отвечу. Сила без плана бесполезна.\nТы: Тогда этот бой решит моя команда.","after":"Маскарад: Ты выдержал испытание. Кубок твой. Леонидас, аниме-поле и повторные испытания открыты."},
]
var chapter: int = 0
var completed: bool = false
var coins: int = 0
var claimed: Array[int] = []
var unlocked_species: Array[String] = STARTERS.duplicate()
var unlocked_arenas: Array[String] = ["ds_toy"]
var unlocked_cards: Array[String] = []
var levels: Dictionary = {}
var evolution_base: Dictionary = {}
var team: Array[String] = STARTERS.duplicate()
var attributes: Array[String] = ["Pyrus","Ventus","Aquos"]
var decks: Dictionary = {"gate":[],"ability":[]}
func _init() -> void:
	for kind: String in ["gate","ability"]:
		var entries: Array[Dictionary]=Cards.cards(kind)
		for index: int in Cards.default_selection(kind):
			unlocked_cards.append(str(entries[index].key)); decks[kind].append(str(entries[index].key))
func stage() -> Dictionary:
	return STAGES[clampi(chapter,0,STAGES.size()-1)].duplicate(true)
static func species_index(id: String) -> int:
	for index: int in Roster.CREATURES.size():
		if str(Roster.CREATURES[index].id)==id: return index
	return -1
static func species_name(id: String) -> String:
	var index: int=species_index(id)
	return str(Roster.CREATURES[index].name) if index>=0 else id
func level(id: String) -> int:
	return clampi(int(levels.get(id,1)),1,5)
func upgrade_cost(id: String) -> int:
	return 35*level(id)
func upgrade(id: String) -> bool:
	if not unlocked_species.has(id) or level(id)>=5 or coins<upgrade_cost(id): return false
	coins-=upgrade_cost(id); levels[id]=level(id)+1
	return true
func evolution_error(id: String) -> String:
	if not unlocked_species.has(id) or not EVOLUTIONS.has(id): return "У этого вида нет доступной эволюции."
	if unlocked_species.has(str(EVOLUTIONS[id].to)): return "Эта эволюция уже открыта."
	if level(id)<3: return "Нужен уровень 3."
	if claimed.size()<int(EVOLUTIONS[id].chapter): return "Пройди главу %d." % int(EVOLUTIONS[id].chapter)
	if coins<120: return "Нужно 120 очков."
	return ""
func evolve(id: String) -> bool:
	if not evolution_error(id).is_empty(): return false
	var target: String=str(EVOLUTIONS[id].to)
	var index: int=team.find(id)
	var attribute: String=attributes[index] if index>=0 else "Pyrus"
	var source: Array[Dictionary]=Profiles.apply_team(Roster.make_team([species_index(id),species_index("serpenoid"),species_index("falconeer")],[attribute,"Pyrus","Ventus"],0,true))
	evolution_base[target]=int(evolution_base.get(id,source[0].g))+60
	coins-=120; unlocked_species.append(target); levels[target]=level(id)
	if index>=0: team[index]=target
	return true
func player_team() -> Array[Dictionary]:
	var indices: Array[int]=[]
	for id: String in team: indices.append(species_index(id))
	var result: Array[Dictionary]=Profiles.apply_team(Roster.make_team(indices,attributes,0,true))
	for index: int in result.size():
		var unit: Dictionary=result[index]; var id: String=team[index]; var training: int=level(id)-1
		unit["g"]=int(evolution_base.get(id,unit.g))+training*20
		unit["level"]=level(id); unit["campaign_species"]=id
		unit.motion_profile.control=mini(5,int(unit.motion_profile.control)+training/2)
		unit.motion_profile.steering=mini(5,int(unit.motion_profile.steering)+(training+1)/2)
		if training>0 or evolution_base.has(id):
			unit["g_verified"]=false; unit.motion_profile.verified=false
			unit["g_note"]="Развитие кампании ПК: +20 G/уровень, контроль/поворот; эволюция +60 G."
	return result
func enemy_team() -> Array[Dictionary]:
	var data: Dictionary=stage(); var indices: Array[int]=[]
	for id: String in data.team: indices.append(species_index(id))
	var result: Array[Dictionary]=Profiles.apply_team(Roster.make_team(indices,data.attributes,1,true))
	# Later unobserved variants use a campaign curve rather than anime G.
	for index: int in result.size():
		if not bool(result[index].get("g_verified",false)):
			result[index].g=210+chapter*18+index*10
			result[index].g_note="Баланс соперника кампании ПК."
	return result
func deck_indices(kind: String) -> Array[int]:
	var result: Array[int]=[]; var entries: Array[Dictionary]=Cards.cards(kind)
	for key: String in decks[kind]:
		for index: int in entries.size():
			if str(entries[index].key)==key: result.append(index); break
	return Cards.normalize_selection(kind,result)
func set_card(kind: String, slot: int, key: String) -> bool:
	var entry: Dictionary=Cards.metadata(key)
	var colors: Array=Cards.GATE_COLORS if kind=="gate" else Cards.ABILITY_COLORS
	if kind not in ["gate","ability"] or slot<0 or slot>2 or not unlocked_cards.has(key) or str(entry.get("kind",""))!=kind or str(entry.get("color_type",""))!=str(colors[slot]): return false
	decks[kind][slot]=key
	return true
func reward_preview(index: int) -> Dictionary:
	var data: Dictionary=STAGES[clampi(index,0,STAGES.size()-1)]
	var cards: Array[String]=[]
	for kind: String in ["gate","ability"]:
		var entries: Array[Dictionary]=Cards.cards(kind)
		var colors: Array=Cards.GATE_COLORS if kind=="gate" else Cards.ABILITY_COLORS
		for color: String in colors:
			var pool: Array[int]=Cards.indices_for_color(kind,color)
			for card_index: int in pool:
				var key: String=str(entries[card_index].key)
				if not unlocked_cards.has(key):
					cards.append(key)
					break
	return {"coins":int(data.coins),"species":str(data.reward),"arena":str(STAGES[mini(index+1,6)].arena) if index<6 else "ds_anime","cards":cards}
func record_result(won: bool, played_chapter: int) -> Dictionary:
	if not won or played_chapter!=chapter or claimed.has(played_chapter) or completed: return {}
	var reward: Dictionary=reward_preview(chapter)
	claimed.append(chapter); coins+=int(reward.coins)
	if not unlocked_species.has(reward.species): unlocked_species.append(reward.species)
	if not unlocked_arenas.has(reward.arena): unlocked_arenas.append(reward.arena)
	for key: String in reward.cards:
		if not unlocked_cards.has(key): unlocked_cards.append(key)
	if chapter==6: completed=true
	else: chapter+=1
	return reward
func to_dict() -> Dictionary:
	return {"schema":1,"chapter":chapter,"completed":completed,"coins":coins,"claimed":claimed.duplicate(),"species":unlocked_species.duplicate(),"arenas":unlocked_arenas.duplicate(),"cards":unlocked_cards.duplicate(),"levels":levels.duplicate(),"evolution_base":evolution_base.duplicate(),"team":team.duplicate(),"attributes":attributes.duplicate(),"decks":decks.duplicate(true)}
func load_dict(data: Dictionary) -> void:
	if data.get("schema",0)!=1: return
	claimed.clear()
	for i: int in STAGES.size():
		if data.get("claimed",[]) is Array and data.claimed.has(i) and i==claimed.size(): claimed.append(i)
	chapter=mini(claimed.size(),6); completed=claimed.size()==7
	coins=clampi(int(data.get("coins",0)) if typeof(data.get("coins")) in [TYPE_INT,TYPE_FLOAT] else 0,0,100000)
	for id: Variant in data.get("species",[]) if data.get("species",[]) is Array else []:
		if id is String and species_index(id)>=0 and not unlocked_species.has(id): unlocked_species.append(id)
	for id: Variant in data.get("arenas",[]) if data.get("arenas",[]) is Array else []:
		if id is String and id in ["ds_toy","ds_aquos","ds_haos","ds_subterra","ds_ventus","ds_pyrus","ds_darkus","ds_anime"] and not unlocked_arenas.has(id): unlocked_arenas.append(id)
	for key: Variant in data.get("cards",[]) if data.get("cards",[]) is Array else []:
		if key is String and not Cards.metadata(key).is_empty() and not unlocked_cards.has(key): unlocked_cards.append(key)
	for id: String in unlocked_species:
		var saved: Variant=data.get("levels",{}).get(id,1) if data.get("levels",{}) is Dictionary else 1
		var normalized: int=clampi(int(saved),1,5) if typeof(saved) in [TYPE_INT,TYPE_FLOAT] else 1
		if normalized>1: levels[id]=normalized
		var base: Variant=data.get("evolution_base",{}).get(id,0) if data.get("evolution_base",{}) is Dictionary else 0
		if typeof(base) in [TYPE_INT,TYPE_FLOAT] and int(base)>0: evolution_base[id]=clampi(int(base),1,2000)
	var selected: Variant=data.get("team",[])
	if selected is Array and selected.size()==3 and selected[0]!=selected[1] and selected[0]!=selected[2] and selected[1]!=selected[2]:
		if unlocked_species.has(selected[0]) and unlocked_species.has(selected[1]) and unlocked_species.has(selected[2]): team.assign(selected)
	attributes.assign(Roster.normalize_attributes(data.get("attributes",[]) if data.get("attributes",[]) is Array else []))
	for kind: String in ["gate","ability"]:
		var values: Variant=data.get("decks",{}).get(kind,[]) if data.get("decks",{}) is Dictionary else []
		if values is Array and values.size()==3:
			for slot: int in 3:
				if values[slot] is String: set_card(kind,slot,values[slot])
