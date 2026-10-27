# 戦闘キャラの描画（素材を使わず図形で描く）
extends RefCounted


static func draw_fighter(f: Fighter) -> void:
	var a = f.fade
	if a <= 0.0:
		return
	# 影
	var sh_w: float = f.body.x * (0.9 if f.team == 0 else 1.1)
	var sh_scale: float = clamp(1.0 - f.h / 400.0, 0.4, 1.0)
	_ellipse(f, Vector2(0, f.h), sh_w * sh_scale, 9 * sh_scale, Color(0, 0, 0, 0.35 * a))
	# 詠唱陣
	if f.state == "cast":
		_magic_circle(f, f.cast_t, f.cast_time)
	f.draw_set_transform(Vector2.ZERO, 0.0, Vector2(f.facing, 1))
	if f.team == 0:
		_draw_hero(f, a)
	else:
		_draw_enemy(f, a)
	f.draw_set_transform(Vector2.ZERO)
	# ガード
	if f.state == "guard":
		var gc = Color(0.5, 0.8, 1.0, 0.45 + sin(f.anim_t * 20.0) * 0.1)
		f.draw_arc(Vector2(f.facing * 10, -f.body.y / 2.0), f.body.y * 0.62, -PI / 2.6 if f.facing > 0 else PI - PI / 2.6, (PI / 2.6) if f.facing > 0 else PI + PI / 2.6, 16, gc, 5.0)
	# 予備動作（敵の攻撃予告）
	if f.team == 1 and f.state == "act" and f.act_t < f.act.get("startup", 0.0):
		var k: float = f.act_t / max(0.01, f.act.get("startup", 0.3))
		var top = -f.body.y - 28
		f.draw_string(UI.FONT_BOLD, Vector2(-8, top), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1.0, 0.3 + k * 0.5, 0.2, a))
		f.draw_circle(Vector2(0, -f.body.y / 2.0), f.body.x * (0.4 + k * 0.5), Color(1, 0.2, 0.1, 0.12 * k))


