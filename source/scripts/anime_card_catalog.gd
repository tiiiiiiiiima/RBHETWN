extends RefCounted
## Verified, self-contained card subset for local anime card duels.
## English text and raw source statistics are preserved without interpreting costs.

const SOURCE_URL: String = "https://bloxugan.info/json/cards.json?=v14"
const ATTRIBUTES: Array[String] = ["Aquos", "Darkus", "Haos", "Pyrus", "Subterra", "Ventus"]
const GATE_LOADOUT_SIZE: int = 6
const ABILITY_LOADOUT_SIZE: int = 10

const GATES: Array[Dictionary] = [
	{
		"id": "aquos_30",
		"key": "aquos_30",
		"title": "Aquos 30",
		"description": "Aquos Bakugan present on the Gate Card gain +30 G's.",
		"description_ru": "Бакуганы стихии Aquos, находящиеся на карте ворот, получают +30 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].aquos[0]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 50,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Aquos",
		"boosts": {
			"Aquos": 30
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 30
		}
	},
	{
		"id": "aquos_50",
		"key": "aquos_50",
		"title": "Aquos 50",
		"description": "Aquos Bakugan present on the Gate Card gain +50 G's.",
		"description_ru": "Бакуганы стихии Aquos, находящиеся на карте ворот, получают +50 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].aquos[1]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 75,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Aquos",
		"boosts": {
			"Aquos": 50
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 50
		}
	},
	{
		"id": "aquos_70",
		"key": "aquos_70",
		"title": "Aquos 70",
		"description": "Aquos Bakugan present on the Gate Card gain +70 G's.",
		"description_ru": "Бакуганы стихии Aquos, находящиеся на карте ворот, получают +70 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].aquos[2]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 100,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Aquos",
		"boosts": {
			"Aquos": 70
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 70
		}
	},
	{
		"id": "aquos_80",
		"key": "aquos_80",
		"title": "Aquos 80",
		"description": "Aquos Bakugan present on the Gate Card gain +80 G's.",
		"description_ru": "Бакуганы стихии Aquos, находящиеся на карте ворот, получают +80 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].aquos[3]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 150,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Aquos",
		"boosts": {
			"Aquos": 80
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 80
		}
	},
	{
		"id": "aquos_100",
		"key": "aquos_100",
		"title": "Aquos 100",
		"description": "Aquos Bakugan present on the Gate Card gain +100 G's.",
		"description_ru": "Бакуганы стихии Aquos, находящиеся на карте ворот, получают +100 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].aquos[4]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 200,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Aquos",
		"boosts": {
			"Aquos": 100
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 100
		}
	},
	{
		"id": "aquos_120",
		"key": "aquos_120",
		"title": "Aquos 120",
		"description": "Aquos Bakugan present on the Gate Card gain +120 G's.",
		"description_ru": "Бакуганы стихии Aquos, находящиеся на карте ворот, получают +120 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].aquos[5]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 250,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Aquos",
		"boosts": {
			"Aquos": 120
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 120
		}
	},
	{
		"id": "aquos_150",
		"key": "aquos_150",
		"title": "Aquos 150",
		"description": "Aquos Bakugan present on the Gate Card gain +150 G's.",
		"description_ru": "Бакуганы стихии Aquos, находящиеся на карте ворот, получают +150 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].aquos[6]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 400,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Aquos",
		"boosts": {
			"Aquos": 150
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 150
		}
	},
	{
		"id": "aquos_180",
		"key": "aquos_180",
		"title": "Aquos 180",
		"description": "Aquos Bakugan present on the Gate Card gain +180 G's.",
		"description_ru": "Бакуганы стихии Aquos, находящиеся на карте ворот, получают +180 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].aquos[7]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 800,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Aquos",
		"boosts": {
			"Aquos": 180
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 180
		}
	},
	{
		"id": "aquos_200",
		"key": "aquos_200",
		"title": "Aquos 200",
		"description": "Aquos Bakugan present on the Gate Card gain +200 G's.",
		"description_ru": "Бакуганы стихии Aquos, находящиеся на карте ворот, получают +200 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].aquos[8]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 1250,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Aquos",
		"boosts": {
			"Aquos": 200
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 200
		}
	},
	{
		"id": "aquos_250",
		"key": "aquos_250",
		"title": "Aquos 250",
		"description": "Aquos Bakugan present on the Gate Card gain +250 G's.",
		"description_ru": "Бакуганы стихии Aquos, находящиеся на карте ворот, получают +250 G.",
		"type": "agc",
		"immediate": false,
		"limit": 1,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].aquos[9]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 3000,
				"limit": 1
			},
			"verified": true
		},
		"attribute": "Aquos",
		"boosts": {
			"Aquos": 250
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 250
		}
	},
	{
		"id": "darkus_30",
		"key": "darkus_30",
		"title": "Darkus 30",
		"description": "Darkus Bakugan present on the Gate Card gain +30 G's.",
		"description_ru": "Бакуганы стихии Darkus, находящиеся на карте ворот, получают +30 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].darkus[0]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 50,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Darkus",
		"boosts": {
			"Darkus": 30
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 30
		}
	},
	{
		"id": "darkus_50",
		"key": "darkus_50",
		"title": "Darkus 50",
		"description": "Darkus Bakugan present on the Gate Card gain +50 G's.",
		"description_ru": "Бакуганы стихии Darkus, находящиеся на карте ворот, получают +50 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].darkus[1]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 75,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Darkus",
		"boosts": {
			"Darkus": 50
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 50
		}
	},
	{
		"id": "darkus_70",
		"key": "darkus_70",
		"title": "Darkus 70",
		"description": "Darkus Bakugan present on the Gate Card gain +70 G's.",
		"description_ru": "Бакуганы стихии Darkus, находящиеся на карте ворот, получают +70 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].darkus[2]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 100,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Darkus",
		"boosts": {
			"Darkus": 70
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 70
		}
	},
	{
		"id": "darkus_80",
		"key": "darkus_80",
		"title": "Darkus 80",
		"description": "Darkus Bakugan present on the Gate Card gain +80 G's.",
		"description_ru": "Бакуганы стихии Darkus, находящиеся на карте ворот, получают +80 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].darkus[3]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 150,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Darkus",
		"boosts": {
			"Darkus": 80
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 80
		}
	},
	{
		"id": "darkus_100",
		"key": "darkus_100",
		"title": "Darkus 100",
		"description": "Darkus Bakugan present on the Gate Card gain +100 G's.",
		"description_ru": "Бакуганы стихии Darkus, находящиеся на карте ворот, получают +100 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].darkus[4]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 200,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Darkus",
		"boosts": {
			"Darkus": 100
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 100
		}
	},
	{
		"id": "darkus_120",
		"key": "darkus_120",
		"title": "Darkus 120",
		"description": "Darkus Bakugan present on the Gate Card gain +120 G's.",
		"description_ru": "Бакуганы стихии Darkus, находящиеся на карте ворот, получают +120 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].darkus[5]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 250,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Darkus",
		"boosts": {
			"Darkus": 120
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 120
		}
	},
	{
		"id": "darkus_150",
		"key": "darkus_150",
		"title": "Darkus 150",
		"description": "Darkus Bakugan present on the Gate Card gain +150 G's.",
		"description_ru": "Бакуганы стихии Darkus, находящиеся на карте ворот, получают +150 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].darkus[6]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 400,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Darkus",
		"boosts": {
			"Darkus": 150
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 150
		}
	},
	{
		"id": "darkus_180",
		"key": "darkus_180",
		"title": "Darkus 180",
		"description": "Darkus Bakugan present on the Gate Card gain +180 G's.",
		"description_ru": "Бакуганы стихии Darkus, находящиеся на карте ворот, получают +180 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].darkus[7]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 800,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Darkus",
		"boosts": {
			"Darkus": 180
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 180
		}
	},
	{
		"id": "darkus_200",
		"key": "darkus_200",
		"title": "Darkus 200",
		"description": "Darkus Bakugan present on the Gate Card gain +200 G's.",
		"description_ru": "Бакуганы стихии Darkus, находящиеся на карте ворот, получают +200 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].darkus[8]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 1250,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Darkus",
		"boosts": {
			"Darkus": 200
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 200
		}
	},
	{
		"id": "darkus_250",
		"key": "darkus_250",
		"title": "Darkus 250",
		"description": "Darkus Bakugan present on the Gate Card gain +250 G's.",
		"description_ru": "Бакуганы стихии Darkus, находящиеся на карте ворот, получают +250 G.",
		"type": "agc",
		"immediate": false,
		"limit": 1,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].darkus[9]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 3000,
				"limit": 1
			},
			"verified": true
		},
		"attribute": "Darkus",
		"boosts": {
			"Darkus": 250
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 250
		}
	},
	{
		"id": "haos_30",
		"key": "haos_30",
		"title": "Haos 30",
		"description": "Haos Bakugan present on the Gate Card gain +30 G's.",
		"description_ru": "Бакуганы стихии Haos, находящиеся на карте ворот, получают +30 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].haos[0]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 50,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Haos",
		"boosts": {
			"Haos": 30
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 30
		}
	},
	{
		"id": "haos_50",
		"key": "haos_50",
		"title": "Haos 50",
		"description": "Haos Bakugan present on the Gate Card gain +50 G's.",
		"description_ru": "Бакуганы стихии Haos, находящиеся на карте ворот, получают +50 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].haos[1]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 75,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Haos",
		"boosts": {
			"Haos": 50
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 50
		}
	},
	{
		"id": "haos_70",
		"key": "haos_70",
		"title": "Haos 70",
		"description": "Haos Bakugan present on the Gate Card gain +70 G's.",
		"description_ru": "Бакуганы стихии Haos, находящиеся на карте ворот, получают +70 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].haos[2]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 100,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Haos",
		"boosts": {
			"Haos": 70
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 70
		}
	},
	{
		"id": "haos_80",
		"key": "haos_80",
		"title": "Haos 80",
		"description": "Haos Bakugan present on the Gate Card gain +80 G's.",
		"description_ru": "Бакуганы стихии Haos, находящиеся на карте ворот, получают +80 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].haos[3]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 150,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Haos",
		"boosts": {
			"Haos": 80
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 80
		}
	},
	{
		"id": "haos_100",
		"key": "haos_100",
		"title": "Haos 100",
		"description": "Haos Bakugan present on the Gate Card gain +100 G's.",
		"description_ru": "Бакуганы стихии Haos, находящиеся на карте ворот, получают +100 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].haos[4]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 200,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Haos",
		"boosts": {
			"Haos": 100
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 100
		}
	},
	{
		"id": "haos_120",
		"key": "haos_120",
		"title": "Haos 120",
		"description": "Haos Bakugan present on the Gate Card gain +120 G's.",
		"description_ru": "Бакуганы стихии Haos, находящиеся на карте ворот, получают +120 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].haos[5]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 250,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Haos",
		"boosts": {
			"Haos": 120
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 120
		}
	},
	{
		"id": "haos_150",
		"key": "haos_150",
		"title": "Haos 150",
		"description": "Haos Bakugan present on the Gate Card gain +150 G's.",
		"description_ru": "Бакуганы стихии Haos, находящиеся на карте ворот, получают +150 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].haos[6]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 400,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Haos",
		"boosts": {
			"Haos": 150
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 150
		}
	},
	{
		"id": "haos_180",
		"key": "haos_180",
		"title": "Haos 180",
		"description": "Haos Bakugan present on the Gate Card gain +180 G's.",
		"description_ru": "Бакуганы стихии Haos, находящиеся на карте ворот, получают +180 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].haos[7]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 800,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Haos",
		"boosts": {
			"Haos": 180
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 180
		}
	},
	{
		"id": "haos_200",
		"key": "haos_200",
		"title": "Haos 200",
		"description": "Haos Bakugan present on the Gate Card gain +200 G's.",
		"description_ru": "Бакуганы стихии Haos, находящиеся на карте ворот, получают +200 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].haos[8]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 1250,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Haos",
		"boosts": {
			"Haos": 200
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 200
		}
	},
	{
		"id": "haos_250",
		"key": "haos_250",
		"title": "Haos 250",
		"description": "Haos Bakugan present on the Gate Card gain +250 G's.",
		"description_ru": "Бакуганы стихии Haos, находящиеся на карте ворот, получают +250 G.",
		"type": "agc",
		"immediate": false,
		"limit": 1,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].haos[9]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 3000,
				"limit": 1
			},
			"verified": true
		},
		"attribute": "Haos",
		"boosts": {
			"Haos": 250
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 250
		}
	},
	{
		"id": "pyrus_30",
		"key": "pyrus_30",
		"title": "Pyrus 30",
		"description": "Pyrus Bakugan present on the Gate Card gain +30 G's.",
		"description_ru": "Бакуганы стихии Pyrus, находящиеся на карте ворот, получают +30 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].pyrus[0]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 50,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Pyrus",
		"boosts": {
			"Pyrus": 30
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 30
		}
	},
	{
		"id": "pyrus_50",
		"key": "pyrus_50",
		"title": "Pyrus 50",
		"description": "Pyrus Bakugan present on the Gate Card gain +50 G's.",
		"description_ru": "Бакуганы стихии Pyrus, находящиеся на карте ворот, получают +50 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].pyrus[1]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 75,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Pyrus",
		"boosts": {
			"Pyrus": 50
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 50
		}
	},
	{
		"id": "pyrus_70",
		"key": "pyrus_70",
		"title": "Pyrus 70",
		"description": "Pyrus Bakugan present on the Gate Card gain +70 G's.",
		"description_ru": "Бакуганы стихии Pyrus, находящиеся на карте ворот, получают +70 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].pyrus[2]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 100,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Pyrus",
		"boosts": {
			"Pyrus": 70
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 70
		}
	},
	{
		"id": "pyrus_80",
		"key": "pyrus_80",
		"title": "Pyrus 80",
		"description": "Pyrus Bakugan present on the Gate Card gain +80 G's.",
		"description_ru": "Бакуганы стихии Pyrus, находящиеся на карте ворот, получают +80 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].pyrus[3]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 150,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Pyrus",
		"boosts": {
			"Pyrus": 80
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 80
		}
	},
	{
		"id": "pyrus_100",
		"key": "pyrus_100",
		"title": "Pyrus 100",
		"description": "Pyrus Bakugan present on the Gate Card gain +100 G's.",
		"description_ru": "Бакуганы стихии Pyrus, находящиеся на карте ворот, получают +100 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].pyrus[4]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 200,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Pyrus",
		"boosts": {
			"Pyrus": 100
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 100
		}
	},
	{
		"id": "pyrus_120",
		"key": "pyrus_120",
		"title": "Pyrus 120",
		"description": "Pyrus Bakugan present on the Gate Card gain +120 G's.",
		"description_ru": "Бакуганы стихии Pyrus, находящиеся на карте ворот, получают +120 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].pyrus[5]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 250,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Pyrus",
		"boosts": {
			"Pyrus": 120
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 120
		}
	},
	{
		"id": "pyrus_150",
		"key": "pyrus_150",
		"title": "Pyrus 150",
		"description": "Pyrus Bakugan present on the Gate Card gain +150 G's.",
		"description_ru": "Бакуганы стихии Pyrus, находящиеся на карте ворот, получают +150 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].pyrus[6]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 400,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Pyrus",
		"boosts": {
			"Pyrus": 150
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 150
		}
	},
	{
		"id": "pyrus_180",
		"key": "pyrus_180",
		"title": "Pyrus 180",
		"description": "Pyrus Bakugan present on the Gate Card gain +180 G's.",
		"description_ru": "Бакуганы стихии Pyrus, находящиеся на карте ворот, получают +180 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].pyrus[7]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 800,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Pyrus",
		"boosts": {
			"Pyrus": 180
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 180
		}
	},
	{
		"id": "pyrus_200",
		"key": "pyrus_200",
		"title": "Pyrus 200",
		"description": "Pyrus Bakugan present on the Gate Card gain +200 G's.",
		"description_ru": "Бакуганы стихии Pyrus, находящиеся на карте ворот, получают +200 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].pyrus[8]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 1250,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Pyrus",
		"boosts": {
			"Pyrus": 200
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 200
		}
	},
	{
		"id": "pyrus_250",
		"key": "pyrus_250",
		"title": "Pyrus 250",
		"description": "Pyrus Bakugan present on the Gate Card gain +250 G's.",
		"description_ru": "Бакуганы стихии Pyrus, находящиеся на карте ворот, получают +250 G.",
		"type": "agc",
		"immediate": false,
		"limit": 1,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].pyrus[9]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 3000,
				"limit": 1
			},
			"verified": true
		},
		"attribute": "Pyrus",
		"boosts": {
			"Pyrus": 250
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 250
		}
	},
	{
		"id": "subterra_30",
		"key": "subterra_30",
		"title": "Subterra 30",
		"description": "Subterra Bakugan present on the Gate Card gain +30 G's.",
		"description_ru": "Бакуганы стихии Subterra, находящиеся на карте ворот, получают +30 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].subterra[0]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 50,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Subterra",
		"boosts": {
			"Subterra": 30
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 30
		}
	},
	{
		"id": "subterra_50",
		"key": "subterra_50",
		"title": "Subterra 50",
		"description": "Subterra Bakugan present on the Gate Card gain +50 G's.",
		"description_ru": "Бакуганы стихии Subterra, находящиеся на карте ворот, получают +50 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].subterra[1]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 75,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Subterra",
		"boosts": {
			"Subterra": 50
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 50
		}
	},
	{
		"id": "subterra_70",
		"key": "subterra_70",
		"title": "Subterra 70",
		"description": "Subterra Bakugan present on the Gate Card gain +70 G's.",
		"description_ru": "Бакуганы стихии Subterra, находящиеся на карте ворот, получают +70 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].subterra[2]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 100,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Subterra",
		"boosts": {
			"Subterra": 70
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 70
		}
	},
	{
		"id": "subterra_80",
		"key": "subterra_80",
		"title": "Subterra 80",
		"description": "Subterra Bakugan present on the Gate Card gain +80 G's.",
		"description_ru": "Бакуганы стихии Subterra, находящиеся на карте ворот, получают +80 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].subterra[3]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 150,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Subterra",
		"boosts": {
			"Subterra": 80
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 80
		}
	},
	{
		"id": "subterra_100",
		"key": "subterra_100",
		"title": "Subterra 100",
		"description": "Subterra Bakugan present on the Gate Card gain +100 G's.",
		"description_ru": "Бакуганы стихии Subterra, находящиеся на карте ворот, получают +100 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].subterra[4]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 200,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Subterra",
		"boosts": {
			"Subterra": 100
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 100
		}
	},
	{
		"id": "subterra_120",
		"key": "subterra_120",
		"title": "Subterra 120",
		"description": "Subterra Bakugan present on the Gate Card gain +120 G's.",
		"description_ru": "Бакуганы стихии Subterra, находящиеся на карте ворот, получают +120 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].subterra[5]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 250,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Subterra",
		"boosts": {
			"Subterra": 120
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 120
		}
	},
	{
		"id": "subterra_150",
		"key": "subterra_150",
		"title": "Subterra 150",
		"description": "Subterra Bakugan present on the Gate Card gain +150 G's.",
		"description_ru": "Бакуганы стихии Subterra, находящиеся на карте ворот, получают +150 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].subterra[6]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 400,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Subterra",
		"boosts": {
			"Subterra": 150
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 150
		}
	},
	{
		"id": "subterra_180",
		"key": "subterra_180",
		"title": "Subterra 180",
		"description": "Subterra Bakugan present on the Gate Card gain +180 G's.",
		"description_ru": "Бакуганы стихии Subterra, находящиеся на карте ворот, получают +180 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].subterra[7]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 800,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Subterra",
		"boosts": {
			"Subterra": 180
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 180
		}
	},
	{
		"id": "subterra_200",
		"key": "subterra_200",
		"title": "Subterra 200",
		"description": "Subterra Bakugan present on the Gate Card gain +200 G's.",
		"description_ru": "Бакуганы стихии Subterra, находящиеся на карте ворот, получают +200 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].subterra[8]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 1250,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Subterra",
		"boosts": {
			"Subterra": 200
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 200
		}
	},
	{
		"id": "subterra_250",
		"key": "subterra_250",
		"title": "Subterra 250",
		"description": "Subterra Bakugan present on the Gate Card gain +250 G's.",
		"description_ru": "Бакуганы стихии Subterra, находящиеся на карте ворот, получают +250 G.",
		"type": "agc",
		"immediate": false,
		"limit": 1,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].subterra[9]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 3000,
				"limit": 1
			},
			"verified": true
		},
		"attribute": "Subterra",
		"boosts": {
			"Subterra": 250
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 250
		}
	},
	{
		"id": "ventus_30",
		"key": "ventus_30",
		"title": "Ventus 30",
		"description": "Ventus Bakugan present on the Gate Card gain +30 G's.",
		"description_ru": "Бакуганы стихии Ventus, находящиеся на карте ворот, получают +30 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].ventus[0]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 50,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Ventus",
		"boosts": {
			"Ventus": 30
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 30
		}
	},
	{
		"id": "ventus_50",
		"key": "ventus_50",
		"title": "Ventus 50",
		"description": "Ventus Bakugan present on the Gate Card gain +50 G's.",
		"description_ru": "Бакуганы стихии Ventus, находящиеся на карте ворот, получают +50 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].ventus[1]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 75,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Ventus",
		"boosts": {
			"Ventus": 50
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 50
		}
	},
	{
		"id": "ventus_70",
		"key": "ventus_70",
		"title": "Ventus 70",
		"description": "Ventus Bakugan present on the Gate Card gain +70 G's.",
		"description_ru": "Бакуганы стихии Ventus, находящиеся на карте ворот, получают +70 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].ventus[2]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 100,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Ventus",
		"boosts": {
			"Ventus": 70
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 70
		}
	},
	{
		"id": "ventus_80",
		"key": "ventus_80",
		"title": "Ventus 80",
		"description": "Ventus Bakugan present on the Gate Card gain +80 G's.",
		"description_ru": "Бакуганы стихии Ventus, находящиеся на карте ворот, получают +80 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].ventus[3]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 150,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Ventus",
		"boosts": {
			"Ventus": 80
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 80
		}
	},
	{
		"id": "ventus_100",
		"key": "ventus_100",
		"title": "Ventus 100",
		"description": "Ventus Bakugan present on the Gate Card gain +100 G's.",
		"description_ru": "Бакуганы стихии Ventus, находящиеся на карте ворот, получают +100 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].ventus[4]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 200,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Ventus",
		"boosts": {
			"Ventus": 100
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 100
		}
	},
	{
		"id": "ventus_120",
		"key": "ventus_120",
		"title": "Ventus 120",
		"description": "Ventus Bakugan present on the Gate Card gain +120 G's.",
		"description_ru": "Бакуганы стихии Ventus, находящиеся на карте ворот, получают +120 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].ventus[5]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 250,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Ventus",
		"boosts": {
			"Ventus": 120
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 120
		}
	},
	{
		"id": "ventus_150",
		"key": "ventus_150",
		"title": "Ventus 150",
		"description": "Ventus Bakugan present on the Gate Card gain +150 G's.",
		"description_ru": "Бакуганы стихии Ventus, находящиеся на карте ворот, получают +150 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].ventus[6]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 400,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Ventus",
		"boosts": {
			"Ventus": 150
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 150
		}
	},
	{
		"id": "ventus_180",
		"key": "ventus_180",
		"title": "Ventus 180",
		"description": "Ventus Bakugan present on the Gate Card gain +180 G's.",
		"description_ru": "Бакуганы стихии Ventus, находящиеся на карте ворот, получают +180 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].ventus[7]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 800,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Ventus",
		"boosts": {
			"Ventus": 180
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 180
		}
	},
	{
		"id": "ventus_200",
		"key": "ventus_200",
		"title": "Ventus 200",
		"description": "Ventus Bakugan present on the Gate Card gain +200 G's.",
		"description_ru": "Бакуганы стихии Ventus, находящиеся на карте ворот, получают +200 G.",
		"type": "agc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].ventus[8]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 1250,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Ventus",
		"boosts": {
			"Ventus": 200
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 200
		}
	},
	{
		"id": "ventus_250",
		"key": "ventus_250",
		"title": "Ventus 250",
		"description": "Ventus Bakugan present on the Gate Card gain +250 G's.",
		"description_ru": "Бакуганы стихии Ventus, находящиеся на карте ворот, получают +250 G.",
		"type": "agc",
		"immediate": false,
		"limit": 1,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].agc[0].ventus[9]",
			"raw_stats": {
				"gcp": 0,
				"hsp": 3000,
				"limit": 1
			},
			"verified": true
		},
		"attribute": "Ventus",
		"boosts": {
			"Ventus": 250
		},
		"effect": {
			"type": "attribute_gain",
			"amount": 250
		}
	},
	{
		"id": "energy_merge",
		"key": "energy_merge",
		"title": "Energy Merge",
		"description": "Automatically opens once a Bakugan from each side is on the Gate Card, transferring 125 G's from the last Bakugan thrown onto it to the first Bakugan that was on it.",
		"description_ru": "Автоматически открывается, когда на воротах находится хотя бы один бакуган с каждой стороны. Переносит 125 G от последнего брошенного на неё бакугана первому бакугану, находившемуся на карте.",
		"type": "cogc",
		"immediate": false,
		"limit": 1,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].cogc[0].1point[3]",
			"raw_stats": {
				"gcp": 1,
				"hsp": 675,
				"limit": 1
			},
			"verified": true
		},
		"boosts": {},
		"effect": {
			"type": "energy_merge",
			"amount": 125,
			"auto_open": true
		}
	},
	{
		"id": "aquos_hazard",
		"key": "aquos_hazard",
		"title": "Aquos Hazard",
		"description": "All Bakugan on the Gate Card are changed to Aquos.",
		"description_ru": "Все бакуганы на этой карте ворот меняют стихию на Aquos.",
		"type": "cogc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].cogc[0].1point[0]",
			"raw_stats": {
				"gcp": 1,
				"hsp": 300,
				"limit": 2
			},
			"verified": true
		},
		"boosts": {},
		"attribute": "Aquos",
		"effect": {
			"type": "hazard",
			"attribute": "Aquos"
		}
	},
	{
		"id": "darkus_hazard",
		"key": "darkus_hazard",
		"title": "Darkus Hazard",
		"description": "All Bakugan on the Gate Card are changed to Darkus.",
		"description_ru": "Все бакуганы на этой карте ворот меняют стихию на Darkus.",
		"type": "cogc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].cogc[0].1point[2]",
			"raw_stats": {
				"gcp": 1,
				"hsp": 300,
				"limit": 2
			},
			"verified": true
		},
		"boosts": {},
		"attribute": "Darkus",
		"effect": {
			"type": "hazard",
			"attribute": "Darkus"
		}
	},
	{
		"id": "haos_hazard",
		"key": "haos_hazard",
		"title": "Haos Hazard",
		"description": "All Bakugan on the Gate Card are changed to Haos.",
		"description_ru": "Все бакуганы на этой карте ворот меняют стихию на Haos.",
		"type": "cogc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].cogc[0].1point[5]",
			"raw_stats": {
				"gcp": 1,
				"hsp": 300,
				"limit": 2
			},
			"verified": true
		},
		"boosts": {},
		"attribute": "Haos",
		"effect": {
			"type": "hazard",
			"attribute": "Haos"
		}
	},
	{
		"id": "pyrus_hazard",
		"key": "pyrus_hazard",
		"title": "Pyrus Hazard",
		"description": "All Bakugan on the Gate Card are changed to Pyrus.",
		"description_ru": "Все бакуганы на этой карте ворот меняют стихию на Pyrus.",
		"type": "cogc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].cogc[0].1point[8]",
			"raw_stats": {
				"gcp": 1,
				"hsp": 300,
				"limit": 2
			},
			"verified": true
		},
		"boosts": {},
		"attribute": "Pyrus",
		"effect": {
			"type": "hazard",
			"attribute": "Pyrus"
		}
	},
	{
		"id": "subterra_hazard",
		"key": "subterra_hazard",
		"title": "Subterra Hazard",
		"description": "All Bakugan on the Gate Card are changed to Subterra.",
		"description_ru": "Все бакуганы на этой карте ворот меняют стихию на Subterra.",
		"type": "cogc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].cogc[0].1point[10]",
			"raw_stats": {
				"gcp": 1,
				"hsp": 300,
				"limit": 2
			},
			"verified": true
		},
		"boosts": {},
		"attribute": "Subterra",
		"effect": {
			"type": "hazard",
			"attribute": "Subterra"
		}
	},
	{
		"id": "ventus_hazard",
		"key": "ventus_hazard",
		"title": "Ventus Hazard",
		"description": "All Bakugan on the Gate Card are changed to Ventus.",
		"description_ru": "Все бакуганы на этой карте ворот меняют стихию на Ventus.",
		"type": "cogc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].cogc[0].1point[13]",
			"raw_stats": {
				"gcp": 1,
				"hsp": 300,
				"limit": 2
			},
			"verified": true
		},
		"boosts": {},
		"attribute": "Ventus",
		"effect": {
			"type": "hazard",
			"attribute": "Ventus"
		}
	},
	{
		"id": "positive_delta",
		"key": "positive_delta",
		"title": "Positive Delta",
		"description": "If the opponent's Bakugan is Pyrus, Aquos, or Haos, it loses -200 G's. Otherwise, the user's Bakugan loses -200 G's.",
		"description_ru": "Если бакуган соперника имеет стихию Pyrus, Aquos, Haos, он теряет 200 G. Иначе 200 G теряет твой бакуган.",
		"type": "cogc",
		"immediate": false,
		"limit": 1,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].cogc[0].2point[6]",
			"raw_stats": {
				"gcp": 2,
				"hsp": 300,
				"limit": 1
			},
			"verified": true
		},
		"boosts": {},
		"effect": {
			"type": "delta",
			"amount": 200,
			"pair": [
				"Pyrus",
				"Aquos",
				"Haos"
			]
		}
	},
	{
		"id": "negative_delta",
		"key": "negative_delta",
		"title": "Negative Delta",
		"description": "If the opponent's Bakugan is Darkus, Subterra, or Ventus, it loses -200 G's. Otherwise, the user's Bakugan loses -200 G's.",
		"description_ru": "Если бакуган соперника имеет стихию Darkus, Subterra, Ventus, он теряет 200 G. Иначе 200 G теряет твой бакуган.",
		"type": "cogc",
		"immediate": false,
		"limit": 1,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].cogc[0].2point[5]",
			"raw_stats": {
				"gcp": 2,
				"hsp": 300,
				"limit": 1
			},
			"verified": true
		},
		"boosts": {},
		"effect": {
			"type": "delta",
			"amount": 200,
			"pair": [
				"Darkus",
				"Subterra",
				"Ventus"
			]
		}
	},
	{
		"id": "peacemaker",
		"key": "peacemaker",
		"title": "Peacemaker",
		"description": "All Bakugan on the Gate Card are returned to their owners' hands.",
		"description_ru": "Все бакуганы на этой карте ворот возвращаются в руки своих владельцев.",
		"type": "cogc",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].cogc[0].1point[7]",
			"raw_stats": {
				"gcp": 1,
				"hsp": 250,
				"limit": 2
			},
			"verified": true
		},
		"boosts": {},
		"effect": {
			"type": "peacemaker"
		}
	}
]

