from gen import *
def build():
    m = M(44, 36, seed=11)
    # --- A: 南の草原（スタート）
    m.blob(8, 30, 6, 4); m.blob(18, 29, 6, 3); m.blob(29, 30, 7, 3); m.blob(36, 28, 4, 3)
    m.blob(24, 33, 3, 1)
    m.hline(5, 38, 30, ":")
    m.vline(38, 26, 30, ":")
    m.put(5, 31, "P")
    m.put(15, 27, "C", item="apple_gel", n=2)            # 最初の宝箱（道のすぐ脇）
    m.put(25, 33, "?")            # 花畑のイベント
    m.put(27, 28, "E", g=["slime"], move="wander")            # 道の近くをうろつくスライム（避けてもよい）
    # --- 門の小道（ここだけは戦闘を避けられない）
    m.vline(38, 21, 25, ".")
    m.put(38, 24, "E", g=["slime", "slime"], move="guard")            # 番をするスライム
    m.put(38, 22, "G")            # ナイン「さっきの見た？」
    # --- B: 川のある中央の草原
    m.blob(32, 17, 9, 4); m.blob(12, 16, 9, 4); m.blob(22, 14, 4, 2)
    m.vline(21, 11, 21, "~", 2)
    m.rect(21, 16, 22, 17, "=")   # 橋
    m.hline(5, 38, 17, ":")
    m.vline(38, 17, 21, ":")
    m.put(28, 14, "E", g=["wolf"], move="wander")            # 草原ウルフ
    m.put(13, 19, "E", g=["bat", "slime"], move="wander")
    m.put(9, 13, "M")             # 異形の行商人
    m.put(34, 13, "C", item="orange_gel", n=2)
    m.put(16, 21, "C", gald=150)
    m.blob(4, 20, 2, 1); m.put(3, 20, "C", item="lemon_gel", n=1)   # 隠れた小部屋
    m.hline(4, 6, 19, ".")
    # --- 北への小道
    m.vline(5, 7, 17, ":")
    m.put(5, 11, "E", g=["bat", "slime"], move="guard")   # 北への小道の番
    # --- C: 北の森（ボスへ）
    m.blob(9, 5, 5, 3); m.blob(19, 6, 5, 3); m.blob(27, 7, 4, 2)
    m.hline(5, 34, 6, ":")
    m.put(14, 3, "E", g=["slime", "slime"], move="wander")
    m.put(22, 8, "E", g=["wolf"], move="wander")
    m.blob(19, 2, 3, 1); m.put(19, 2, "L", g=["golem"]); m.put(21, 1, "C", item="life_bottle", n=1)   # 強敵が守る宝箱
    m.blob(36, 5, 5, 4)
    m.put(31, 7, "F")
    m.put(37, 3, "B")
    m.put(9, 8, "?")
    # 装飾（通行を妨げない）
    m.scatter("T", 34, near_wall=True)
    m.scatter("o", 6)
    m.scatter(",", 40)
    m.scatter('"', 40)
    return m
