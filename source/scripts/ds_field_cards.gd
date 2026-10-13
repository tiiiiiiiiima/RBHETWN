extends RefCounted
## Field pickups, separate from the three-card ability hand.
const Source=preload("res://scripts/ds_card_catalog.gd")
const IDS: Array[int]=[701,702,703,704,705,706,707,708,709,710,711,712]
const DESCRIPTIONS: Array[String]=[
	"После этого броска получишь ещё один, если есть доступный бакуган.",
	"Текущий бросок начинается заново; уже собранные предметы не возвращаются.",
	"При постановке замени ворота выбранной картой из своей руки.",
	"При постановке замени брошенного бакугана доступным резервным.",
	"Если сфера встанет на ворота, забери карту сразу.",
	"При постановке начни бой с противником на других воротах; мини-игра случайна.",
	"При постановке переместись на случайную карту ворот.",
	"После постановки защищает от Critical K.O.",
	"Удваивает G от предметов текущего броска, до +240 G.",
	"Заполняет счётчик S-Power до 100.",
	"Обнуляет G от предметов у стоящих бакуганов и текущей сферы.",
	"Удваивает G от предметов у стоящих бакуганов и текущей сферы, до +240 G."
]
static func metadata(key: String) -> Dictionary:
	var card: Dictionary=Source.metadata(key)
	var index: int=IDS.find(int(card.get("source_card_id",0)))
	if index<0: return {}
	card["description"]=DESCRIPTIONS[index]
	return card
static func title(id: int) -> String:
	return str(metadata("ds_card_%d" % id).get("name","Карта поля"))
static func initial() -> Dictionary:
	return {"ids":[],"multiplier":1,"invulnerable":false,"swap_gate":false,"replace_unit":false,"early":false,"surprise":false,"road_trip":false}