const ABILITIES: Array[Dictionary] = [
	{
		"id": "correlation_aquos_ventus",
		"key": "correlation_aquos_ventus",
		"title": "Correlation: Aquos & Ventus",
		"description": "If there is a Ventus Bakugan on your Aquos Bakugan's Gate Card, your Aquos Bakugan gains +150 G's; if the other Bakugan is an ally, both Bakugan gain +100 G's instead; otherwise, your Bakugan gains +50 G's; vice versa applies.",
		"description_ru": "Если на воротах твоего Aquos находится Ventus соперника, твой Aquos получает +150 G. Если другой Ventus — союзник, оба получают по +100 G. Иначе твой бакуган получает +50 G. Действует и при перестановке стихий.",
		"type": "nac",
		"immediate": false,
		"limit": 3,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].nac[0].correlation[0]",
			"raw_stats": {
				"hsp": 75,
				"limit": 3
			},
			"verified": true
		},
		"attribute": [
			"Aquos",
			"Ventus"
		],
		"effect": {
			"type": "correlation",
			"amount": 50,
			"opposing_amount": 150,
			"allied_amount": 100,
			"pair": [
				"Aquos",
				"Ventus"
			]
		}
	},
	{
		"id": "correlation_darkus_aquos",
		"key": "correlation_darkus_aquos",
		"title": "Correlation: Darkus & Aquos",
		"description": "If there is an Aquos Bakugan on your Darkus Bakugan's Gate Card, your Darkus Bakugan gains +150 G's; if the other Bakugan is an ally, both Bakugan gain +100 G's instead; otherwise, your Bakugan gains +50 G's; vice versa applies.",
		"description_ru": "Если на воротах твоего Darkus находится Aquos соперника, твой Darkus получает +150 G. Если другой Aquos — союзник, оба получают по +100 G. Иначе твой бакуган получает +50 G. Действует и при перестановке стихий.",
		"type": "nac",
		"immediate": false,
		"limit": 3,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].nac[0].correlation[1]",
			"raw_stats": {
				"hsp": 75,
				"limit": 3
			},
			"verified": true
		},
		"attribute": [
			"Darkus",
			"Aquos"
		],
		"effect": {
			"type": "correlation",
			"amount": 50,
			"opposing_amount": 150,
			"allied_amount": 100,
			"pair": [
				"Darkus",
				"Aquos"
			]
		}
	},
	{
		"id": "correlation_haos_darkus",
		"key": "correlation_haos_darkus",
		"title": "Correlation: Haos & Darkus",
		"description": "If there is a Darkus Bakugan on your Haos Bakugan's Gate Card, your Haos Bakugan gains +150 G's; if the other Bakugan is an ally, both Bakugan gain +100 G's instead; otherwise, your Bakugan gains +50 G's; vice versa applies.",
		"description_ru": "Если на воротах твоего Haos находится Darkus соперника, твой Haos получает +150 G. Если другой Darkus — союзник, оба получают по +100 G. Иначе твой бакуган получает +50 G. Действует и при перестановке стихий.",
		"type": "nac",
		"immediate": false,
		"limit": 3,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].nac[0].correlation[2]",
			"raw_stats": {
				"hsp": 75,
				"limit": 3
			},
			"verified": true
		},
		"attribute": [
			"Haos",
			"Darkus"
		],
		"effect": {
			"type": "correlation",
			"amount": 50,
			"opposing_amount": 150,
			"allied_amount": 100,
			"pair": [
				"Haos",
				"Darkus"
			]
		}
	},
	{
		"id": "correlation_pyrus_subterra",
		"key": "correlation_pyrus_subterra",
		"title": "Correlation: Pyrus & Subterra",
		"description": "If there is a Subterra Bakugan on your Pyrus Bakugan's Gate Card, your Pyrus Bakugan gains +150 G's; if the other Bakugan is an ally, both Bakugan gain +100 G's instead; otherwise, your Bakugan gains +50 G's; vice versa applies.",
		"description_ru": "Если на воротах твоего Pyrus находится Subterra соперника, твой Pyrus получает +150 G. Если другой Subterra — союзник, оба получают по +100 G. Иначе твой бакуган получает +50 G. Действует и при перестановке стихий.",
		"type": "nac",
		"immediate": false,
		"limit": 3,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].nac[0].correlation[3]",
			"raw_stats": {
				"hsp": 75,
				"limit": 3
			},
			"verified": true
		},
		"attribute": [
			"Pyrus",
			"Subterra"
		],
		"effect": {
			"type": "correlation",
			"amount": 50,
			"opposing_amount": 150,
			"allied_amount": 100,
			"pair": [
				"Pyrus",
				"Subterra"
			]
		}
	},
	{
		"id": "correlation_subterra_haos",
		"key": "correlation_subterra_haos",
		"title": "Correlation: Subterra & Haos",
		"description": "If there is a Haos Bakugan on your Subterra Bakugan's Gate Card, your Subterra Bakugan gains +150 G's; if the other Bakugan is an ally, both Bakugan gain +100 G's instead; otherwise, your Bakugan gains +50 G's; vice versa applies.",
		"description_ru": "Если на воротах твоего Subterra находится Haos соперника, твой Subterra получает +150 G. Если другой Haos — союзник, оба получают по +100 G. Иначе твой бакуган получает +50 G. Действует и при перестановке стихий.",
		"type": "nac",
		"immediate": false,
		"limit": 3,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].nac[0].correlation[4]",
			"raw_stats": {
				"hsp": 75,
				"limit": 3
			},
			"verified": true
		},
		"attribute": [
			"Subterra",
			"Haos"
		],
		"effect": {
			"type": "correlation",
			"amount": 50,
			"opposing_amount": 150,
			"allied_amount": 100,
			"pair": [
				"Subterra",
				"Haos"
			]
		}
	},
	{
		"id": "correlation_ventus_pyrus",
		"key": "correlation_ventus_pyrus",
		"title": "Correlation: Ventus & Pyrus",
		"description": "If there is a Pyrus Bakugan on your Ventus Bakugan's Gate Card, your Ventus Bakugan gains +150 G's; if the other Bakugan is an ally, both Bakugan gain +100 G's instead; otherwise, your Bakugan gains +50 G's; vice versa applies.",
		"description_ru": "Если на воротах твоего Ventus находится Pyrus соперника, твой Ventus получает +150 G. Если другой Pyrus — союзник, оба получают по +100 G. Иначе твой бакуган получает +50 G. Действует и при перестановке стихий.",
		"type": "nac",
		"immediate": false,
		"limit": 3,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].nac[0].correlation[5]",
			"raw_stats": {
				"hsp": 75,
				"limit": 3
			},
			"verified": true
		},
		"attribute": [
			"Ventus",
			"Pyrus"
		],
		"effect": {
			"type": "correlation",
			"amount": 50,
			"opposing_amount": 150,
			"allied_amount": 100,
			"pair": [
				"Ventus",
				"Pyrus"
			]
		}
	},
	{
		"id": "aqua_guardian",
		"key": "aqua_guardian",
		"title": "Aqua Guardian",
		"description": "Negate the last Ability Card if it targets your Aquos Bakugan, is activated in battle involving your Aquos Bakugan, or alters the Gate Card it is standing on; this Ability Card cannot be activated in response to an immediate Ability Card.",
		"description_ru": "Отменяет последнюю карту способности, если она направлена на твоего Aquos, активирована в бою с его участием или изменяет карту ворот, на которой он стоит. Нельзя отвечать на немедленную карту способности.",
		"type": "nac",
		"immediate": false,
		"limit": 1,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].nac[0].aquos[1]",
			"raw_stats": {
				"hsp": 1000,
				"limit": 1
			},
			"verified": true
		},
		"attribute": "Aquos",
		"effect": {
			"type": "counter",
			"cannot_counter_immediate": true
		}
	},
	{
		"id": "double_dimension",
		"key": "double_dimension",
		"title": "Double Dimension",
		"description": "Negate the last Ability Card if it targets your Darkus Bakugan, is activated in battle involving your Darkus Bakugan, or alters the Gate Card it is standing on; this Ability Card cannot be activated in response to an immediate Ability Card.",
		"description_ru": "Отменяет последнюю карту способности, если она направлена на твоего Darkus, активирована в бою с его участием или изменяет карту ворот, на которой он стоит. Нельзя отвечать на немедленную карту способности.",
		"type": "nac",
		"immediate": false,
		"limit": 1,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].nac[0].darkus[7]",
			"raw_stats": {
				"hsp": 1000,
				"limit": 1
			},
			"verified": true
		},
		"attribute": "Darkus",
		"effect": {
			"type": "counter",
			"cannot_counter_immediate": true
		}
	},
	{
		"id": "ability_counter",
		"key": "ability_counter",
		"title": "Ability Counter",
		"description": "Negate the last Ability Card if it targets your Haos Bakugan, is activated in battle involving your Haos Bakugan, or alters the Gate Card it is standing on; this Ability Card cannot be activated in response to an immediate Ability Card.",
		"description_ru": "Отменяет последнюю карту способности, если она направлена на твоего Haos, активирована в бою с его участием или изменяет карту ворот, на которой он стоит. Нельзя отвечать на немедленную карту способности.",
		"type": "nac",
		"immediate": false,
		"limit": 1,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].nac[0].haos[0]",
			"raw_stats": {
				"hsp": 1000,
				"limit": 1
			},
			"verified": true
		},
		"attribute": "Haos",
		"effect": {
			"type": "counter",
			"cannot_counter_immediate": true
		}
	},
	{
		"id": "face_of_grief",
		"key": "face_of_grief",
		"title": "Face Of Grief",
		"description": "Fourtress immediately negates the last Ability Card if it targets Fourtress; is activated in a battle involving Fourtress; or alters the Gate Card it is standing on; this Ability Card cannot be activated in response to an immediate Ability Card.",
		"description_ru": "Fourtress немедленно отменяет последнюю карту способности, если она направлена на Fourtress, активирована в бою с его участием или изменяет карту ворот, на которой он стоит. Нельзя отвечать на немедленную карту способности.",
		"type": "sac",
		"immediate": true,
		"limit": 1,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].sac[0].fourtress[0]",
			"raw_stats": {
				"masteryLevel": [
					"35"
				],
				"gpd": "+05",
				"limit": 1
			},
			"verified": true
		},
		"species": "Fourtress",
		"effect": {
			"type": "counter",
			"cannot_counter_immediate": true
		}
	},
	{
		"id": "grand_down",
		"key": "grand_down",
		"title": "Grand Down",
		"description": "Nullify the Gate Card your Darkus Bakugan is standing on; that Gate Card cannot be opened in response.",
		"description_ru": "Отменяет действие карты ворот, на которой стоит твой Darkus. Эту карту ворот нельзя открыть в ответ.",
		"type": "nac",
		"immediate": false,
		"limit": 3,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].nac[0].darkus[8]",
			"raw_stats": {
				"hsp": 150,
				"limit": 3
			},
			"verified": true
		},
		"attribute": "Darkus",
		"effect": {
			"type": "nullify",
			"cannot_open_in_response": true
		}
	},
	{
		"id": "storm_breaker",
		"key": "storm_breaker",
		"title": "Storm Breaker",
		"description": "Nullify the Gate Card your Ventus Bakugan is standing on; that Gate Card cannot be opened in response.",
		"description_ru": "Отменяет действие карты ворот, на которой стоит твой Ventus. Эту карту ворот нельзя открыть в ответ.",
		"type": "nac",
		"immediate": false,
		"limit": 3,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].nac[0].ventus[8]",
			"raw_stats": {
				"hsp": 150,
				"limit": 3
			},
			"verified": true
		},
		"attribute": "Ventus",
		"effect": {
			"type": "nullify",
			"cannot_open_in_response": true
		}
	},
	{
		"id": "lightning_shield",
		"key": "lightning_shield",
		"title": "Lightning Shield",
		"description": "Your Haos Bakugan nullifies the Gate Card an allied Bakugan is standing on; that Gate Card cannot be opened in response.",
		"description_ru": "Твой Haos отменяет действие карты ворот, на которой стоит союзный бакуган. Эту карту ворот нельзя открыть в ответ.",
		"type": "nac",
		"immediate": false,
		"limit": 3,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].nac[0].haos[4]",
			"raw_stats": {
				"hsp": 175,
				"limit": 3
			},
			"verified": true
		},
		"attribute": "Haos",
		"effect": {
			"type": "nullify",
			"cannot_open_in_response": true
		}
	},
	{
		"id": "face_of_joy",
		"key": "face_of_joy",
		"title": "Face Of Joy",
		"description": "Fourtress immediately nullifies the Gate Card it is standing on.",
		"description_ru": "Fourtress немедленно отменяет действие карты ворот, на которой стоит.",
		"type": "sac",
		"immediate": true,
		"limit": 1,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].sac[0].fourtress[1]",
			"raw_stats": {
				"masteryLevel": [
					"45"
				],
				"gpd": "+15",
				"limit": 1
			},
			"verified": true
		},
		"species": "Fourtress",
		"effect": {
			"type": "nullify",
			"cannot_open_in_response": false
		}
	},
	{
		"id": "fire_tornado",
		"key": "fire_tornado",
		"title": "Fire Tornado",
		"description": "Transfer 100 G's from an opposing Bakugan in battle with your Pyrus Bakugan.",
		"description_ru": "Твой Pyrus переносит себе 100 G от бакугана соперника, с которым сражается.",
		"type": "nac",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].nac[0].pyrus[4]",
			"raw_stats": {
				"hsp": 450,
				"limit": 2
			},
			"verified": true
		},
		"attribute": "Pyrus",
		"effect": {
			"type": "transfer",
			"amount": 100
		}
	},
	{
		"id": "lightning_tornado",
		"key": "lightning_tornado",
		"title": "Lightning Tornado",
		"description": "Transfer 100 G's from an opposing Bakugan in battle with your Haos Bakugan.",
		"description_ru": "Твой Haos переносит себе 100 G от бакугана соперника, с которым сражается.",
		"type": "nac",
		"immediate": false,
		"limit": 1,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].nac[0].haos[5]",
			"raw_stats": {
				"hsp": 650,
				"limit": 1
			},
			"verified": true
		},
		"attribute": "Haos",
		"effect": {
			"type": "transfer",
			"amount": 100
		}
	},
	{
		"id": "face_of_rage",
		"key": "face_of_rage",
		"title": "Face Of Rage",
		"description": "Fourtress immediately transfers 50 G's from an opposing Bakugan it is in battle in.",
		"description_ru": "Fourtress немедленно переносит себе 50 G от бакугана соперника, с которым сражается.",
		"type": "sac",
		"immediate": true,
		"limit": 1,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].sac[0].fourtress[2]",
			"raw_stats": {
				"masteryLevel": [
					"27"
				],
				"gpd": "+20",
				"limit": 1
			},
			"verified": true
		},
		"species": "Fourtress",
		"effect": {
			"type": "transfer",
			"amount": 50
		}
	},
	{
		"id": "fire_storm",
		"key": "fire_storm",
		"title": "Fire Storm",
		"description": "Skyress gains +125 G's.",
		"description_ru": "Skyress получает +125 G.",
		"type": "sac",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].sac[0].skyress[0]",
			"raw_stats": {
				"masteryLevel": [
					"35",
					"45"
				],
				"gpd": "60",
				"limit": 2
			},
			"verified": true
		},
		"species": "Skyress",
		"effect": {
			"type": "gain",
			"amount": 125
		}
	},
	{
		"id": "alpha_blaster",
		"key": "alpha_blaster",
		"title": "Alpha Blaster",
		"description": "If Leonidas is in battle, it gains +200 G's; if that battle is on an opposing Gate Card, Leonidas gains +250 G's instead.",
		"description_ru": "В бою Leonidas получает +200 G. Если бой проходит на воротах соперника, вместо этого получает +250 G.",
		"type": "sac",
		"immediate": false,
		"limit": 1,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].sac[0].leonidas[0]",
			"raw_stats": {
				"masteryLevel": [
					"27"
				],
				"gpd": "+30",
				"limit": 1
			},
			"verified": true
		},
		"species": "Leonidas",
		"effect": {
			"type": "gain",
			"amount": 200,
			"opposing_amount": 250,
			"requires_battle": true
		}
	},
	{
		"id": "super_shard",
		"key": "super_shard",
		"title": "Super Shard",
		"description": "Juggernoid subtracts -75 G's from an opposing Bakugan.",
		"description_ru": "Juggernoid уменьшает G бакугана соперника на 75.",
		"type": "sac",
		"immediate": false,
		"limit": 2,
		"source": {
			"url": "https://bloxugan.info/json/cards.json?=v14",
			"path": "$[0].sac[0].juggernoid[1]",
			"raw_stats": {
				"masteryLevel": [
					"15",
					"45"
				],
				"ace-gpd": "+35",
				"gpd": "+30",
				"limit": 2
			},
			"verified": true
		},
		"species": "Juggernoid",
		"effect": {
			"type": "enemy_loss",
			"amount": 75
		}
	}
]