static func _ellipse(f: Node2D, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts = PackedVector2Array()
	for i in range(20):
		var t = TAU * i / 20.0
		pts.append(c + Vector2(cos(t) * rx, sin(t) * ry))
	UI.poly(f, pts, col)


static func _magic_circle(f: Fighter, t: float, total: float) -> void:
	var k: float = clamp(t / max(0.01, total), 0.0, 1.0)
	var col: Color = DB.arte(f.cast_id).get("color", Color(0.6, 0.8, 1.0)) if f.cast_id != "" else Color.WHITE
	var rx = 70.0
	var ry = 18.0
	var pts = PackedVector2Array()
	for i in range(33):
		var ang = TAU * i / 32.0
		pts.append(Vector2(cos(ang) * rx, sin(ang) * ry + f.h))
	f.draw_polyline(pts, Color(col.r, col.g, col.b, 0.8), 3.0)
	var pts2 = PackedVector2Array()
	for i in range(33):
		var ang2 = TAU * i / 32.0
		pts2.append(Vector2(cos(ang2) * rx * 0.7, sin(ang2) * ry * 0.7 + f.h))
	f.draw_polyline(pts2, Color(col.r, col.g, col.b, 0.6), 2.0)
	for i in range(6):
		var ang3 = f.anim_t * 2.0 + TAU * i / 6.0
		var p = Vector2(cos(ang3) * rx * 0.85, sin(ang3) * ry * 0.85 + f.h)
		f.draw_circle(p, 4, col)
	# 詠唱ゲージ
	f.draw_rect(Rect2(-36, -f.body.y - 30, 72, 6), Color(0, 0, 0, 0.6))
	f.draw_rect(Rect2(-36, -f.body.y - 30, 72 * k, 6), col)
	for i in range(3):
		var y = -fmod(f.anim_t * 60.0 + i * 30.0, 90.0)
		f.draw_circle(Vector2(sin(f.anim_t * 3.0 + i) * 40, y), 2.5, Color(col.r, col.g, col.b, 0.6))


static func _tint(c: Color, f: Fighter, a: float) -> Color:
	var out = c
	if f.flash_t > 0.0:
		out = c.lerp(Color.WHITE, 0.75)
	if f.invul > 0.0 and fmod(f.anim_t, 0.12) < 0.06 and f.team == 0:
		out.a = 0.5 * a
	else:
		out.a = a
	return out


# ------------------------------------------------------------ 味方
static func _draw_hero(f: Fighter, a: float) -> void:
	var d: Dictionary = f.data
	var col: Color = _tint(d["color"], f, a)
	var acc: Color = _tint(d["accent"], f, a)
	var hair: Color = _tint(d["hair"], f, a)
	var skin: Color = _tint(Color(1.0, 0.86, 0.74), f, a)
	var dark = _tint(Color(0.15, 0.13, 0.16), f, a)
	var B: float = f.body.y
	var lean = 0.0
	var bob = sin(f.anim_t * 4.0) * 1.5
	var leg_swing = 0.0
	var weapon_ang = 0.6
	var weapon_ext = 1.0
	var arm_ang = 0.4
	var lying = false
	match f.state:
		"move":
			leg_swing = sin(f.anim_t * 14.0) * 0.6
			lean = 0.12
			bob = abs(sin(f.anim_t * 14.0)) * -3.0
		"jump":
			leg_swing = 0.4
		"hit":
			lean = -0.3
		"dead", "down":
			lying = true
		"win":
			weapon_ang = -1.2
			arm_ang = -1.6
			bob = sin(f.anim_t * 6.0) * 3.0
		"cast":
			weapon_ang = -0.9
			arm_ang = -1.2
		"guard":
			weapon_ang = -0.2
			arm_ang = 0.0
			lean = -0.05
		"act":
			var su: float = f.act.get("startup", 0.1)
			var ac: float = f.act.get("active", 0.1)
			var t: float = f.act_t
			var fx: String = f.act.get("fx", "slash")
			if f.act.has("projectile") or d["weapon"] in ["gun"]:
				weapon_ang = 0.0
				arm_ang = 0.0
			elif fx == "rise":
				var k: float = clamp((t - su) / max(0.01, ac), 0.0, 1.0)
				weapon_ang = lerp(1.4, -1.6, k)
				arm_ang = weapon_ang
			elif fx == "thrust" or fx == "punch":
				weapon_ang = 0.0
				arm_ang = 0.0
				weapon_ext = 1.0 + 0.4 * sin(t * 40.0)
				lean = 0.2
			elif fx == "iai":
				weapon_ang = 0.1 if t > su else 1.6
				arm_ang = weapon_ang
				lean = 0.35 if t > su else -0.1
			else:
				if t < su:
					weapon_ang = lerp(0.4, -1.8, t / max(0.01, su))
				else:
					var k2: float = clamp((t - su) / max(0.01, ac), 0.0, 1.0)
					weapon_ang = lerp(-1.8, 1.4, k2)
				arm_ang = weapon_ang
				lean = 0.1
	if lying:
		f.draw_set_transform(Vector2(0, -10), PI / 2.0 * -1.0, Vector2(f.facing, 1))
	var hip = Vector2(0, -B * 0.42 + bob)
	# 脚
	var l1 = hip + Vector2(sin(leg_swing) * B * 0.42, cos(leg_swing) * B * 0.42)
	var l2 = hip + Vector2(sin(-leg_swing) * B * 0.42, cos(-leg_swing) * B * 0.42)
	f.draw_line(hip + Vector2(-5, 0), l2 + Vector2(-5, 0), dark, 9.0)
	f.draw_line(hip + Vector2(5, 0), l1 + Vector2(5, 0), dark, 9.0)
	# 胴
	var torso_top = hip + Vector2(lean * 30.0, -B * 0.34)
	var tw = 30.0 if f.cid != "john" else 40.0
	var torso = PackedVector2Array([hip + Vector2(-tw / 2, 4), torso_top + Vector2(-tw / 2 - 2, 0), torso_top + Vector2(tw / 2 + 2, 0), hip + Vector2(tw / 2, 4)])
	UI.poly(f, torso, col)
	match f.cid:
		"ren":
			# 赤いマフラー
			var cape = _tint(Color(0.85, 0.1, 0.12), f, a)
			var flow = sin(f.anim_t * 8.0) * 4.0
			UI.poly(f, PackedVector2Array([torso_top + Vector2(-12, 2), torso_top + Vector2(12, 2), torso_top + Vector2(-26, 14 + flow), torso_top + Vector2(-34, 8 + flow)]), cape)
			if Game.flags.get("red_cape", false):
				UI.poly(f, PackedVector2Array([torso_top + Vector2(-10, 0), torso_top + Vector2(10, 0), hip + Vector2(-30 - flow, 30), hip + Vector2(-50 - flow * 2, 20)]), cape)
		"angie":
			UI.poly(f, PackedVector2Array([hip + Vector2(-tw / 2 - 6, 2), hip + Vector2(tw / 2 + 6, 2), hip + Vector2(tw / 2 + 14, 30), hip + Vector2(-tw / 2 - 14, 30)]), col.darkened(0.2))
		"sona":
			f.draw_rect(Rect2(hip + Vector2(-tw / 2, -4), Vector2(tw, 6)), _tint(Color(0.3, 0.22, 0.15), f, a))
		"jin":
			UI.poly(f, PackedVector2Array([hip + Vector2(-tw / 2 - 4, 2), hip + Vector2(tw / 2 + 4, 2), hip + Vector2(tw / 2 + 8, 26), hip + Vector2(-tw / 2 - 8, 26)]), acc.darkened(0.3))
		"john":
			f.draw_line(torso_top + Vector2(-tw / 2, 6), hip + Vector2(tw / 2, -2), _tint(Color(0.4, 0.28, 0.16), f, a), 7.0)
	# 頭
	var hc = torso_top + Vector2(lean * 10.0, -16)
	var hr = 15.0
	f.draw_circle(hc, hr, skin)
	f.draw_circle(hc + Vector2(-2, -5), hr - 2, hair)
	f.draw_circle(hc + Vector2(5, 2), hr - 6, skin)
	f.draw_circle(hc + Vector2(8, 0), 2.2, dark)
	match f.cid:
		"angie":
			var hat = _tint(Color(0.35, 0.18, 0.45), f, a)
			UI.poly(f, PackedVector2Array([hc + Vector2(-24, -8), hc + Vector2(24, -8), hc + Vector2(10, -16), hc + Vector2(-10, -16)]), hat)
			UI.poly(f, PackedVector2Array([hc + Vector2(-10, -15), hc + Vector2(10, -15), hc + Vector2(-14, -44)]), hat)
			UI.poly(f, PackedVector2Array([hc + Vector2(-hr, -2), hc + Vector2(-hr - 6, 26), hc + Vector2(-hr + 8, 20)]), hair)
		"sona":
			f.draw_rect(Rect2(hc + Vector2(-hr, -10), Vector2(hr * 2, 5)), _tint(Color(0.3, 0.25, 0.2), f, a))
			f.draw_circle(hc + Vector2(6, -8), 4.5, _tint(Color(0.4, 0.85, 0.9), f, a))
		"jin":
			f.draw_circle(hc + Vector2(-4, -hr - 2), 5.5, hair)
			f.draw_line(hc + Vector2(5, 0), hc + Vector2(11, 0), dark, 2.0)
		"john":
			f.draw_line(hc + Vector2(2, 8), hc + Vector2(12, 8), hair, 4.0)
	# 腕と武器
	var shoulder = torso_top + Vector2(4, 4)
	var hand = shoulder + Vector2(cos(arm_ang), sin(arm_ang)) * 26.0
	f.draw_line(shoulder, hand, skin.darkened(0.1), 7.0)
	_draw_weapon(f, d["weapon"], hand, weapon_ang, weapon_ext, a)
	if lying:
		f.draw_set_transform(Vector2.ZERO, 0.0, Vector2(f.facing, 1))
	# 攻撃の軌跡
	if f.state == "act" and not f.act.has("projectile") and d["weapon"] in ["sword", "katana", "fists", "rod"]:
		var su2: float = f.act.get("startup", 0.1)
		var ac2: float = f.act.get("active", 0.1)
		if f.act_t >= su2 and f.act_t <= su2 + ac2 + 0.05:
			var tc: Color = f.act.get("color", Color(1, 1, 1))
			var reach: float = f.act.get("reach", 70)
			var fx2: String = f.act.get("fx", "slash")
			var cy = -B * 0.55
			if fx2 in ["thrust", "punch", "iai"]:
				for i in range(3):
					var yy = cy + randf_range(-14, 14)
					f.draw_line(Vector2(10, yy), Vector2(f.body.x / 2 + reach, yy), Color(tc.r, tc.g, tc.b, 0.7 * a), 3.0)
			elif fx2 in ["quake", "mystic"]:
				pass
			else:
				var r0: float = f.body.x / 2 + reach * 0.6
				var st = -1.6 if fx2 != "rise" else 1.4
				var en = 1.3 if fx2 != "rise" else -1.6
				f.draw_arc(Vector2(0, cy), r0, min(st, en), max(st, en), 18, Color(tc.r, tc.g, tc.b, 0.8 * a), 7.0)
				f.draw_arc(Vector2(0, cy), r0 - 10, min(st, en), max(st, en), 18, Color(1, 1, 1, 0.5 * a), 3.0)


static func _draw_weapon(f: Fighter, w: String, hand: Vector2, ang: float, ext: float, a: float) -> void:
	var dir = Vector2(cos(ang), sin(ang))
	match w:
		"sword":
			var blade = _tint(Color(0.85, 0.88, 0.95), f, a)
			f.draw_line(hand - dir * 6, hand + dir * 52 * ext, blade, 6.0)
			f.draw_line(hand + dir.orthogonal() * 8, hand - dir.orthogonal() * 8, _tint(Color(0.8, 0.65, 0.3), f, a), 4.0)
		"katana":
			var blade2 = _tint(Color(0.92, 0.94, 1.0), f, a)
			f.draw_line(hand - dir * 10, hand + dir * 60 * ext, blade2, 4.0)
			f.draw_line(hand - dir * 10, hand, _tint(Color(0.2, 0.15, 0.3), f, a), 6.0)
		"rod":
			f.draw_line(hand - dir * 30, hand + dir * 34, _tint(Color(0.45, 0.3, 0.2), f, a), 5.0)
			f.draw_circle(hand + dir * 38, 7, _tint(Color(0.9, 0.5, 1.0), f, a))
		"gun":
			f.draw_line(hand, hand + dir * 30, _tint(Color(0.25, 0.25, 0.3), f, a), 8.0)
			f.draw_line(hand + Vector2(-2, 4), hand + Vector2(-2, 14), _tint(Color(0.3, 0.22, 0.15), f, a), 6.0)
			if f.state == "act" and f.act_t >= f.act.get("startup", 0.1) and f.act_t < f.act.get("startup", 0.1) + 0.06:
				f.draw_circle(hand + dir * 36, 9, _tint(Color(1, 0.9, 0.4), f, a))
		"fists":
			f.draw_circle(hand + dir * 4 * ext, 8, _tint(Color(0.85, 0.55, 0.3), f, a))
		"spear":
			f.draw_line(hand - dir * 30, hand + dir * 64 * ext, _tint(Color(0.5, 0.4, 0.3), f, a), 4.0)
			UI.poly(f, PackedVector2Array([hand + dir * 64 * ext, hand + dir * 52 * ext + dir.orthogonal() * 6, hand + dir * 82 * ext, hand + dir * 52 * ext - dir.orthogonal() * 6]), _tint(Color(0.85, 0.85, 0.9), f, a))
		"blades":
			f.draw_line(hand, hand + dir * 34 * ext, _tint(Color(0.9, 0.9, 0.95), f, a), 4.0)
			f.draw_line(hand + Vector2(-8, 4), hand + Vector2(-8, 4) + dir.rotated(0.6) * 30, _tint(Color(0.9, 0.9, 0.95), f, a), 4.0)


# ------------------------------------------------------------ 敵
static func _draw_enemy(f: Fighter, a: float) -> void:
	var d: Dictionary = f.data
	var col: Color = _tint(d["color"], f, a)
	var dark: Color = _tint(Color(d["color"]).darkened(0.45), f, a)
	var light: Color = _tint(Color(d["color"]).lightened(0.35), f, a)
	var eye: Color = _tint(Color(1.0, 0.95, 0.4), f, a)
	var W: float = f.body.x
	var H: float = f.body.y
	var t = f.anim_t
	var windup = f.state == "act" and f.act_t < f.act.get("startup", 0.0)
	var attacking = f.state == "act" and not windup
	if f.state == "dead":
		f.draw_set_transform(Vector2(0, 0), -0.4, Vector2(f.facing, 1))
	match d["shape"]:
		"slime":
			var squash = 1.0 + sin(t * 6.0) * 0.08
			if windup:
				squash = 0.75
			var pts = PackedVector2Array()
			for i in range(24):
				var ang = PI + PI * i / 23.0
				pts.append(Vector2(cos(ang) * W / 2 / squash, sin(ang) * H * squash))
			UI.poly(f, pts, col)
			f.draw_circle(Vector2(W * 0.12, -H * 0.55 * squash), 6, Color(1, 1, 1, a))
			f.draw_circle(Vector2(W * 0.14, -H * 0.55 * squash), 3, _tint(Color(0.1, 0.1, 0.1), f, a))
			f.draw_circle(Vector2(-W * 0.18, -H * 0.7 * squash), 5, Color(1, 1, 1, 0.5 * a))
		"bat":
			var flap = sin(t * 18.0) * 0.8
			var c = Vector2(0, -H / 2)
			UI.poly(f, PackedVector2Array([c, c + Vector2(-W * 0.9, -20 * flap - 6), c + Vector2(-W * 0.5, 10)]), dark)
			UI.poly(f, PackedVector2Array([c, c + Vector2(W * 0.9, -20 * flap - 6), c + Vector2(W * 0.5, 10)]), dark)
			f.draw_circle(c, H * 0.45, col)
			f.draw_circle(c + Vector2(6, -2), 3, eye)
		"wolf", "beast":
			var big = d["shape"] == "beast"
			var run = sin(t * (14.0 if f.state == "move" else 3.0)) * 6.0
			var bodyc = Vector2(0, -H * 0.55)
			_ellipse(f, bodyc, W * 0.42, H * 0.32, col)
			for lx in [-W * 0.28, W * 0.22]:
				f.draw_line(bodyc + Vector2(lx, H * 0.15), Vector2(lx + run * (1 if lx > 0 else -1), 0), dark, 8.0 if not big else 18.0)
			var headc = bodyc + Vector2(W * 0.42, -H * 0.18)
			f.draw_circle(headc, H * 0.24, col)
			UI.poly(f, PackedVector2Array([headc + Vector2(H * 0.1, -4), headc + Vector2(H * 0.42, 4), headc + Vector2(H * 0.1, H * 0.14)]), light)
			UI.poly(f, PackedVector2Array([headc + Vector2(-H * 0.12, -H * 0.16), headc + Vector2(-H * 0.02, -H * 0.36), headc + Vector2(H * 0.06, -H * 0.16)]), dark)
			f.draw_circle(headc + Vector2(H * 0.08, -H * 0.04), 3 if not big else 7, Color(1, 0.3, 0.2, a) if windup or attacking else eye)
			f.draw_line(bodyc + Vector2(-W * 0.42, -4), bodyc + Vector2(-W * 0.62, -H * 0.2 + run), col, 6.0 if not big else 14.0)
			if big:
				for i in range(4):
					f.draw_line(bodyc + Vector2(-W * 0.3 + i * 22, -H * 0.3), bodyc + Vector2(-W * 0.34 + i * 22, -H * 0.5), dark, 6.0)
		"golem":
			var sway = sin(t * 2.0) * 2.0
			f.draw_rect(Rect2(-W * 0.36, -H * 0.4, W * 0.24, H * 0.4), dark)
			f.draw_rect(Rect2(W * 0.12, -H * 0.4, W * 0.24, H * 0.4), dark)
			f.draw_rect(Rect2(-W * 0.5, -H * 0.85 + sway, W, H * 0.5), col)
			f.draw_rect(Rect2(-W * 0.22, -H + sway, W * 0.44, H * 0.2), light)
			f.draw_circle(Vector2(W * 0.08, -H * 0.9 + sway), 5, Color(1, 0.3, 0.2, a) if windup else eye)
			var arm = -0.4 if windup else (1.2 if attacking else 0.4)
			var sh = Vector2(W * 0.45, -H * 0.75 + sway)
			f.draw_line(sh, sh + Vector2(cos(arm), sin(arm)) * H * 0.45, col, W * 0.22)
			f.draw_circle(sh + Vector2(cos(arm), sin(arm)) * H * 0.5, W * 0.16, dark)
			for i in range(3):
				f.draw_circle(Vector2(-W * 0.3 + i * W * 0.25, -H * 0.6 + sway), 4, _tint(Color(0.4, 0.7, 0.4), f, a))
		"wisp":
			var c2 = Vector2(0, -H / 2 + sin(t * 3.0) * 6.0)
			for i in range(4):
				f.draw_circle(c2 + Vector2(-i * 6, i * 5), W * 0.5 - i * 4, Color(col.r, col.g, col.b, (0.25 - i * 0.05) * a))
			f.draw_circle(c2, W * 0.35, light)
			f.draw_circle(c2 + Vector2(5, -2), 3, _tint(Color(0.1, 0.1, 0.3), f, a))
		"ikei":
			var c3 = Vector2(0, -H * 0.55)
			_ellipse(f, c3, W * 0.45, H * 0.45, col)
			for i in range(4):
				var ph = t * 4.0 + i
				var base = c3 + Vector2(-W * 0.3 + i * W * 0.2, H * 0.35)
				f.draw_line(base, base + Vector2(sin(ph) * 8, H * 0.2), dark, 6.0)
			var reach = 0.0
			if attacking:
				reach = 60.0
			f.draw_line(c3 + Vector2(W * 0.3, 0), c3 + Vector2(W * 0.6 + reach, sin(t * 6.0) * 10), col, 8.0)
			f.draw_circle(c3 + Vector2(W * 0.1, -H * 0.15), 8, Color(1, 1, 1, a))
			f.draw_circle(c3 + Vector2(W * 0.12, -H * 0.15), 4, _tint(Color(0.2, 0, 0.3), f, a))
		"oni":
			var c4 = Vector2(0, -H * 0.5)
			f.draw_line(Vector2(-W * 0.18, 0), c4 + Vector2(-W * 0.18, H * 0.1), dark, W * 0.2)
			f.draw_line(Vector2(W * 0.18, 0), c4 + Vector2(W * 0.18, H * 0.1), dark, W * 0.2)
			_ellipse(f, c4, W * 0.42, H * 0.3, col)
			var hcen = c4 + Vector2(0, -H * 0.36)
			f.draw_circle(hcen, W * 0.3, col)
			UI.poly(f, PackedVector2Array([hcen + Vector2(-W * 0.2, -W * 0.2), hcen + Vector2(-W * 0.12, -W * 0.5), hcen + Vector2(-W * 0.04, -W * 0.24)]), _tint(Color(0.95, 0.9, 0.7), f, a))
			UI.poly(f, PackedVector2Array([hcen + Vector2(W * 0.2, -W * 0.2), hcen + Vector2(W * 0.12, -W * 0.5), hcen + Vector2(W * 0.04, -W * 0.24)]), _tint(Color(0.95, 0.9, 0.7), f, a))
			f.draw_circle(hcen + Vector2(W * 0.12, -2), 4, eye)
			var club = -1.6 if windup else (0.9 if attacking else -0.3)
			var hand = c4 + Vector2(W * 0.4, -H * 0.1)
			var cd = Vector2(cos(club), sin(club))
			f.draw_line(hand, hand + cd * H * 0.55, _tint(Color(0.35, 0.3, 0.3), f, a), W * 0.16)
		"book":
			var c5 = Vector2(0, -H / 2 + sin(t * 4.0) * 5)
			var op = 0.5 + sin(t * 6.0) * 0.3
			UI.poly(f, PackedVector2Array([c5, c5 + Vector2(-W * 0.6, -H * op), c5 + Vector2(-W * 0.6, H * 0.4), c5 + Vector2(0, H * 0.5)]), col)
			UI.poly(f, PackedVector2Array([c5, c5 + Vector2(W * 0.6, -H * op), c5 + Vector2(W * 0.6, H * 0.4), c5 + Vector2(0, H * 0.5)]), light)
			f.draw_circle(c5 + Vector2(W * 0.25, 0), 4, _tint(Color(0.9, 0.2, 0.3), f, a))
		"gearbot":
			var c6 = Vector2(0, -H / 2)
			var rot = t * (12.0 if attacking else 2.0)
			for i in range(8):
				var ang = rot + TAU * i / 8.0
				f.draw_rect(Rect2(c6 + Vector2(cos(ang), sin(ang)) * W * 0.46 - Vector2(6, 6), Vector2(12, 12)), dark)
			f.draw_circle(c6, W * 0.42, col)
			f.draw_circle(c6, W * 0.18, dark)
			f.draw_circle(c6 + Vector2(W * 0.1, -4), 5, Color(1, 0.3, 0.2, a))
		"drone":
			var c7 = Vector2(0, -H / 2 + sin(t * 5.0) * 4)
			f.draw_rect(Rect2(c7 - Vector2(W * 0.4, H * 0.3), Vector2(W * 0.8, H * 0.6)), col)
			f.draw_line(c7 + Vector2(-W * 0.6, -H * 0.5), c7 + Vector2(-W * 0.2, -H * 0.5), dark, 3)
			f.draw_line(c7 + Vector2(W * 0.2, -H * 0.5), c7 + Vector2(W * 0.6, -H * 0.5), dark, 3)
			f.draw_line(c7 + Vector2(-W * 0.4 + cos(t * 40) * 14, -H * 0.55), c7 + Vector2(-W * 0.4 - cos(t * 40) * 14, -H * 0.55), light, 2)
			f.draw_line(c7 + Vector2(W * 0.4 + cos(t * 40) * 14, -H * 0.55), c7 + Vector2(W * 0.4 - cos(t * 40) * 14, -H * 0.55), light, 2)
			f.draw_circle(c7 + Vector2(W * 0.2, 0), 5, Color(1, 0.2, 0.2, a) if windup else _tint(Color(0.3, 1, 0.9), f, a))
		"siren":
			var c8 = Vector2(0, -H * 0.55 + sin(t * 2.0) * 8)
			var tail = PackedVector2Array([c8 + Vector2(-W * 0.25, 0), c8 + Vector2(W * 0.25, 0), c8 + Vector2(W * 0.1 + sin(t * 3) * 10, H * 0.5), c8 + Vector2(-W * 0.4 + sin(t * 3) * 14, H * 0.55)])
			UI.poly(f, tail, col)
			UI.poly(f, PackedVector2Array([c8 + Vector2(-W * 0.2, 0), c8 + Vector2(W * 0.2, 0), c8 + Vector2(W * 0.15, -H * 0.35), c8 + Vector2(-W * 0.15, -H * 0.35)]), light)
			f.draw_circle(c8 + Vector2(0, -H * 0.45), W * 0.2, _tint(Color(0.9, 0.95, 1.0), f, a))
			for i in range(5):
				f.draw_line(c8 + Vector2(-W * 0.1, -H * 0.5), c8 + Vector2(-W * 0.45 - i * 4, -H * 0.2 + i * 14 + sin(t * 2 + i) * 6), _tint(Color(0.4, 0.7, 0.95), f, a), 5.0)
			for i in range(3):
				var ph = fmod(t * 0.8 + i * 0.33, 1.0)
				f.draw_string(UI.FONT, c8 + Vector2(W * 0.3 + ph * 40, -H * 0.5 - ph * 60), "♪", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.7, 0.95, 1.0, (1.0 - ph) * a))
		"humanoid":
			_draw_humanoid_enemy(f, a, col, dark, light, windup, attacking)
		_:
			f.draw_rect(Rect2(-W / 2, -H, W, H), col)
	if f.state == "dead":
		f.draw_set_transform(Vector2.ZERO, 0.0, Vector2(f.facing, 1))


