from gen import *
EXTRA = {"gate": True, "gate_hint": "大きな鉄の門は、固く閉ざされている。……どこかに仕掛けがありそうだ。"}
def build():
    m = M(44, 36, seed=44)
    m.rect(2, 2, 41, 33, ".")
    # 中央の闘技場（ボス）
    m.rect(12, 8, 31, 27, "#")
    m.rect(14, 10, 29, 25, ".")
    m.rect(15, 11, 28, 24, ":")
    m.rect(20, 8, 23, 9, "+")
    m.rect(20, 10, 23, 12, "^")
    m.put(21, 18, "B")
    # 南：入口の広間
    m.rect(2, 28, 11, 33, "#"); m.rect(32, 28, 41, 33, "#")
    m.rect(5, 29, 11, 31, "."); m.rect(8, 28, 11, 28, ".")
    m.put(6, 30, "C", gald=260)
    m.rect(32, 29, 38, 31, "."); m.rect(32, 28, 35, 28, ".")
    m.put(37, 30, "E", g=["lion", "lion"], move="guard"); m.put(38, 31, "C", item="lemon_gel", n=2)
    m.vline(21, 28, 33, ":", 2)
    m.put(21, 32, "P")
    # 西翼：独房と、地下の石碑へ
    m.rect(2, 2, 8, 27, "#")
    m.rect(3, 4, 7, 6, "."); m.rect(8, 5, 8, 5, ".")          # 独房1
    m.put(4, 5, "C", item="mixed_gel", n=1)
    m.rect(3, 10, 7, 12, "."); m.rect(8, 11, 8, 11, ".")      # 独房2
    m.put(4, 11, "?")
    m.rect(3, 16, 7, 20, "^"); m.rect(8, 18, 8, 18, "^")      # 地下への階段 → 石碑
    m.rect(3, 17, 5, 19, ".")
    m.put(4, 18, "G")
    m.put(10, 15, "E", g=["soldier", "soldier"], move="wander")
    # 西と東の回廊は、狭い所に番兵（どちらから回っても一戦は避けられない）
    m.put(9, 22, "#"); m.put(11, 22, "#"); m.put(10, 22, "E", g=["gunner", "soldier"], move="guard")
    m.put(32, 22, "#"); m.put(34, 22, "#"); m.put(33, 22, "E", g=["lion", "soldier"], move="guard")
    m.rect(3, 23, 7, 25, "."); m.rect(8, 24, 8, 24, ".")      # 独房3
    m.put(4, 24, "E", g=["gunner", "soldier"], move="guard"); m.put(3, 25, "C", item="life_bottle", n=1)
    # 東翼：観客席の下（行商人・幽霊）
    m.rect(35, 2, 41, 27, "#")
    m.rect(36, 4, 40, 7, "."); m.rect(35, 6, 35, 6, ".")
    m.put(38, 5, "M")
    m.rect(36, 11, 40, 14, "."); m.rect(35, 12, 35, 12, ".")
    m.put(38, 12, "N", cid="towner", sprite="ghost", lines=[["", "鎧だけの剣闘士が、空っぽの観客席を見上げている。"], ["towner", "……歓声ガ、聞コエルカ。オレハ、百年、ココデ戦ッテイル。", ""], ["towner", "門ヲ開ケタイナラ、地下ノ石碑ヲ読メ。西ノ階段ダ。", ""], ["john", "……ここで戦った者たちの墓標か。", "serious"]])
    m.rect(36, 18, 40, 22, "."); m.rect(35, 20, 35, 20, ".")
    m.put(39, 20, "L", g=["soldier", "soldier", "gunner"]); m.put(40, 21, "C", item="orange_gel", n=3)
    m.put(38, 25, "?"); m.rect(36, 24, 40, 26, "."); m.rect(35, 25, 35, 25, "."); m.put(38, 25, "?")
    # 回廊
    m.put(33, 14, "E", g=["lion", "lion"], move="wander")
    m.put(16, 4, "E", g=["gunner", "soldier"], move="wander")
    m.put(28, 30, "E", g=["lion", "soldier"], move="wander")
    m.put(27, 5, "F")
    m.put(32, 3, "C", gald=300)
    # 柱
    for x in range(10, 34, 4):
        if m.get(x, 3) == ".":
            m.put(x, 3, "T")
    m.scatter("T", 10, near_wall=True)
    m.scatter("o", 12)
    m.scatter(",", 40)
    m.scatter('"', 12)
    return m