static func get_gate(id: String) -> Dictionary:
	return _lookup(GATES, id)


static func get_ability(id: String) -> Dictionary:
	return _lookup(ABILITIES, id)


static func normalize_attribute(value: Variant) -> String:
	if not value is String:
		return ""
	var identity: String = value.strip_edges().to_lower()
	for attribute: String in ATTRIBUTES:
		if attribute.to_lower() == identity:
			return attribute
	return ""


static func valid_gate_loadout(ids: Array) -> bool:
	return _valid_loadout(ids, GATES, GATE_LOADOUT_SIZE)


static func valid_ability_loadout(ids: Array) -> bool:
	return _valid_loadout(ids, ABILITIES, ABILITY_LOADOUT_SIZE)


static func default_gate_loadout(team: Array = []) -> Array[String]:
	var attribute_counts: Dictionary = {}
	for unit: Variant in team:
		if not unit is Dictionary:
			continue
		var attribute: String = normalize_attribute(unit.get("attribute", ""))
		if not attribute.is_empty():
			attribute_counts[attribute] = int(attribute_counts.get(attribute, 0)) + 1
	var ranked: Array[Dictionary] = []
	for index: int in range(ATTRIBUTES.size()):
		var attribute: String = ATTRIBUTES[index]
		ranked.append({"attribute": attribute, "score": attribute_counts.get(attribute, 0), "index": index})
	_sort_ranked(ranked)
	var primary: String = str(ranked[0].attribute) if not attribute_counts.is_empty() else "Pyrus"
	var secondary: String = str(ranked[1].attribute) if attribute_counts.size() > 1 else primary
	if attribute_counts.is_empty():
		secondary = "Aquos"
	var delta: String = "positive_delta" if ["Pyrus", "Aquos", "Haos"].has(primary) else "negative_delta"
	# Two matching moderate Attribute Gates and four different Command Gates
	# expose distinct tactical choices while respecting every source copy limit.
	return [
		primary.to_lower() + "_50",
		secondary.to_lower() + "_70",
		"energy_merge",
		primary.to_lower() + "_hazard",
		delta,
		"peacemaker"
	]


