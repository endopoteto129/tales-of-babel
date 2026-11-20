from gen import *
EXTRA = {"gate": True}
T = "towner"
def build():
    m = M(44, 36, seed=22)
    # ---------------- 南：魔物のいない街（安全）
    m.rect(3, 19, 40, 34, ".")
    m.vline(20, 17, 34, ":", 2)       # 大通り
    m.hline(3, 40, 27, ":", 2)        # 横の通り
    for (x0, y0, x1, y1) in [(5, 21, 10, 24), (13, 21, 17, 24), (25, 21, 29, 24), (32, 21, 38, 24),
                             (5, 30, 11, 33), (14, 30, 17, 33), (25, 30, 29, 33), (32, 30, 38, 33)]:
        m.rect(x0, y0, x1, y1, "#")
    m.put(20, 34, "P")
    m.put(23, 32, "N", cid=T, lines=[["towner", "ヨウコソ、上ヘ昇ル人。ココハ魔物ノ来ナイ街。", ""], ["towner", "北ノ門ノ外ハ、ズット昔ニ壊レタ街。魔物ガ住ンデイル。", ""], ["nine", "おしえてくれて、ありがとう！", "smile"]])
    m.put(12, 26, "M")                                   # 市場の行商人
    m.rect(11, 25, 13, 25, "\"")
    m.put(36, 26, "N", cid=T, lines=[["towner", "歌姫ノ歌ヲ、聞イタコトアルカ？", ""], ["towner", "キレイナ声ダ。デモ、聞イタ者ハ、目ヲ覚マサナイ。", ""], ["ren", "……用心しておこう。", "serious"]])
    m.put(7, 28, "?")                                    # 大道芸人など
    m.put(39, 29, "C", gald=120)
    m.put(4, 34, "C", item="orange_gel", n=2)
    m.rect(4, 33, 4, 34, "."); m.put(4, 34, "C", item="orange_gel", n=2)
    m.put(30, 20, "N", cid=T, lines=[["towner", "外カラ来タ人間ハ、久シブリ。少シ前ニモ、一人来タ。", ""], ["towner", "変ナ機械ヲ持ッタ、女ノ人。広場デ、空ヲ測ッテイル。", ""], ["angie", "機械……？　魔学の道具かしら。", "think"]])
    # 広場と噴水
    m.blob(20, 18, 6, 3)
    m.rect(20, 18, 21, 18, "~")
    m.put(16, 17, "o"); m.put(25, 17, "o")
    m.hline(18, 23, 16, "G")                             # ソナとの出会い
    m.rect(17, 15, 24, 15, "#")
    m.rect(19, 15, 22, 15, "+")                          # 北の門
    # ---------------- 北：崩れた旧市街（魔物が出る）
    m.rect(3, 2, 40, 14, ".")
    m.vline(20, 9, 14, ":", 2)
    for (x0, y0, x1, y1) in [(5, 10, 9, 13), (12, 10, 16, 12), (25, 10, 29, 13), (32, 11, 38, 13),
                             (5, 4, 9, 7), (12, 3, 17, 7), (21, 3, 24, 7), (27, 5, 30, 8)]:
        m.rect(x0, y0, x1, y1, "#")
    m.rect(5, 8, 9, 8, "#")                               # 西の路地を細くする
    m.hline(3, 31, 9, ":")
    m.vline(3, 2, 9, ":")
    m.hline(3, 19, 2, ":")
    m.vline(19, 2, 8, ":")
    m.rect(25, 2, 26, 4, ".")
    m.rect(5, 8, 40, 8, "#")                              # 崩れた城壁（西の端からしか上へ行けない）
    m.rect(31, 2, 31, 7, "#"); m.rect(31, 3, 31, 3, ".")  # ボスの舞台への入口
    m.rect(32, 2, 40, 7, ".")
    m.rect(32, 2, 40, 2, "^")
    m.put(36, 3, "B")
    m.put(33, 6, "F")
    m.put(22, 12, "E", g=["ikei", "slime"], move="wander")
    m.put(11, 9, "E", g=["wisp", "wolf"], move="wander")
    m.put(31, 10, "E", g=["bat", "bat", "wisp"], move="wander")
    m.put(4, 5, "E", g=["ikei", "ikei"], move="guard")    # 西の路地の番
    m.put(19, 5, "E", g=["wisp", "wolf"], move="wander")
    m.put(38, 7, "E", g=["ikei", "slime"], move="wander")
    m.put(39, 13, "L", g=["golem", "wisp"])                # 強敵の奥に宝箱
    m.put(40, 14, "C", item="life_bottle", n=1)
    m.put(10, 2, "C", recipe="herb_soup")
    m.put(14, 9, "C", item="lemon_gel", n=2)
    m.put(26, 2, "C", gald=200)
    m.put(4, 13, "?")
    m.scatter("T", 14, near_wall=True)
    m.scatter("o", 10)
    m.scatter(",", 30)
    m.scatter('"', 8)
    return m
