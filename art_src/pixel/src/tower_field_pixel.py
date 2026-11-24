"""上層のタイル、住人、赤いマントを羽織ったレンの歩行素材を描く。"""

import argparse
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps

from floor1_pixel import ren

# 地面、床ハイライト、目地、壁の影、壁の正面、壁ハイライト、水面、反射、装飾
PALETTES = {
    "town": ("514250", "635263", "3a333f", "302137", "633951", "885771", "203153", "58809b", "efb76e"),
    "bamboo": ("203941", "2d4d54", "142e39", "102634", "24504f", "41776c", "162b49", "6999ab", "b2cdb5"),
    "colosseum": ("8b654a", "a57e56", "654b3a", "4a302c", "80513d", "c39365", "241c2a", "514053", "eac391"),
    "library": ("59404b", "705044", "392635", "251d32", "5b3941", "916045", "262343", "746998", "dabb80"),
    "factory": ("555059", "69636c", "34313a", "29242f", "51404a", "79717b", "8b3543", "ffd174", "ecad59"),
    "summit": ("a9a1ab", "cfc4c3", "7d7f97", "515679", "8188ad", "c7c4d2", "555981", "aeb0cb", "f2d896"),
}


def tile(theme, index):
    floor, light, grout, wall_dark, wall, wall_light, water, glint, trim = (
        "#" + color for color in PALETTES[theme]
    )
    rng = random.Random(theme + str(index))
    transparent = index in (7, 12, 14, 15)
    sprite = Image.new("RGBA", (16, 16), (0, 0, 0, 0) if transparent else floor)
    d = ImageDraw.Draw(sprite)
    rect, line, dot, poly = d.rectangle, d.line, d.point, d.polygon

    if index in (0, 1, 2, 3, 4, 6):
        if theme in ("bamboo", "colosseum") and index < 4:
            for _ in range(26):
                x, y = rng.randrange(16), rng.randrange(16)
                line((x, y, x + rng.randrange(2), y), fill=rng.choice((light, grout)))
        else:
            row_height = 4 if theme == "library" else 8
            for y in range(0, 16, row_height):
                shift = 4 if y % (row_height * 2) else 0
                line((0, y, 15, y), fill=grout)
                for x in range(shift, 16, 8):
                    line((x, y, x, y + row_height - 1), fill=grout)
                    line((x + 1, y + 1, min(x + 6, 15), y + 1), fill=light)
                    if theme == "factory":
                        dot((min(x + 6, 15), y + row_height - 2), fill=wall_dark)
        if index == 1:
            line([(3, 5), (6, 6), (7, 9), (10, 10), (11, 13)], fill=grout)
        if index == 2:
            for x, y in ((4, 6), (7, 12), (11, 4)):
                line((x - 1, y + 2, x + 2, y + 2), fill=grout)
                dot((x, y), fill=trim)
                dot((x + 1, y + 1), fill=light)
        if index in (3, 4) and theme in ("library", "summit", "factory"):
            textile = {"library": "#783f52", "summit": "#967c65", "factory": wall_dark}[theme]
            rect((2, 0, 13, 15), fill=textile)
            for x in (2, 13):
                line((x, 0, x, 15), fill=trim)
            if theme == "factory":
                for y in range(0, 16, 4):
                    line((3, y + 3, 6, y), fill=trim, width=2)
                    line((10, y + 3, 13, y), fill=trim, width=2)
            else:
                for y in (4, 12):
                    poly([(8, y - 2), (10, y), (8, y + 2), (6, y)], fill=trim)
                    dot((8, y), fill=textile)
        elif index == 3:
            for x, y in ((4, 7), (11, 6), (8, 14)):
                line([(x - 2, y - 3), (x, y), (x + 2, y - 4)], fill=light)
                dot((x + 2, y - 4), fill=trim)
        elif index == 4:
            line((0, 0, 0, 15), fill=light)
            line((15, 0, 15, 15), fill=grout)
        if index == 6:
            for y in (1, 6, 11):
                rect((0, y, 15, y + 3), fill=wall)
                line((0, y, 15, y), fill=wall_light)
                line((0, y + 3, 15, y + 3), fill=wall_dark)
                dot((2, y + 1), fill=trim)
    elif index in (5, 10, 11, 13):
        rect((0, 0, 15, 15), fill=wall_dark if index == 13 else water)
        for x, y, span in ((1, 3, 4), (9, 6, 3), (4, 11, 4), (12, 14, 2)):
            x = (x + (2 if index == 11 else 0)) % 16
            line((x, y, min(x + span, 15), y), fill=glint)
            if theme in ("library", "summit", "bamboo"):
                dot(((x + 6) % 16, (y + 2) % 16), fill=trim)
        if index == 5:
            for y in range(0, 16, 4):
                rect((1, y, 14, y + 2), fill=wall)
                line((2, y, 13, y), fill=wall_light)
                dot((3, y + 1), fill=wall_dark)
                dot((12, y + 1), fill=wall_dark)
            for x in (1, 14):
                line((x, 0, x, 15), fill=trim)
    elif index in (8, 9):
        rect((0, 0, 15, 15), fill=wall_dark)
        if theme == "bamboo":
            for x, height in ((0, 3), (4, 0), (8, 5), (12, 1)):
                rect((x, height, x + 2, 15), fill=wall)
                line((x, height, x, 15), fill=wall_light)
                for y in range(height + 3, 16, 5):
                    line((x, y, x + 2, y), fill=glint)
                    line((x + 2, y + 1, min(x + 5, 15), y - 1), fill=wall_light)
        elif theme == "summit":
            for x, y in ((1, 5), (9, 8), (4, 12), (13, 2)):
                d.ellipse((x - 5, y - 3, x + 5, y + 4), fill=wall)
                d.arc((x - 5, y - 3, x + 5, y + 4), 195, 343, fill=wall_light)
        else:
            for y in range(0, 16, 4):
                rect((0, y, 15, y + 2), fill=wall)
                line((0, y, 15, y), fill=wall_light)
                for x in range(0 if y % 8 else 3, 16, 6):
                    line((x, y + 1, x, y + 2), fill=wall_dark)
            if index == 9:
                rect((0, 8, 15, 15), fill=grout)
                if theme == "town":
                    for x in (2, 10):
                        rect((x, 9, x + 4, 14), outline=wall_light)
                        rect((x + 1, 10, x + 3, 13), fill=trim)
                        line((x + 2, 10, x + 2, 13), fill=wall)
                elif theme == "library":
                    for x in range(1, 15, 2):
                        rect((x, 10 + x % 3, x + 1, 14), fill=rng.choice((wall, wall_light, glint)))
                    line((0, 15, 15, 15), fill=trim)
                elif theme == "factory":
                    line([(0, 12), (5, 12), (5, 9), (15, 9)], fill=wall_light, width=2)
                    rect((9, 8, 11, 11), fill=trim)
                else:
                    line((0, 8, 15, 8), fill=wall_light)
                    line((0, 13, 15, 13), fill=wall)
                    line((7, 9, 7, 12), fill=wall_dark)
    elif index == 7:
        for x in (1, 12):
            rect((x, 1, x + 2, 15), fill=wall_dark)
            line((x, 2, x, 14), fill=wall_light)
        for x in (5, 8, 11):
            line((x, 5, x, 13), fill=trim)
        line((2, 5, 13, 5), fill=wall_light, width=2)
        line((2, 12, 13, 12), fill=wall)
        dot((8, 8), fill=glint)
    elif index == 12:
        if theme in ("town", "library", "factory"):
            for x, y in ((2, 9), (7, 5)):
                rect((x, y, x + 6, y + 5), fill=wall_dark, outline=grout)
                rect((x + 1, y + 1, x + 4, y + 3), fill=wall)
                line((x + 1, y + 1, x + 4, y + 1), fill=wall_light)
                dot((x + 4, y + 2), fill=trim)
        else:
            poly([(2, 14), (3, 10), (6, 9), (7, 5), (11, 4), (14, 13)],
                 fill=wall, outline=wall_dark)
            line([(3, 12), (6, 10), (8, 6), (11, 5)], fill=wall_light)
            dot((10, 8), fill=trim)
    else:
        tall = Image.new("RGBA", (16, 32))
        t = ImageDraw.Draw(tall)
        if theme == "bamboo":
            for x, top in ((3, 6), (7, 1), (11, 9)):
                t.line((x, top, x - 1, 30), fill=wall_dark, width=4)
                t.line((x, top + 1, x - 1, 29), fill=wall_light, width=2)
                for y in range(top + 4, 28, 6):
                    t.line((x - 1, y, x + 1, y), fill=trim)
                t.polygon([(x, top + 6), (x + 4, top + 3), (x + 2, top + 7)], fill=wall_light)
        else:
            t.rectangle((5, 10, 10, 29), fill=wall, outline=wall_dark)
            t.line((6, 11, 6, 29), fill=wall_light)
            t.rectangle((3, 28, 12, 31), fill=wall, outline=wall_dark)
            t.line((4, 29, 11, 29), fill=wall_light)
            if theme == "town":
                t.polygon([(3, 7), (8, 2), (12, 7), (10, 15), (5, 15)], fill=wall_dark)
                t.rectangle((5, 8, 10, 12), fill=trim)
                t.line((7, 8, 7, 12), fill=wall)
            elif theme == "library":
                t.ellipse((2, 1, 13, 14), fill=water, outline=trim)
                t.arc((4, 4, 11, 11), 0, 325, fill=glint)
                t.line((4, 11, 10, 4), fill=trim)
                t.point((7, 5), fill="#fff2c3")
            else:
                t.rectangle((3, 4, 12, 11), fill=wall, outline=wall_dark)
                t.line((4, 5, 11, 5), fill=wall_light)
                t.line((5, 9, 10, 9), fill=trim)
                t.line((8, 12, 8, 27), fill=trim if theme == "summit" else wall_dark)
        return tall.crop((0, 0 if index == 14 else 16, 16, 16 if index == 14 else 32))
    return sprite