static func default_ability_loadout(team: Array = []) -> Array[String]:
	var units: Array = team
	if units.is_empty():
		units = [
			{"name": "Leonidas", "attribute": "Pyrus"},
			{"name": "Preyas", "attribute": "Aquos"},
			{"name": "Skyress", "attribute": "Ventus"}
		]
	var ranked: Array[Dictionary] = []
	for index: int in range(ABILITIES.size()):
		var card: Dictionary = ABILITIES[index]
		var compatible_count: int = 0
		for unit: Variant in units:
			if unit is Dictionary and compatible_caster(card, unit):
				compatible_count += 1
		var effect_type: String = str(card.effect.type)
		var priority: int = int({"counter": 40, "transfer": 35, "gain": 30, "enemy_loss": 25, "nullify": 20, "correlation": 10}.get(effect_type, 0))
		ranked.append({"id": card.id, "score": compatible_count * 100 + priority, "index": index, "limit": card.limit, "compatible": compatible_count > 0})
	_sort_ranked(ranked)
	var result: Array[String] = []
	# Prefer a range of usable cards before taking extra permitted copies.
	# For a team with fewer than ten supported usable copies, fill the remaining
	# slots legally; the duel UI still enforces each card's caster restriction.
	for require_compatible: bool in [true, false]:
		for copy_index: int in range(3):
			for candidate: Dictionary in ranked:
				if bool(candidate.compatible) != require_compatible or copy_index >= int(candidate.limit):
					continue
				result.append(str(candidate.id))
				if result.size() == ABILITY_LOADOUT_SIZE:
					return result
	return result


