from gen import *
EXTRA = {"gate": True, "gate_hint": "重い隔壁が閉じている。……中央の制御室で開けられそうだ。"}
XS = [(2, 12), (16, 27), (31, 41)]
YS = [(2, 10), (14, 21), (25, 33)]
def room(m, i, j):
    x0, x1 = XS[i]; y0, y1 = YS[j]
    m.rect(x0, y0, x1, y1, ".")
def cx(i): return (XS[i][0] + XS[i][1]) // 2
def cy(j): return (YS[j][0] + YS[j][1]) // 2
def hall(m, a, b, c=":"):
    (i1, j1), (i2, j2) = a, b
    if j1 == j2:
        m.hline(cx(i1), cx(i2), cy(j1), c, 2)
    else:
        m.vline(cx(i1), cy(j1), cy(j2), c, 2)
def build():
    m = M(44, 36, seed=66)
    for i in range(3):
        for j in range(3):
            room(m, i, j)
    for a, b in [((2, 2), (1, 2)), ((1, 2), (0, 2)), ((0, 2), (0, 1)), ((1, 2), (1, 1)), ((2, 2), (2, 1)),
                 ((2, 1), (2, 0)), ((2, 0), (1, 0)), ((1, 1), (2, 1)), ((1, 1), (1, 0))]:
        hall(m, a, b)
    # ボスの部屋（左上）へは隔壁だけ
    m.vline(cx(0), cy(0), cy(1), ":", 2)
    m.rect(cx(0), 11, cx(0) + 1, 12, "+")
    # 機械と溶けた鉄
    m.rect(19, 28, 24, 30, "~")                 # 溶鉱炉（南中央）
    m.rect(3, 15, 5, 17, "~"); m.rect(9, 19, 11, 21, "~")
    m.rect(33, 4, 35, 6, "o"); m.rect(38, 8, 40, 9, "o")
    m.rect(18, 3, 20, 4, "o"); m.rect(24, 7, 26, 9, "o")
    m.rect(33, 16, 34, 19, "o"); m.rect(38, 15, 39, 16, "o")
    # 中央：制御室（中盤）
    m.rect(19, 16, 24, 19, "\"")
    m.rect(20, 17, 23, 18, "G")
    m.put(41, 33, "P")
    # 敵
    m.put(30, 29, "E", g=["gear", "drone"], move="wander")
    m.put(36, 22, "E", g=["soldier", "drone", "drone"], move="guard")
    m.put(36, 12, "E", g=["gear", "gear"], move="wander")
    m.put(28, 6, "E", g=["gunner", "gunner", "soldier"], move="wander")
    m.put(14, 30, "E", g=["gear", "drone"], move="wander")
    m.put(7, 27, "E", g=["soldier", "drone", "drone"], move="wander")
    m.put(22, 12, "E", g=["gunner", "gunner", "soldier"], move="guard")
    m.put(7, 15, "E", g=["gear", "gear"], move="wander")
    m.put(16, 2, "L", g=["gear", "gear", "drone"]); m.put(18, 2, "C", item="life_bottle", n=2)
    # 宝・店・イベント
    m.put(41, 2, "C", gald=380)
    m.put(2, 33, "C", item="mixed_gel", n=2)
    m.put(26, 21, "C", item="lemon_gel", n=3)
    m.put(2, 21, "C", item="orange_gel", n=3)
    m.put(39, 19, "M")
    m.put(12, 25, "?")
    m.put(31, 2, "?")
    m.put(27, 33, "N", cid="towner", sprite="robot", lines=[["", "古い作業ロボットが、同じ動きを繰り返している。"], ["towner", "ピ……ピピ。作業手順、三万六千五百回目。……ハカセ、マダ帰ッテキマセン。", ""], ["pots", "……あなたも、誰かを待っているのですね。", ""], ["towner", "ピ。マッテイマス。ズット。", ""]])
    m.put(6, 4, "F")
    m.put(7, 7, "B")
    m.scatter("T", 14, near_wall=True)
    m.scatter(",", 40)
    m.scatter('"', 10)
    return m
