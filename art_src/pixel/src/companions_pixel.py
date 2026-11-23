"""アンジーとナインの立ち絵に合わせた探索・戦闘用ドット絵。"""
from pathlib import Path
import sys

from PIL import Image, ImageDraw

INK = "#241d28"
SKIN, SKIN_DARK = "#f0bc9b", "#bb826e"
HERO_COUNTS = (4, 6, 2, 2, 4, 4, 4, 6, 4, 2, 3, 4)

PALETTES = {
    "angie": ("#4b303e", "#795064", "#352c38", "#58505b", "#ac4a44", "#cf8370"),
    "nine": ("#c19359", "#edc780", "#b96d3e", "#db9953", "#e5ca9e", "#c75248"),
}


def new(w, h):
    return Image.new("RGBA", (w, h))


def atlas(frames, columns):
    w, h = frames[0].size
    sheet = new(w*columns, h*((len(frames)+columns-1)//columns))
    for i, frame in enumerate(frames):
        sheet.paste(frame, (w*(i % columns), h*(i // columns)))
    return sheet


def polygon(d, color, *points):
    d.polygon(points, fill=color)


def walker(cid, facing, gait):
    canvas = new(16, 24)
    d = ImageDraw.Draw(canvas)
    hair, hair_light, cloth, cloth_light, accent, trim = PALETTES[cid]
    angie = cid == "angie"
    dy = abs(gait) + (0 if angie else 3)
    side, back = facing in (1, 2), facing == 3
    def p(color, *pts):
        polygon(d, color, *((x, y+dy) for x,y in pts))
    for i, x in enumerate((5, 9)):
        x += (gait * (-1 if i == 0 else 1)) if side else 0
        y = 23 - (1 if gait == (-1 if i == 0 else 1) else 0)
        d.rectangle((x, y-3, x+2, y), INK)
        d.line((x+1, y-1, x+2, y-1), "#8e6049" if not angie else "#60515b")
    if angie:
        p(INK,(4,4),(6,2),(10,2),(12,5),(12,10),(14,15),(12,18),(3,18),(1,16),(3,12))
        p(hair,(4,5),(6,3),(10,3),(11,5),(11,10),(13,15),(11,17),(3,17),(2,15),(4,11))
        p(hair_light,(4,6),(5,4),(8,3),(6,5),(5,9),(3,13))
    else:
        p(INK,(5,5),(7,3),(10,3),(12,5),(13,8),(15,10),(14,13),(11,12),(9,10),
          (6,10),(4,13),(1,13),(0,10),(2,8),(3,5))
        p(hair,(5,5),(7,4),(10,4),(12,6),(12,9),(14,10),(13,12),(11,11),(9,9),
          (6,9),(3,12),(1,12),(1,10),(3,9),(4,6))
        p(hair_light,(4,7),(6,5),(9,4),(11,6),(8,6),(6,7))
        d.point((3,9+dy), trim)
        d.point((12,9+dy), trim)
    # 子供の胴は短く、アンジーは黒衣の裾を長く取る。
    bottom = (21 if angie else 18) - abs(gait)
    p(INK,(5,10),(10,10),(12,13),(12,16),(13,bottom),(3,bottom),(4,15),(3,13))
    p(cloth,(5,11),(10,11),(11,14),(11,16),(12,bottom-1),(4,bottom-1),(5,15),(4,13))
    p(cloth_light,(5,13),(7,12),(8,14),(7,bottom-1),(5,bottom-1),(6,15))
    p(accent,(5,14 if angie else 15),(10,14 if angie else 15),(11,15 if angie else 16),
      (5,15 if angie else 16))
    if not back:
        p(SKIN_DARK,(5,6),(10,6),(12 if side else 11,8),(10,11),(6,11),(5,9))
        p(SKIN,(6,7),(10,7),(11,8),(10,10),(6,10),(5,9))
        p(hair,(4,7),(5,5),(8,4),(11,5),(11,7),(9,6),(8,8),(7,7),(5,8))
        d.point((11 if side else 10,8+dy), "#664862" if angie else "#8b5233")
        if not side:
            d.point((6,8+dy), "#664862" if angie else "#8b5233")
    else:
        p(hair,(4,6),(7,4),(10,4),(11,6),(11,11),(10,14),(5,13),(4,10))
        p(hair_light,(5,6),(7,5),(7,7),(6,9),(5,11))
    if not back:
        p(accent,(5,11),(7,11),(8,12),(10,11),(11,12),(9,13),(7,13))
        if not angie:
            d.point((8,13+dy), trim)
    if angie and side:
        d.line((14,9+dy,13,22), "#674a38")
        d.point((14,9+dy), "#be7768")
    return canvas.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if facing == 1 else canvas


# 待機、走り、ジャンプ、ガード、通常攻撃3段、術技、詠唱、のけぞり、ダウン、勝利。
# 各姿勢は腰の横移動、高さ、前傾、両足、握る手、杖先。
IDLE = [(0,0,0,-4,4,8,-4,19,-21),(0,-1,0,-4,4,8,-4,19,-22),
        (0,-1,0,-4,4,9,-4,20,-21),(0,0,0,-4,4,8,-3,19,-20)]
POSES = (
    IDLE,
    [(0,y,3,a,b,6,-4,18,-11) for y,a,b in
     [(-1,-7,7),(0,-4,5),(1,0,3),(-1,7,-7),(0,5,-4),(1,3,0)]],
    [(0,-4,1,-4,4,5,-8,15,-27),(1,-2,1,-5,5,7,-4,20,-14)],
    [(-1,1,-1,-5,4,8,-4,12,-25),(-2,3,-2,-5,5,8,-5,13,-25)],
    [(-2,0,-2,-4,4,-1,-7,-13,-22),(1,0,1,-5,6,8,-7,20,-24),
     (4,1,3,-7,7,10,-3,22,-3),(1,1,0,-5,5,8,-2,19,-15)],
    [(-2,1,0,-4,4,6,1,18,9),(1,1,2,-6,6,10,0,22,3),
     (4,0,3,-7,7,11,-8,21,-22),(0,0,0,-4,4,7,-7,12,-26)],
    [(-3,0,-1,-4,4,3,-10,-4,-28),(0,-1,0,-5,5,7,-11,12,-29),
     (4,2,4,-7,8,11,-1,22,4),(2,1,1,-6,6,9,0,20,2)],
    [(-3,0,-1,-5,4,2,-8,-5,-26),(-3,-1,-1,-6,4,4,-11,2,-30),
     (0,-2,1,-5,5,6,-12,13,-31),(4,-1,3,-7,7,11,-8,22,-19),
     (5,1,3,-7,8,11,-1,22,-4),(2,1,1,-5,5,8,-1,18,-9)],
    [(0,-i%2,0,-4,4,7,-7-i%2,12,-30-i%2) for i in range(4)],
    [(-4,0,-3,-4,5,5,0,12,6),(-3,2,-2,-4,4,6,0,15,5)],
    [(-4,5,-4,-4,6,4,2,15,6),(-2,6,-3,-4,5,5,4,16,5),
     (-2,4,-2,-4,4,8,0,17,7)],
    [(0,0,0,-4,4,6,-8,7,-29),(0,-1,0,-4,4,6,-10,10,-31),
     (0,-1,0,-4,4,6,-11,12,-31),(0,0,0,-4,4,6,-9,9,-29)],
)


def staff(d, hand, tip):
    hx,hy = hand
    tx,ty = tip
    end = (max(1,min(46,round(hx+(hx-tx)*.52))),max(1,min(46,round(hy+(hy-ty)*.52))))
    d.line((end,tip), INK, 3)
    d.line((end,tip), "#8a644c")
    d.ellipse((tx-2,ty-2,tx+2,ty+2), INK)
    d.ellipse((tx-1,ty-1,tx+1,ty+1), "#a4485b")
    d.point((tx,ty-1), "#e7837b")


def angie_frame(row, frame):
    canvas = new(48,48)
    d = ImageDraw.Draw(canvas)
    hair, hair_light, cloth, cloth_light, red, red_light = PALETTES["angie"]
    shift, bob, lean, back, front, hx, hy, tx, ty = POSES[row][frame]
    x, y = 23+shift, 32+bob
    if row == 10 and frame < 2:
        polygon(d,INK,(5,46),(9,42),(17,41),(24,41),(28,40),(34,36+frame*3),
                (39,38+frame*2),(43,43),(41,47),(7,47))
        polygon(d,cloth,(8,45),(12,42),(22,42),(28,41),(32,45),(27,46),(10,46))
        d.line((16,44,27,43), red)
        d.ellipse((29,38+frame*2,40,46), hair)
        d.line((31,42+frame,36,41+frame), hair_light)
        d.point((39,44), SKIN)
        d.line((17,47,44,47), "#8a644c")
        return canvas
    def p(color,*pts):
        polygon(d,color,*((x+a,y+b) for a,b in pts))
    for i,step in enumerate((back,front)):
        fx = 23+step
        lift = (0, 0, 2, 3, 2, 0)[(frame+3*i)%6] if row == 1 else (3 if row == 2 and i == 0 else 0)
        fy = 47-lift
        d.line(((x+(-3 if i==0 else 3),y+4),(fx,fy-2)), INK, 5)
        d.line(((x+(-3 if i==0 else 3),y+4),(fx,fy-2)), cloth_light if i else cloth, 3)
        polygon(d,INK,(fx-2,fy-4),(fx+1,fy-4),(fx+4,fy-1),(fx+4,fy),(fx-3,fy))
        d.line((fx-1,fy-1,fx+3,fy-1),"#6e554e")
    flow = 4 if row in (1,4,5,6,7) else 1
    p(INK,(lean-7,-17),(lean-6,-23),(lean+1,-26),(lean+7,-22),(lean+7,-15),
      (3,-6),(-2,5),(-8-flow,8),(-10-flow,4),(-9-flow,-5))
    p(hair,(lean-6,-17),(lean-5,-22),(lean+1,-25),(lean+5,-21),(lean+6,-15),
      (2,-6),(-3,4),(-8-flow,7),(-9-flow,4),(-8-flow,-5))
    p(hair_light,(lean-5,-19),(lean-3,-22),(lean+1,-23),(lean-1,-19),
      (-4,-11),(-5-flow,-4),(-7-flow,3),(-8-flow,3))
    hem = min(12,46-y)
    p(INK,(lean-5,-15),(lean+4,-15),(8,-10),(8,-5),(6,1),(10,hem),
      (5,hem+1),(-4,hem+1),(-9-flow,hem),(-6,3),(-8,-4),(-7,-11))
    p(cloth,(lean-4,-14),(lean+3,-14),(7,-10),(7,-5),(5,1),(9,hem-1),
      (5,hem),(-4,hem),(-8-flow,hem-1),(-5,3),(-7,-4),(-6,-10))
    p(cloth_light,(-5,-8),(-1,-9),(1,-5),(-1,0),(-2,5),(-5,hem),(-7-flow,hem-1),(-4,5))
    p("#483946",(3,1),(5,2),(8,hem-1),(5,hem),(1,hem),(3,6))
    p(red,(lean-5,-14),(lean+3,-14),(5,-11),(3,-9),(0,-10),(-5,-11))
    p(red,(-6,-1),(5,-1),(6,1),(3,3),(-6,2))
    p("#7d343c",(4,1),(6,2),(7,8),(5,9),(3,7))
    p(red_light,(-4,0),(3,0),(4,1),(-2,1))
    p(hair,(lean-7,-16),(lean-6,-22),(lean-2,-25),(lean+3,-25),(lean+6,-22),
      (lean+7,-18),(lean+3,-15),(lean, -14),(lean-5,-14))
    p(SKIN_DARK,(lean-2,-22),(lean+4,-22),(lean+6,-18),(lean+8,-16),(lean+6,-15),
      (lean+5,-12),(lean+1,-12),(lean-3,-15))
    p(SKIN,(lean,-21),(lean+4,-21),(lean+5,-18),(lean+7,-16),(lean+5,-15),
      (lean+5,-13),(lean+1,-13),(lean-2,-16))
    p(hair,(lean-5,-22),(lean-1,-24),(lean+3,-24),(lean+5,-22),(lean+5,-20),
      (lean+3,-21),(lean+1,-18),(lean-1,-19),(lean-3,-15),(lean-5,-16))
    p(hair_light,(lean-4,-21),(lean-1,-23),(lean+2,-23),(lean-1,-21),(lean-2,-19))
    d.line((x+lean+4,y-18,x+lean+5,y-18), "#674269")
    d.point((x+lean+5,y-17),"#925482")
    hand = (x+hx,y+hy)
    elbow = (round((x+lean+hand[0])/2)+1,round((y-9+hand[1])/2)+3)
    arm = ((x+lean+1,y-9),elbow,hand)
    d.line(arm, INK, 7)
    d.line(arm, cloth, 5)
    d.line((arm[0],elbow),cloth_light,2)
    d.line((elbow,hand), "#534553", 2)
    staff(d, hand, (min(45,23+tx),max(2,32+ty)))
    d.rectangle((hand[0]-1,hand[1]-1,hand[0]+1,hand[1]+1), SKIN_DARK)
    d.point(hand, SKIN)
    if row in (4,5,6,7) and frame == (3 if row==7 else 2):
        # 杖の先端が走る方向を示す短い軌跡。魔法の色はゲーム側のまま。
        d.line([(40,11),(44,16),(46,23),(45,28)], "#c9959e")
        d.point((45,17), "#ebc7cb")
    return canvas


def nine_frame(cheer, f):
    canvas = new(32,32)
    d=ImageDraw.Draw(canvas)
    hair, hi, cloth, shade, collar, red = PALETTES["nine"]
    x=15
    y=19+([0,-1,-1,0][f] if not cheer else [0,-1,-2,-1][f])
    def p(color, *pts):
        polygon(d,color,*((x+a,y+b) for a,b in pts))
    for dx in (-3,3):
        d.line((x+dx,y+5,x+dx,30),INK,4)
        d.line((x+dx,y+5,x+dx,28),"#93654c",2)
        d.rectangle((x+dx-1,29,x+dx+2,31),INK)
        d.point((x+dx+1,30),"#b18058")
    p(INK,(-3,-6),(3,-6),(5,-2),(5,3),(7,8),(-7,8),(-5,3),(-5,-2))
    p(cloth,(-3,-5),(3,-5),(4,-1),(4,4),(6,7),(-6,7),(-4,3),(-4,-1))
    p(shade,(-3,-2),(-1,-3),(1,-2),(0,6),(-4,7),(-5,6),(-3,3))
    d.line((x-4,y+2,x+4,y+2), "#c6a27c")
    for side in (-1,1):
        if cheer:
            hand = (x+side*(8+f%2),y+[-5,-9,-10,-7][f])
        else:
            hand = (x+side*5,y+4-f%2)
        elbow = (x+side*6,y+(0 if cheer else 1))
        points=((x+side*3,y-3),elbow,hand)
        d.line(points,INK,4)
        d.line(points,cloth,2)
        d.point(hand,SKIN)
    p(INK,(-5,-9),(-6,-5),(-10,-5),(-11,-8),(-9,-12),(-5,-13),
      (-4,-15),(0,-17),(4,-16),(6,-13),(8,-13),(10,-10),(10,-6),(8,-5),
      (5,-7),(4,-5),(-3,-5))
    p(hair,(-5,-9),(-6,-6),(-9,-6),(-10,-8),(-8,-11),(-4,-12),
      (-3,-15),(0,-16),(4,-15),(5,-12),(8,-12),(9,-9),(9,-7),(7,-6),
      (5,-8),(3,-6),(-3,-6))
    p(SKIN_DARK,(-4,-10),(-1,-13),(4,-12),(5,-10),(5,-8),(3,-6),(-1,-6),(-4,-8))
    p(SKIN,(-3,-10),(-1,-12),(4,-11),(5,-9),(3,-7),(-1,-7),(-3,-8))
    p(hi,(-4,-12),(-2,-15),(0,-16),(4,-14),(4,-12),(1,-13),(0,-11),(-2,-12),(-4,-10))
    d.point((x-6,y-11),red)
    d.point((x+6,y-11),red)
    if cheer and f%2:
        d.point((x+3,y-10),"#885234")
        d.point((x+2,y-8),"#9d4f39")
    else:
        d.line((x+3,y-10,x+3,y-9),"#885234")
        d.point((x+3,y-7),"#a75c40")
    p(collar,(-3,-5),(-1,-5),(1,-4),(3,-5),(4,-4),(2,-3),(-1,-3))
    d.point((x+1,y-3),red)
    return canvas


def save(root, rel, image):
    path=root/rel
    path.parent.mkdir(parents=True,exist_ok=True)
    with path.open("xb") as stream:
        image.save(stream,"PNG",optimize=True)


def main():
    root=Path(sys.argv[1]).resolve()
    for cid in PALETTES:
        save(root, f"field/chara_{cid}.png",
             atlas([walker(cid,d,g) for d in range(4) for g in (-1,0,1)],3))
    save(root,"battle/angie.png",atlas([angie_frame(r,f) if f < count else new(48,48)
                                      for r,count in enumerate(HERO_COUNTS) for f in range(8)],8))
    save(root,"battle/nine.png",atlas([nine_frame(r,f) if f<4 else new(32,32)
                                     for r in range(2) for f in range(8)],8))


if __name__ == "__main__":
    main()
