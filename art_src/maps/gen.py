# 探索マップの設計スクリプト（設計用。ゲームは data/fieldmaps.gd を読む）
# 使い方: python3 gen.py  → 各層の ASCII を表示し、data/fieldmaps_rows.txt を書く
import random, collections, sys
SOLID = set("#To~+ |")
class M:
    def __init__(s, w, h, fill="#", seed=1):
        s.w, s.h = w, h
        s.g = [[fill] * w for _ in range(h)]
        s.rng = random.Random(seed)
        s.props = {}
    def rect(s, x0, y0, x1, y1, c="."):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                s.g[y][x] = c
    def blob(s, cx, cy, rx, ry, c="."):
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                if ((x - cx) / (rx + 0.5)) ** 2 + ((y - cy) / (ry + 0.5)) ** 2 <= 1.0:
                    s.g[y][x] = c
    def hline(s, x0, x1, y, c=":", wdt=1):
        for x in range(min(x0, x1), max(x0, x1) + 1):
            for k in range(wdt):
                s.g[y + k][x] = c
    def vline(s, x, y0, y1, c=":", wdt=1):
        for y in range(min(y0, y1), max(y0, y1) + 1):
            for k in range(wdt):
                s.g[y][x + k] = c
    def put(s, x, y, c, **props):
        s.g[y][x] = c
        if props:
            s.props[(x, y)] = props
    def get(s, x, y):
        return s.g[y][x]
    def scatter(s, c, n, on=".", near_wall=False, keep=None):
        # 通行を妨げない位置にだけ置く
        cells = [(x, y) for y in range(1, s.h - 1) for x in range(1, s.w - 1) if s.g[y][x] == on]
        s.rng.shuffle(cells)
        placed = 0
        base = None
        for (x, y) in cells:
            if placed >= n:
                break
            if near_wall and not any(s.g[y + dy][x + dx] in "#T" for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))):
                continue
            if any(s.g[y + dy][x + dx] in "PECLMNF?BGX" for dx in (-1,0,1) for dy in (-1,0,1)):
                continue
            if c in SOLID:
                if base is None:
                    base = len(reach(s.g))
                old = s.g[y][x]
                s.g[y][x] = c
                if len(reach(s.g)) != base - 1 or not all_objs_reach(s.g):
                    s.g[y][x] = old
                    continue
                base -= 1
            else:
                s.g[y][x] = c
            placed += 1
    def text(s):
        return ["".join(r) for r in s.g]

def find(g, ch):
    return [(x, y) for y, r in enumerate(g) for x, c in enumerate(r) if c == ch]
def reach(g, gate_open=True, block=set(), start=None):
    if start is None:
        start = find(g, "P")[0]
    h, w = len(g), len(g[0])
    seen = {start: 0}
    q = collections.deque([start])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
            nx, ny = x + dx, y + dy
            if not (0 <= nx < w and 0 <= ny < h) or (nx, ny) in seen or (nx, ny) in block:
                continue
            c = g[ny][nx]
            if c in SOLID and not (c == "+" and gate_open):
                continue
            seen[(nx, ny)] = seen[(x, y)] + 1
            if c in "CMNF?BX":
                continue
            q.append((nx, ny))
    return seen
def all_objs_reach(g):
    r = reach(g)
    return all(o in r for ch in "ECLMNF?BGX" for o in find(g, ch))

def report(name, g):
    print("=" * 10, name, len(g[0]), "x", len(g))
    for i, row in enumerate(g):
        print("%2d %s" % (i, row))
    objs = {ch: find(g, ch) for ch in "PECLMNF?BGX"}
    print({k: len(v) for k, v in objs.items() if v})
    r_open = reach(g, True)
    r_closed = reach(g, False)
    B = objs["B"][0]
    gs = set(objs["G"])
    if gs:
        print("G reachable while closed:", any(x in r_closed for x in gs), "| boss reachable while closed:", B in r_closed,
              "| boss reachable avoiding G:", B in reach(g, True, gs))
    for ch in "ECLMNF?BX":
        for o in objs[ch]:
            if o not in r_open:
                print("  !! UNREACHABLE", ch, o)
    ms = []
    for e in objs["E"] + objs["L"]:
        blk = {(e[0] + dx, e[1] + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)}
        ms.append((e, B not in reach(g, True, blk), r_open.get(e)))
    print("  enemies:", " ".join("%s%s@%s" % ("*" if m else "", e, d) for e, m, d in ms))
    print("  path to boss:", r_open.get(B), "walkable:", len(r_open))

