"""第一層の探索用32ドットタイルを原寸で描く。"""
from collections import deque
from pathlib import Path
from random import Random
import sys

from PIL import Image, ImageDraw

SIZE = 32
GRASS = "#79a957"
ROAD = "#bd965e"


def grass(index):
    image = Image.new("RGBA", (SIZE, SIZE), GRASS)
    d = ImageDraw.Draw(image)
    rng = Random(502 + index)
    # 低コントラストの草を数本ずつまとめ、広い余白を残す。
    for _ in range(13):
        x, y = rng.randrange(2, 30), rng.randrange(3, 30)
        color = rng.choice(["#6e9e51", "#739f53", "#81ae59", "#84ad58"])
        d.line((x - 1, y, x + rng.randrange(3), y), color)
        if rng.randrange(3) == 0:
            d.point((x, y - 1), color)
    for _ in range(2 if index < 6 else 5):
        x, y = rng.randrange(4, 28), rng.randrange(6, 29)
        d.line((x - 2, y + 1, x + 2, y + 1), "#6a984e")
        d.line([(x - 2, y - 1), (x, y), (x, y - 3)], "#648f49")
        d.line([(x + 2, y - 2), (x + 1, y), (x, y)], "#8cb35e")
    if index in (6, 7):
        x, y = (8, 19) if index == 6 else (22, 11)
        for dx, dy, color in [(0, 0, "#efe4a7"), (4, 2, "#ddb7a0"), (7, -3, "#f6edba")]:
            px, py = x + dx, y + dy
            d.line((px, py, px - 1, py + 3), "#568440")
            d.point([(px-1, py), (px+1, py), (px, py-1)], color)
            d.point((px, py), "#bd955c")
    return image


def road(bits, variant):
    image = grass(variant)
    d = ImageDraw.Draw(image)
    rng = Random(73 + bits * 7 + variant)
    shape = Image.new("1", (SIZE, SIZE))
    s = ImageDraw.Draw(shape)
    s.ellipse((6, 6, 25, 25), fill=1)
    # 上・右・下・左。接続面の幅と中心をすべてのマスでそろえる。
    for bit, box in [(1, (6, 0, 25, 16)), (2, (16, 6, 31, 25)),
                     (4, (6, 16, 25, 31)), (8, (0, 6, 16, 25))]:
        if bits & bit:
            s.rectangle(box, fill=1)
    # 形状の境界からの距離で縁の草、砂利、締まった土を分ける。
    distances = {}
    queue = deque()
    for y in range(SIZE):
        for x in range(SIZE):
            if not shape.getpixel((x, y)):
                distances[x, y] = 0
                queue.append((x, y))
    while queue:
        x, y = queue.popleft()
        if distances[x, y] >= 5:
            continue
        for dx, dy in [(1, 0), (0, 1), (-1, 0), (0, -1)]:
            key = x+dx, y+dy
            if 0 <= key[0] < SIZE and 0 <= key[1] < SIZE and key not in distances:
                distances[key] = distances[x, y] + 1
                queue.append(key)
    for y in range(SIZE):
        for x in range(SIZE):
            depth = distances.get((x, y), 6)
            if depth == 0:
                continue
            if depth == 1:
                color = rng.choice(["#8aa557", "#9da059", "#a2a45b", "#9ba05b"]) if 2 < x < 29 and 2 < y < 29 else "#9da059"
            elif depth == 2:
                color = rng.choice(["#aa9a5b", "#b0a063", "#b39e60"])
            elif depth == 3:
                color = "#b5945e"
            else:
                color = ROAD
            d.point((x, y), color)
    for _ in range(25):
        x, y = rng.randrange(2, 29), rng.randrange(2, 30)
        if distances.get((x, y), 6) > 2 and distances.get((x+1, y), 6) > 2:
            d.line((x, y, x + rng.randrange(2), y), rng.choice(
                ["#c6a16b", "#b28a56", "#b98f5a", "#c39460"]))
    # 草が欠けた縁や土の小さな濃淡を加え、道を均一な帯に見せない。
    for _ in range(48):
        x, y = rng.randrange(3, 29), rng.randrange(3, 29)
        depth = distances.get((x, y), 6)
        if depth in (1, 2):
            d.point((x, y), rng.choice(["#7f9e50", "#91a458", "#a69c60", "#b59b66"]))
            if depth == 1 and distances.get((x, y-1), 6) <= 2:
                d.line((x, y, x, y-1), "#86a452")
    for _ in range(10):
        x, y = rng.randrange(3, 27), rng.randrange(3, 29)
        width = rng.randrange(2, 5)
        if all(distances.get((x+i, y), 6) >= 4 for i in range(width)):
            d.line((x, y, x+width-1, y), rng.choice(["#c39b64", "#b8915a", "#b68d57"]))
    return image


