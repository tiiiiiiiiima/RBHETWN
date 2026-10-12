extends RefCounted
## Controls follow mes_tips_Dan 18–23; numerical timing/scoring are PC fits.
const MODES: Array[String] = ["scratch","spin","timing","pop","trace","bound"]
const NAMES: Dictionary = {"scratch":"SCRATCH · ТРИ СИМВОЛ","spin":"SPIN · КРУТИ СИМВОЛ","timing":"TIMING · ПОЙМАЙ В ЦЕНТРЕ","pop":"POP · НАЖМИ НА СИМВОЛ","trace":"TRACE · СЛЕДУЙ ЗА СИМВОЛОМ","bound":"BOUND · УДЕРЖИ СИМВОЛ"}
const HINTS: Dictionary = {"scratch":"Удерживай левую кнопку и быстро три знак стихии.","spin":"Зажми левую кнопку и описывай круг вокруг знака; движение туда-обратно не считается оборотом.","timing":"Нажимай центральное кольцо, когда к нему подходит знак с любой стороны.","pop":"Щёлкай появляющиеся знаки до их исчезновения; каждый знак засчитывается один раз.","trace":"Удерживай левую кнопку и веди курсор по движущемуся знаку.","bound":"Нажми на движущийся знак и удерживай курсор на нём до замедления и вспышки."}
static func choose(selection: String, round_index: int) -> String:
	return MODES[posmod(round_index,MODES.size())] if selection=="cycle" else selection if MODES.has(selection) else "scratch"
