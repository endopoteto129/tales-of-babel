# 秘奥義（オーバーリミッツ中に秘奥義ゲージを使って放つ大技）
# 100%：レンの単独秘奥義、200%：レン＋仲間1人、300%：レン＋仲間2人の合体秘奥義。
# 仲間はその場で戦える中からランダムに選ぶ。lines はカットインの台詞（キャラごと）。
extends RefCounted

const SOLO := {
	"ren": {"name": "紅蓮・天穿斬", "power": 9.0, "hits": 14, "shape": "pillar", "element": "fire", "color": Color(1.0, 0.35, 0.25),
		"lines": {"ren": "ここで決める……！　天まで、穿て！"}},
	# 頂上（赤く染まった白衣を羽織った後）
	"ren_red": {"name": "絶対レッドスラッシュ", "power": 12.0, "hits": 18, "shape": "wave", "element": "light", "color": Color(1.0, 0.15, 0.2),
		"lines": {"ren": "――ぜったい、助ける！！"}},
}

# レン＋仲間1人。キーは仲間の id
const DUO := {
	"angie": {"name": "灼焔魔皇陣", "power": 14.0, "hits": 20, "shape": "pillar", "element": "fire", "color": Color(1.0, 0.45, 0.2)},
	"sona": {"name": "天穿つ流星弾", "power": 14.0, "hits": 22, "shape": "meteor", "element": "wind", "color": Color(0.5, 0.9, 1.0)},
	"jin": {"name": "月影・千刃竹取", "power": 14.0, "hits": 24, "shape": "spikes", "element": "ice", "color": Color(0.8, 0.9, 1.0)},
	"john": {"name": "覇王獅子吼撃", "power": 15.0, "hits": 16, "shape": "burst", "element": "earth", "color": Color(1.0, 0.75, 0.3)},
}

# レン＋仲間2人。キーは仲間2人の id を名前順に + でつないだもの
const TRIO := {
	"angie+sona": {"name": "星焔のレクイエム", "power": 21.0, "hits": 30, "shape": "meteor", "element": "fire", "color": Color(1.0, 0.55, 0.6)},
	"angie+jin": {"name": "月下紅蓮華", "power": 21.0, "hits": 30, "shape": "pillar", "element": "fire", "color": Color(1.0, 0.5, 0.7)},
	"angie+john": {"name": "焦天覇王撃", "power": 22.0, "hits": 26, "shape": "burst", "element": "fire", "color": Color(1.0, 0.6, 0.2)},
	"jin+sona": {"name": "千夜一閃・流星群", "power": 21.0, "hits": 34, "shape": "storm", "element": "wind", "color": Color(0.6, 0.85, 1.0)},
	"john+sona": {"name": "轟天砲撃陣", "power": 22.0, "hits": 28, "shape": "meteor", "element": "earth", "color": Color(1.0, 0.8, 0.45)},
	"jin+john": {"name": "剛月一刀破", "power": 22.0, "hits": 26, "shape": "wave", "element": "ice", "color": Color(0.85, 0.85, 1.0)},
}

# 合体秘奥義でのカットイン台詞。人数（2 or 3）ごと
const LINES := {
	2: {
		"ren": "合わせろ……これが俺たちの全力だ！",
		"angie": "いいわ、燃やし尽くしてあげる！",
		"sona": "照準、ロック――外さない！",
		"jin": "ほな、月まで斬り上げたろか！",
		"john": "うおおおッ！　砕けろォ！",
	},
	3: {
		"ren": "みんな、行くぞ――！",
		"angie": "あたしたちの魔法、見せてあげる！",
		"sona": "背中は任せて。……全部、撃ち抜く！",
		"jin": "この一撃、物語の見せ場にしたるわ！",
		"john": "……オレたちは、負けん！",
	},
}


static func pick(level: int, allies: Array) -> Dictionary:
	var md: Dictionary
	var lines := {}
	if level <= 1 or allies.is_empty():
		var key = "ren_red" if Game.flags.get("red_cape", false) else "ren"
		md = SOLO[key].duplicate()
		lines = md["lines"]
	else:
		var ids: Array = allies.duplicate()
		ids.sort()
		if level == 2 or ids.size() == 1:
			md = DUO[ids[0]].duplicate()
		else:
			md = TRIO["+".join(ids)].duplicate()
		var n = 1 + ids.size()
		for cid in ["ren"] + ids:
			lines[cid] = LINES[n].get(cid, "")
	md["lines"] = lines
	md["members"] = ["ren"] + allies
	return md