MAPS = {}


def gd_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return '"%s"' % v
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, (list, tuple)):
        return "[" + ", ".join(gd_value(x) for x in v) + "]"
    if isinstance(v, dict):
        return "{" + ", ".join('"%s": %s' % (k, gd_value(x)) for k, x in v.items()) + "}"
    raise TypeError(v)

def write_gd(floors, path):
    out = ["# 探索マップ（各層）。art_src/maps/gen.py で設計・生成。直接編集しても良い",
           "# 文字: # 壁 T 背の高い飾り(木・柱) o 岩・樽 . 床 , 床の飾り : 道 \" 草むら ~ 水 = 橋 + 門(中盤ストーリー後に開く) ^ 階段・敷物",
           "#       P 開始 E 敵 L 強敵 C 宝箱 M 行商人 N 住人 F 焚火 ? イベント B ボス G 中盤ストーリーの発生地点",
           "# objects: \"x,y\" → その位置の物の設定（敵の群れ・宝箱の中身・会話など）",
           "extends RefCounted", "", "const MAPS := {"]
    for f, (theme, m, extra) in floors.items():
        out.append("\t%d: {" % f)
        out.append('\t\t"theme": "%s",' % theme)
        for k, v in extra.items():
            out.append('\t\t"%s": %s,' % (k, gd_value(v)))
        out.append('\t\t"rows": [')
        for r in m.text():
            out.append('\t\t\t"%s",' % r.replace('"', '\\"'))
        out.append("\t\t],")
        out.append('\t\t"objects": {')
        for (x, y), p in sorted(m.props.items(), key=lambda kv: (kv[0][1], kv[0][0])):
            out.append('\t\t\t"%d,%d": %s,' % (x, y, gd_value(p)))
        out.append("\t\t},")
        out.append("\t},")
    out.append("}")
    open(path, "w", encoding="utf-8").write("\n".join(out) + "\n")

def maze(m, x0, y0, cols, rows, seed, path="."):
    # 2マス幅の通路と1マス幅の壁でできた迷路を (x0,y0) から掘る。セルは3×3
    rng = random.Random(seed)
    seen = set()
    stack = [(0, 0)]
    seen.add((0, 0))
    def carve_cell(cx, cy):
        m.rect(x0 + cx * 3, y0 + cy * 3, x0 + cx * 3 + 1, y0 + cy * 3 + 1, path)
    carve_cell(0, 0)
    while stack:
        cx, cy = stack[-1]
        nb = [(cx + dx, cy + dy, dx, dy) for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))
              if 0 <= cx + dx < cols and 0 <= cy + dy < rows and (cx + dx, cy + dy) not in seen]
        if not nb:
            stack.pop()
            continue
        nx, ny, dx, dy = rng.choice(nb)
        carve_cell(nx, ny)
        # 間の壁を抜く
        if dx == 1:
            m.rect(x0 + cx * 3 + 2, y0 + cy * 3, x0 + cx * 3 + 2, y0 + cy * 3 + 1, path)
        elif dx == -1:
            m.rect(x0 + nx * 3 + 2, y0 + ny * 3, x0 + nx * 3 + 2, y0 + ny * 3 + 1, path)
        elif dy == 1:
            m.rect(x0 + cx * 3, y0 + cy * 3 + 2, x0 + cx * 3 + 1, y0 + cy * 3 + 2, path)
        else:
            m.rect(x0 + nx * 3, y0 + ny * 3 + 2, x0 + nx * 3 + 1, y0 + ny * 3 + 2, path)
        seen.add((nx, ny))
        stack.append((nx, ny))
    # 行き止まりを少し減らす（ループを作る）
    for _ in range(cols * rows // 6):
        cx, cy = rng.randrange(cols - 1), rng.randrange(rows)
        m.rect(x0 + cx * 3 + 2, y0 + cy * 3, x0 + cx * 3 + 2, y0 + cy * 3 + 1, path)
