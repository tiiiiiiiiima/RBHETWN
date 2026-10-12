extends RefCounted
## Prototype fields, Workshop board, and native DS fields adapted to shared cards.

const DS_FIELD_PALETTE = {
	"background": Color("243d76"), "ambient": Color("f2f4ff"),
	"key": Color("ffffff"), "fill": Color("a5b9de"),
	"warm": Color("ffbb66"), "cold": Color("6adaff"),
	"floor": Color("566b89"), "base": Color("172c4c"),
	"edge": Color("dcecff"), "grid": Color("a7b7d7"),
	"slot": Color("455576"), "stone": Color("6f89a0"),
	"crystal": Color("83e4ff"),
}

const ENTRIES = [
	{
		"id": "stadium",
		"title": "Неоновый стадион",
		"description": "Авторская арена прототипа: трибуны, тёмная площадка и яркие огни турнира.",
		"palette": {
			"background": Color("080b1a"),
			"ambient": Color("8093bc"),
			"key": Color("ccd8ff"),
			"fill": Color("798ee5"),
			"warm": Color("ff9a35"),
			"cold": Color("41d8f5"),
			"floor": Color("202a3e"),
			"base": Color("080f20"),
			"edge": Color("765df1"),
			"grid": Color("2d3953"),
			"slot": Color("172032"),
			"stone": Color("344b74"),
			"crystal": Color("41d8f5"),
		},
	},
	{
		"id": "canyon",
		"title": "Красный каньон",
		"description": "Авторская арена прототипа: уступы красного камня, тёплый песок и янтарные кристаллы.",
		"palette": {
			"background": Color("211020"),
			"ambient": Color("c69891"),
			"key": Color("ffe1b2"),
			"fill": Color("a6687e"),
			"warm": Color("ffad60"),
			"cold": Color("86b9d4"),
			"floor": Color("784c3a"),
			"base": Color("372230"),
			"edge": Color("ff732e"),
			"grid": Color("a36749"),
			"slot": Color("593b33"),
			"stone": Color("8b4e34"),
			"crystal": Color("ffbe72"),
		},
	},
	{
		"id": "glacier",
		"title": "Ледяной рубеж",
		"description": "Авторская арена прототипа: ледяные шпили, синяя площадка и холодное сияние кристаллов.",
		"palette": {
			"background": Color("071b33"),
			"ambient": Color("8fc1dc"),
			"key": Color("e4fcff"),
			"fill": Color("588ecb"),
			"warm": Color("c4edff"),
			"cold": Color("4bceff"),
			"floor": Color("164760"),
			"base": Color("0c2c45"),
			"edge": Color("61e9ff"),
			"grid": Color("2e7e9c"),
			"slot": Color("123a54"),
			"stone": Color("4b97b8"),
			"crystal": Color("a3f1ff"),
		},
	},
	{
		"id": "anime_board",
		"title": "Поле шести стихий",
		"description": "Поле из Bakugan Anime Style Format: исходная текстура доски и космическая панорама. Размер адаптирован под игру.",
		"source_origin": "source_table_board",
		"source_workshop": "https://steamcommunity.com/sharedfiles/filedetails/?id=3412700725",
		"palette": {
			"background": Color("041821"),
			"ambient": Color("b0d1d9"),
			"key": Color("efffff"),
			"fill": Color("8abcca"),
			"warm": Color("ffbe72"),
			"cold": Color("64ebed"),
			"floor": Color("144e64"),
			"base": Color("082630"),
			"edge": Color("9cefff"),
			"grid": Color("75bccb"),
			"slot": Color("104657"),
			"stone": Color("175a68"),
			"crystal": Color("a5f9ff"),
		},
	},
	{
		"id": "ds_toy",
		"title": "DS · игровая арена",
		"description": "Исходная 3D-арена Toythrow из твоей DS-версии: модели, текстуры и UV. Расстановка карт и размер поля адаптированы под текущие правила.",
		"source_origin": "user_ds_nitrofs",
		"ds_throw_group": "toy_throw",
		"ds_battle_group": "toy_battle",
		"palette": {
			"background": Color("243d76"), "ambient": Color("f2f4ff"),
			"key": Color("ffffff"), "fill": Color("a5b9de"),
			"warm": Color("ffbb66"), "cold": Color("6adaff"),
			"floor": Color("566b89"), "base": Color("172c4c"),
			"edge": Color("dcecff"), "grid": Color("a7b7d7"),
			"slot": Color("455576"), "stone": Color("6f89a0"),
			"crystal": Color("83e4ff"),
		},
	},
	{
		"id": "ds_anime",
		"title": "DS · поле аниме",
		"description": "Исходное animethrow из DS-версии с оригинальными текстурами. Размер и постановка карт адаптированы под текущую игру.",
		"source_origin": "user_ds_nitrofs",
		"ds_throw_group": "anime_throw",
		"ds_battle_group": "anime_battle",
		"palette": {
			"background": Color("071736"), "ambient": Color("d4e7ee"),
			"key": Color("f4ffff"), "fill": Color("9eafc3"),
			"warm": Color("ffca79"), "cold": Color("72e4ff"),
			"floor": Color("215868"), "base": Color("173847"),
			"edge": Color("b2ffff"), "grid": Color("87b7c4"),
			"slot": Color("234556"), "stone": Color("33798d"),
			"crystal": Color("a1f4ff"),
		},
	},
	{
		"id": "ds_pyrus", "title": "DS · Pyrus",
		"description": "Поле Pyrus: движущиеся платформы и исходные предметы. Лава отнимает 30 G при касании; Pyrus защищён. Опасные участки отмечены на мини-карте.",
		"source_origin": "user_ds_nitrofs", "ds_throw_group": "pyrus_throw", "ds_battle_group": "pyrus_battle", "palette": DS_FIELD_PALETTE,
	},
	{
		"id": "ds_aquos", "title": "DS · Aquos",
		"description": "Исходные арены броска и боя Aquos из DS-версии. Статические поверхности и препятствия измерены по исходной геометрии; движение и карты адаптированы для ПК.",
		"source_origin": "user_ds_nitrofs", "ds_throw_group": "aquos_throw", "ds_battle_group": "aquos_battle", "palette": DS_FIELD_PALETTE,
	},
	{
		"id": "ds_subterra", "title": "DS · Subterra",
		"description": "Исходные арены броска и боя Subterra из DS-версии. Статические поверхности и препятствия измерены по исходной геометрии; движение и карты адаптированы для ПК.",
		"source_origin": "user_ds_nitrofs", "ds_throw_group": "subterra_throw", "ds_battle_group": "subterra_battle", "palette": DS_FIELD_PALETTE,
	},
	{
		"id": "ds_haos", "title": "DS · Haos",
		"description": "Исходные арены броска и боя Haos из DS-версии. Статические поверхности и препятствия измерены по исходной геометрии; движение и карты адаптированы для ПК.",
		"source_origin": "user_ds_nitrofs", "ds_throw_group": "haos_throw", "ds_battle_group": "haos_battle", "palette": DS_FIELD_PALETTE,
	},
	{
		"id": "ds_darkus", "title": "DS · Darkus",
		"description": "Исходные арены броска и боя Darkus из DS-версии. Статические поверхности и препятствия измерены по исходной геометрии; движение и карты адаптированы для ПК.",
		"source_origin": "user_ds_nitrofs", "ds_throw_group": "darkus_throw", "ds_battle_group": "darkus_battle", "palette": DS_FIELD_PALETTE,
	},
	{
		"id": "ds_ventus", "title": "DS · Ventus",
		"description": "Исходные арены броска и боя Ventus из DS-версии. Статические поверхности и препятствия измерены по исходной геометрии; движение и карты адаптированы для ПК.",
		"source_origin": "user_ds_nitrofs", "ds_throw_group": "ventus_throw", "ds_battle_group": "ventus_battle", "palette": DS_FIELD_PALETTE,
	},
	{
		"id": "sfm_battle_field", "title": "SFM · поле Бакуган",
		"description": "Аниме-поле PenDragon из Steam: шесть стен стихий, пол и туман. Геометрия и текстуры исходные; размер и игровой профиль адаптированы для ПК.",
		"source_origin": "source_sfm_workshop",
		"source_workshop": "https://steamcommunity.com/sharedfiles/filedetails/?id=3256465343",
		"palette": DS_FIELD_PALETTE,
	},
]


static func normalize_id(value: Variant) -> String:
	if typeof(value) == TYPE_STRING:
		for entry: Dictionary in ENTRIES:
			if value == entry["id"]:
				return String(value)
	return "stadium"


static func get_entry(id: String) -> Dictionary:
	var normalized: String = normalize_id(id)
	for entry: Dictionary in ENTRIES:
		if entry["id"] == normalized:
			return entry.duplicate(true)
	return ENTRIES[0].duplicate(true)
