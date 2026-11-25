# ゲーム全体の進行状態（パーティ・塔マップ・加護・称号・セーブ）
extends Node

signal notified(text: String, kind: String)
signal skit_available(skit_id: String)
signal input_mode_changed  # キーボード操作とゲームパッド操作が切り替わった

const SAVE_PATH := "user://save.json"
const MAX_ROW := 8

var party: Array = []          # パーティメンバーの状態 Dictionary
var gald := 0
var items: Dictionary = {}
var floor_num := 1
var map: Dictionary = {}       # 探索マップの状態（init_field を参照）
var floor_buffs: Array = []    # 層限定の加護 id
var meal: Dictionary = {}      # {"id": recipe_id, "left": 3}
var flags: Dictionary = {}
var counters: Dictionary = {}
var bond: Dictionary = {}      # pair_key -> int
var seen_skits: Dictionary = {}
var pending_skits: Array = []
var known_recipes: Array = ["onigiri", "curry"]
var floor_snapshot: Dictionary = {}
var play_time := 0.0

var rng := RandomNumberGenerator.new()
const SETTINGS_PATH := "user://settings.cfg"
var battle_25d := true  # バトルは 2.5D（奥行きあり）が正式仕様。--2d を付けて起動したときだけ従来の 2D で比較できる
var pad_mode := false  # 最後の入力がゲームパッドなら true（ボタン表示を切り替える）
var touch_mode := false  # 最後の入力がタッチ（スマホ・タブレット）なら true。画面にタッチ操作ボタンを出す
var quiet := false  # true の間は通知（トースト）を出さない（デバッグジャンプ用）

# 通常プレイでの想定レベル（層の開始時 / ボス戦時）。バランス確認とデバッグジャンプで使う
const EXPECTED_LV_START := [2, 4, 6, 9, 12, 15, 17]
const EXPECTED_LV_BOSS := [3, 5, 8, 10, 13, 15, 17]


func _ready() -> void:
	rng.randomize()
	_setup_input()
	pad_mode = Input.get_connected_joypads().size() > 0
	if "--2d" in OS.get_cmdline_user_args():
		battle_25d = false   # 比較用：従来の 2D バトル


func set_battle_25d(on: bool) -> void:
	battle_25d = on
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("battle", "depth", on)
	cfg.save(SETTINGS_PATH)


func _input(event: InputEvent) -> void:
	var pad = event is InputEventJoypadButton or (event is InputEventJoypadMotion and abs(event.axis_value) > 0.5)
	# タッチから作られたマウス操作（device = -1）はキーボード扱いにしない
	var emulated: bool = event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION
	var kb = event is InputEventKey or (event is InputEventMouseButton and not emulated)
	if event is InputEventScreenTouch and not touch_mode:
		touch_mode = true
		pad_mode = false
		input_mode_changed.emit()
	elif (pad or kb) and touch_mode:
		touch_mode = false
		input_mode_changed.emit()
	if pad and not pad_mode:
		pad_mode = true
		input_mode_changed.emit()
	elif kb and pad_mode:
		pad_mode = false
		input_mode_changed.emit()


# 操作ボタンの表示名。今の入力方法（キーボード／ゲームパッド）に合わせて返す
const KEY_NAMES := {
	"attack": ["J", "X"], "arte": ["K", "B"], "jump": ["Space", "A"], "guard": ["L", "LB"], "dodge": ["O", "RT"],
	"target": ["Tab", "RB"], "link": ["U", "LT"], "overlimit": ["I", "Y"], "pause": ["Esc", "START"],
	"skit": ["T", "BACK"], "menu": ["M", "START"], "accept": ["Enter", "A"], "cancel": ["Esc", "B"],
	"allies": ["1/2/3", "右スティック"], "move": ["←→", "左スティック"], "dir": ["↑↓←→", "十字キー"],
}


# タッチ操作のときの表示名（画面のボタンの文字に合わせる）
const TOUCH_NAMES := {
	"attack": "［攻撃］", "arte": "［術技］", "jump": "［跳ぶ］", "guard": "［ガード］", "dodge": "［回避］",
	"target": "［狙う］", "link": "［秘技］", "overlimit": "［OVL］", "pause": "［Ⅱ］",
	"skit": "［スキット］", "menu": "［メニュー］", "accept": "［調べる］", "cancel": "［戻る］",
	"allies": "ポーズメニュー", "move": "スティック", "dir": "スティック",
}