# 輪郭、服、明るい縁、顔・金属、小物
NPCS = {
    "merchant": ("#271b31", "#6a4477", "#9d6793", "#b7a3ae", "#ecc482"),
    "towner": ("#202932", "#426966", "#79a68a", "#a5bcc2", "#e7d3a4"),
    "ghost": ("#25243c", "#57567a", "#999ec0", "#434160", "#8cf2eb"),
    "librarian": ("#211c35", "#54446f", "#887aab", "#b9b0d1", "#dcae72"),
    "robot": ("#282735", "#74584f", "#ad8660", "#918c91", "#86e0cb"),
}


def walker(name, direction, step):
    ink, robe, light, face, accent = NPCS[name]
    sprite = Image.new("RGBA", (16, 24))
    d = ImageDraw.Draw(sprite)
    side = direction in (1, 2)
    back = direction == 3
    lift = int(step != 1)
    foot = step - 1
    d.rectangle((4, 19, 6, 23 - (foot < 0)), fill=ink)
    d.rectangle((9 if not side else 8, 19, 11, 23 - (foot > 0)), fill=ink)
    d.line((5, 20, 5, 22 - (foot < 0)), fill=robe)
    d.line((10, 20, 10, 22 - (foot > 0)), fill=robe)
    d.polygon([(4, 10 + lift), (10, 10 + lift), (12, 15), (11, 20),
               (4, 20), (2, 15)], fill=robe, outline=ink)
    d.line((4, 13, 4, 18), fill=light)
    d.line((5, 19, 10, 19), fill=light)
    if name in ("robot", "ghost"):
        d.rectangle((4, 13, 10, 18), fill=face, outline=ink)
        d.line((5, 14, 9, 14), fill=light)
        d.point((8, 16), fill=accent)
        if name == "robot":
            d.line((7, 1 + lift, 7, 4 + lift), fill=ink)
            d.point((7, 1 + lift), fill=accent)
        else:
            d.polygon([(2, 13), (0, 10), (5, 11), (10, 11), (14, 9), (12, 14)],
                      fill=robe, outline=ink)
    elif name == "merchant":
        d.line((4, 12, 10, 18), fill=accent)
        d.rectangle((10, 16, 14, 20), fill=robe, outline=ink)
        d.line((11, 17, 13, 17), fill=accent)
    elif name == "librarian":
        d.rectangle((9, 14, 14, 18), fill="#745044", outline=ink)
        d.line((10, 15, 13, 15), fill=accent)
        d.point((12, 17), fill="#f0d8a9")
    else:
        d.line((5, 14, 10, 14), fill=accent)
        d.line((7, 15, 7, 17), fill=accent)

    y = 3 + lift
    d.polygon([(4, y + 1), (7, y), (10, y + 1), (12, y + 4),
               (11, y + 8), (4, y + 8), (2, y + 5)], fill=robe, outline=ink)
    d.line((4, y + 2, 9, y + 2), fill=light)
    if not back:
        d.rectangle((6 if side else 5, y + 4, 11 if side else 10, y + 7), fill=face)
        if name in ("ghost", "robot"):
            d.line((6, y + 5, 11 if side else 10, y + 5), fill=ink)
            d.point((10, y + 5), fill=accent)
            if not side:
                d.point((6, y + 5), fill=accent)
        else:
            d.point((10, y + 5), fill=ink)
            d.point((11, y + 6) if side else (6, y + 5), fill=accent if side else ink)
    else:
        d.line((7, y + 3, 7, y + 7), fill=light)
    return ImageOps.mirror(sprite) if direction == 1 else sprite


