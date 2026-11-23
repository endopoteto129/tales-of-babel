"""第一層の戦闘素材。すべて原寸の格子上に描画する。"""
from math import cos, pi, sin
from pathlib import Path
import random
import sys

from PIL import Image, ImageDraw, ImageFont


HERO = (4, 6, 2, 2, 4, 4, 4, 6, 4, 2, 3, 4)
ENEMY = (4, 4, 2, 4, 2, 3)
INK = "#242230"


def blank(w, h=None):
    return Image.new("RGBA", (w, h or w))


def poly(d, color, *points):
    d.polygon(points, "#" + color)


def outlined_limb(d, points, shade, light, width):
    d.line(points, INK, width + 2, joint="curve")
    d.line(points, shade, width, joint="curve")
    a, b = points[:2]
    d.line(((a[0], a[1]-1), (b[0], b[1]-1)), light)


def sword(d, hand, tip):
    x, y = hand
    u, v = tip
    dx, dy = u-x, v-y
    length = max(1, (dx*dx + dy*dy)**0.5)
    a, b = -dy/length, dx/length
    def pos(t, s):
        return round(x+t*dx+s*a), round(y+t*dy+s*b)
    poly(d,"292b3c",pos(.15,-2),pos(.84,-2),tip,pos(.88,2),pos(.15,2))
    poly(d,"9dacc0",pos(.22,-1),pos(.85,-1),pos(.94,0),pos(.82,1),pos(.22,1))
    d.line((pos(.23,-1),pos(.88,0)), "#dce4da")
    d.line((pos(.14,-3),pos(.14,3)), "#302736", 2)
    d.line((pos(.14,-2),pos(.14,2)), "#b08b65")
    d.line((pos(-.15,0), hand), "#593f3e", 2)


