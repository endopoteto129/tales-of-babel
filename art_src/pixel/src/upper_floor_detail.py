"""第二層から頂上までの32ドット地形と小物を描く。"""
from pathlib import Path
from random import Random
from sys import argv

from PIL import Image, ImageDraw

SIZE = 32
# 床、目地、光、壁の影、壁、水面、装飾
COLORS = {
    "town": ("#615568", "#47394b", "#887586", "#30263b", "#734b65", "#203b59", "#efc080"),
    "bamboo": ("#2b4648", "#1e343b", "#507061", "#132735", "#315b54", "#1e3859", "#a9cbb4"),
    "colosseum": ("#a07a54", "#75553f", "#c49b6c", "#4c3431", "#95674b", "#332839", "#eec38e"),
    "library": ("#62505a", "#453644", "#8a6554", "#2a2438", "#754c48", "#252242", "#d7b681"),
    "factory": ("#5a555e", "#3e3a46", "#79747c", "#282635", "#5d4b56", "#843743", "#f0ab59"),
    "summit": ("#a9a7bb", "#7b7b95", "#d6ced2", "#515979", "#8288a8", "#5e638b", "#f4da9a"),
}


class Theme:
    def __init__(self, name):
        self.name = name
        self.floor, self.grout, self.light, self.ink, self.wall, self.water, self.trim = COLORS[name]

    def ground(self, variant):
        im = Image.new("RGBA", (32, 32), self.floor)
        d = ImageDraw.Draw(im)
        rng = Random(self.name + str(variant))
        if self.name in ("bamboo", "colosseum"):
            for i in range(48):
                x, y = rng.randrange(32), rng.randrange(32)
                d.line((x, y, x + rng.randrange(3), y), self.light if i % 3 == 0 else self.grout)
            for x, y in ((7, 24), (21, 5), (28, 20)):
                x = (x + variant * 7) % 29
                d.line([(x, y), (x + 2, y - 3), (x + 5, y - 5)], self.grout)
                if self.name == "bamboo":
                    d.line((x + 1, y, x + 3, y - 4), self.light)
        else:
            row = 8 if self.name == "library" else 16 if self.name == "factory" else 8
            for y in range(0, 32, row):
                d.line((0, y, 31, y), self.grout)
                for x in range(-8 if y % (row * 2) else 0, 32, 16):
                    d.line((x, y, x, y + row - 1), self.grout)
                    d.line((x + 2, y + 1, x + 14, y + 1), self.light)
                    if self.name == "factory":
                        for ax, ay in ((2, 3), (13, 3), (2, 13), (13, 13)):
                            d.point((x + ax, y + ay), self.ink)
                            d.point((x + ax, y + ay - 1), self.light)
            for i in range(30):
                x, y = rng.randrange(32), rng.randrange(32)
                d.line((x, y, x + rng.randrange(1, 4), y), self.grout if i % 3 == 0 else self.light)
        if variant >= 6:
            for x, y in ((8, 18), (17, 9), (23, 24)):
                d.polygon([(x - 2, y), (x, y - 2), (x + 3, y - 1), (x + 1, y + 1)],
                          self.light, outline=self.grout)
                d.point((x, y - 1), self.trim)
        return im

    def road(self, mask, variant):
        im = self.ground(variant)
        d = ImageDraw.Draw(im)
        material = {"library": "#784455", "factory": "#34313f", "summit": "#ad8b68"}.get(self.name, self.light)
        rects = [(7, 7, 24, 24)]
        for bit, box in [(1, (7, 0, 24, 8)), (2, (23, 7, 31, 24)),
                         (4, (7, 23, 24, 31)), (8, (0, 7, 8, 24))]:
            if mask & bit:
                rects.append(box)
        road = Image.new("L", im.size)
        rd = ImageDraw.Draw(road)
        for box in rects:
            rd.rectangle(box, fill=255)
        d.bitmap((0, 0), road, fill=material)
        tex = Image.new("RGBA", im.size)
        td = ImageDraw.Draw(tex)
        for y in range(2, 32, 5):
            for x in range(2 + y % 5, 32, 9):
                td.line((x, y, x + 4, y), self.grout if self.name != "library" else "#6b3c4e")
                if self.name == "factory":
                    td.line((x, y + 2, x + 2, y), self.trim)
        for y in range(32):
            for x in range(32):
                if road.getpixel((x, y)) and any(not road.getpixel((nx, ny)) for nx, ny in
                    ((x-1,y),(x+1,y),(x,y-1),(x,y+1)) if 0 <= nx < 32 and 0 <= ny < 32):
                    td.point((x,y), self.trim if self.name in ("library", "factory", "summit") else self.wall)
        im.paste(tex, (0, 0), Image.composite(tex.getchannel("A"), Image.new("L", im.size), road))
        return im

    def panel(self, index, front):
        im = Image.new("RGBA", (32, 32), self.ink)
        d = ImageDraw.Draw(im)
        if self.name in ("bamboo", "summit"):
            if self.name == "bamboo":
                for x in range(-2, 32, 5):
                    y = (x + index * 3) % 7
                    d.rectangle((x, y, x + 3, 31), self.wall)
                    d.line((x + 1, y, x + 1, 31), self.light)
                    for j in range(y + 3, 32, 8):
                        d.line((x, j, x + 3, j), self.ink)
                        d.polygon([(x + 2, j + 2), (x + 9, j - 1), (x + 6, j + 4)], self.light)
            else:
                for x, y, rx in [(2, 5, 9), (12, 12, 12), (25, 8, 10), (28, 23, 15), (2, 25, 14)]:
                    y += index % 2
                    d.ellipse((x - rx, y - 5, x + rx, y + 7), self.wall)
                    d.arc((x - rx, y - 6, x + rx, y + 6), 190, 342, self.light, 2)
        else:
            for y in range(0, 32, 5 if self.name == "town" else 8):
                d.rectangle((0, y, 31, y + 3), self.wall)
                d.line((0, y, 31, y), self.light)
                for x in range((y + index * 2) % 8, 32, 8):
                    d.line((x, y + 1, x, y + 3), self.grout)
            if front:
                d.rectangle((0, 15, 31, 31), self.grout)
                d.line((0, 15, 31, 15), self.light, 2)
                if self.name == "town":
                    for x in (4, 20):
                        d.rounded_rectangle((x, 18, x + 7, 29), radius=2, fill=self.trim, outline=self.ink)
                        d.line((x + 4, 19, x + 4, 28), self.wall)
                        d.line((x + 1, 23, x + 6, 23), self.wall)
                elif self.name == "library":
                    for x in range(2, 29, 3):
                        colors = (self.wall, "#577384", "#94615c", "#a17d56")
                        d.rectangle((x, 19 + x % 4, x + 1, 29), colors[(x + index) % 4])
                        d.point((x, 26), self.trim)
                    d.line((0, 30, 31, 30), self.trim)
                elif self.name == "factory":
                    d.line([(0, 25), (10, 25), (15, 20), (31, 20)], self.wall, 6)
                    d.line([(0, 23), (10, 23), (15, 18), (31, 18)], self.light)
                    for x, y in ((8,24),(23,19)):
                        d.rectangle((x, y - 2, x + 3, y + 2), self.trim, self.ink)
                else:
                    for x in (4, 16, 27):
                        d.line((x, 17, x, 30), self.ink)
                        d.line((x + 1, 18, x + 1, 29), self.wall)
        return im

    def liquid(self, bank, frame):
        im = Image.new("RGBA", (32, 32), self.water)
        d = ImageDraw.Draw(im)
        rng = Random(self.name)
        for i in range(24):
            x, y = (rng.randrange(32) + 2 * frame) % 32, rng.randrange(32)
            fill = self.trim if self.name in ("factory", "library") and i % 4 == 0 else self.light
            if self.name == "library":
                d.point((x, y), fill)
            else:
                d.line((x, y, min(31, x + rng.randrange(1, 7)), y), fill if i % 3 == 0 else self.wall)
        for bit, line in ((1,(0,0,31,0)),(2,(31,0,31,31)),(4,(0,31,31,31)),(8,(0,0,0,31))):
            if bit & bank:
                d.line(line, self.ink, 4)
                d.line(line, self.light)
        return im

    def bridge(self, sides, part=0):
        im = self.liquid(0, 0)
        d = ImageDraw.Draw(im)
        top, bot = [(5, 26), (4, 31), (0, 17)][part]
        left, right = (0 if sides & 1 else 2), (31 if sides & 2 else 29)
        d.rectangle((left, top, right, bot), self.ink)
        for y in range(top + 2, bot, 5):
            d.rectangle((left + 1, y, right - 1, min(bot - 1, y + 3)), self.wall)
            d.line((left + 1, y, right - 1, y), self.light)
            for x in (left + 4, right - 4):
                d.point((x, y + 1), self.trim)
        return im

    def column(self, i):
        im = Image.new("RGBA", (32, 64))
        d = ImageDraw.Draw(im)
        d.ellipse((2, 55, 30, 62), fill=(14, 18, 30, 102))
        x = 15 + (i - 1)
        if self.name == "bamboo":
            for dx, top in ((-7, 15), (-1, 5), (5, 11)):
                d.line((x+dx, top, x+dx-2, 57), self.ink, 6)
                d.line((x+dx, top+2, x+dx-2, 57), self.light, 3)
                for y in range(top+5,57,9):
                    d.line((x+dx-3,y,x+dx+2,y),self.trim)
                    d.polygon([(x+dx,y),(x+dx+7,y-5),(x+dx+5,y+1)],self.wall)
            return im
        d.rounded_rectangle((x-6, 16, x+6, 57), radius=3, fill=self.wall, outline=self.ink, width=2)
        for dx in (-3, 0, 3):
            d.line((x+dx,20,x+dx,52), self.light if dx != 3 else self.grout)
        d.polygon([(x-10,54),(x+10,54),(x+12,57),(x+10,60),(x-10,60),(x-12,57)],
                  self.wall, self.ink)
        d.line((x-8,55,x+8,55), self.trim)
        if self.name in ("town", "library"):
            d.polygon([(x,3),(x+10,10),(x+7,23),(x-7,23),(x-10,10)], self.ink)
            d.ellipse((x-6,8,x+6,20), self.trim if self.name == "town" else self.water, self.light)
            d.line([(x-5,16),(x+3,10),(x+6,14),(x,20)],self.trim if self.name == "library" else self.wall)
            d.point((x,11), "#fff3cb")
        else:
            d.rectangle((x-9, 8, x+9, 18), self.wall, self.ink, width=2)
            d.line((x-7,10,x+7,10),self.trim,2)
            d.line((x-7,15,x+7,15),self.light)
        return im

    def obstacle(self):
        im = Image.new("RGBA", (32, 32))
        d = ImageDraw.Draw(im)
        d.ellipse((3,19,29,30), fill=(14,18,29,100))
        for x, y in ((4,17),(13,12),(18,17)):
            d.polygon([(x,y+4),(x+2,y),(x+7,y-1),(x+9,y+3),(x+7,y+8),(x+1,y+7)],
                      self.wall,self.ink)
            d.line([(x+1,y+3),(x+3,y),(x+7,y)],self.light)
            d.point((x+5,y+2),self.trim)
        return im

    def ledge(self, sides, variant):
        im = self.panel(variant, True)
        mask = Image.new("L", im.size)
        a = 4 if sides & 1 else 0
        b = 4 if sides & 2 else 0
        y = 17 + variant * 2
        ImageDraw.Draw(mask).polygon([(0,0),(31,0),(31-b,y-b),(31-2*b,y),(2*a,y),(a,y-a)],fill=255)
        im.putalpha(mask)
        return im


def atlas(theme):
    im = Image.new("RGBA", (256, 480))
    def put(cell, x, y):
        im.paste(cell, (x * SIZE, y * SIZE))
    for i in range(8):
        put(theme.ground(i), i, 0)
    for n in range(32):
        put(theme.road(n % 16, n // 16), n % 8, 1+n//8)
        put(theme.liquid(n % 16, n // 16), n % 8, 8+n//8)
    for i in range(4):
        put(theme.column(i), i, 5)
        put(theme.panel(i, False), i, 7)
        put(theme.panel(i, True), i+4, 7)
        put(theme.bridge(i), i, 12)
        put(theme.bridge(i, 1), i, 14)
        put(theme.bridge(i, 2), i+4, 14)
        for v in range(2):
            put(theme.ledge(i, v), i+v*4, 13)
    put(theme.obstacle(), 4, 12)
    return im


if __name__ == "__main__":
    output = Path(argv[1])
    output.mkdir(parents=True, exist_ok=True)
    for name in COLORS:
        atlas(Theme(name)).save(output / f"{name}.png", optimize=True)
