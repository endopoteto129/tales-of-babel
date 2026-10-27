# アイテム・料理データ
extends RefCounted

const DATA := {
	"apple_gel": {"name": "アップルグミ", "price": 40, "desc": "HPを30%回復する。", "hp": 0.3},
	"lemon_gel": {"name": "レモングミ", "price": 120, "desc": "HPを60%回復する。", "hp": 0.6},
	"orange_gel": {"name": "オレンジグミ", "price": 80, "desc": "TPを30%回復する。", "tp": 0.3},
	"mixed_gel": {"name": "ミックスグミ", "price": 180, "desc": "HPとTPを40%回復する。", "hp": 0.4, "tp": 0.4},
	"life_bottle": {"name": "ライフボトル", "price": 200, "desc": "戦闘不能を回復する。(HP25%)", "revive": 0.25},
}

# 焚火で作れる料理。次の3戦闘の間効果が続く。cook は得意なキャラ（作ると効果が上がる）
const RECIPES := {
	"onigiri": {"name": "おにぎり", "desc": "戦闘終了時にHPが15%回復する。", "effects": {"meal_heal": 0.15}, "best": "ren"},
	"curry": {"name": "フェルガリアカレー", "desc": "攻撃力が15%上がる。", "effects": {"atk_mult": 1.15}, "best": "john"},
	"herb_soup": {"name": "薬草スープ", "desc": "術技の消費TPが15%減る。", "effects": {"tp_cost_mult": 0.85}, "best": "sona"},
	"star_parfait": {"name": "星屑パフェ", "desc": "絆ゲージが50%たまった状態で戦闘開始。", "effects": {"link_start": 50.0}, "best": "angie"},
	"azuma_soba": {"name": "アヅマ蕎麦", "desc": "術技の威力が10%上がる。", "effects": {"damage_mult": 1.1}, "best": "jin"},
}