def ren(row, frame):
    img = blank(48)
    d = ImageDraw.Draw(img)
    # 腰の移動、重心の高さ、頭の傾き、両足、剣を握る手と切っ先。
    idle = [(0, 0, 0, -4, 4, 7, -2, 17, -12),
            (0,-1, 0, -4, 4, 7, -3, 17, -13),
            (0,-1, 0, -4, 4, 8, -3, 18, -12),
            (0, 0, 0, -4, 4, 7, -2, 17, -11)]
    attacks = [
        [(-3,0,-2,-4,4,-4,-8,-15,-18),(2,0,3,-5,6,11,-7,21,-18),
         (4,1,4,-7,7,11,-1,22,5),(1,1,1,-5,5,7,-1,18,2)],
        [(-2,1,0,-4,4,3,2,13,6),(1,1,2,-6,6,11,0,22,4),
         (4,0,3,-7,7,11,-7,20,-20),(0,0,0,-4,4,5,-9,8,-24)],
        [(-3,0,-1,-4,4,3,-11,-3,-26),(0,-1,0,-5,5,7,-11,12,-28),
         (5,2,4,-7,8,12,0,22,7),(3,2,2,-6,6,9,1,19,6)],
        [(-4,0,-2,-5,4,-4,-9,-15,-21),(-3,-1,-1,-6,4,1,-12,-3,-27),
         (0,-2,1,-5,5,6,-11,13,-25),(5,0,4,-7,7,13,-6,23,-14),
         (5,2,4,-7,8,13,0,23,6),(2,1,1,-5,5,8,1,18,5)],
    ]
    poses = {
        0: idle,
        1: [(0,b,3,u,v,4+(i%3),-2,15,4) for i,(b,u,v) in
            enumerate([(-1,-7,7),(0,-4,5),(1,0,3),(-1,7,-7),(0,5,-4),(1,3,0)])],
        2: [(0,-4,2,-4,4,6,-8,16,-22),(0,-2,1,-5,5,8,-5,19,-9)],
        3: [(-1,1,-1,-5,4,8,-4,13,-20),(-2,3,-2,-5,5,8,-5,13,-20)],
        4: attacks[0], 5: attacks[1], 6: attacks[2], 7: attacks[3],
        8: [(0,-(i%2),0,-4,4,2,-7-i%2,4,-23-i%2) for i in range(4)],
        9: [(-4,0,-3,-4,5,5,2,14,7),(-3,2,-3,-4,4,6,1,16,7)],
        10: [(-4,5,-4,-4,6,4,2,15,5),(-2,6,-3,-4,5,5,4,16,5),
             (-2,3,-2,-4,4,8,0,17,6)],
        11: [(0,0,0,-4,4,4,-8,2,-26),(0,-1,0,-4,4,5,-11,6,-28),
             (0,-1,0,-4,4,5,-12,10,-29),(0,0,0,-4,4,5,-10,7,-27)],
    }
    shift, bob, lean, back, front, hx, hy, tx, ty = poses[row][frame]
    cx, cy = 23+shift, 35+bob
    if row == 10 and frame < 2:
        # 倒れ込み・横倒し。武器と手が床につく。
        poly(d,"242230",(7,44),(12,41),(19,41),(22,39),(29,39),(32,36+frame*4),
             (38,37+frame*4),(41,42),(39,46),(10,47))
        poly(d,"3a4059",(10,44),(16,42),(24,42),(29,40),(33,44),(28,46),(12,46))
        poly(d,"59617b",(16,43),(26,41),(29,42),(24,44),(17,45))
        d.line((28,42,32,45), "#903e51", 3)
        d.ellipse((31,38+2*frame,39,45), "#353547")
        d.point((38,44), "#efbb99")
        d.line((29,47,43,47), "#9dacc0", 1)
        return img
    def p(color, *points):
        poly(d,color,*[(cx+x,cy+y) for x,y in points])
    for idx, foot in enumerate((back, front)):
        fx = 23+foot
        fy = 46
        if row == 1:
            fy -= (0,0,2,3,2,0)[(frame+3*idx)%6]
        if row == 2 and idx == 0:
            fy -= 4 if frame == 0 else 2
        hip = (cx + (-2 if idx == 0 else 2), cy+1)
        knee = (round((fx+hip[0])/2)+(1 if idx else -1), min(fy-3,cy+5))
        outlined_limb(d, [hip,knee,(fx,fy-2)], "#383649" if idx==0 else "#515470", "#68677a", 3)
        poly(d,"28232c",(fx-2,fy-3),(fx+1,fy-3),(fx+3,fy-1),(fx+3,fy+1),(fx-2,fy+1))
        d.line((fx-1,fy,fx+2,fy), "#896758")
    p("242230",(-5,-10),(lean+4,-12),(lean+6,-9),(5,-2),(6,3),
      (1,6),(-6,5),(-6,-1),(-8,-4))
    p("3a4059",(-5,-9),(lean+3,-11),(lean+5,-8),(4,-2),(5,2),(0,5),(-5,4),(-5,-1))
    p("59617b",(-5,-8),(lean+1,-9),(1,-6),(-1,-5),(-2,1),(-4,3),(-5,2))
    p("733448",(-3,-3),(-2,-3),(-3,3),(-4,4),(-5,3))
    p("a38366",(lean+3,-9),(lean+4,-8),(-1,-1),(-3,0),(-3,-1))
    p("76584e",(-5,0),(4,-1),(4,0),(-5,1))
    d.point((cx+2,cy), "#cfb18a")
    # マフラーの端は走りと大振りで後ろに流れる。
    tail = 12 if row in (1,4,5,6,7) else 7
    p("502d3c",(lean-5,-12),(-tail,-11+bob),(-tail-2,-9+bob),(-tail+2,-8+bob),(-3,-8))
    p("903e51",(lean-5,-11),(-tail,-10+bob),(-tail+1,-9+bob),(-3,-9))
    # 横顔と髪。前髪、目、襟の順で重ねる。
    head = cx+lean
    def h(color, *points):
        poly(d,color,*[(head+x,cy+y) for x,y in points])
    h("242230",(-6,-15),(-6,-20),(-3,-23),(2,-23),(5,-21),(6,-18),(5,-17),
      (7,-15),(6,-14),(5,-11),(0,-10),(-4,-12))
    h("b97d68",(-1,-19),(3,-20),(5,-17),(5,-15),(6,-15),(4,-12),(0,-12),(-2,-14))
    h("efbb99",(1,-18),(4,-18),(4,-16),(5,-15),(4,-13),(1,-13),(-1,-15))
    h("353547",(-5,-19),(-3,-22),(2,-22),(4,-21),(5,-19),(3,-17),(2,-19),
      (0,-16),(-1,-17),(-2,-14),(-4,-14),(-5,-16))
    h("65697d",(-4,-19),(-2,-21),(2,-21),(0,-20),(-2,-19),(-3,-17),(-4,-17))
    d.point((head+4,cy-16), "#533541")
    h("502d3c",(-4,-13),(-1,-12),(4,-12),(5,-10),(2,-8),(-4,-9),(-5,-11))
    h("903e51",(-4,-12),(-1,-11),(4,-11),(4,-10),(0,-9),(-4,-10))
    d.line((head-3,cy-11,head,cy-10), "#b45a61")
    hand = (cx+hx,cy+hy)
    tip = (min(46,23+tx),max(1,35+ty))
    shoulder = (cx+lean+1,cy-8)
    elbow = (round((shoulder[0]+hand[0])/2)-1, round((shoulder[1]+hand[1])/2)+2)
    outlined_limb(d, [shoulder,elbow,hand], "#424960", "#697186", 4)
    sword(d, hand, tip)
    d.rectangle((hand[0]-1,hand[1]-1,hand[0]+1,hand[1]+1), "#a57a62")
    d.point(hand, "#c79776")
    if row in (4,5,6,7) and frame == (3 if row==7 else 2):
        # 攻撃の軌跡も不透明色で1ドットずつ描く。
        if row in (5,7) and ty < 0:
            poly(d,"b4c4cb",(35,38),(42,31),(46,23),(47,17),(47,24),(44,32),(38,37))
            d.line((44,29,47,19), "#e5ecdd")
        else:
            poly(d,"b4c4cb",(43,15),(46,21),(47,28),(46,34),(43,40),(38,43),
                 (43,37),(45,30),(45,22))
            d.line((46,23,46,33), "#e5ecdd")
    return img


