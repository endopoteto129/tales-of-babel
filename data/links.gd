# 共鳴秘技（絆ゲージ満タンで発動する、レンと仲間の合体技）
# キーは DB.pair_key で並べた2人のid。lines は各キャラのカットイン台詞（キャラごとに最初の1行を使う）。
extends RefCounted

const DATA := {
	"nine+ren": {"name": "ヒーロー・ブレイク", "power": 6.0, "hits": 8, "color": Color(1.0, 0.45, 0.35), "shape": "burst", "element": "light",
		"lines": [["nine", "がんばれー！　レーン！！"], ["ren", "……ああ。任せろ！"]]},
	"angie+ren": {"name": "紅蓮魔神剣", "power": 7.0, "hits": 10, "color": Color(1.0, 0.5, 0.2), "shape": "pillar", "element": "fire",
		"lines": [["ren", "合わせろ、アンジー！"], ["angie", "燃え上がれ、古の焔！"]]},
	"ren+sona": {"name": "クロスファイア・レクイエム", "power": 7.0, "hits": 12, "color": Color(0.5, 0.85, 1.0), "shape": "storm", "element": "wind",
		"lines": [["ren", "背中は任せた！"], ["sona", "……今度は、外さない！"]]},
	"jin+ren": {"name": "月下竹取一閃", "power": 7.0, "hits": 9, "color": Color(0.85, 0.9, 1.0), "shape": "spikes", "element": "ice",
		"lines": [["ren", "続け、ジン！"], ["jin", "ほな、月まで飛ばしたろか！"]]},
	"john+ren": {"name": "剣闘覇王撃", "power": 8.0, "hits": 7, "color": Color(1.0, 0.75, 0.3), "shape": "meteor", "element": "earth",
		"lines": [["ren", "ぶち抜くぞ、ジョン！"], ["john", "……おうッ！"]]},
}
