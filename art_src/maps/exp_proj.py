import importlib, gen
EXP = dict(slime=16, bat=18, wolf=24, golem=40, wisp=22, ikei=28, oni=28, lion=34, book=30, gear=34, soldier=32, gunner=30, drone=28, mage_soldier=34)
BOSS = [200, 360, 520, 700, 900, 1100, 0]
SCALE = [1, 1.35, 1.8, 2.3, 2.9, 3.6, 4.0]
EXPECT = [3, 5, 8, 10, 13, 15, 17]
def nxt(l): return int(30 * l ** 1.55) + 20
import sys
MULT = float(sys.argv[1]) if len(sys.argv) > 1 else 1.0
def run(policy):
    lv, ex = 1, 0
    def gain(a):
        nonlocal lv, ex
        ex += a
        while ex >= nxt(lv):
            ex -= nxt(lv); lv += 1
    gain(64)
    out = []
    for f in range(1, 8):
        m = importlib.import_module("f%d" % f).build()
        g = m.text()
        B = gen.find(g, "B")[0]
        start = lv
        n = 0
        for (x, y), p in m.props.items():
            if "g" not in p:
                continue
            c = g[y][x]
            blk = {(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)}
            mand = B not in gen.reach(g, True, blk)
            if policy == "rush" and not mand:
                continue
            if policy == "typical" and not mand and (x * 7 + y * 3) % 10 >= 6:
                continue
            e = sum(int(EXP[k] * SCALE[f - 1]) for k in p["g"])
            if c == "L":
                e = int(e * 1.4)
            gain(int(e * MULT)); n += 1
        out.append((f, start, lv, EXPECT[f - 1], n))
        gain(int(BOSS[f - 1] * SCALE[f - 1] * MULT))
    return out
for pol in ("rush", "typical", "full"):
    print(pol, " ".join("F%d:%d→%d(期待%d,%d戦)" % r for r in run(pol)))
