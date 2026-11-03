# 2.5D（試作）用の敵の技。2D のときは使わない。
# dz は奥行き方向の半分の幅。床に赤い範囲が予告され、奥行きや左右にずれればかわせる。
# 画面全体を覆う技（大咆哮などの at_self）は従来どおり「面攻撃」で、ジャンプかガードでしのぐ。
#   lane   : 横一列。狙われた奥行きの帯を床が走る → 奥か手前へずれてかわす
#   column : 縦一列。奥から手前まで貫く柱 → 左右へかわす
#   circle : 円。狙われた場所を中心に爆ぜる → どちらへでも離れればかわせる
extends RefCounted

const LANE := {"name": "地走り", "range": 900, "windup": 0.5, "active": 0.2, "recovery": 0.9, "power": 1.4, "cooldown": 6.5,
	"aoe": {"w": 1400, "h": 90, "dz": 24.0, "delay": 1.4, "hits": 1, "interval": 0.1, "shape": "lane"}, "depth_kind": "side"}
const COLUMN := {"name": "天穿ち", "range": 900, "windup": 0.5, "active": 0.2, "recovery": 0.9, "power": 1.5, "cooldown": 7.5,
	"aoe": {"w": 130, "h": 420, "dz": 999.0, "delay": 1.3, "hits": 1, "interval": 0.1, "shape": "column"}, "depth_kind": "lr"}
const CIRCLE := {"name": "爆砕", "range": 700, "windup": 0.5, "active": 0.2, "recovery": 0.8, "power": 1.3, "cooldown": 5.5,
	"aoe": {"w": 280, "h": 200, "dz": 46.0, "delay": 1.2, "hits": 1, "interval": 0.1, "shape": "circle"}, "depth_kind": "away"}


# 敵のデータに 2.5D 用の技を足したコピーを返す
static func augment(data: Dictionary, kind: String) -> Dictionary:
	var d: Dictionary = data.duplicate(true)
	var adds: Array = []
	if d.get("boss", false):
		adds = [LANE, COLUMN, CIRCLE]
	elif kind == "elite":
		adds = [LANE if d["ai"] in ["melee", "charger"] else CIRCLE]
	elif d["ai"] == "ranged":
		adds = [CIRCLE]
	elif d["ai"] == "charger":
		adds = [LANE]
	for a in adds:
		var at: Dictionary = a.duplicate(true)
		if not d.get("boss", false):
			# 雑魚は弱め・間隔長め・小さめ
			at["power"] *= 0.65
			at["cooldown"] *= 1.8
			at["aoe"]["w"] = min(at["aoe"]["w"], 220) if a == CIRCLE else at["aoe"]["w"]
		d["attacks"].append(at)
	return d