def caped_ren(direction, step):
    figure = ren(2 if direction == 1 else direction, step)
    cape = Image.new("RGBA", figure.size)
    d = ImageDraw.Draw(cape)
    y = 10 - abs(step)
    hem = 1 + (step == 1)
    ink, shadow, red, light = "#342133", "#69293d", "#96384c", "#ca5861"
    if direction == 3:
        d.polygon([(4, y), (10, y), (12, y + 4), (13, 20), (10, 22),
                   (7, 21), (3, 22), (2, 19)], fill=shadow, outline=ink)
        d.polygon([(5, y + 1), (9, y + 1), (10, 20), (8, 20), (6, 17), (4, 21),
                   (3, 19)], fill=red)
        d.line([(6, y + 2), (5, 17), (5, 19)], fill=light)
        d.line([(9, y + 4), (10, 17), (11, 20)], fill=ink)
        d.point((8, y + 2), fill="#c19661")
        figure.alpha_composite(cape)
        return figure
    d.polygon([(6, y), (10, y + 1), (10, 18), (8, 21), (hem, 22),
               (hem + 2, 18), (3, y + 4)], fill=shadow, outline=ink)
    d.line([(5, y + 2), (4, 17), (hem + 1, 20)], fill=red, width=2)
    d.point((4, y + 4), fill=light)
    cape.alpha_composite(figure)
    return ImageOps.mirror(cape) if direction == 1 else cape


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root", nargs="?", type=Path,
                        default=Path(__file__).resolve().parents[3] / "assets" / "pixel")
    root = parser.parse_args().root
    for child in ("tiles", "field"):
        (root / child).mkdir(parents=True, exist_ok=True)
    for theme in PALETTES:
        atlas = Image.new("RGBA", (128, 32))
        for index in range(16):
            atlas.paste(tile(theme, index), (index % 8 * 16, index // 8 * 16))
        atlas.save(root / "tiles" / f"{theme}.png")
    for name in NPCS:
        atlas = Image.new("RGBA", (48, 96))
        for direction in range(4):
            for step in range(3):
                atlas.paste(walker(name, direction, step), (step * 16, direction * 24))
        atlas.save(root / "field" / f"npc_{name}.png")
    atlas = Image.new("RGBA", (48, 96))
    for direction in range(4):
        for step in range(3):
            atlas.paste(caped_ren(direction, step - 1), (step * 16, direction * 24))
    atlas.save(root / "field" / "chara_ren_cape.png")


if __name__ == "__main__":
    main()