def slime(d, x, y, w, h, _: int):
    x -= w//2
    poly(d,"234037",(x,y-3),(x+2,y-h+4),(x+5,y-h),(x+w-5,y-h),
         (x+w-2,y-h+3),(x+w,y-3),(x+w-1,y-1),(x+w-4,y),(x+3,y))
    poly(d,"429b66",(x+1,y-3),(x+3,y-h+4),(x+6,y-h+1),(x+w-5,y-h+1),
         (x+w-2,y-h+4),(x+w-1,y-3),(x+w-4,y-1),(x+3,y-1))
    poly(d,"72c77d",(x+2,y-3),(x+4,y-h+3),(x+7,y-h+1),(x+w-5,y-h+2),
         (x+w-3,y-4),(x+w-6,y-2),(x+4,y-2))
    if h > 5:
        d.line((x+4,y-h+4,x+7,y-h+2), "#c7ed9c", 2)
        d.rectangle((x+w-6,y-6,x+w-4,y-4), "#f6edc8")
        d.line((x+w-4,y-6,x+w-4,y-5), "#253b34")
    d.point((x+w-3,y-2), "#29624d")


def bat(d, x, y, w, h, wing):
    low = y-2
    top = y-h
    left, right = x-w//2, x+w//2
    if h < 6:
        poly(d,"2c223e",(left,y),(x-5,y-h),(x+4,y-h),(right,y-1),(right-3,y),(left,y))
        d.line((left+4,y-1,right-4,y-1), "#72559b")
        return
    wing_y = min(y-5, max(0, top+wing))
    poly(d,"2c223e",(left,wing_y),(left+5,wing_y+1),(x-2,top+4),(x,top+1),
         (x+3,top),(x+5,top+3),(right,wing_y+1),(right-2,wing_y+5),
         (x+5,low),(x+3,y),(x-1,y),(x-4,low),(left+3,wing_y+5))
    poly(d,"72559b",(left+1,wing_y+1),(left+5,wing_y+2),(x-2,top+5),(x-4,low-1),
         (left+4,wing_y+4))
    poly(d,"a371ad",(left+2,wing_y+2),(left+5,wing_y+2),(x-5,top+5),(left+4,wing_y+3))
    poly(d,"654982",(x+4,top+4),(right-1,wing_y+2),(right-3,wing_y+5),(x+4,low))
    poly(d,"9367ae",(x-2,top+4),(x,top+2),(x+1,top+4),(x+3,top+1),(x+4,top+4),
         (x+4,low),(x+2,y-1),(x-1,low))
    d.point((x+3,top+5), "#ffe795")
    d.point((x+3,low), "#e8d7ea")


