# ボスのとどめ演出。ボスのHPが残り1になると、とどめボタン（オーバーリミッツと同じボタン）で発動する。
# members はカットインに出る順（最後がレン）。lines はキャラごとの台詞。shout があると最後に一語ずつ大きく叫ぶ。
extends RefCounted

const DATA := {
	"boss_beast": {"name": "解析一閃・弱点直撃", "color": Color(0.4, 0.9, 1.0), "members": ["pots", "ren"],
		"lines": {"pots": "弱点、右腕の付け根。……今です、レン！", "ren": "――そこか！"}},
	"boss_siren": {"name": "笑顔のアンコール", "color": Color(1.0, 0.7, 0.4), "members": ["nine", "ren"],
		"lines": {"nine": "歌はね、みんなを笑顔にするものなんだよ！　♪ら〜ら〜♪", "ren": "ナインの歌に、合わせる……！"}},
	"boss_oni": {"name": "月下竹取・鬼やらい", "color": Color(0.85, 0.9, 1.0), "members": ["jin", "ren"],
		"lines": {"jin": "鬼退治は、昔から月夜って決まっとるんや！", "ren": "続け、ジン！"}},
	"boss_nene": {"name": "真心一閃", "color": Color(1.0, 0.6, 0.75), "members": ["jin", "ren"],
		"lines": {"jin": "ネネさん。今度は、嘘やない言葉で迎えに来たで。", "ren": "ジン、道は俺が開ける！"}},
	"boss_val": {"name": "大義なき魔術・紅蓮天墜", "color": Color(1.0, 0.45, 0.2), "members": ["angie", "ren"],
		"lines": {"angie": "大義なんかなくたって――この一発は、本物よ！", "ren": "アンジー、合わせる！"}},
	"boss_zone": {"name": "リオ・レクイエム", "color": Color(0.5, 0.85, 1.0), "members": ["sona", "ren"],
		"lines": {"sona": "リオ、見てて。……あなたの隊長と、一緒に撃つから！", "ren": "ソナ、撃て！"}},
	"boss_shasta": {"name": "スーパー・レッドスラッシュ", "color": Color(1.0, 0.15, 0.2), "members": ["nine", "ren"],
		"lines": {"nine": "（……レ……ン……！　……スー、パー……！）", "ren": "お前がつけた名前だ。――聞いてろ、ナイン！"},
		"shout": ["スーパーッ！", "レッドッ！", "スラーッシュ！！"]},
}