def tree(index):
    rng = Random(312 + index)
    image = Image.new("RGBA", (32, 64))
    d = ImageDraw.Draw(image)
    d.ellipse((2, 55, 30, 63), (43, 70, 47, 92))
    d.ellipse((8, 56, 26, 61), (40, 63, 42, 138))
    d.polygon([(13, 34), (19, 34), (19, 53), (21, 57), (25, 59),
               (22, 60), (18, 59), (16, 61), (12, 59), (7, 60),
               (10, 56), (13, 53)], "#3e372b")
    d.polygon([(14, 38), (18, 37), (17, 53), (19, 57), (22, 59),
               (17, 57), (15, 60), (14, 57), (10, 58), (14, 53)], "#8e6645")
    d.line([(15, 41), (15, 53), (13, 56)], "#b48659")
    d.line([(17, 50), (16, 55), (17, 57)], "#644b39")
    crowns = [
        [(15, 16, 10, 12), (10, 25, 9, 11), (22, 26, 8, 10), (16, 36, 12, 10), (9, 35, 8, 8)],
        [(18, 17, 9, 12), (15, 26, 11, 11), (9, 35, 7, 10), (22, 31, 8, 12), (16, 40, 10, 8)],
        [(12, 18, 9, 10), (19, 21, 9, 12), (24, 31, 7, 9), (9, 32, 8, 10), (16, 38, 11, 9)],
        [(16, 13, 8, 11), (12, 23, 8, 12), (22, 26, 8, 11), (9, 38, 7, 8), (18, 38, 12, 10)],
    ][index]
    # 重なる葉の塊を枝ごとに描き、左上から色を明るくする。
    for x, y, a, b in crowns:
        d.ellipse((x-a, y-b, x+a, y+b), "#294a38")
    for x, y, a, b in reversed(crowns):
        d.ellipse((x-a+1, y-b+1, x+a-1, y+b-2), "#38764c")
        d.ellipse((x-a+1, y-b+1, x+a-3, y+b-5), "#4a8d52")
        d.ellipse((x-a+2, y-b+2, x+1, y+1), "#5b9b56")
        for _ in range(12):
            px, py = rng.randrange(x-a+2, x+a-1), rng.randrange(y-b+2, y+b-1)
            if ((px-x)/(a-1))**2 + ((py-y)/(b-1))**2 < .76:
                color = rng.choice(["#64a357", "#6eab60", "#4b8950", "#39754b"])
                d.line([(px, py), (px+1, py-1), (px+2, py-1)], color)
        d.line([(x-a+3, y-2), (x-a+4, y-4), (x-a+6, y-5)], "#74af62")
    return image


def rock_face(d, rng, top, bottom):
    """32ドット幅の岩肌に、大きな面と割れ目を描く。"""
    d.rectangle((0, top, 31, bottom), "#414941")
    for x in range(-7, 33, 8):
        u = x + rng.randrange(-2, 2)
        v = u + rng.randrange(-2, 3)
        mid = top + (bottom - top)//2
        d.polygon([(u, top), (u+7, top), (u+9, mid), (v+6, bottom),
                   (v-1, bottom), (u+1, mid)], fill=rng.choice(["#666b50", "#61644e", "#74715a"]))
        d.polygon([(u+7, top+1), (u+9, mid), (v+6, bottom),
                   (v+4, bottom), (u+6, mid)], fill="#4d5848")
        d.line([(u+1, top+2), (u+2, mid), (v+1, min(bottom, mid+3))], fill="#888267")
        d.line([(u+3, mid+1), (u+6, mid+1), (u+8, mid+3)], fill="#555e4e")
    d.line((0, bottom, 31, bottom), fill="#3b4941")