def quadruped(d, x, y, w, h, stride, boss=False):
    # 同じ骨格で脚を動かし、巨獣には別の輪郭・角・たてがみを重ねる。
    ink, mid, light, pale, dark = (("342832","805b4b","a57d5a","d8b38a","553949") if boss else
                                    ("242939","626b84","a5a7b5","c5bbb8","4c4d63"))
    def p(color, *points):
        poly(d,color,*[(x+round(u*w/40), y-round(v*h/40)) for u,v in points])
    def foot(at, sway, color, far):
        reach = 5 if boss else 3
        z = 2 if far else 0
        p(ink,(at-3,15),(at+3,15),(at+2+sway,6+z),(at+sway+reach,4+z),
          (at+sway+reach,z),(at+sway-4,z),(at+sway-5,5+z))
        p(color,(at-2,14),(at+2,14),(at+1+sway,6+z),(at+sway+reach-1,3+z),
          (at+sway+reach-1,z+1),(at+sway-3,z+1),(at+sway-4,5+z))
        if boss and not far:
            p(pale,(at+sway+1,3),(at+sway+reach-1,3),(at+sway+reach-1,1),(at+sway+1,1))
    if h <= (9 if boss else 5):
        p(ink,(-22,0),(-16,19),(-5,34),(7,27),(14,30),(22,19),(23,3),(19,0))
        p(mid,(-20,3),(-14,19),(-5,30),(7,22),(14,26),(21,17),(20,3))
        p(light,(-13,20),(-5,30),(7,22),(4,13),(-6,16))
        p(pale,(16,17),(20,14),(18,9),(13,10))
        return
    foot(-11,stride,dark,True)
    foot(9,-stride,dark,True)
    p(ink,(-23,25),(-19,27),(-14,22),(-9,24),(0,24),(8,25),(12,30),
      (11,36),(15,40),(18,32),(20,30),(21,25),(23,22),(23,17),(20,15),
      (15,15),(11,11),(3,10),(-6,12),(-12,10),(-16,14),(-18,17),(-22,20))
    p(mid,(-22,25),(-19,25),(-14,20),(-9,23),(0,23),(8,24),(13,29),(12,35),
      (15,37),(17,31),(20,28),(20,24),(22,22),(22,18),(18,17),(14,17),(10,13),
      (2,12),(-6,14),(-12,12),(-15,15),(-17,18),(-21,21))
    p(light,(-13,19),(-9,22),(4,22),(10,25),(14,29),(16,29),(18,27),(15,25),
      (11,20),(6,18),(-2,18),(-8,16))
    p(dark,(-9,15),(-3,17),(5,16),(11,18),(10,13),(3,12),(-6,14))
    if boss:
        p(ink,(4,24),(7,33),(12,34),(17,30),(18,23),(13,14),(6,11),(3,17))
        p(dark,(5,23),(8,32),(12,33),(16,29),(16,23),(12,15),(6,13))
        p(light,(6,24),(9,31),(13,33),(16,28),(14,26),(13,21),(10,23),(8,18))
        p(ink,(12,31),(8,33),(5,37),(4,41),(9,38),(15,36),(19,38),(23,43),(23,37),(20,33),(16,31))
        p(pale,(6,39),(9,37),(14,35),(14,33),(10,34),(7,37))
        p("c19b75",(22,41),(21,37),(18,34),(16,34),(18,36))
        p(mid,(13,31),(17,32),(20,29),(21,25),(23,22),(22,18),(18,17),(15,19),(13,24))
        p(light,(15,30),(18,30),(20,28),(18,26),(15,27),(14,25))
        p("553949",(16,26),(20,27),(20,24),(17,23))
        p("ffd478",(17,25),(19,26),(19,24),(17,24))
        p("e9c296",(19,20),(21,22),(21,18),(20,16))
    else:
        p(pale,(13,22),(17,23),(21,21),(22,19),(17,18),(14,17))
        p("e7bf79",(17,27),(19,26),(18,24),(17,25))
    foot(-10,-stride,mid,False)
    foot(11,stride,mid,False)


