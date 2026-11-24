"""シャスタの肖像に合わせた探索・戦闘ドット絵。"""
from pathlib import Path
from sys import argv
from math import cos, radians, sin

from PIL import Image, ImageDraw

ID = "boss_shasta"
INK = "#262637"
IVORY = "#e5dcc4"
SHADE = "#a5989d"
GOLD = "#b99963"
LIGHT = "#fff3ca"
RED = "#833b54"
DARK_RED = "#502d48"
SKIN = "#efc4a2"
HAIR = "#d0ab70"
ROWS = (4, 4, 2, 4, 2, 3)


def frame(row, col, front=False):
    image = Image.new("RGBA", (48, 48))
    d = ImageDraw.Draw(image)
    if row == 5 and col >= 1:
        d.polygon([(5,46),(8,42),(14,40),(24,38),(30,40),(34,38),(40,39),(43,45),(40,47),(5,47)], INK)
        d.polygon([(7,46),(12,42),(22,40),(32,42),(37,46)], RED)
        d.polygon([(18,43),(24,39),(32,41),(33,45),(24,46)], IVORY)
        d.ellipse((33,39,41,45), HAIR)
        d.line((34,40,38,40), LIGHT)
        d.point((39,43), SKIN)
        d.line((30,46,44,46), GOLD)
        return image
    x = 22 + ([-1, 0, 2, 1][col] if row == 3 else 0)
    bob = (col % 2 if row in (0, 1) else 2 if row in (2, 5) else 0)
    lean = 3 if row == 3 else -2 if row == 4 else 0
    y = 25 + bob
    sx = x + lean
    stride = (-5, -2, 5, 2)[col] if row == 1 else 4 if row == 3 else 0
    trail = 4 if row in (1, 3) else col % 2
    d.polygon([(sx-4,y-8),(sx+3,y-5),(x+4,y+3),(x-3,39),
               (x-12-trail,45),(x-15-trail,41),(x-11,29),(sx-8,y)], DARK_RED, INK)
    d.polygon([(sx-4,y-6),(x-4,y+7),(x-8,39),(x-13-trail,42),
               (x-10,30),(sx-7,y)], RED)
    d.line([(sx-5,y-5),(x-6,31),(x-10-trail,42)], GOLD)
    for i, sign in enumerate((-1, 1)):
        hip = x + sign * 3
        foot = x + sign * (4 + stride)
        d.line([(hip,y+8),(foot,42),(foot,46)], INK, 5)
        d.line([(hip,y+9),(foot,42)], SHADE if i == 0 else IVORY, 3)
        d.polygon([(foot-2,42),(foot+2,42),(foot+2,44),(foot+4,45),(foot+4,47),(foot-3,47)], INK)
        d.line((foot-1,44,foot+1,44), GOLD)
    d.polygon([(sx-6,y-7),(sx+5,y-7),(sx+7,y-3),(x+4,y+5),(x+7,y+12),
               (x+1,y+13),(x-7,y+12),(x-5,y+5),(sx-7,y-2)], IVORY, INK)
    d.polygon([(sx-5,y-5),(sx-2,y-5),(x-1,y+4),(x-2,y+11),(x-6,y+11),(x-4,y+3)], SHADE)
    d.line([(sx-2,y-6),(x+1,y+2),(x+2,y+11)], GOLD)
    d.line((x-5,y+4,x+4,y+4), "#694d52", 2)
    d.rectangle((x,y+4,x+2,y+5), LIGHT)
    d.line([(sx-4,y-5),(sx-1,y-4),(sx+2,y-5)], RED, 2)
    d.point((sx+1,y-2), GOLD)
    hy = y - 16
    d.polygon([(sx-5,hy+1),(sx,hy-2),(sx+5,hy),(sx+6,hy+4),(sx+8,hy+7),
               (sx+4,hy+10),(sx-5,hy+11),(sx-7,hy+5)], HAIR, INK)
    d.polygon([(sx,hy+3),(sx+4,hy+2),(sx+5,hy+4),(sx+7,hy+7),(sx+4,hy+9),(sx,hy+8)], SKIN)
    d.line([(sx-4,hy+1),(sx,hy),(sx+3,hy+1)], LIGHT)
    d.line([(sx-4,hy+4),(sx-4,hy+7),(sx-2,hy+10)], GOLD, 2)
    d.line([(sx-4,hy+2),(sx-2,hy+2),(sx-2,hy),(sx,hy+2),(sx+3,hy+2)], GOLD)
    d.point((sx,hy+2), "#a94e4e")
    d.point((sx+4,hy+5), "#654347")
    if front:
        d.point((sx,hy+5), "#654347")
    hand = (min(35, sx+9),y+2)
    if row == 2:
        hand = (sx+5,y-3)
    elif row == 3:
        hand = (min(34, sx+8+col),y-2+col)
    d.line([(sx+5,y-4),(sx+6,y+1),hand],INK,5)
    d.line([(sx+5,y-4),(sx+6,y+1),hand],IVORY,3)
    d.point(hand,SKIN)
    angle = -58 if row not in (2,3) else -115 if row == 2 else (-90,-44,-8,27)[col]
    a=radians(angle)
    v=(cos(a),sin(a))
    tip=(min(46,round(hand[0]+v[0]*13)),round(hand[1]+v[1]*13))
    d.line((hand,tip),INK,4)
    d.line((hand,tip),"#a5aabd",2)
    d.line(((hand[0],hand[1]-1),(tip[0],tip[1]-1)),LIGHT)
    d.line((hand[0]-2,hand[1]-2,hand[0]+3,hand[1]+2),GOLD,2)
    return image


def main():
    root = Path(argv[1])
    battle = Image.new("RGBA",(384,288))
    for row, count in enumerate(ROWS):
        for col in range(count):
            battle.paste(frame(row,col),(48*col,48*row))
    field = Image.new("RGBA",(96,48))
    for col in range(2):
        field.paste(frame(0,col,True),(48*col,0))
    battle.save(root / "battle" / f"{ID}.png",optimize=True)
    field.save(root / "field" / f"{ID}.png",optimize=True)


if __name__ == "__main__":
    main()
