from gen import *
def build():
    m = M(44, 36, seed=33)
    # 西の竹林（迷路）→ 月見の広場（中盤）→ 東の竹林（迷路）→ ボス
    maze(m, 2, 2, 6, 11, seed=301, path=".")      # x 2..19, y 2..34
    maze(m, 26, 2, 6, 11, seed=302, path=".")     # x 26..43
    for y in range(36):
        m.put(43, y, "#")
    # 月見の広場（両方の竹林をつなぐ唯一の場所）
    m.blob(22, 18, 3, 4)
    m.rect(20, 17, 25, 18, ".")
    m.hline(18, 21, 18, ".", 1); m.hline(19, 21, 17, ".", 1)
    m.hline(23, 26, 18, ".", 1); m.hline(23, 26, 17, ".", 1)
    m.rect(21, 15, 23, 15, "~")                  # 月を映す池
    m.put(22, 19, "G")
    m.put(21, 19, "G"); m.put(23, 19, "G")
    m.rect(24, 1, 25, 34, "#"); m.rect(24, 17, 25, 18, "+")   # 東への門（竹の柵）。ここ以外は通れない
    m.put(2, 34, "P")
    # 西の竹林
    m.put(8, 30, "E", g=["oni", "oni"], move="wander")
    m.put(14, 24, "E", g=["oni", "wisp"], move="wander")
    m.put(5, 13, "E", g=["bat", "bat", "oni"], move="wander")
    m.put(17, 8, "E", g=["wolf", "oni"], move="guard")
    m.put(2, 2, "C", recipe="azuma_soba")
    m.put(19, 2, "C", item="mixed_gel", n=1)
    m.put(11, 17, "?")
    m.put(13, 34, "C", gald=220)
    m.put(18, 20, "M")
    m.put(19, 17, "E", g=["oni", "oni"], move="guard")      # 広場の手前の番
    # 東の竹林
    m.put(32, 29, "E", g=["oni", "oni"], move="wander")
    m.put(38, 20, "E", g=["oni", "wisp"], move="wander")
    m.put(29, 9, "E", g=["bat", "bat", "oni"], move="wander")
    m.put(41, 34, "L", g=["oni", "oni", "golem"])
    m.put(42, 34, "C", item="life_bottle", n=1)
    m.put(35, 14, "?")
    m.put(26, 34, "C", item="lemon_gel", n=2)
    # ボスの広場
    m.blob(36, 4, 5, 2)
    m.put(36, 3, "B")
    m.put(27, 17, "E", g=["wolf", "oni"], move="guard")     # 門を抜けた先の番
    m.put(31, 5, "F")
    m.scatter("T", 26, near_wall=True)
    m.scatter("o", 6)
    m.scatter(",", 40)
    m.scatter('"', 30)
    return m