func key(action: String) -> String:
	if touch_mode:
		return TOUCH_NAMES.get(action, action)
	var names: Array = KEY_NAMES.get(action, [action, action])
	return names[1] if pad_mode else names[0]


# 操作説明（今の入力方法に合わせる）。battle_only なら戦闘部分だけ
func controls_text(battle_only: bool = false) -> String:
	var t := ""
	if pad_mode:
		t = "[b]バトル（ゲームパッド）[/b]\n移動：左スティック／十字キー（上下で奥・手前）　通常攻撃：X\n術技：B（＋方向なしで1種、十字キー↑/↓/←→で計4種）\nジャンプ：A　ガード：LB　回避：RT（スティックを倒した方向へ）\nターゲット切替：RB　共鳴秘技：LT（絆ゲージ満タン時）\nオーバーリミッツ：Y（OVLゲージ満タン時）\n秘奥義：オーバーリミッツ中に Y（秘奥義ゲージ100%以上）\n仲間に術技を指示：右スティック ←↑→　メニュー：START"
		if not battle_only:
			t += "\n\n[b]マップ[/b]\n移動：左スティック　調べる：A　ダッシュ：LB を押しながら\nスキット：BACK　メニュー：START"
	else:
		t = "[b]バトル（キーボード）[/b]\n移動：WASD・矢印キー（上下で奥・手前）　通常攻撃：J（Z）\n術技：K（X）＋方向なし/↑/↓/←→で4種\nジャンプ：Space（C）　ガード：L（Shift）　方向キー＋ガードで回避\nターゲット切替：Tab（Q）　共鳴秘技：U（V）（絆ゲージ満タン時）\nオーバーリミッツ：I（B）（OVLゲージ満タン時）\n秘奥義：オーバーリミッツ中に I（秘奥義ゲージ100%以上）\n仲間に術技を指示：1/2/3　メニュー：Esc\n（デバッグ：F9 で敵のHPを残り10に）"
		if not battle_only:
			t += "\n\n[b]マップ[/b]\n移動：WASD・矢印キー　調べる：Enter（J）　ダッシュ：Shift を押しながら\nスキット：T　メニュー：M"
	t += "\n\n[b]回避[/b]\n回避ボタン（パッドは RT、キーボードは O か「方向＋ガード」）で、倒している方向へ一瞬で移動して攻撃をかわす（移動中は無敵）。\nバトルは奥行きのある 2.5D。上下で奥・手前へ移動でき、回避も奥・手前に出せる。"
	t += "\n\n[b]ボスの大技[/b]\nボスが大技を構えると、仲間が声をかけ、レンの頭上に対処方法のアイコンが出る。\n矢印なら「ジャンプ」、盾なら「ガード」。外側の輪が内側の円に重なる瞬間に攻撃が来る。"
	t += "\n\n[b]テイルズ流のコツ[/b]\n通常攻撃 → 特技 → 奥義 の順にキャンセルして繋げよう。\n仲間と同じ敵を叩くと「連携」で絆ゲージが一気にたまる。\n秘奥義ゲージは戦闘をまたいで300%までたまる。200%で2人、300%で3人の合体秘奥義になる。"
	return t


# [ボタン名] の形で返す
func btn(action: String) -> String:
	return "[%s]" % key(action)


func _process(delta: float) -> void:
	play_time += delta