def golem(d, x, y, w, h, swing):
    def p(color, *points):
        poly(d,color,*[(x+round(u*w/20), y-round(v*h/27)) for u,v in points])
    z = swing
    if h < 15:
        p("2b3435",(-11,0),(-11,6),(-6,12),(0,10),(4,16),(10,12),(12,6),(12,0))
        p("79837b",(-10,2),(-9,6),(-6,10),(-2,7),(-3,2))
        p("a9ac93",(0,6),(4,14),(9,11),(10,6),(5,4))
        p("47734f",(-8,6),(-6,9),(-3,7),(-5,5))
        p("555e58",(-2,1),(1,5),(6,4),(9,6),(11,4),(10,1))
        return
    p("2b3435",(-8,0),(-8,6),(-6,9),(-2,9),(-1,4),(-2,0))
    p("2b3435",(2,0),(1,6),(2,9),(7,9),(8,5),(10,1),(9,0))
    p("7e8375",(-7,2),(-7,6),(-5,8),(-3,7),(-3,2))
    p("646e69",(3,2),(2,6),(5,8),(7,6),(8,2))
    p("2b3435",(-8,8),(-9,18),(-5,23),(4,24),(8,20),(9,12),(5,7),(-4,6))
    p("79837b",(-7,9),(-8,17),(-4,22),(3,23),(7,19),(8,12),(5,8),(-4,7))
    p("a9ac93",(-7,17),(-4,21),(3,22),(4,20),(1,17),(-4,14))
    p("555e58",(1,16),(5,19),(7,15),(6,12),(3,9),(-3,9),(-1,12),(-3,14))
    p("47734f",(-9,15),(-9,20),(-5,23),(-1,22),(-3,19),(-5,18),(-6,15))
    p("80a35f",(-8,18),(-6,21),(-3,21),(-5,19),(-7,17))
    p("2b3435",(-1,21),(-1,25),(2,27),(7,27),(10,24),(10,21),(7,19),(2,19))
    p("8d9385",(0,22),(0,25),(3,26),(7,26),(9,24),(9,22),(6,20),(2,20))
    p("adb69a",(1,25),(4,26),(7,25),(5,24),(2,23))
    p("dcb369",(5,23),(9,24),(9,22),(5,22))
    p("ffe58d",(7,23),(9,24),(9,23))
    p("2b3435",(4,16),(6+z,19),(10+z,18),(13+z,14),(12+z,9),
      (9+z,7),(5+z,9),(4+z,12))
    p("687d70",(5,16),(6+z,18),(10+z,17),(12+z,14),(11+z,10),(9+z,8),
      (6+z,10),(5+z,12))
    p("a1a88e",(6+z,15),(7+z,17),(9+z,17),(11+z,15),(8+z,14))
    p("485b52",(9+z,13),(11+z,13),(10+z,10),(9+z,9),(7+z,10))


