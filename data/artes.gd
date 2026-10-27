# 術技データ。
# kind: tech=特技 / arcane=奥義 / spell=攻撃術 / heal=回復術 / support=補助術
# 特技は通常攻撃から、奥義は特技からキャンセルで繋がる（テイルズ伝統のチェイン）。
# mystic=秘奥義
extends RefCounted

const DATA := {
	# ---------- レン（剣） ----------
	"majinken": {
		"name": "魔神剣", "kind": "tech", "tp": 6,
		"startup": 0.10, "active": 0.06, "recovery": 0.28, "power": 1.1,
		"projectile": {"speed": 620, "w": 40, "h": 46, "life": 0.9, "pierce": false, "shape": "wave"},
		"color": Color(1.0, 0.85, 0.5), "desc": "地を這う衝撃波を放つ。",
	},
	"sougazan": {
		"name": "蒼破刃", "kind": "tech", "tp": 8,
		"startup": 0.08, "active": 0.10, "recovery": 0.30, "power": 0.9, "hits": 2, "hit_interval": 0.12,
		"reach": 90, "height": 90, "knock": 30, "launch": 0, "fx": "slash",
		"projectile": {"speed": 560, "w": 46, "h": 70, "life": 0.6, "pierce": true, "shape": "wave"},
		"color": Color(0.5, 0.8, 1.0), "desc": "斬撃と同時に蒼い衝撃波を飛ばす。",
	},
	"kogahazan": {
		"name": "虎牙破斬", "kind": "tech", "tp": 9,
		"startup": 0.06, "active": 0.30, "recovery": 0.30, "power": 0.95, "hits": 2, "hit_interval": 0.15,
		"reach": 80, "height": 120, "knock": 20, "launch": 520, "jump": 380, "fx": "rise",
		"color": Color(1.0, 0.6, 0.3), "desc": "斬り上げから斬り下ろす二段斬り。敵を打ち上げる。",
	},
	"akisasame": {
		"name": "秋沙雨", "kind": "arcane", "tp": 16,
		"startup": 0.08, "active": 0.55, "recovery": 0.35, "power": 0.55, "hits": 7, "hit_interval": 0.07,
		"reach": 96, "height": 60, "knock": 6, "dash": 90, "fx": "thrust",
		"color": Color(1.0, 0.95, 0.7), "desc": "目にも止まらぬ連続突き。",
	},
	"shishisenkou": {
		"name": "獅子戦吼", "kind": "arcane", "tp": 18,
		"startup": 0.16, "active": 0.14, "recovery": 0.40, "power": 2.4,
		"reach": 110, "height": 110, "knock": 420, "launch": 260, "fx": "lion",
		"color": Color(1.0, 0.7, 0.2), "desc": "獅子の闘気を叩きつけ、大きく吹き飛ばす。",
	},
	"souga": {
		"name": "魔神剣・双牙", "kind": "arcane", "tp": 14,
		"startup": 0.10, "active": 0.06, "recovery": 0.30, "power": 1.0,
		"projectile": {"speed": 640, "w": 44, "h": 52, "life": 0.9, "pierce": false, "shape": "wave", "count": 2, "interval": 0.14},
		"color": Color(1.0, 0.75, 0.4), "desc": "魔神剣を二連続で放つ。",
	},
	# ---------- アンジー（魔術） ----------
	"fireball": {
		"name": "ファイアボール", "kind": "spell", "tp": 8, "cast": 0.7, "power": 0.9, "element": "fire",
		"projectile": {"speed": 520, "w": 30, "h": 30, "life": 1.6, "pierce": false, "shape": "orb", "count": 3, "interval": 0.15, "homing": true},
		"color": Color(1.0, 0.45, 0.15), "desc": "火球を三つ放つ。",
	},
	"icicle": {
		"name": "アイシクル", "kind": "spell", "tp": 12, "cast": 1.1, "power": 0.7, "element": "ice",
		"aoe": {"w": 120, "h": 120, "delay": 0.2, "hits": 3, "interval": 0.18, "shape": "spikes"},
		"color": Color(0.6, 0.9, 1.0), "desc": "敵の足元から氷柱を突き上げる。",
	},
	"airthrust": {
		"name": "エアスラスト", "kind": "spell", "tp": 10, "cast": 0.9, "power": 0.45, "element": "wind",
		"aoe": {"w": 110, "h": 160, "delay": 0.1, "hits": 6, "interval": 0.1, "shape": "storm"},
		"color": Color(0.6, 1.0, 0.7), "desc": "真空の刃で敵を切り刻む。",
	},
	"thunderblade": {
		"name": "サンダーブレード", "kind": "spell", "tp": 22, "cast": 2.0, "power": 0.7, "element": "thunder",
		"aoe": {"w": 220, "h": 260, "delay": 0.35, "hits": 5, "interval": 0.12, "shape": "pillar"},
		"color": Color(1.0, 1.0, 0.4), "desc": "雷の剣を突き立て、周囲に放電する上級術。",
	},
	"eruption": {
		"name": "イラプション", "kind": "spell", "tp": 26, "cast": 2.3, "power": 0.6, "element": "fire",
		"aoe": {"w": 280, "h": 180, "delay": 0.4, "hits": 7, "interval": 0.1, "shape": "burst"},
		"color": Color(1.0, 0.35, 0.1), "desc": "地中からマグマを噴出させる上級術。",
	},
	"firstaid": {
		"name": "ファーストエイド", "kind": "heal", "tp": 9, "cast": 1.0, "heal": 1.1,
		"color": Color(0.6, 1.0, 0.6), "desc": "古式魔術の治癒術。味方一人のHPを回復する。",
	},
	"barrier": {
		"name": "バリアー", "kind": "support", "tp": 12, "cast": 1.0,
		"buff": {"stat": "def", "mult": 1.4, "time": 25.0, "all": true},
		"color": Color(0.6, 0.8, 1.0), "desc": "味方全員の防御力を上げる。",
	},
	# ---------- ソナ（銃） ----------
	"rapidshot": {
		"name": "ラピッドショット", "kind": "tech", "tp": 6,
		"startup": 0.08, "active": 0.05, "recovery": 0.24, "power": 0.6,
		"projectile": {"speed": 1000, "w": 18, "h": 10, "life": 0.8, "shape": "bullet", "count": 4, "interval": 0.07},
		"color": Color(1.0, 0.9, 0.5), "desc": "銃弾を素早く四連射する。",
	},
	"healbullet": {
		"name": "ヒールバレット", "kind": "heal", "tp": 9, "cast": 0.6, "heal": 1.0,
		"color": Color(0.5, 1.0, 0.7), "desc": "治癒薬を込めた弾で、味方一人のHPを回復する。",
	},
	"grenade": {
		"name": "グレネード", "kind": "tech", "tp": 9,
		"startup": 0.18, "active": 0.05, "recovery": 0.3, "power": 1.2, "element": "fire",
		"aoe": {"w": 130, "h": 110, "delay": 0.45, "hits": 1, "interval": 0.1, "shape": "burst", "range": 300},
		"color": Color(1.0, 0.55, 0.2), "desc": "爆薬を放り投げ、着弾点を吹き飛ばす。",
	},
	"stunbullet": {
		"name": "スタンバレット", "kind": "tech", "tp": 8,
		"startup": 0.12, "active": 0.05, "recovery": 0.26, "power": 0.8, "element": "thunder", "stun": 1.4,
		"projectile": {"speed": 900, "w": 22, "h": 14, "life": 0.9, "shape": "bullet"},
		"color": Color(1.0, 1.0, 0.4), "desc": "電撃弾で敵を痺れさせ、長く怯ませる。",
	},
	"raybullet": {
		"name": "レイバレット", "kind": "arcane", "tp": 16,
		"startup": 0.22, "active": 0.05, "recovery": 0.35, "power": 0.5, "element": "light",
		"projectile": {"speed": 1300, "w": 80, "h": 16, "life": 0.9, "pierce": true, "multi": 5, "shape": "lance"},
		"color": Color(0.7, 1.0, 1.0), "desc": "魔学の光線弾。敵を貫き、何度も焼き焦がす。",
	},
	"medicalfield": {
		"name": "メディカルフィールド", "kind": "heal", "tp": 20, "cast": 1.5, "heal": 0.8, "all": true,
		"color": Color(0.6, 1.0, 0.8), "desc": "治癒フィールドを展開し、味方全員を回復する。",
	},
	"revivebullet": {
		"name": "リヴァイブバレット", "kind": "heal", "tp": 26, "cast": 1.6, "heal": 0.5, "revive": true,
		"color": Color(1.0, 1.0, 0.6), "desc": "蘇生薬の弾丸。戦闘不能の味方を復活させる。",
	},
	"deadlyaim": {
		"name": "デッドリーエイム", "kind": "arcane", "tp": 18,
		"startup": 0.45, "active": 0.05, "recovery": 0.35, "power": 3.2,
		"projectile": {"speed": 1500, "w": 30, "h": 14, "life": 0.9, "shape": "bullet"},
		"color": Color(1.0, 0.5, 0.5), "desc": "狙い澄ました一撃必殺の狙撃。",
	},
	# ---------- ジン（刀） ※奥義は竹取物語の五つの宝にちなむ ----------
	"oborozuki": {
		"name": "朧月", "kind": "tech", "tp": 7,
		"startup": 0.12, "active": 0.16, "recovery": 0.28, "power": 1.5,
		"reach": 80, "height": 70, "knock": 120, "dash": 760, "fx": "iai",
		"color": Color(0.8, 0.85, 1.0), "desc": "月影のごとく踏み込み、居合で斬り抜ける。",
	},
	"tsubame": {
		"name": "燕の子安貝", "kind": "tech", "tp": 8,
		"startup": 0.06, "active": 0.28, "recovery": 0.3, "power": 0.8, "hits": 3, "hit_interval": 0.09,
		"reach": 84, "height": 130, "knock": 10, "launch": 560, "jump": 400, "fx": "rise",
		"color": Color(0.7, 0.9, 1.0), "desc": "燕のように舞い上がりながら斬り上げる。",
	},
	"hinezumi": {
		"name": "火鼠の皮衣", "kind": "tech", "tp": 8, "element": "fire",
		"startup": 0.08, "active": 0.2, "recovery": 0.28, "power": 0.75, "hits": 3, "hit_interval": 0.08,
		"reach": 100, "height": 90, "knock": 60, "fx": "slash",
		"color": Color(1.0, 0.45, 0.2), "desc": "燃えない衣の伝説を纏い、炎の刃で三度斬る。",
	},
	"taketori": {
		"name": "竹取一閃", "kind": "arcane", "tp": 15,
		"startup": 0.3, "active": 0.14, "recovery": 0.35, "power": 2.8,
		"reach": 150, "height": 100, "knock": 300, "dash": 500, "fx": "iai",
		"color": Color(0.9, 1.0, 0.7), "desc": "竹を割るがごとき神速の一閃。",
	},
	"ryuunotama": {
		"name": "龍の首の珠", "kind": "arcane", "tp": 18, "element": "thunder",
		"startup": 0.2, "active": 0.05, "recovery": 0.35, "power": 0.6,
		"aoe": {"w": 160, "h": 200, "delay": 0.25, "hits": 5, "interval": 0.1, "shape": "pillar", "range": 260},
		"color": Color(1.0, 1.0, 0.5), "desc": "龍の珠の力を借り、雷を呼び落とす。",
	},
	"hourai": {
		"name": "蓬莱の玉の枝", "kind": "arcane", "tp": 20,
		"startup": 0.08, "active": 0.7, "recovery": 0.35, "power": 0.45, "hits": 9, "hit_interval": 0.07,
		"reach": 110, "height": 100, "knock": 6, "dash": 50, "fx": "slash",
		"color": Color(1.0, 0.8, 0.9), "desc": "玉の枝のごとく枝分かれする無数の斬撃。",
	},
	# ---------- ジョン（格闘） ----------
	"renga": {
		"name": "連牙弾", "kind": "tech", "tp": 6,
		"startup": 0.04, "active": 0.36, "recovery": 0.24, "power": 0.45, "hits": 5, "hit_interval": 0.07,
		"reach": 70, "height": 70, "knock": 8, "dash": 60, "fx": "punch",
		"color": Color(1.0, 0.9, 0.6), "desc": "拳を連続で叩き込む。",
	},
	"shouhaken": {
		"name": "昇破拳", "kind": "tech", "tp": 8,
		"startup": 0.06, "active": 0.22, "recovery": 0.32, "power": 1.2, "hits": 2, "hit_interval": 0.1,
		"reach": 64, "height": 130, "knock": 10, "launch": 600, "jump": 420, "fx": "rise",
		"color": Color(1.0, 0.6, 0.4), "desc": "跳び上がりながらのアッパー。",
	},
	"kuuhazan": {
		"name": "空破衝", "kind": "tech", "tp": 7,
		"startup": 0.08, "active": 0.24, "recovery": 0.28, "power": 1.3,
		"reach": 70, "height": 70, "knock": 260, "dash": 620, "fx": "thrust",
		"color": Color(0.7, 1.0, 0.7), "desc": "一気に間合いを詰めて突進する。",
	},
	"bakusaishou": {
		"name": "爆砕掌", "kind": "arcane", "tp": 15,
		"startup": 0.14, "active": 0.12, "recovery": 0.36, "power": 2.6,
		"reach": 80, "height": 90, "knock": 360, "launch": 200, "fx": "burst",
		"color": Color(1.0, 0.5, 0.2), "desc": "闘気を込めた掌底で敵を爆砕する。",
	},
	"shikou": {
		"name": "獅吼爆砕陣", "kind": "arcane", "tp": 22,
		"startup": 0.20, "active": 0.40, "recovery": 0.45, "power": 0.8, "hits": 4, "hit_interval": 0.1,
		"reach": 200, "height": 120, "offset": -100, "knock": 200, "launch": 300, "fx": "quake",
		"color": Color(1.0, 0.8, 0.3), "desc": "地面を砕き、周囲の敵をまとめて吹き飛ばす。",
	},
}

const KIND_NAME := {"tech": "特技", "arcane": "奥義", "spell": "攻撃術", "heal": "回復術", "support": "補助術", "mystic": "秘奥義"}