def forest_wall(index, front):
    rng = Random(6512 + index)
    image = Image.new("RGBA", (SIZE, SIZE), "#2b503b")
    d = ImageDraw.Draw(image)
    limit = 19 if front else 31
    if front:
        rock_face(d, rng, 15, 31)
    # 大きさと形が違う樹冠を重ね、つながる深い緑の森をつくる。
    clusters = [(2, 1), (16, 3), (30, 1), (7, 11), (24, 12)]
    clusters += ([(1, 19), (16, 18), (30, 18)] if front else
                 [(1, 20), (16, 20), (30, 20), (8, 30), (25, 31)])
    for x, y in clusters:
        x += rng.randrange(-2, 3)
        y += rng.randrange(-2, 3)
        w, h = rng.randrange(7, 11), rng.randrange(5, 8)
        btm = min(limit + rng.randrange(3), y+h)
        d.ellipse((x-w, y-h, x+w, btm), fill="#254936")
        d.ellipse((x-w+1, y-h+1, x+w-1, btm-1), fill=rng.choice(["#387451", "#3b7752", "#3c7b53"]))
        d.ellipse((x-w+1, y-h+1, x+w-4, min(btm-2, y+3)), fill="#4a8758")
        for _ in range(9):
            dx, dy = rng.randrange(-w+2, w-2), rng.randrange(-h+2, h-1)
            if (dx/w)**2+(dy/h)**2 < .78 and y+dy < btm-1:
                px, py = x+dx, y+dy
                d.line((px, py, px+1, py), fill=rng.choice(["#52965d", "#5d9d62", "#32684c", "#418053"]))
    if front:
        for x in range(2, 31, 5):
            y = rng.randrange(22, 30)
            d.line([(x-1, y), (x, y-1), (x+2,y-1)], fill="#6f7c53")
    return image