static func compatible_caster(card: Dictionary, unit: Dictionary) -> bool:
	var species: String = str(card.get("species", ""))
	if not species.is_empty():
		return _species_identity(species) == _species_identity(str(unit.get("species", unit.get("name", ""))))
	var attribute: String = normalize_attribute(unit.get("attribute", ""))
	if attribute.is_empty():
		return false
	var restriction: Variant = card.get("attribute", "")
	if restriction is Array:
		for candidate: Variant in restriction:
			if normalize_attribute(candidate) == attribute:
				return true
		return false
	return normalize_attribute(restriction) == attribute


static func _lookup(catalog: Array[Dictionary], id: String) -> Dictionary:
	for card: Dictionary in catalog:
		if str(card.id) == id:
			return card.duplicate(true)
	return {}


static func _valid_loadout(ids: Array, catalog: Array[Dictionary], required_size: int) -> bool:
	if ids.size() != required_size:
		return false
	var limits: Dictionary = {}
	for card: Dictionary in catalog:
		limits[str(card.id)] = int(card.limit)
	var copies: Dictionary = {}
	for id: Variant in ids:
		if not id is String or not limits.has(id):
			return false
		copies[id] = int(copies.get(id, 0)) + 1
		if int(copies[id]) > int(limits[id]):
			return false
	return true


static func _sort_ranked(ranked: Array[Dictionary]) -> void:
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.score) != int(b.score):
			return int(a.score) > int(b.score)
		return int(a.index) < int(b.index))


static func _species_identity(value: String) -> String:
	return value.strip_edges().to_lower().replace(" ", "").replace("_", "").replace("-", "").replace("'", "")
