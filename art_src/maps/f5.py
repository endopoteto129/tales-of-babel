from gen import *
EXTRA = {"gate": True}
def build():
    m = M(44, 36, seed=55)
    m.rect(2, 2, 41, 33, ".")
    # 書架の列（端の切れ目を左右交互にして、行ったり来たりさせる）
    shelves = [(30, "R"), (26, "L"), (22, "R"), (14, "L"), (10, "R"), (6, "L")]
    for y, gap in shelves:
        m.rect(2, y, 41, y, "#")
        if gap == "R":
            m.rect(38, y, 40, y, ".")
        else:
            m.rect(3, y, 5, y, ".")
    # 中央の閲覧室（中盤）。上の段へは門を通る
    m.rect(2, 18, 41, 18, "#")
    m.rect(19, 18, 22, 18, "+")
    m.rect(16, 15, 25, 17, "\"")
    m.rect(17, 19, 24, 21, "\"")
    m.rect(19, 19, 22, 20, "G")
    # 細い書架で区切った小部屋
    for x in (10, 18, 27, 34):
        m.rect(x, 31, x, 32, "#")
    for x in (12, 24, 31):
        m.rect(x, 27, x, 28, "#")
    for x in (9, 15, 30):
        m.rect(x, 23, x, 24, "#")
    for x in (8, 26, 33):
        m.rect(x, 11, x, 12, "#")
    for x in (12, 20, 30):
        m.rect(x, 7, x, 8, "#")
    # 星空の吹き抜け
    m.rect(14, 28, 17, 29, "~"); m.rect(24, 8, 25, 8, "~"); m.rect(34, 19, 36, 20, "~"); m.rect(6, 15, 8, 16, "~")
    m.put(3, 32, "P")
    m.vline(39, 2, 5, "^")
    # 敵（本の魔物と魔学兵）
    m.put(22, 32, "E", g=["book", "book"], move="wander")
    m.put(9, 28, "E", g=["mage_soldier", "soldier"], move="wander")
    m.put(39, 26, "E", g=["book", "wisp", "wisp"], move="guard")
    m.put(25, 24, "E", g=["gunner", "book"], move="wander")
    m.put(4, 20, "E", g=["book", "book"], move="wander")
    m.put(33, 12, "E", g=["mage_soldier", "soldier"], move="wander")
    m.put(12, 12, "E", g=["gunner", "book"], move="wander")
    m.put(4, 6, "E", g=["book", "wisp", "wisp"], move="guard")
    m.put(16, 4, "L", g=["golem", "book", "book"])
    m.put(14, 3, "C", item="life_bottle", n=1)
    # 宝・店・イベント
    m.put(40, 32, "C", gald=320)
    m.put(11, 24, "C", recipe="star_parfait")
    m.put(41, 21, "C", item="mixed_gel", n=2)
    m.put(28, 12, "C", item="lemon_gel", n=2)
    m.put(2, 28, "C", item="orange_gel", n=3)
    m.put(30, 20, "M")
    m.put(25, 29, "?")
    m.put(7, 11, "?")
    m.put(34, 4, "F")
    m.put(38, 3, "B")
    m.put(27, 3, "N", cid="towner", sprite="librarian", lines=[["", "本の山に埋もれて、古い司書の影が頁をめくっている。"], ["towner", "……シッ。ココハ書庫。オ静カニ。", ""], ["towner", "星ノ本ハ、読ム者ノ『認識』ヲ映ス。……アナタタチノ本ハ、マダ白紙ネ。", ""], ["angie", "……ちょっと、ここに住みたいんだけど。", "laugh"], ["sona", "だめよ。", ""]])
    m.scatter("T", 10, near_wall=True)
    m.scatter("o", 14)
    m.scatter(",", 40)
    return m
