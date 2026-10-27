# 塔の各層の設定
# deco: 背景の描き分け / scale: 敵ステータス倍率 / final: 頂上（一本道マップ）
extends RefCounted

# 全体の難易度調整（敵のHP倍率・攻撃力倍率）。boss_hp は層ごとのボスHP倍率
const ENEMY_HP_MULT := 1.6
const ENEMY_POWER_MULT := 1.45
const BOSS_POWER_MULT := 1.15

const DATA := [
	{
		"name": "第一層 始まりの草原", "sub": "塔の中に広がる、もうひとつの世界",
		"deco": "grass", "bg_top": Color(0.45, 0.65, 0.9), "bg_bottom": Color(0.55, 0.75, 0.45), "ground": Color(0.3, 0.45, 0.25), "accent": Color(1.0, 0.9, 0.5),
		"groups": [["slime"], ["slime", "slime"], ["wolf"], ["bat", "slime"]],
		"elites": [["golem"], ["wolf", "wolf"]],
		"boss": ["boss_beast"], "boss_hp": 2.6, "scale": 1.0,
	},
	{
		"name": "第二層 異形の街", "sub": "壁に囲まれた、魔物のいない街",
		"deco": "town", "bg_top": Color(0.25, 0.2, 0.35), "bg_bottom": Color(0.55, 0.42, 0.45), "ground": Color(0.35, 0.3, 0.3), "accent": Color(1.0, 0.7, 0.5),
		"groups": [["ikei", "slime"], ["wisp", "wolf"], ["bat", "bat", "wisp"], ["ikei", "ikei"]],
		"elites": [["golem", "wisp"], ["ikei", "ikei", "wisp"]],
		"boss": ["boss_siren"], "boss_hp": 2.3, "scale": 1.35,
	},
	{
		"name": "第三層 月下の竹林", "sub": "いつまでも明けない夜",
		"deco": "bamboo", "bg_top": Color(0.05, 0.07, 0.16), "bg_bottom": Color(0.12, 0.22, 0.2), "ground": Color(0.12, 0.2, 0.15), "accent": Color(1.0, 0.95, 0.75),
		"groups": [["oni", "oni"], ["oni", "wisp"], ["bat", "bat", "oni"], ["wolf", "oni"]],
		"elites": [["oni", "oni", "golem"], ["golem", "golem"]],
		"boss": ["boss_oni"], "boss_hp": 2.0, "scale": 1.8,
	},
	{
		"name": "第四層 忘れられた闘技場", "sub": "歓声の残響が消えない場所",
		"deco": "colosseum", "bg_top": Color(0.55, 0.35, 0.2), "bg_bottom": Color(0.8, 0.62, 0.4), "ground": Color(0.6, 0.45, 0.3), "accent": Color(1.0, 0.8, 0.4),
		"groups": [["lion", "soldier"], ["soldier", "soldier"], ["lion", "lion"], ["gunner", "soldier"]],
		"elites": [["soldier", "soldier", "gunner"], ["golem", "lion"]],
		"boss": ["boss_nene"], "boss_hp": 1.6, "scale": 2.3,
	},
	{
		"name": "第五層 星詠みの書庫", "sub": "誰かの『認識』が眠る場所",
		"deco": "library", "bg_top": Color(0.06, 0.05, 0.16), "bg_bottom": Color(0.22, 0.15, 0.36), "ground": Color(0.25, 0.18, 0.3), "accent": Color(0.75, 0.6, 1.0),
		"groups": [["book", "book"], ["mage_soldier", "soldier"], ["book", "wisp", "wisp"], ["gunner", "book"]],
		"elites": [["mage_soldier", "mage_soldier", "soldier"], ["golem", "book", "book"]],
		"boss": ["boss_val"], "boss_hp": 1.35, "scale": 2.9,
	},
	{
		"name": "第六層 機巧の大工房", "sub": "百年前の天才が遺したもの",
		"deco": "factory", "bg_top": Color(0.18, 0.12, 0.08), "bg_bottom": Color(0.42, 0.3, 0.16), "ground": Color(0.3, 0.24, 0.18), "accent": Color(1.0, 0.75, 0.3),
		"groups": [["gear", "drone"], ["soldier", "drone", "drone"], ["gear", "gear"], ["gunner", "gunner", "soldier"]],
		"elites": [["gear", "gear", "drone"], ["soldier", "mage_soldier", "gunner"]],
		"boss": ["boss_zone", "soldier", "gunner"], "boss_hp": 0.5, "scale": 3.6,
	},
	{
		"name": "頂上 神の座", "sub": "認識が真実になる場所",
		"deco": "summit", "bg_top": Color(0.3, 0.4, 0.75), "bg_bottom": Color(0.9, 0.82, 0.9), "ground": Color(0.85, 0.85, 0.9), "accent": Color(1.0, 0.95, 0.7),
		"groups": [["soldier", "soldier", "gunner"], ["drone", "drone", "mage_soldier"]],
		"elites": [["soldier", "mage_soldier", "gunner"]],
		"boss": ["boss_shasta"], "boss_hp": 0.45, "scale": 4.0, "final": true,
	},
]
