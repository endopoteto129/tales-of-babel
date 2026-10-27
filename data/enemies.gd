# 敵データ。ステータスは「層1」基準で、層ごとに倍率（floors.gd の scale）がかかる。
# shape は描画の種類。humanoid 系は weapon で持ち物が変わる。
extends RefCounted

const DATA := {
	# ---------- 塔内生物 ----------
	"slime": {
		"name": "塔ぷにぷに", "shape": "slime", "color": Color(0.4, 0.8, 0.5), "size": Vector2(56, 44),
		"stats": {"hp": 240, "atk": 24, "def": 10, "matk": 10, "mdef": 8, "agi": 8},
		"ai": "melee", "speed": 110, "weak": ["fire"], "exp": 16, "gald": 20,
		"attacks": [
			{"name": "体当たり", "range": 70, "windup": 0.5, "active": 0.2, "recovery": 0.6, "power": 1.0, "reach": 60, "height": 50, "knock": 160, "dash": 260, "cooldown": 1.5},
		],
	},
	"bat": {
		"name": "ダスクバット", "shape": "bat", "color": Color(0.55, 0.35, 0.7), "size": Vector2(50, 36),
		"stats": {"hp": 190, "atk": 22, "def": 8, "matk": 10, "mdef": 10, "agi": 18},
		"ai": "flyer", "speed": 160, "fly": 110, "weak": ["wind", "light"], "exp": 18, "gald": 18,
		"attacks": [
			{"name": "急降下", "range": 90, "windup": 0.55, "active": 0.3, "recovery": 0.7, "power": 1.0, "reach": 56, "height": 60, "knock": 120, "dash": 300, "dive": true, "cooldown": 1.7},
		],
	},
	"wolf": {
		"name": "草原ウルフ", "shape": "wolf", "color": Color(0.5, 0.5, 0.6), "size": Vector2(80, 50),
		"stats": {"hp": 280, "atk": 28, "def": 12, "matk": 6, "mdef": 8, "agi": 22},
		"ai": "charger", "speed": 190, "weak": ["fire"], "exp": 24, "gald": 22,
		"attacks": [
			{"name": "牙突", "range": 260, "windup": 0.55, "active": 0.35, "recovery": 0.6, "power": 1.1, "reach": 60, "height": 50, "knock": 180, "dash": 560, "cooldown": 1.9},
		],
	},
	"golem": {
		"name": "苔むしたゴーレム", "shape": "golem", "color": Color(0.55, 0.6, 0.5), "size": Vector2(80, 110),
		"stats": {"hp": 600, "atk": 34, "def": 24, "matk": 8, "mdef": 10, "agi": 4},
		"ai": "melee", "speed": 60, "armor": 60, "weak": ["thunder"], "resist": ["fire"], "exp": 40, "gald": 40,
		"attacks": [
			{"name": "岩拳", "range": 100, "windup": 0.85, "active": 0.2, "recovery": 0.9, "power": 1.6, "reach": 100, "height": 90, "knock": 300, "cooldown": 2.0},
		],
	},
	"wisp": {
		"name": "ウィスプ", "shape": "wisp", "color": Color(0.5, 0.8, 1.0), "size": Vector2(40, 40),
		"stats": {"hp": 170, "atk": 14, "def": 6, "matk": 26, "mdef": 22, "agi": 12},
		"ai": "ranged", "speed": 90, "fly": 70, "weak": ["light"], "resist": ["ice"], "exp": 22, "gald": 24,
		"attacks": [
			{"name": "魔弾", "range": 520, "windup": 0.75, "active": 0.1, "recovery": 1.0, "power": 1.0, "magic": true,
				"projectile": {"speed": 340, "w": 26, "h": 26, "life": 2.5, "shape": "orb"}, "cooldown": 2.3},
		],
	},
	"ikei": {
		"name": "はぐれ異形", "shape": "ikei", "color": Color(0.6, 0.45, 0.7), "size": Vector2(60, 80),
		"stats": {"hp": 320, "atk": 28, "def": 14, "matk": 20, "mdef": 14, "agi": 12},
		"ai": "melee", "speed": 100, "weak": ["light"], "exp": 28, "gald": 30,
		"attacks": [
			{"name": "触腕", "range": 120, "windup": 0.6, "active": 0.25, "recovery": 0.6, "power": 1.1, "reach": 120, "height": 60, "knock": 140, "cooldown": 1.6},
		],
	},
	"oni": {
		"name": "竹林の小鬼", "shape": "oni", "color": Color(0.75, 0.3, 0.3), "size": Vector2(56, 76),
		"stats": {"hp": 300, "atk": 30, "def": 14, "matk": 8, "mdef": 10, "agi": 16},
		"ai": "charger", "speed": 150, "weak": ["ice"], "exp": 28, "gald": 28,
		"attacks": [
			{"name": "金棒", "range": 90, "windup": 0.5, "active": 0.2, "recovery": 0.5, "power": 1.2, "reach": 84, "height": 80, "knock": 200, "cooldown": 1.5},
			{"name": "突進", "range": 300, "windup": 0.6, "active": 0.3, "recovery": 0.6, "power": 1.1, "reach": 60, "height": 60, "knock": 220, "dash": 520, "cooldown": 2.4},
		],
	},
	"lion": {
		"name": "闘技場の獅子", "shape": "wolf", "color": Color(0.85, 0.65, 0.3), "size": Vector2(96, 60),
		"stats": {"hp": 420, "atk": 34, "def": 16, "matk": 6, "mdef": 10, "agi": 22},
		"ai": "charger", "speed": 200, "weak": ["ice"], "exp": 34, "gald": 30,
		"attacks": [
			{"name": "飛びかかり", "range": 280, "windup": 0.5, "active": 0.35, "recovery": 0.55, "power": 1.2, "reach": 70, "height": 60, "knock": 220, "dash": 620, "cooldown": 1.8},
		],
	},
	"book": {
		"name": "さまよう魔導書", "shape": "book", "color": Color(0.6, 0.4, 0.25), "size": Vector2(44, 36),
		"stats": {"hp": 220, "atk": 12, "def": 8, "matk": 32, "mdef": 26, "agi": 14},
		"ai": "ranged", "speed": 100, "fly": 90, "weak": ["fire"], "exp": 30, "gald": 34,
		"attacks": [
			{"name": "ページカッター", "range": 560, "windup": 0.7, "active": 0.1, "recovery": 0.9, "power": 0.6, "magic": true,
				"projectile": {"speed": 420, "w": 30, "h": 14, "life": 2.0, "shape": "lance", "count": 3, "interval": 0.15}, "cooldown": 2.6},
		],
	},
	"gear": {
		"name": "暴走歯車", "shape": "gearbot", "color": Color(0.75, 0.6, 0.3), "size": Vector2(64, 64),
		"stats": {"hp": 380, "atk": 32, "def": 22, "matk": 10, "mdef": 12, "agi": 12},
		"ai": "charger", "speed": 120, "armor": 30, "weak": ["thunder", "ice"], "exp": 34, "gald": 36,
		"attacks": [
			{"name": "回転突撃", "range": 300, "windup": 0.7, "active": 0.5, "recovery": 0.7, "power": 0.5, "reach": 64, "height": 64, "knock": 60, "dash": 420, "hits": 4, "cooldown": 2.4},
		],
	},
	# ---------- 王国軍 ----------
	"soldier": {
		"name": "王国兵", "shape": "humanoid", "weapon": "spear", "color": Color(0.45, 0.5, 0.65), "size": Vector2(50, 96),
		"stats": {"hp": 380, "atk": 30, "def": 18, "matk": 10, "mdef": 12, "agi": 14},
		"ai": "melee", "speed": 110, "guard": 0.25, "weak": [], "exp": 32, "gald": 40,
		"attacks": [
			{"name": "槍突き", "range": 110, "windup": 0.45, "active": 0.15, "recovery": 0.5, "power": 1.1, "reach": 110, "height": 50, "knock": 140, "cooldown": 1.3},
			{"name": "突撃", "range": 240, "windup": 0.65, "active": 0.3, "recovery": 0.7, "power": 1.4, "reach": 70, "height": 70, "knock": 260, "dash": 520, "cooldown": 3.0},
		],
	},
	"gunner": {
		"name": "王国銃兵", "shape": "humanoid", "weapon": "gun", "color": Color(0.4, 0.45, 0.55), "size": Vector2(50, 96),
		"stats": {"hp": 300, "atk": 30, "def": 12, "matk": 10, "mdef": 12, "agi": 14},
		"ai": "ranged", "speed": 100, "weak": [], "exp": 30, "gald": 42,
		"attacks": [
			{"name": "魔学銃", "range": 620, "windup": 0.8, "active": 0.1, "recovery": 0.9, "power": 0.7,
				"projectile": {"speed": 700, "w": 18, "h": 10, "life": 1.5, "shape": "bullet", "count": 2, "interval": 0.12}, "cooldown": 2.2},
		],
	},
	"drone": {
		"name": "魔学ドローン", "shape": "drone", "color": Color(0.6, 0.65, 0.7), "size": Vector2(50, 34),
		"stats": {"hp": 240, "atk": 20, "def": 16, "matk": 26, "mdef": 14, "agi": 16},
		"ai": "ranged", "speed": 130, "fly": 120, "weak": ["thunder"], "exp": 28, "gald": 40,
		"attacks": [
			{"name": "レーザー", "range": 600, "windup": 0.9, "active": 0.1, "recovery": 0.8, "power": 1.0, "magic": true,
				"projectile": {"speed": 800, "w": 50, "h": 8, "life": 1.2, "shape": "lance"}, "cooldown": 2.4},
		],
	},
	"mage_soldier": {
		"name": "王国魔学兵", "shape": "humanoid", "weapon": "rod", "color": Color(0.5, 0.35, 0.55), "size": Vector2(50, 92),
		"stats": {"hp": 320, "atk": 14, "def": 10, "matk": 32, "mdef": 24, "agi": 12},
		"ai": "ranged", "speed": 90, "weak": [], "exp": 34, "gald": 44,
		"attacks": [
			{"name": "フレイムランス", "range": 620, "windup": 1.2, "active": 0.1, "recovery": 1.0, "power": 1.2, "magic": true, "element": "fire",
				"aoe": {"w": 100, "h": 140, "delay": 0.6, "hits": 2, "interval": 0.15, "shape": "pillar"}, "cooldown": 3.0},
		],
	},
	# ---------- ボス ----------
	"boss_beast": {
		"name": "巨獣グランバウロス", "shape": "beast", "color": Color(0.5, 0.42, 0.35), "size": Vector2(190, 150),
		"stats": {"hp": 2400, "atk": 34, "def": 18, "matk": 20, "mdef": 14, "agi": 8},
		"ai": "boss", "speed": 80, "armor": 120, "boss": true, "weak": ["fire"], "exp": 200, "gald": 260,
		"attacks": [
			{"name": "爪撃", "range": 170, "windup": 0.7, "active": 0.2, "recovery": 0.8, "power": 1.4, "reach": 170, "height": 110, "knock": 300, "cooldown": 1.8},
			{"name": "突進", "range": 900, "windup": 1.0, "active": 0.7, "recovery": 1.0, "power": 1.5, "reach": 120, "height": 120, "knock": 380, "dash": 520, "cooldown": 4.5},
			{"name": "大咆哮", "range": 900, "windup": 1.4, "active": 0.2, "recovery": 1.2, "power": 1.2,
				"aoe": {"w": 1400, "h": 50, "delay": 0.0, "hits": 1, "interval": 0.1, "shape": "quake", "at_self": true}, "cooldown": 7.0, "phase": 1, "warn": "跳んで避けろ！"},
		],
	},
	"boss_siren": {
		"name": "水晶の歌姫セイレーン", "shape": "siren", "color": Color(0.45, 0.8, 0.95), "size": Vector2(90, 150),
		"stats": {"hp": 3600, "atk": 30, "def": 16, "matk": 40, "mdef": 28, "agi": 16},
		"ai": "boss", "speed": 90, "fly": 60, "armor": 110, "boss": true, "weak": ["thunder"], "resist": ["ice"], "exp": 360, "gald": 400,
		"attacks": [
			{"name": "アクアスパイク", "range": 900, "windup": 1.0, "active": 0.1, "recovery": 0.9, "power": 1.0, "magic": true, "element": "ice",
				"aoe": {"w": 120, "h": 150, "delay": 0.6, "hits": 3, "interval": 0.15, "shape": "spikes"}, "cooldown": 2.6},
			{"name": "水泡弾", "range": 900, "windup": 0.7, "active": 0.1, "recovery": 0.6, "power": 0.9, "magic": true,
				"projectile": {"speed": 300, "w": 30, "h": 30, "life": 3.2, "shape": "orb", "count": 4, "interval": 0.2, "homing": true}, "cooldown": 3.2},
			{"name": "滅びの旋律", "range": 900, "windup": 2.0, "active": 0.2, "recovery": 1.5, "power": 2.0, "magic": true,
				"aoe": {"w": 1400, "h": 400, "delay": 0.0, "hits": 1, "interval": 0.1, "shape": "wave", "at_self": true}, "cooldown": 12.0, "phase": 1, "warn": "ガードで耐えろ！", "guardable": true},
		],
	},
	"boss_oni": {
		"name": "月喰いの大鬼", "shape": "oni", "color": Color(0.55, 0.2, 0.3), "size": Vector2(140, 190),
		"stats": {"hp": 4800, "atk": 44, "def": 22, "matk": 24, "mdef": 18, "agi": 12},
		"ai": "boss", "speed": 90, "armor": 160, "boss": true, "weak": ["ice", "light"], "resist": ["fire"], "exp": 520, "gald": 520,
		"attacks": [
			{"name": "大金棒", "range": 170, "windup": 0.75, "active": 0.25, "recovery": 0.8, "power": 1.6, "reach": 170, "height": 140, "knock": 340, "cooldown": 1.7},
			{"name": "竹槍の雨", "range": 900, "windup": 1.0, "active": 0.1, "recovery": 0.8, "power": 0.9,
				"aoe": {"w": 140, "h": 220, "delay": 0.6, "hits": 3, "interval": 0.12, "shape": "spikes"}, "cooldown": 3.0},
			{"name": "月落とし", "range": 900, "windup": 1.5, "active": 0.2, "recovery": 1.2, "power": 1.5,
				"aoe": {"w": 1400, "h": 50, "delay": 0.0, "hits": 1, "interval": 0.1, "shape": "quake", "at_self": true}, "cooldown": 7.0, "phase": 1, "warn": "跳んで避けろ！"},
		],
	},
	"boss_nene": {
		"name": "幹部ネネ", "shape": "humanoid", "weapon": "blades", "mask": true, "color": Color(0.85, 0.4, 0.55), "size": Vector2(56, 104),
		"stats": {"hp": 6000, "atk": 46, "def": 22, "matk": 40, "mdef": 26, "agi": 26},
		"ai": "boss", "speed": 180, "armor": 120, "boss": true, "weak": [], "exp": 700, "gald": 600,
		"attacks": [
			{"name": "双刃乱舞", "range": 120, "windup": 0.45, "active": 0.4, "recovery": 0.5, "power": 0.6, "reach": 110, "height": 90, "knock": 40, "hits": 4, "cooldown": 1.4},
			{"name": "瞬影", "range": 500, "windup": 0.5, "active": 0.25, "recovery": 0.6, "power": 1.4, "reach": 80, "height": 80, "knock": 260, "dash": 900, "cooldown": 2.6},
			{"name": "呪いの言の葉", "range": 900, "windup": 1.0, "active": 0.1, "recovery": 0.8, "power": 0.8, "magic": true,
				"projectile": {"speed": 360, "w": 28, "h": 28, "life": 3.0, "shape": "orb", "count": 5, "interval": 0.15, "homing": true}, "cooldown": 3.4},
			{"name": "嘘つきへの罰", "range": 900, "windup": 2.0, "active": 0.2, "recovery": 1.4, "power": 2.0, "magic": true,
				"aoe": {"w": 1400, "h": 400, "delay": 0.0, "hits": 1, "interval": 0.1, "shape": "wave", "at_self": true}, "cooldown": 12.0, "phase": 1, "warn": "ガードで耐えろ！", "guardable": true},
		],
	},
	"boss_val": {
		"name": "幹部ヴァル", "shape": "humanoid", "weapon": "rod", "color": Color(0.3, 0.25, 0.45), "size": Vector2(54, 104),
		"stats": {"hp": 7200, "atk": 30, "def": 22, "matk": 46, "mdef": 36, "agi": 18},
		"ai": "boss", "speed": 110, "armor": 140, "boss": true, "weak": [], "resist": ["thunder"], "exp": 900, "gald": 800,
		"attacks": [
			{"name": "魔学砲", "range": 900, "windup": 0.8, "active": 0.1, "recovery": 0.6, "power": 0.9, "magic": true,
				"projectile": {"speed": 620, "w": 50, "h": 20, "life": 2.5, "shape": "lance", "count": 3, "interval": 0.15}, "cooldown": 2.6},
			{"name": "グラビティ", "range": 900, "windup": 1.0, "active": 0.1, "recovery": 0.8, "power": 0.8, "magic": true,
				"aoe": {"w": 180, "h": 180, "delay": 0.6, "hits": 4, "interval": 0.12, "shape": "storm"}, "cooldown": 2.8},
			{"name": "エクスプロード", "range": 900, "windup": 1.2, "active": 0.1, "recovery": 0.8, "power": 1.4, "magic": true, "element": "fire",
				"aoe": {"w": 240, "h": 180, "delay": 0.7, "hits": 2, "interval": 0.2, "shape": "burst"}, "cooldown": 4.0},
			{"name": "大義の裁き", "range": 900, "windup": 2.4, "active": 0.2, "recovery": 1.6, "power": 1.0, "magic": true,
				"aoe": {"w": 1400, "h": 500, "delay": 0.0, "hits": 4, "interval": 0.25, "shape": "meteor", "at_self": true}, "cooldown": 13.0, "phase": 1, "warn": "ガードで耐えろ！", "guardable": true},
		],
	},
	"boss_zone": {
		"name": "幹部ゾーン", "shape": "humanoid", "weapon": "gun", "coat": true, "color": Color(0.3, 0.32, 0.3), "size": Vector2(56, 108),
		"stats": {"hp": 8400, "atk": 44, "def": 26, "matk": 40, "mdef": 30, "agi": 20},
		"ai": "boss", "speed": 120, "armor": 160, "boss": true, "weak": [], "exp": 1100, "gald": 1000,
		"attacks": [
			{"name": "精密射撃", "range": 900, "windup": 0.6, "active": 0.1, "recovery": 0.5, "power": 0.9,
				"projectile": {"speed": 900, "w": 20, "h": 10, "life": 1.5, "shape": "bullet", "count": 3, "interval": 0.1}, "cooldown": 1.8},
			{"name": "地雷設置", "range": 900, "windup": 0.8, "active": 0.1, "recovery": 0.6, "power": 1.3, "element": "fire",
				"aoe": {"w": 120, "h": 100, "delay": 1.0, "hits": 1, "interval": 0.1, "shape": "burst"}, "cooldown": 3.2},
			{"name": "近接制圧", "range": 120, "windup": 0.4, "active": 0.2, "recovery": 0.5, "power": 1.3, "reach": 100, "height": 90, "knock": 300, "cooldown": 1.6},
			{"name": "包囲殲滅", "range": 900, "windup": 1.6, "active": 0.2, "recovery": 1.2, "power": 1.5,
				"aoe": {"w": 1400, "h": 50, "delay": 0.0, "hits": 1, "interval": 0.1, "shape": "quake", "at_self": true}, "cooldown": 7.0, "phase": 1, "warn": "跳んで避けろ！"},
		],
	},
	"boss_shasta": {
		"name": "王子シャスタ", "shape": "humanoid", "weapon": "sword", "crown": true, "color": Color(0.95, 0.85, 0.5), "size": Vector2(58, 112),
		"stats": {"hp": 11000, "atk": 46, "def": 30, "matk": 46, "mdef": 32, "agi": 22},
		"ai": "boss", "speed": 140, "armor": 200, "boss": true, "weak": [], "exp": 0, "gald": 0,
		"attacks": [
			{"name": "王剣", "range": 170, "windup": 0.55, "active": 0.25, "recovery": 0.6, "power": 1.5, "reach": 170, "height": 140, "knock": 320, "cooldown": 1.4},
			{"name": "勅命の雷", "range": 900, "windup": 1.0, "active": 0.1, "recovery": 0.7, "power": 0.9, "magic": true, "element": "thunder",
				"aoe": {"w": 140, "h": 300, "delay": 0.5, "hits": 3, "interval": 0.12, "shape": "pillar"}, "cooldown": 2.2},
			{"name": "王権の鎖", "range": 900, "windup": 1.4, "active": 0.2, "recovery": 1.0, "power": 1.4,
				"aoe": {"w": 1400, "h": 50, "delay": 0.0, "hits": 1, "interval": 0.1, "shape": "quake", "at_self": true}, "cooldown": 6.5, "phase": 1, "warn": "跳んで避けろ！"},
			{"name": "神罰の光", "range": 900, "windup": 2.4, "active": 0.2, "recovery": 1.4, "power": 2.2, "magic": true,
				"aoe": {"w": 1400, "h": 500, "delay": 0.0, "hits": 1, "interval": 0.1, "shape": "wave", "at_self": true}, "cooldown": 14.0, "phase": 2, "warn": "ガードで耐えろ！", "guardable": true},
		],
	},
}
