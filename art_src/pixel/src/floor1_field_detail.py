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


def road(bits, variant, join_east=False):
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
    if join_east:
        s.polygon([(16, 6), (24, 3), (31, 0), (31, 31), (24, 28),
                   (16, 25)], fill=1)
        s.line((31, 0, 31, 31), fill=1)
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
            if join_east and x == 31:
                color = ROAD
            elif depth == 1:
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


def main():
    output = Path(sys.argv[1])
    atlas = Image.new("RGBA", (8*SIZE, 8*SIZE))
    for i in range(8):
        atlas.paste(grass(i), (i*SIZE, 0))
    for bits in range(16):
        for variant in range(2):
            i = bits + variant * 16
            atlas.paste(road(bits, variant), (i % 8 * SIZE, (1 + i // 8) * SIZE))
    for i in range(4):
        atlas.paste(tree(i), (i*SIZE, 5*SIZE))
    for i in range(8):
        # 最後の行は、旧タイルの幅へ戻す東端の接続用。
        bits = (i & 1) | 2 | ((i & 2) << 1) | ((i & 4) << 1)
        atlas.paste(road(bits, 0, join_east=True), (i*SIZE, 7*SIZE))
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("xb") as stream:
        atlas.save(stream, "PNG", optimize=True)


if __name__ == "__main__":
    main()