def enemy(kind, size, row, frame):
    img = blank(size)
    d = ImageDraw.Draw(img)
    shift = [[0,0,0,0],[-1,0,1,0],[-2,-3],[-1,3,4,1],[-3,-1],[-2,0,1]][row][frame]
    pose = [[0,1,1,0],[1,0,1,0],[-2,-3],[-1,2,1,0],[-2,-1],[-4,-7,-8]][row][frame]
    stride = [[0,0,0,0],[-3,0,3,0],[-1,-2],[-2,4,2,0],[-2,0],[-1,0,0]][row][frame]
    bottom = size-1
    x = size//2-1+shift
    if kind == "slime":
        slime(d,x,bottom,13-pose//2, max(4,10+pose),stride)
    elif kind == "bat":
        wing = [[0,3,6,3],[0,5,8,4],[5,8],[1,5,8,4],[2,7],[4,5,5]][row][frame]
        bat(d,x,bottom,19 if row==5 else 18,9+pose if row!=5 else 4-frame//2,wing)
    elif kind == "golem":
        golem(d,x,bottom,19,27+pose if row!=5 else [19,13,9][frame],stride)
    elif kind == "wolf":
        quadruped(d,x,bottom,19,11+pose if row!=5 else [8,5,4][frame],stride)
    else:
        quadruped(d,x,bottom,39,34+pose if row!=5 else [24,9,8][frame],stride,True)
    return img


def background():
    img = blank(320,180)
    d = ImageDraw.Draw(img)
    rng = random.Random(1705)
    for y in range(0,156,6):
        t=y/150
        color=tuple(round(a+(b-a)*t) for a,b in zip((113,154,186),(213,225,210)))
        d.rectangle((0,y,319,y+5),color)
    clouds = [(23,35,33),(81,59,49),(166,25,25),(215,51,43),(283,27,29)]
    for x,y,w in clouds:
        for j,(ox,oy,a,b) in enumerate([(0,0,7,4),(w//5,-3,9,6),(w//2,-6,9,8),
                                         (w*2//3,-2,11,6),(w,0,8,4)]):
            d.ellipse((x+ox-a,y+oy-b,x+ox+a,y+oy+b),"#b4ccce")
            d.ellipse((x+ox-a,y+oy-b-2,x+ox+a-1,y+oy+b-2),
                      "#edf0d9" if j%2 else "#dfe9d7")
        d.line((x-5,y+3,x+w+4,y+3),"#d4e2d6",2)
    # 遠景の塔と昇降台。
    poly(d,"789ca2",(267,146),(271,38),(276,29),(282,29),(287,39),(290,146))
    poly(d,"aac0b6",(271,145),(273,38),(277,33),(279,34),(277,145))
    d.rectangle((279,37,282,145),"#5f8997")
    d.line((280,38,280,145),"#c0d2ba")
    d.rectangle((275,62,286,70),"#536f7d")
    d.rectangle((276,63,285,67),"#c8c6a0")
    d.line((278,64,283,64),"#e7dfad")
    for color, base, amplitude, phase, speed in [
        ("90b39e",119,12,1.4,.031),("79a48e",131,15,.1,.026),
        ("648d74",139,11,2.2,.038),("507d65",146,8,.7,.050)]:
        pts = [(x,round(base+amplitude*sin(x*speed+phase)+3*sin(x*.07))) for x in range(320)]
        poly(d,color,*pts,(319,153),(0,153))
        for _ in range(32):
            x=rng.randrange(320)
            y=pts[x][1]+rng.randrange(2,7)
            d.line((x,y,x+rng.randrange(2,8),y), "#"+color)
    for x in range(0,320,3):
        y = rng.randrange(145,150)
        d.line((x,y,x+1,150),"#537f59")
    d.rectangle((0,150,319,179),"#638857")
    d.line((0,150,319,150),"#95ae69",2)
    d.line((0,152,319,152),"#739753")
    for y in range(154,180,4):
        for _ in range(20):
            x=rng.randrange(320)
            d.line((x,y,x+rng.randrange(1,12),y),rng.choice(["#5d8255","#71915a","#7e9a5c"]))
    for x,y in [(11,161),(24,173),(45,155),(78,178),(252,174),(279,166),(308,156)]:
        d.line([(x-2,y-2),(x,y),(x+1,y-4),(x+2,y-1),(x+4,y-3)],"#476f52")
        d.point((x+1,y-4),"#aeaf65")
    return img


def spark(frame):
    img = blank(24)
    d = ImageDraw.Draw(img)
    for i, angle in enumerate((.12,.75,1.54,2.21,2.94,3.52,4.21,5.10,5.66)):
        r = [5,9,11,11][frame] - i%3
        tail = [0,2,5,8][frame] - i%2
        tx,ty=round(11.5+cos(angle)*r),round(11.5+sin(angle)*r)
        sx,sy=round(11.5+cos(angle)*tail),round(11.5+sin(angle)*tail)
        d.line((sx,sy,tx,ty),["#ededed","#eeeeee","#cacaca","#a2a2a2"][frame],
               2 if frame < 2 and i%2==0 else 1)
        if frame == 1 and i%2==0:
            d.point((tx,ty),"#ffffff")
    if frame < 2:
        poly(d,"ffffff",(11,7+frame),(13,10),(17-frame,11),(13,13),(12,17-frame),
             (10,13),(7+frame,12),(10,10))
    return img


def sheet(size, rows, draw):
    img = blank(size*8,size*len(rows))
    for r,count in enumerate(rows):
        for f in range(count):
            img.paste(draw(r,f),(f*size,r*size))
    return img


def proofs(root, images):
    hero_labels = ("Idle","Run","Jump","Guard","Normal 1","Normal 2","Normal 3",
                   "Arte","Cast","Hit","Down","Victory")
    enemy_labels = ("Idle","Move","Wind-up","Attack","Hit","Down")
    font = ImageFont.load_default(size=16)
    for path,img in images.items():
        if path.startswith("battle/"):
            cw=img.width//8
            count, labels = (HERO,hero_labels) if path=="battle/ren.png" else (ENEMY,enemy_labels)
            proof = Image.new("RGB",(140+max(count)*cw*4+22, 48+len(count)*(cw*4+6)+14),"#151d2a")
            d=ImageDraw.Draw(proof)
            d.text((18,14),path+"  /  4x",font=font,fill="#f3e8d6")
            for row,num in enumerate(count):
                y=48+row*(cw*4+6)
                d.text((18,y+cw*2-8),labels[row],font=font,fill="#f3e8d6")
                for f in range(num):
                    x=140+f*cw*4
                    d.rectangle((x,y,x+cw*4-1,y+cw*4-1),fill="#3b5554" if f%2 else "#46635e",
                                outline="#788982")
                    frame=img.crop((f*cw,row*cw,(f+1)*cw,(row+1)*cw))
                    frame=frame.resize((cw*4,cw*4),Image.Resampling.NEAREST)
                    proof.paste(frame,(x,y),frame)
                    d.line((x,y+cw*4-1,x+cw*4-1,y+cw*4-1),"#788982")
        else:
            proof=Image.new("RGB",(img.width*4+36,img.height*4+64),"#151d2a")
            d=ImageDraw.Draw(proof)
            d.text((18,14),path+"  /  4x",font=font,fill="#f3e8d6")
            scaled=img.resize((img.width*4,img.height*4),Image.Resampling.NEAREST)
            proof.paste(scaled,(18,46),scaled)
            if path=="fx/spark.png":
                for f in range(5):
                    x=18+f*96
                    d.line((x,46,x,142),"#788982")
                d.line((18,142,402,142),"#788982")
        save(root / (Path(path).stem+"-4x.png"),proof)


def save(path, image):
    path.parent.mkdir(parents=True,exist_ok=True)
    with path.open("xb") as stream:
        image.save(stream,"PNG",optimize=True)


def main():
    root=Path(sys.argv[1]).resolve()
    images={"battle/ren.png":sheet(48,HERO,ren)}
    for kind,size in [("slime",32),("bat",32),("wolf",32),("golem",48),("boss_beast",64)]:
        images[f"battle/{kind}.png"]=sheet(size,ENEMY,lambda r,f:enemy(kind,size,r,f))
    images["battle_bg/grass.png"]=background()
    strip=blank(96,24)
    for i in range(4):
        strip.paste(spark(i),(i*24,0))
    images["fx/spark.png"]=strip
    for path,img in images.items():
        save(root / "assets/pixel" / path,img)
    proofs(root / "art_src/pixel/preview/battle_floor1",images)


if __name__=="__main__":
    main()
