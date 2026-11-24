"""ボス固有の攻撃、焚火、タイトルロゴを原寸の画像にする。"""
from math import cos, sin, tau
from pathlib import Path
from random import Random
from sys import argv

from PIL import Image, ImageDraw, ImageFont

SIZE = 80
NAMES = ("beast_roar", "siren_song", "oni_moon", "nene_curse", "val_verdict",
         "zone_barrage", "shasta_chain", "shasta_light")


def point(x, y, r, a):
    return round(x + r * cos(a)), round(y + r * sin(a))


def signature(name, frame):
    im = Image.new("RGBA", (SIZE, SIZE))
    d = ImageDraw.Draw(im)
    rng = Random(name)
    f = frame / 7
    if name == "beast_roar":
        for x in range(-8, 90, 7):
            h = round((5 + rng.random() * 25) * sin((f + 0.05) * 2.9))
            y = 74 - h
            d.polygon([(x-4,78),(x+1,y),(x+5,y+7),(x+8,76)], "#644338")
            d.line([(x-3,77),(x+1,y),(x+4,y+5)], "#ffcd83", 2)
        for k in range(3):
            y = 70 - k * 13 - frame
            d.line([(0,y),(19,y-4),(39,y+2),(58,y-4),(79,y)], ("#a35e40","#eaa66a","#ffe1ac")[k], 2)
    elif name == "siren_song":
        for k in range(5):
            ry = 5 + k * 5
            y = 48 + round(8 * sin(f * 4 + k))
            d.arc((-16 + frame, y-ry, 95 - frame, y+ry), 0, 353, ("#7df2ef","#e3ffff","#78b9f8")[k%3], 2)
        for i in range(22):
            x = rng.randrange(80)
            y = (rng.randrange(77) - frame * 3) % 75
            d.ellipse((x,y,x+2,y+3), None, "#abf4fa")
    elif name == "oni_moon":
        reach = 5 + frame * 5
        for x in range(0, 81, 5):
            mid = 39
            if abs(x - mid) < reach:
                y = 35 + round(abs(x-mid)*.67) + rng.randrange(10)
                d.polygon([(x-3,79),(x+3,y),(x+6,y+5),(x+8,79)],"#8b586d")
                d.line((x-2,77,x+3,y), "#fac8aa", 2)
        d.arc((3, 47-frame*2, 76, 83), 184, 358, "#fff0bd", 2)
        for i in range(13):
            x = rng.randrange(80)
            y = rng.randrange(45, 78) - frame
            d.point((x,y),"#ffe4a9")
    elif name == "nene_curse":
        for j in range(5):
            x = 10 + 15 * j
            y = 42 + round(11 * sin(j + f * 5))
            r = 8 + frame
            d.regular_polygon((x,y,r), 4, 0, fill="#472440", outline="#e17a9c")
            d.regular_polygon((x,y,r-3), 4, 0, outline="#ffc8cf")
            d.line((x-3,y,x+3,y),"#ffe8dc")
            d.line((x,y-4,x,y+4),"#ffe8dc")
        for k in range(4):
            coords = [(x, 51 + k*4 + round(6*sin(x*.11+f*6+k))) for x in range(80)]
            d.line(coords,("#a74680","#e9789b","#ffa5bd","#793d72")[k],2)
    elif name == "val_verdict":
        for j in range(7):
            x = rng.randrange(5, 76)
            y = min(71, 5 + rng.randrange(25) + frame * 7)
            d.line((x-14,y-30,x,y), "#677591", 4)
            d.line((x-9,y-23,x,y), "#9dc4cb", 2)
            d.regular_polygon((x,y, 4), 6, 15, fill="#d5fff0", outline="#a6ffff")
        for r in range(7, 30, 7):
            a = r + frame
            d.ellipse((40-a,77-a//3,40+a,77+a//3), outline="#829db7")
    elif name == "zone_barrage":
        for x in range(4, 82, 9):
            y = 71 - (frame + x // 9) % 4 * 5
            d.polygon([(x-5,78),(x-2,y),(x+2,y-16),(x+6,78)], "#a35149")
            d.line((x-2,76,x+2,y-16), "#ffd49b", 2)
            d.line((x+2,y-16,x+4,y-31), "#fff1bd", 2)
        d.line((0,78,79,78), "#ecc386", 2)
    elif name == "shasta_chain":
        for k in range(3):
            for j in range(-1, 10):
                x = j * 10 + frame % 10
                y = 21 + k * 17 + round(5*sin(x*.12 + frame*.55 + k))
                d.rounded_rectangle((x-6,y-5,x+6,y+4),3,outline="#835838",width=3)
                d.rounded_rectangle((x-6,y-6,x+6,y+3),3,outline="#f6c982",width=2)
                d.line((x-2,y-6,x+2,y-6),"#fff7c8")
        d.line((0,74,79,74),"#e8b66d",2)
    else:
        for j in range(8):
            x = 4 + j * 11
            k = (j + frame) % 7
            d.polygon([(x-7,0),(x+4+k,0),(x+6,79),(x-2,79)],"#b9814c")
            d.polygon([(x-4,0),(x+2+k,0),(x+3,79),(x-1,79)],"#eed092")
            d.line((x,0,x+1,79),"#fff7d3",2)
        d.regular_polygon((40,38,9+frame*3),8,0,outline="#fffdeb")
        d.ellipse((6,67-frame,73,78-frame),outline="#ffebc1",width=2)
    return im


def flame(frame):
    im = Image.new("RGBA", (96, 96))
    d = ImageDraw.Draw(im)
    phase = frame * tau / 8
    for r in range(45, 3, -1):
        d.ellipse((48-r,74-r//2,48+r,74+r//2), (241,106,29, max(4, 62-r)))
    for i, color in enumerate(("#773044", "#d04c41", "#f98236", "#ffb85c", "#fff1ab")):
        w = 29 - i * 4
        h = 58 - i * 8
        x = 48 + round(4*sin(phase + i))
        d.polygon([(48-w,85),(48-w-4,74),(x-w+7,54),(x-w//2,39+i*6),
                   (x-7,51+i*3),(x+2,84-h),(x+10,54+i*3),(x+21,62+i*2),
                   (48+w,77),(48+w-3,85)], color)
    for j in range(12):
        x = 30 + (j * 19 + frame * 2) % 38
        y = 10 + (j * 13 - frame * 5) % 53
        d.rectangle((x,y,x+(j%3==0),y+1), ("#ed7740","#ffc56b","#fff3a9")[j%3])
    return im


def strip(n, size, render):
    im = Image.new("RGBA", (n * size, size))
    for i in range(n):
        im.paste(render(i), (i * size, 0))
    return im


def logo(path):
    im = Image.new("RGBA", (1484, 304))
    d = ImageDraw.Draw(im)
    japanese = ImageFont.truetype("C:/Windows/Fonts/yumindb.ttf", 108)
    english = ImageFont.truetype("C:/Windows/Fonts/georgiab.ttf", 38)
    ink, gold, pearl = "#211c33", "#c69659", "#fff0d5"
    for x, sign in ((75, 1), (1409, -1)):
        d.line((x,151,x+sign*179,151), gold, 2)
        d.line((x+sign*25,159,x+sign*137,159), "#967056", 2)
        d.regular_polygon((x+sign*9,151,11),4,0,fill=pearl,outline=ink)
    d.text((742,137),"テイルズ オブ バベル",pearl,font=japanese,anchor="mm",stroke_width=9,stroke_fill=ink)
    d.text((742,137),"テイルズ オブ バベル",pearl,font=japanese,anchor="mm",stroke_width=2,stroke_fill=gold)
    d.text((742,240),"T A L E S   O F   B A B E L", "#e6bb7d",font=english,anchor="mm",stroke_width=4,stroke_fill=ink)
    d.regular_polygon((742,39,19),4,0,outline=gold)
    d.regular_polygon((742,39,9),4,0,fill=pearl)
    d.line((516,240,431,240),gold,2)
    d.line((968,240,1053,240),gold,2)
    im.save(path, optimize=True)


def main():
    root = Path(argv[1])
    fx = root / "pixel" / "fx"
    art = root / "illustrations"
    fx.mkdir(parents=True, exist_ok=True)
    art.mkdir(parents=True, exist_ok=True)
    for name in NAMES:
        strip(8, SIZE, lambda i: signature(name, i)).save(fx / f"boss_{name}.png", optimize=True)
    strip(8, 96, flame).save(art / "campfire.png", optimize=True)
    logo(art / "logo.png")


if __name__ == "__main__":
    main()