static func _draw_humanoid_enemy(f: Fighter, a: float, col: Color, dark: Color, light: Color, windup: bool, attacking: bool) -> void:
	var d: Dictionary = f.data
	var H: float = f.body.y
	var t = f.anim_t
	var skin = _tint(Color(0.95, 0.82, 0.7), f, a)
	var leg = sin(t * 12.0) * 0.5 if f.state == "move" else 0.0
	var hip = Vector2(0, -H * 0.42)
	f.draw_line(hip + Vector2(-5, 0), hip + Vector2(-5 + sin(leg) * H * 0.42, H * 0.42), dark, 9.0)
	f.draw_line(hip + Vector2(5, 0), hip + Vector2(5 - sin(leg) * H * 0.42, H * 0.42), dark, 9.0)
	var top = hip + Vector2(0, -H * 0.36)
	UI.poly(f, PackedVector2Array([hip + Vector2(-16, 4), top + Vector2(-18, 0), top + Vector2(18, 0), hip + Vector2(16, 4)]), col)
	if d.get("coat", false):
		UI.poly(f, PackedVector2Array([top + Vector2(-18, 0), top + Vector2(-4, 0), hip + Vector2(-10, 40), hip + Vector2(-26, 36)]), _tint(Color(0.15, 0.15, 0.15), f, a))
	if d["weapon"] == "rod":
		UI.poly(f, PackedVector2Array([hip + Vector2(-18, 0), hip + Vector2(18, 0), hip + Vector2(24, H * 0.4), hip + Vector2(-24, H * 0.4)]), col.darkened(0.2))
	var hc = top + Vector2(0, -16)
	f.draw_circle(hc, 15, skin)
	var hair = _tint(DB.Characters.DATA.get(_officer_id(f.cid), {}).get("hair", Color(0.3, 0.3, 0.3)), f, a)
	if f.cid in ["soldier", "gunner", "mage_soldier"]:
		f.draw_circle(hc + Vector2(-1, -4), 15, _tint(Color(0.55, 0.58, 0.66), f, a))
		f.draw_rect(Rect2(hc + Vector2(-4, -2), Vector2(20, 6)), _tint(Color(0.15, 0.15, 0.2), f, a))
	else:
		f.draw_circle(hc + Vector2(-2, -5), 13, hair)
		f.draw_circle(hc + Vector2(5, 2), 9, skin)
		f.draw_circle(hc + Vector2(8, 0), 2.2, _tint(Color(0.15, 0.1, 0.1), f, a))
	if d.get("mask", false):
		UI.poly(f, PackedVector2Array([hc + Vector2(-6, 4), hc + Vector2(15, 2), hc + Vector2(12, 14), hc + Vector2(-2, 14)]), _tint(Color(0.97, 0.97, 0.98), f, a))
	if d.get("crown", false):
		UI.poly(f, PackedVector2Array([hc + Vector2(-12, -12), hc + Vector2(-14, -26), hc + Vector2(-6, -18), hc + Vector2(0, -28), hc + Vector2(6, -18), hc + Vector2(14, -26), hc + Vector2(12, -12)]), _tint(Color(1, 0.85, 0.2), f, a))
		var cape = _tint(Color(0.6, 0.1, 0.2), f, a)
		UI.poly(f, PackedVector2Array([top + Vector2(-16, 0), top + Vector2(-4, 0), hip + Vector2(-24 + sin(t * 3) * 4, 46), hip + Vector2(-40 + sin(t * 3) * 6, 40)]), cape)
	var ang = 0.5
	if windup:
		ang = -1.6
	elif attacking:
		ang = lerp(-1.6, 1.2, clamp((f.act_t - f.act.get("startup", 0.0)) / max(0.01, f.act.get("active", 0.1)), 0.0, 1.0))
	if d["weapon"] in ["gun", "rod"]:
		ang = 0.0 if (windup or attacking) else 0.5
	var sh = top + Vector2(4, 4)
	var hand = sh + Vector2(cos(ang), sin(ang)) * 26
	f.draw_line(sh, hand, skin, 7.0)
	var wpn: String = d["weapon"]
	if wpn == "rod" and (windup or attacking):
		f.draw_circle(hand + Vector2(40, 0), 10 + sin(t * 20) * 3, _tint(Color(0.8, 0.4, 1.0, 0.7), f, a))
	_draw_weapon(f, wpn, hand, ang, 1.0, a)


static func _officer_id(eid: String) -> String:
	match eid:
		"boss_nene":
			return "nene"
		"boss_val":
			return "val"
		"boss_zone":
			return "zone"
		"boss_shasta":
			return "shasta"
	return "soldier"
