extends RefCounted
## Names/effects from native mes_myroom 22-33. Motion curves are PC fits.
const PATH: String="res://assets/ds/special_shots.json"
const ATTRIBUTES: Array[String]=["Pyrus","Aquos","Subterra","Haos","Darkus","Ventus"]
const TITLES: Array[String]=["Pyrus Strike","Aquos Spiral","Subterra Quake","Haos Lightning","Darkus Critical","Ventus Storm"]
const DESCRIPTIONS: Array[String]=[
	"Скорость и силовая атака при столкновении. Может выполнить Critical K.O.",
	"Сильная непрерывная коррекция направления во время полёта и качения.",
	"Высокий бросок. Убирает бакуганов с карты приземления и соседних ворот.",
	"При контакте с соперником убирает бакуганов со всего поля.",
	"Проходит без Sphere Attack; после постановки защищён от выбивания.",
	"При контакте сдувает соперника с ворот. Защищает от Critical K.O."
]
static func available(unit: Dictionary, s: int, mode: String="quick") -> bool:
	return ATTRIBUTES.has(str(unit.get("attribute",""))) and s>=100 and (mode!="campaign" or int(unit.get("level",1))>=3)
static func title(attribute: String) -> String:
	var index: int=ATTRIBUTES.find(attribute)
	return TITLES[index] if index>=0 else "Обычный бросок"
static func description(attribute: String) -> String:
	var index: int=ATTRIBUTES.find(attribute)
	return DESCRIPTIONS[index] if index>=0 else ""
static func protected(attribute: String) -> bool:
	return attribute in ["Darkus","Ventus"]