def water(bits, frame):
    image = Image.new("RGBA", (SIZE, SIZE), "#3e849a")
    d = ImageDraw.Draw(image)
    rng = Random(346)
    # 岸の方向だけ浅瀬を置く。上下左右の接続面で色と幅をそろえる。
    bend = (0,0,0,1,1,1,2,2,1,1,0,0,-1,-1,-1,0,
            0,0,1,2,2,1,1,0,0,-1,-1,0,0,0,0,0)
    for y in range(SIZE):
        for x in range(SIZE):
            distances = ((1,y-bend[x]),(2,31-x-bend[31-y]),
                         (4,31-y-bend[31-x]),(8,x-bend[y]))
            depth = min((v for side,v in distances if bits & side), default=32)
            if depth < 2:
                d.point((x,y),"#759f91")
            elif depth < 4:
                d.point((x,y),"#6ca7a8")
            elif depth < 7:
                d.point((x,y),"#5197a1")
    for _ in range(17):
        x, y = rng.randrange(1,26), rng.randrange(1,31)
        w = rng.randrange(2,7)
        x = (x + frame*3) % (31-w)
        c = rng.choice(["#5895a3", "#4c8f9e", "#357a91", "#72aeb2"])
        d.line((x,y,x+w,y), fill=c)
        if w > 4:
            d.point((x+w-1,y+1), "#4d91a1")
    for bit in (1,2,4,8):
        if not bits & bit:
            continue
        for i in (5,15,24):
            v = 2 + (i//6 + frame)%2
            if bit == 1 or bit == 4:
                p = v+bend[i] if bit == 1 else 31-v-bend[31-i]
                d.line((i,p,i+2,p), fill="#aac4ad")
            else:
                p = v+bend[i] if bit == 8 else 31-v-bend[31-i]
                d.line((p,i,p,i+2), fill="#aac4ad")
    return image


def bridge(bits, section=0):
    image = water(0, 0)
    d = ImageDraw.Draw(image)
    rng = Random(477+bits)
    left = "#839a66" if not bits & 1 else "#316d80"
    right = "#839a66" if not bits & 2 else "#316d80"
    if not bits & 1:
        d.polygon([(0,0),(3,0),(5,5),(3,13),(4,22),(3,31),(0,31)], fill=left)
    if not bits & 2:
        d.polygon([(31,0),(28,0),(26,5),(28,13),(27,22),(28,31),(31,31)], fill=right)
    # 0: 単独、1: 幅広の北側、2: 幅広の南側。板の色は南北で一致させる。
    start, end = (0 if section == 2 else 6), (31 if section == 1 else 24)
    d.rectangle((0, start+1, 31, min(31,end+2)), "#365359")
    d.rectangle((0, start, 31, end), "#5f4436")
    for x in range(0,32,4):
        c = rng.choice(["#ad7f53", "#b58a5a", "#a6754c", "#be905b"])
        board_top, board_end = (0 if section == 2 else 9), (31 if section == 1 else 21)
        d.rectangle((x, board_top, x+2, board_end), c)
        d.line((x,board_top,x,board_end), "#c79b65")
        y=rng.randrange(11,19)
        d.line((x+2,y,x+2,y+3), "#8b6647")
    rails = (6,22) if section == 0 else ((6,) if section == 1 else (22,))
    for y in rails:
        d.rectangle((0,y,31,y+2), "#73523b")
        d.line((0,y,31,y), "#b38b59")
        for x in (3,19):
            d.rectangle((x,y-1,x+1,y+2), "#674b39")
            d.point((x,y-1), "#d0a46e")
    return image


def boulder():
    image = Image.new("RGBA", (SIZE,SIZE))
    d = ImageDraw.Draw(image)
    d.ellipse((3,21,30,31), fill=(38,66,44,94))
    d.polygon([(3,24),(5,16),(11,10),(20,8),(27,12),(30,21),(28,26),(12,29)],
              fill="#3b4d45")
    d.polygon([(5,23),(7,17),(12,11),(20,10),(26,13),(22,19),(14,23),(8,25)],
              fill="#829184")
    d.polygon([(9,17),(13,12),(20,10),(23,13),(17,16),(13,17)], fill="#a9ae93")
    d.polygon([(23,18),(27,14),(29,21),(27,25),(14,27),(12,25)], fill="#5b7167")
    d.line([(17,16),(15,20),(18,21)], fill="#697c71")
    d.line([(6,23),(8,24),(11,23)], fill="#86a061")
    return image


def ledge(bits, variant):
    rng = Random(142+bits+variant*7)
    face=Image.new("RGBA",(SIZE,SIZE))
    d=ImageDraw.Draw(face)
    bottom=19+variant*2
    rock_face(d,rng,0,bottom)
    d.line((0,0,31,0),"#7c8263",2)
    mask=Image.new("L",(SIZE,SIZE))
    left=4 if bits & 1 else 0
    right=4 if bits & 2 else 0
    ImageDraw.Draw(mask).polygon([(0,0),(31,0),(31-right,bottom-right),
        (31-right*2,bottom),(left*2,bottom),(left,bottom-left)], fill=255)
    face.putalpha(mask)
    return face


def main():
    output = Path(sys.argv[1])
    atlas = Image.new("RGBA", (8*SIZE, 15*SIZE))
    for i in range(8):
        atlas.paste(grass(i), (i*SIZE, 0))
    for bits in range(16):
        for variant in range(2):
            i = bits + variant * 16
            atlas.paste(road(bits, variant), (i % 8 * SIZE, (1 + i // 8) * SIZE))
    for i in range(4):
        atlas.paste(tree(i), (i*SIZE, 5*SIZE))
    for i in range(4):
        atlas.paste(forest_wall(i, False), (i*SIZE, 7*SIZE))
        atlas.paste(forest_wall(i, True), ((i+4)*SIZE, 7*SIZE))
        atlas.paste(bridge(i), (i*SIZE, 12*SIZE))
        atlas.paste(bridge(i,1),(i*SIZE,14*SIZE))
        atlas.paste(bridge(i,2),((i+4)*SIZE,14*SIZE))
        for v in range(2):
            atlas.paste(ledge(i,v), ((i+v*4)*SIZE,13*SIZE))
    for f in range(2):
        for bits in range(16):
            atlas.paste(water(bits,f), ((bits%8)*SIZE, (8+bits//8+f*2)*SIZE))
    atlas.paste(boulder(),(4*SIZE,12*SIZE))
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("xb") as stream:
        atlas.save(stream, "PNG", optimize=True)


if __name__ == "__main__":
    main()
