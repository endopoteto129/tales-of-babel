from gen import *
def build():
    m = M(28, 40, seed=77)
    W2 = 2
    # 塔の外壁をつづら折りに登る
    m.vline(12, 33, 38, ".", 3)
    m.hline(12, 23, 32, ".", 3)
    m.vline(21, 26, 34, ".", 3)
    m.hline(4, 23, 26, ".", 3)
    m.vline(4, 20, 28, ".", 3)
    m.hline(4, 23, 20, ".", 3)
    m.vline(21, 14, 22, ".", 3)
    m.hline(4, 23, 14, ".", 3)
    m.vline(4, 8, 16, ".", 3)
    m.hline(4, 16, 8, ".", 3)
    m.vline(12, 2, 10, ".", 4)
    m.rect(8, 1, 19, 5, ".")
    m.rect(9, 1, 18, 2, "^")
    # 道の中央に金の敷物
    m.vline(13, 33, 38, ":"); m.hline(13, 22, 33, ":"); m.vline(22, 27, 33, ":"); m.hline(5, 22, 27, ":")
    m.vline(5, 21, 27, ":"); m.hline(5, 22, 21, ":"); m.vline(22, 15, 21, ":"); m.hline(5, 22, 15, ":")
    m.vline(5, 9, 15, ":"); m.hline(5, 13, 9, ":"); m.vline(13, 3, 9, ":")
    m.put(13, 38, "P")
    m.rect(12, 36, 14, 36, "G")
    # 張り出した足場（寄り道）
    m.rect(24, 28, 26, 30, "."); m.put(25, 29, "C", item="life_bottle", n=1)
    m.rect(1, 23, 3, 25, "."); m.put(1, 24, "C", item="mixed_gel", n=2)
    m.put(2, 23, "E", g=["soldier", "soldier", "mage_soldier"], move="guard")
    m.rect(24, 17, 26, 19, "."); m.put(25, 18, "C", item="lemon_gel", n=3)
    # 避けられない戦い
    m.put(17, 27, "E", g=["soldier", "soldier", "gunner"], move="guard")
    m.put(19, 22, "E", g=["soldier", "soldier", "mage_soldier"], move="wander")
    m.put(13, 15, "L", g=["soldier", "mage_soldier", "gunner"])
    m.put(6, 10, "F")
    m.put(13, 2, "B")
    for (x, y) in [(11, 31), (15, 31), (19, 31), (7, 25), (15, 25), (7, 19), (15, 19), (9, 13), (17, 13), (8, 7)]:
        if m.get(x, y) == ".":
            m.put(x, y, "T")
    m.scatter(",", 18)
    return m