# ------------------------------------------------------------ 入力設定
func _setup_input() -> void:
	# キーボードとゲームパッド（Xbox配置。PlayStation等は同じ位置のボタン）
	# 移動: 左スティック/十字キー  攻撃: X(□)  術技: B(○)  ジャンプ: A(×)  ガード: LB(L1)  回避: RT(R2)
	# ターゲット: RB(R1)  共鳴秘技: LT(L2)  オーバーリミッツ／秘奥義: Y(△)  ポーズ: START  スキット: BACK  仲間への指示: 右スティック ←↑→
	_bind("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_bind("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_bind("move_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_bind("move_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
	_bind("attack", [KEY_J, KEY_Z], [JOY_BUTTON_X])
	_bind("arte", [KEY_K, KEY_X], [JOY_BUTTON_B])
	_bind("jump", [KEY_SPACE, KEY_C], [JOY_BUTTON_A])
	_bind("guard", [KEY_L, KEY_SHIFT], [JOY_BUTTON_LEFT_SHOULDER])
	_bind("dodge", [KEY_O], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_bind("link", [KEY_U, KEY_V], [], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	_bind("overlimit", [KEY_I, KEY_B], [JOY_BUTTON_Y])
	_bind("target", [KEY_TAB, KEY_Q], [JOY_BUTTON_RIGHT_SHOULDER])
	_bind("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	_bind("skit", [KEY_T], [JOY_BUTTON_BACK])
	_bind("menu", [KEY_M], [])
	_bind("ally1", [KEY_1], [], [[JOY_AXIS_RIGHT_X, -1.0]])
	_bind("ally2", [KEY_2], [], [[JOY_AXIS_RIGHT_Y, -1.0]])
	_bind("ally3", [KEY_3], [], [[JOY_AXIS_RIGHT_X, 1.0]])
	# メニュー操作（ui_*）も全コントローラーで効くようにする
	for a in ["ui_accept", "ui_cancel", "ui_left", "ui_right", "ui_up", "ui_down", "ui_focus_next", "ui_focus_prev"]:
		for ev in InputMap.action_get_events(a):
			ev.device = -1
	_bind("ui_accept", [], [JOY_BUTTON_A])
	_bind("ui_cancel", [], [JOY_BUTTON_B])
	_bind("ui_left", [], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_bind("ui_right", [], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_bind("ui_up", [], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_bind("ui_down", [], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])


func _bind(action: String, keys: Array, buttons: Array, axes: Array = []) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.4)
	# device = -1 で、どの番号のコントローラーからの入力も受け付ける
	for k in keys:
		var ev = InputEventKey.new()
		ev.physical_keycode = k
		ev.device = -1
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var jb = InputEventJoypadButton.new()
		jb.button_index = b
		jb.device = -1
		InputMap.action_add_event(action, jb)
	for ax in axes:
		var jm = InputEventJoypadMotion.new()
		jm.axis = ax[0]
		jm.axis_value = ax[1]
		jm.device = -1
		InputMap.action_add_event(action, jm)


# ------------------------------------------------------------ ニューゲーム
func new_game() -> void:
	party.clear()
	party.append(_new_member("ren"))
	gald = 200
	items = {"apple_gel": 4, "orange_gel": 2, "life_bottle": 1}
	floor_num = 1
	floor_buffs.clear()
	meal = {}
	flags = {}
	counters = {}
	bond = {}
	seen_skits = {}
	pending_skits = []
	known_recipes = ["onigiri", "curry"]
	play_time = 0.0
	gen_map()
	award_title("climber", "")
	full_heal_party()


func _new_member(cid: String) -> Dictionary:
	var c: Dictionary = DB.chara(cid)
	var m = {
		"id": cid, "level": 1, "exp": 0, "sp": 1,
		"nodes": [], "titles": [], "title": "",
		"artes": c["artes"].duplicate(),
		"slots": ["", "", "", ""],
		"hp": 0, "tp": 0,
	}
	for i in range(min(4, m["artes"].size())):
		m["slots"][i] = m["artes"][i]
	m["hp"] = max_hp_of(m)
	m["tp"] = int(c["base"]["tp"])
	return m


func max_hp_of(m: Dictionary) -> int:
	var c: Dictionary = DB.chara(m["id"])
	return int(c["base"]["hp"] + c["growth"]["hp"] * (m["level"] - 1))


# 仲間の加入。レベルはパーティ平均に合わせ、共通称号を引き継ぐ。
func join(cid: String) -> void:
	if not member(cid).is_empty():
		return
	var m = _new_member(cid)
	var total = 0
	for pm in party:
		total += pm["level"]
	var lv: int = max(1, int(round(float(total) / party.size())))
	m["level"] = lv
	m["sp"] = lv
	m["active"] = active_party().size() < 4
	for tid in party[0]["titles"]:
		if DB.title(tid)["char"] == "" and not tid in m["titles"]:
			m["titles"].append(tid)
	party.append(m)
	m["hp"] = max_hp(cid)
	m["tp"] = max_tp(cid)
	notified.emit("%sが仲間になった！" % DB.cname(cid), "join")


func active_party() -> Array:
	var res: Array = []
	for m in party:
		if m.get("active", true) and res.size() < 4 and not captured(m["id"]):
			res.append(m)
	if res.is_empty() and not party.is_empty():
		res.append(party[0])
	return res


# 頂上：レンが突き落とされてから決戦直前まで、仲間は王子に捕らわれている
func captured(cid: String) -> bool:
	return flags.get("allies_captured", false) and cid != "ren"


# いま一緒にいる仲間（捕らわれている仲間を除く）
func present_party() -> Array:
	return party.filter(func(m) -> bool: return not captured(m["id"]))


# チュートリアル：まだ見ていなければ true を返して既読にする（自動テスト中は出さない）
func should_tutorial(id: String) -> bool:
	if flags.get("tut_" + id, false) or not DB.Tutorials.DATA.has(id):
		return false
	flags["tut_" + id] = true
	return not is_test_run()


# 自動テスト中か（チュートリアルや戦闘中の強制イベントの会話を飛ばす）
func is_test_run() -> bool:
	for a in ["--autotest", "--balance", "--shots", "--gallery"]:
		if a in OS.get_cmdline_user_args():
			return true
	return false


func seen_tutorials() -> Array:
	return DB.Tutorials.ORDER.filter(func(id) -> bool: return flags.get("tut_" + id, false))


# まだ加入していない仲間や、捕らわれている仲間がしゃべる場面は出さない
func lines_available(lines: Array) -> bool:
	for ln in lines:
		var sp = str(ln[0])
		if DB.Characters.DATA.has(sp) and DB.chara(sp).get("playable", false) and not is_joined(sp):
			return false
	return true


func is_joined(cid: String) -> bool:
	return not member(cid).is_empty() and not captured(cid)


func member(cid: String) -> Dictionary:
	for m in party:
		if m["id"] == cid:
			return m
	return {}


func leader_id() -> String:
	return party[0]["id"]


# ------------------------------------------------------------ ステータス
func stat(cid: String, key: String) -> float:
	var m = member(cid)
	var c: Dictionary = DB.chara(cid)
	var v: float = c["base"][key] + c["growth"][key] * (m["level"] - 1)
	for nid in m["nodes"]:
		var n = DB.tree_node(cid, nid)
		if n.has("effect") and n["effect"].has("stat"):
			v += n["effect"]["stat"].get(key, 0)
	if m["title"] != "":
		v += DB.title(m["title"])["bonus"].get(key, 0)
	return v


func max_hp(cid: String) -> int:
	return int(stat(cid, "hp"))


func max_tp(cid: String) -> int:
	return int(stat(cid, "tp"))


func has_skill(cid: String, key: String) -> bool:
	var m = member(cid)
	for nid in m["nodes"]:
		var n = DB.tree_node(cid, nid)
		if n.get("effect", {}).get("skill", "") == key:
			return true
	return false


func exp_to_next(level: int) -> int:
	return int(30.0 * pow(level, 1.55)) + 20


func full_heal_party() -> void:
	for m in party:
		m["hp"] = max_hp(m["id"])
		m["tp"] = max_tp(m["id"])


func gain_exp(amount: int) -> Array:
	# 戻り値: レベルアップしたキャラの一覧 [{id, level}]
	var ups: Array = []
	for m in party:
		m["exp"] += amount
		while m["exp"] >= exp_to_next(m["level"]):
			m["exp"] -= exp_to_next(m["level"])
			var old_hp = max_hp(m["id"])
			var old_tp = max_tp(m["id"])
			m["level"] += 1
			m["sp"] += 1
			m["hp"] += max_hp(m["id"]) - old_hp
			m["tp"] += max_tp(m["id"]) - old_tp
			ups.append({"id": m["id"], "level": m["level"]})
	return ups


func learn_node(cid: String, nid: String) -> bool:
	var m = member(cid)
	var n = DB.tree_node(cid, nid)
	if n.is_empty() or nid in m["nodes"] or m["sp"] < n["cost"]:
		return false
	for r in n["req"]:
		if not r in m["nodes"]:
			return false
	m["sp"] -= n["cost"]
	m["nodes"].append(nid)
	var eff: Dictionary = n["effect"]
	if eff.has("arte"):
		m["artes"].append(eff["arte"])
		for i in range(4):
			if m["slots"][i] == "":
				m["slots"][i] = eff["arte"]
				break
	if eff.has("stat"):
		m["hp"] = min(m["hp"] + int(eff["stat"].get("hp", 0)), max_hp(cid))
	return true


# ------------------------------------------------------------ 加護・料理
func bmod(key: String, default: float = 0.0) -> float:
	var mult = key.ends_with("_mult")
	var v = 1.0 if mult else default
	var sources: Array = []
	for b in floor_buffs:
		sources.append(DB.buff(b)["effects"])
	if not meal.is_empty():
		sources.append(DB.Items.RECIPES[meal["id"]]["effects"])
	for eff in sources:
		if eff.has(key):
			if mult:
				v *= eff[key]
			else:
				v += eff[key]
	return v


func add_floor_buff(id: String) -> void:
	if not id in floor_buffs:
		floor_buffs.append(id)
		notified.emit("加護『%s』を得た！" % DB.buff(id)["name"], "buff")


func random_buffs(n: int, exclude: Array = []) -> Array:
	var pool: Array = []
	for id in DB.Buffs.DATA.keys():
		if id in floor_buffs or id in exclude:
			continue
		pool.append(id)
	pool.shuffle()
	return pool.slice(0, n)


func consume_meal() -> void:
	if meal.is_empty():
		return
	meal["left"] -= 1
	if meal["left"] <= 0:
		notified.emit("料理『%s』の効果が切れた" % DB.Items.RECIPES[meal["id"]]["name"], "info")
		meal = {}


# ------------------------------------------------------------ アイテム
func add_item(id: String, n: int = 1) -> void:
	items[id] = items.get(id, 0) + n


func use_item_count(id: String) -> int:
	return items.get(id, 0)


func remove_item(id: String) -> void:
	items[id] = items.get(id, 0) - 1
	if items[id] <= 0:
		items.erase(id)


func add_gald(n: int) -> void:
	gald += n
	if gald >= 2000:
		award_title("rich", "")


# ------------------------------------------------------------ 称号
func award_title(tid: String, cid: String) -> void:
	var t: Dictionary = DB.title(tid)
	var targets: Array = []
	if t["char"] != "":
		targets = [t["char"]]
	elif cid != "":
		targets = [cid]
	else:
		for m in party:
			targets.append(m["id"])
	var got = false
	for id in targets:
		var m = member(id)
		if m.is_empty() or tid in m["titles"]:
			continue
		m["titles"].append(tid)
		if m["title"] == "":
			m["title"] = tid
		got = true
	if got:
		var who = "全員" if targets.size() > 1 else DB.cname(targets[0])
		notified.emit("%sが称号『%s』を獲得！" % [who, t["name"]], "title")


func count(key: String, n: int = 1) -> int:
	counters[key] = counters.get(key, 0) + n
	return counters[key]


func add_bond(a: String, b: String, n: int) -> void:
	var k = DB.pair_key(a, b)
	bond[k] = bond.get(k, 0) + n


func get_bond(a: String, b: String) -> int:
	return bond.get(DB.pair_key(a, b), 0)


# ------------------------------------------------------------ スキット
func check_skits(trigger: String) -> void:
	for sid in DB.Skits.DATA.keys():
		if seen_skits.has(sid) or sid in pending_skits:
			continue
		var s: Dictionary = DB.Skits.DATA[sid]
		if s.get("trigger", "") != trigger:
			continue
		if s.has("floor") and s["floor"] != floor_num:
			continue
		if s.has("min_floor") and floor_num < s["min_floor"]:
			continue
		if s.has("max_floor") and floor_num > s["max_floor"]:
			continue
		var ok = true
		for r in s.get("req", []):
			if not is_joined(r):
				ok = false
		for f in s.get("flags", []):
			if not flags.get(f, false):
				ok = false
		for f in s.get("not_flags", []):
			if flags.get(f, false):
				ok = false
		if not ok or not lines_available(s["lines"]):
			continue
		pending_skits.append(sid)
		skit_available.emit(sid)
		# 一度に発生するスキットは一つまで（会話の間隔をあける）
		return


func mark_skit_seen(sid: String) -> void:
	seen_skits[sid] = true
	pending_skits.erase(sid)
	var s: Dictionary = DB.Skits.DATA[sid]
	var speakers: Array = []
	for line in s["lines"]:
		if line[0] in DB.Characters.DATA and not line[0] in speakers:
			speakers.append(line[0])
	for i in range(speakers.size()):
		for j in range(i + 1, speakers.size()):
			add_bond(speakers[i], speakers[j], 1)
	if s.has("award"):
		award_title(s["award"][0], s["award"][1])


# ------------------------------------------------------------ 探索マップ（層ごと）
# map = {"floor": 層, "pos": [x, y], "dir": 向き, "done": {物のid: true}, "fog": 通った所, "engage": 戦闘中の相手}
func gen_map() -> void:
	init_field()


func init_field() -> void:
	map = {"floor": floor_num, "pos": [], "dir": 3, "done": {}, "fog": "", "engage": ""}


func next_floor() -> void:
	floor_num += 1
	floor_buffs.clear()
	gen_map()
	full_heal_party()


func take_floor_snapshot() -> void:
	floor_snapshot = to_dict()


func restore_floor_snapshot() -> bool:
	if floor_snapshot.is_empty():
		return false
	from_dict(floor_snapshot.duplicate(true))
	return true


# ------------------------------------------------------------ セーブ/ロード
func to_dict() -> Dictionary:
	return {
		"party": party, "gald": gald, "items": items, "floor": floor_num, "map": _map_to_json(),
		"floor_buffs": floor_buffs, "meal": meal, "flags": flags, "counters": counters,
		"bond": bond, "seen_skits": seen_skits, "pending_skits": pending_skits,
		"known_recipes": known_recipes, "play_time": play_time,
	}.duplicate(true)


func _map_to_json() -> Dictionary:
	return map


func from_dict(d: Dictionary) -> void:
	party = d["party"]
	for m in party:
		m["level"] = int(m["level"])
		m["exp"] = int(m["exp"])
		m["sp"] = int(m["sp"])
		m["hp"] = int(m["hp"])
		m["tp"] = int(m["tp"])
	gald = int(d["gald"])
	items = {}
	for k in d["items"]:
		items[k] = int(d["items"][k])
	floor_num = int(d["floor"])
	var md: Dictionary = d["map"]
	if md.has("nodes") or not md.has("done"):
		# 古いセーブ（分かれ道マップ）は、その層の最初の位置から
		init_field()
	else:
		map = md
		map["floor"] = int(map.get("floor", floor_num))
	floor_buffs = d["floor_buffs"]
	meal = d["meal"]
	if meal.has("left"):
		meal["left"] = int(meal["left"])
	flags = d["flags"]
	# 絆技・OVLの解放が物語のイベントになる前のセーブ：進み具合から解放済みにする
	if flags.has("story_f3_boss_post"):
		flags["link_unlocked"] = true
	if flags.has("story_f5_boss_post"):
		flags["ovl_unlocked"] = true
	counters = d["counters"]
	bond = d["bond"]
	seen_skits = d["seen_skits"]
	pending_skits = d["pending_skits"]
	known_recipes = d["known_recipes"]
	play_time = float(d.get("play_time", 0.0))


func save_game() -> void:
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		var d = to_dict()
		d["snapshot"] = floor_snapshot
		f.store_string(JSON.stringify(d))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> bool:
	if not has_save():
		return false
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return false
	from_dict(d)
	floor_snapshot = d.get("snapshot", {})
	return true


# ------------------------------------------------------------ デバッグ：章ジャンプ
# 指定した層の「開始時」または「ボス戦直前」の状態を、通常プレイで想定される強さ・所持品で再現する。
func debug_setup(target_floor: int, at_boss: bool) -> void:
	quiet = true
	new_game()
	# 序章と、それ以前の層のストーリーで起きること（加入・称号・フラグなど）を順に適用
	for sid in ["p1_sisters", "p2_balfour", "p3_tragedy", "p4_prince", "p5_lab", "p6_entry"]:
		_debug_apply_story(sid)
	flags.erase("nine_absent")
	flags.erase("pots_absent")
	for f in range(1, target_floor + 1):
		var fs: Dictionary = DB.Story.FLOORS[f]
		var keys: Array = ["intro", "mid", "camp", "boss_pre", "boss_post"]
		if f == target_floor:
			keys = ["intro", "mid", "camp"] if at_boss else []
		for k in keys:
			_debug_apply_story(fs[k])
		if f < target_floor:
			flags["floor_started_%d" % f] = true
			if DB.Titles.DATA.has("floor%d" % f):
				award_title("floor%d" % f, "")
			# 過去の層で起きたはずのスキットは既読にする
			for sk in DB.Skits.DATA:
				if DB.Skits.DATA[sk].get("floor", 99) == f:
					seen_skits[sk] = true
	floor_num = target_floor
	# 第五層のボス戦の途中で起きるOVL解放イベント
	if target_floor > 5:
		_debug_apply_story("f5_ovl")
	# 成長：想定レベル、SP（レベルアップ＋層クリア報酬）を自動でスキルツリーに振る
	var lv: int = (EXPECTED_LV_BOSS if at_boss else EXPECTED_LV_START)[target_floor - 1]
	for m in party:
		m["level"] = lv
		m["exp"] = 0
		m["sp"] = (lv - 1) + 2 * (target_floor - 1)
		m["nodes"] = []
		_debug_auto_learn(m["id"])
	# 所持品・お金・レシピ・絆
	gald = 200 + 260 * (target_floor - 1) + (150 if at_boss else 0)
	items = {"apple_gel": 4 + target_floor, "orange_gel": 2 + target_floor / 2, "life_bottle": 1 + target_floor / 2}
	if target_floor >= 2:
		items["lemon_gel"] = target_floor - 1
	if target_floor >= 3:
		items["mixed_gel"] = target_floor - 2
	var recipe_order := ["onigiri", "curry", "herb_soup", "star_parfait", "azuma_soba"]
	known_recipes = recipe_order.slice(0, min(recipe_order.size(), 1 + target_floor))
	for m in party:
		if m["id"] != "ren":
			add_bond("ren", m["id"], 2 * target_floor)
	counters["battles"] = 5 * (target_floor - 1)
	# マップ
	gen_map()
	floor_buffs.clear()
	if at_boss:
		flags["floor_started_%d" % target_floor] = true
		# 道中で手に入れていたはずの加護（層の加護＋強敵の加護）
		for b in random_buffs(2):
			add_floor_buff(b)
		_debug_move_before_boss()
	full_heal_party()
	quiet = false
	take_floor_snapshot()


func _debug_apply_story(sid: String) -> void:
	if not DB.Story.DATA.has(sid):
		return
	flags["story_" + sid] = true
	for line in DB.Story.DATA[sid]["lines"]:
		match str(line[0]):
			"@join":
				join(line[1])
			"@title":
				award_title(line[1], line[2] if line.size() > 2 else "")
			"@flag":
				flags[line[1]] = true
			"@unflag":
				flags.erase(line[1])
			"@item":
				add_item(line[1], line[2] if line.size() > 2 else 1)
			"@recipe":
				if not line[1] in known_recipes:
					known_recipes.append(line[1])


func _debug_auto_learn(cid: String) -> void:
	# 安いノードから順に、習得できるものがなくなるまで覚える
	var learned = true
	while learned:
		learned = false
		var nodes: Array = DB.tree(cid).duplicate()
		nodes.sort_custom(func(a, b) -> bool: return a["cost"] < b["cost"])
		for n in nodes:
			if learn_node(cid, n["id"]):
				learned = true
				break


func _debug_move_before_boss() -> void:
	# ボス手前の焚火の前に立たせる
	var fm: Dictionary = DB.FieldMaps.MAPS.get(floor_num, {})
	var rows: Array = fm.get("rows", [])
	for y in range(rows.size()):
		var x: int = rows[y].find("F")
		if x >= 0:
			for d in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
				var c: String = rows[y + d.y][x + d.x]
				if c in ".,:\"=^G":
					map["pos"] = [(x + d.x) * 64.0 + 32.0, (y + d.y) * 64.0 + 52.0]
					return
