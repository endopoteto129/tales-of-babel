# データ整合性チェック（自動テストから呼ぶ）。会話の話者・表情、イベント結果の参照先などを検証する。
extends RefCounted

const EXPRS := ["", "smile", "laugh", "angry", "sad", "cry", "surprise", "serious", "cold", "think", "sweat", "blush"]
const RESULT_KEYS := ["gald", "item", "count", "hp", "tp", "buff", "exp", "recipe", "title", "bond", "sp", "msg", "battle", "lines", "chance", "success", "fail"]
const CHAT_KEYS := ["req", "lines", "who", "by", "boss", "floor", "floor_min", "floor_max", "flags", "not_flags"]

static var errors: Array = []


static func run() -> int:
	errors = []
	for sid in DB.Skits.DATA:
		_lines("skit " + sid, DB.Skits.DATA[sid]["lines"])
		if DB.Skits.DATA[sid].has("award"):
			_title("skit " + sid, DB.Skits.DATA[sid]["award"][0])
	for cid in DB.Skits.CAMP_ORDER:
		if not DB.Skits.CAMP.has(cid):
			errors.append("camp order missing " + cid)
	for cid in DB.Skits.CAMP:
		_lines("camp " + cid, DB.Skits.CAMP[cid]["lines"])
		if not cid in DB.Skits.CAMP_ORDER:
			errors.append("camp not in order " + cid)
	for ev in DB.Chats.DATA:
		for c in DB.Chats.DATA[ev]:
			for k in c.keys():
				if not k in CHAT_KEYS:
					errors.append("chat %s bad key %s" % [ev, k])
			for ln in c["lines"]:
				if ln.size() != 2 or not DB.Characters.DATA.has(ln[0]):
					errors.append("chat %s bad line %s" % [ev, str(ln)])
			if c.has("boss") and not DB.Enemies.DATA.has(c["boss"]):
				errors.append("chat bad boss " + c["boss"])
	for eid in DB.Events.DATA:
		var e: Dictionary = DB.Events.DATA[eid]
		for ch in e["choices"]:
			_result("event " + eid, ch.get("result", {}))
	for k in DB.Links.DATA:
		for ln in DB.Links.DATA[k]["lines"]:
			if not DB.Characters.DATA.has(ln[0]):
				errors.append("link %s bad speaker %s" % [k, ln[0]])
	for cid in ["angie", "jin", "john", "ren", "sona"]:
		if cid != "ren" and not DB.Links.DATA.has(DB.pair_key("ren", cid)):
			errors.append("link missing for " + cid)
	for sid in DB.Story.DATA:
		_lines("story " + sid, DB.Story.DATA[sid]["lines"])
	for e in errors:
		print("[validate] ", e)
	print("[validate] errors=", errors.size())
	return errors.size()


static func _lines(where: String, lines: Array) -> void:
	for ln in lines:
		var sp: String = ln[0]
		if sp.begins_with("@"):
			if sp == "@title":
				_title(where, ln[1])
			if sp == "@join" and not DB.Characters.DATA.has(ln[1]):
				errors.append(where + " bad join " + ln[1])
			continue
		if sp != "" and not DB.Characters.DATA.has(sp):
			errors.append("%s bad speaker %s" % [where, sp])
		if ln.size() > 2 and not ln[2] in EXPRS:
			errors.append("%s bad expr %s" % [where, ln[2]])
		if ln.size() < 2 or str(ln[1]) == "":
			errors.append("%s empty line %s" % [where, str(ln)])


static func _title(where: String, tid: String) -> void:
	if not DB.Titles.DATA.has(tid):
		errors.append(where + " bad title " + tid)


static func _result(where: String, r: Dictionary) -> void:
	for k in r.keys():
		if not k in RESULT_KEYS:
			errors.append("%s bad result key %s" % [where, k])
	if r.has("item") and not DB.Items.DATA.has(r["item"]):
		errors.append(where + " bad item " + r["item"])
	if r.has("buff") and r["buff"] != "random" and not DB.Buffs.DATA.has(r["buff"]):
		errors.append(where + " bad buff " + r["buff"])
	if r.has("recipe") and not DB.Items.RECIPES.has(r["recipe"]):
		errors.append(where + " bad recipe " + r["recipe"])
	if r.has("title"):
		_title(where, r["title"][0])
	for en in r.get("battle", []):
		if not DB.Enemies.DATA.has(en):
			errors.append(where + " bad enemy " + en)
	if r.has("lines"):
		_lines(where, r["lines"])
	if r.has("success"):
		_result(where, r["success"])
		_result(where, r["fail"])
