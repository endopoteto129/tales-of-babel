"""味方の戦闘素材。関節を指定し、48×48の原寸で描く。"""
from dataclasses import dataclass
from math import hypot
from pathlib import Path
import sys

from PIL import Image, ImageDraw

HERO_COUNTS = (4, 6, 2, 2, 4, 4, 4, 6, 4, 2, 3, 4)
INK = "#201d29"
SKIN = "#edba99"
SKIN_SHADE = "#ba806d"


@dataclass(frozen=True)
class Costume:
    base: str
    light: str
    trim: str
    highlight: str
    hair: str
    hair_light: str
    boots: str
    weapon: str


COSTUMES = {
    "ren": Costume("#36394f","#575c76","#783649","#a55162","#2f2e40","#5b5a70","#453942","sword"),
    "angie": Costume("#36303a","#59505c","#913f44","#c36a60","#4b303e","#785166","#3c303a","staff"),
    "sona": Costume("#324e49","#54736b","#968467","#bdac82","#333443","#62636c","#484445","gun"),
    "jin": Costume("#303b57","#4e6079","#9d7950","#c7a570","#272632","#55515c","#393643","katana"),
    "john": Costume("#775640","#aa7a50","#a27448","#d0a372","#a77746","#d6a96b","#46383b","fists"),
}


# 腰の画面位置・肩の前後・脚の前後・杖などを握る手・武器の角度を切り替える。
def pose(row, frame):
    run = (
        ((-5,46),(7,47),(5,26)), ((-2,44),(5,47),(3,24)),
        ((2,43),(2,47),(2,25)), ((7,47),(-5,46),(4,26)),
        ((5,47),(-2,44),(6,27)), ((2,47),(2,43),(5,26)),
    )
    if row == 1:
        a,b,grip=run[frame]
        return (24,31-(frame%3==0),2,a,b,grip,(.82,.57))
    if row == 2:
        return (24,30,1,(-4,43),(5,47),(8,22+frame*3),(.52,-.86) if not frame else (.9,-.44))
    if row == 3:
        return (23,32+frame,-1,(-5,47),(5,47),(9,23),(.36,-.93))
    if 4 <= row <= 7:
        hands = (
            ((-4,22),(8,20),(13,26),(8,28)),
            ((6,31),(11,25),(12,21),(6,21)),
            ((4,18),(7,17),(14,30),(8,28)),
            ((-4,21),(3,17),(8,15),(15,20),(14,27),(8,27)),
        )[row-4]
        angles = (
            ((-.65,-.76),(.6,-.8),(1,.28),(.87,.5)),
            ((.83,.55),(1,.05),(.64,-.78),(.4,-.92)),
            ((-.2,-.98),(.24,-.96),(.97,.48),(.91,.34)),
            ((-.8,-.6),(-.1,-1),(.32,-.95),(.94,-.24),(.99,.1),(.64,-.76)),
        )[row-4]
        impact = frame in ((3,4) if row == 7 else (1,2))
        return (24+(2 if impact else -1),31+int(frame==2),2 if impact else -1,
                (-6,47),(6 if impact else 4,47),hands[frame],angles[frame])
    if row == 8:
        return (24,31-(frame%2),0,(-4,47),(4,47),(8,23-frame%2),(.22,-.98))
    if row == 9:
        return (21+frame,31+frame,-3,(-5,47),(5,47),(6,28),(.81,.58))
    if row == 10:
        return (23,35,-1,(-5,47),(5,47),(9,32),(.93,.4))
    if row == 11:
        return (24,31,0,(-4,47),(4,47),(7,19-frame%2),(.16,-.99))
    return (24,31-(frame in (1,2)),0,(-4,47),(4,47),(8,24-frame%2),(.55,-.84))


def poly(d, fill, *points):
    d.polygon(points,fill)


def limb(d, points, primary, secondary, width):
    d.line(points,INK,width+2,joint="curve")
    d.line(points,primary,width,joint="curve")
    a,b=points[:2]
    d.line((a[0]-1,a[1],b[0]-1,b[1]-1),secondary)


def weapon(d, kind, grip, angle):
    x,y=grip
    dx,dy=angle
    length=hypot(dx,dy)
    dx,dy=dx/length,dy/length
    along = min((44-x)/dx if dx>0 else (3-x)/dx if dx<0 else 99,
                (44-y)/dy if dy>0 else (3-y)/dy if dy<0 else 99)
    def at(n, side=0):
        return (round(x+dx*n-dy*side),round(y+dy*n+dx*side))
    if kind in ("sword","katana"):
        blade=min(along,16 if kind=="katana" else 14)
        tip=at(blade,1 if kind=="katana" else 0)
        poly(d,INK,at(2,-2),at(blade-2,-2),tip,at(blade-3,2),at(2,2))
        poly(d,"#9faab9",at(3,-1),at(blade-3,-1),at(blade-2),at(blade-4,1),at(3,1))
        d.line((at(4,-1),at(blade-2)), "#e2e1d3")
        d.line((at(2,-3),at(2,3)),"#ad8c62",2)
        d.line((at(-3),at(1)),"#6a4a43",2)
    elif kind=="staff":
        tip=at(min(16,along))
        d.line((at(-14),tip),INK,3)
        d.line((at(-13),tip),"#8b674d")
        a,b=tip
        poly(d,INK,(a,b-3),(a+3,b),(a,b+3),(a-3,b))
        poly(d,"#a25167",(a,b-2),(a+2,b),(a,b+2),(a-2,b))
        d.point((a-1,b-1),"#ed9f9b")
    elif kind=="gun":
        nozzle=min(11,along)
        poly(d,INK,at(-1,-3),at(nozzle,-3),at(nozzle+1,-1),at(nozzle,1),
             at(5,1),at(1,3),at(-1,2))
        d.line((at(0,-2),at(nozzle,-2)),"#a1aaa7")
        d.line((at(1,-1),at(nozzle-1,-1)),"#58676a")
        d.point(at(nozzle-1),"#c2bf9f")


def down_frame(cid, i):
    skin = SKIN if cid!="john" else "#d5a076"
    c=COSTUMES[cid]
    img=Image.new("RGBA",(48,48))
    d=ImageDraw.Draw(img)
    poly(d,INK,(6,43),(13,40),(20,40),(25,37),(30,39),(35,36+i*3),(41,39+i*2),(43,45),(40,47),(6,47))
    poly(d,c.base,(8,43),(15,41),(22,41),(25,39),(30,41),(33,45),(28,46),(9,46))
    poly(d,c.light,(12,43),(17,42),(22,42),(21,44),(13,45))
    d.line((22,42,29,41),c.trim,2)
    d.ellipse((32,38+i*2,41,45+i),c.hair)
    d.point((40,43+i),skin)
    d.line((33,40+i*2,36,39+i*2),c.hair_light)
    if c.weapon in ("sword","staff","katana"):
        d.line((26,47,44,47),"#8b746a")
    return img


def hero_frame(cid, row, frame, cape=False):
    if row==10 and frame<2:
        body = down_frame(cid,frame)
        if not cape:
            return body
        img = Image.new("RGBA", (48, 48))
        d = ImageDraw.Draw(img)
        poly(d, INK, (2, 47), (7, 42), (17, 39), (29, 38), (37, 42), (33, 47))
        poly(d, "#a23e52", (3, 46), (8, 43), (20, 40), (30, 39), (35, 42), (31, 46))
        img.alpha_composite(body)
        return img
    c=COSTUMES[cid]
    img=Image.new("RGBA",(48,48))
    d=ImageDraw.Draw(img)
    x,y,lean,leg_a,leg_b,hand,angle=pose(row,frame)
    if cid=="sona":
        # 銃は構えと射撃を中心としたポーズにする。
        if 4<=row<=7:
            hand=(11+frame%3,23+frame%2)
            angle=(1,-.13 if row==5 else 0)
        elif row in (0,1):
            hand,angle=(7,28),(.68,.73)
    if cid=="angie" and row==0:
        hand,angle=(9,25-frame%2),(.10,-.99)
    if cid=="john" and row in (0,1,3,8):
        hand=(8,21+frame%2)
    if cid=="john" and row in (4,5,6,7):
        hand=(12+frame%3,21+frame%2)

    top=y-15
    upper=x+lean
    jaw_y=top-2
    shoulder=7 if cid=="john" else (6 if cid=="ren" else 5)
    hip_width=5 if cid=="john" else (4 if cid=="angie" else 3)
    skin="#dca67d" if cid=="john" else SKIN
    shade="#996d53" if cid=="john" else SKIN_SHADE

    if cape:
        sway = 3 if row in (1, 2, 4, 5, 6, 7) else 0
        outer = max(2, upper - 15 - sway - frame % 3)
        bottom = min(46, y + 13 - sway)
        poly(d, INK, (upper-4, top+1), (upper+1, top+3), (x-2, y+3),
             (outer+5, bottom), (outer, bottom-1), (outer+3, y-3))
        poly(d, "#773045", (upper-4, top+3), (upper-1, top+4), (x-3, y+2),
             (outer+5, bottom-1), (outer+1, bottom-2), (outer+4, y-3))
        poly(d, "#aa4054", (upper-5, top+5), (upper-8, y-1), (outer+3, bottom-2),
             (outer+1, bottom-2), (outer+4, y-3))
        d.line([(upper-6, top+7), (outer+5, y-4), (outer+3, bottom-3)], "#d06668")

    # 前後の脚を別々に描き、立ち姿は地面と骨盤の真下に重心を置く。
    for i,(offset, ground) in enumerate((leg_a,leg_b)):
        ankle=(23+offset,ground-3)
        hip=(x+(-3 if i==0 else 2),y+1)
        knee=(round((ankle[0]+hip[0])/2)+(1 if i else -1),round((ground+y)/2)-1)
        limb(d,(hip,knee,ankle),c.base if not i else c.light,c.light,4 if cid=="john" else 3)
        fx,by=ankle[0],ground
        poly(d,INK,(fx-2,by-4),(fx+1,by-4),(fx+2,by-2),(fx+4,by-1),(fx+4,by),(fx-2,by))
        d.line((fx-1,by-1,fx+2,by-1),c.boots)

    def rel(col, *pts):
        poly(d,col,*[(x+a,y+b) for a,b in pts])

    # 裾と髪を背側から描く。胴の前面を細く保つ。
    flow=2 if row in (1,4,5,6,7) else 0
    if cid=="angie":
        poly(d,INK,(upper-4,jaw_y-7),(upper-5,jaw_y-2),(upper-5,top+6),
             (x-7-flow,y+4),(x-9-flow,y+3),(x-8-flow,top+4),(upper-6,jaw_y-7))
        poly(d,c.hair,(upper-5,jaw_y-6),(upper-6,top+1),(x-8-flow,y+2),
             (x-7-flow,y+3),(upper-4,top+4),(upper-4,jaw_y))
        d.line((upper-5,top+1,x-7-flow,y+1),c.hair_light)
        rel(INK,(-4,-3),(4,-3),(5,4),(7+flow,12),(2,13),(-6-flow,13),(-8-flow,11),(-5,5))
        rel(c.base,(-3,-2),(3,-2),(4,5),(6+flow,11),(2,12),(-5-flow,12),(-7-flow,11),(-4,5))
        rel(c.light,(-3,3),(-1,3),(-1,7),(-4,11),(-6,11),(-4,7))
        rel(c.trim,(3,1),(4,3),(5,9),(4,10),(2,4))
    elif cid=="jin":
        rel(INK,(-4,0),(4,0),(5,5),(5+flow,10),(-7-flow,10),(-5,4))
        rel(c.base,(-3,1),(3,1),(4,5),(4+flow,9),(-6-flow,9),(-4,4))
        rel(c.light,(-3,2),(-1,2),(-2,7),(-5,9),(-5,7))
    else:
        rel(INK,(-hip_width-1,-2),(hip_width+1,-2),(hip_width+2,5),
            (1,7),(-hip_width-2-flow,7),(-hip_width-1,2))
        rel(c.base,(-hip_width,-1),(hip_width,-1),(hip_width+1,4),
            (1,6),(-hip_width-1-flow,6),(-hip_width,2))

    # 肩・胸・腰を一枚の曲線にせず、立った骨格が読めるよう絞る。
    poly(d,INK,(upper-shoulder,top+2),(upper-3,top),(upper+3,top),(upper+shoulder,top+2),
         (upper+shoulder,top+6),(x+hip_width,y-1),(x+hip_width,y+2),(x-hip_width-1,y+2),
         (x-hip_width-1,y-1),(upper-shoulder,top+7))
    poly(d,c.base,(upper-shoulder+1,top+2),(upper-3,top+1),(upper+3,top+1),(upper+shoulder-1,top+3),
         (upper+shoulder-1,top+6),(x+hip_width-1,y-1),(x+hip_width-1,y+1),
         (x-hip_width,y+1),(x-hip_width,y-1),(upper-shoulder+1,top+7))
    poly(d,c.light,(upper-shoulder+1,top+3),(upper-3,top+2),(upper+1,top+4),
         (upper-2,top+8),(x-1,y-2),(x-hip_width,y-2),(upper-shoulder+1,top+7))
    if cid in ("ren","sona","john"):
        d.line((upper-3,top+3,x+2,y),c.trim,2)
    if cid=="ren":
        d.line((upper+3,top+3,x-2,y),"#8e6e56",2)
    if cid=="jin":
        d.line((upper-3,top+2,x+2,y-3),"#d0b183")
        d.line((upper+2,top+3,x-1,y-5),c.trim)
    rel(c.trim,(-hip_width-1,-1),(hip_width,-2),(hip_width,0),(-hip_width-1,1))
    d.point((x+1,y-1),c.highlight)

    hx=upper+1
    # 首と頭。顔の軸は肩の中央から外さない。
    d.rectangle((hx-2,jaw_y-1,hx+2,top+2),INK)
    d.rectangle((hx-1,jaw_y,hx+1,top+1),shade)
    if cid=="ren":
        tail=10 if flow else 6
        poly(d,c.trim,(upper-3,top),(upper-tail,top+1),(upper-tail-1,top+3),
             (upper-4,top+3),(upper+2,top+4),(upper+4,top+1))
        d.line((upper-3,top,upper+3,top+1),c.highlight)
    elif cid=="angie":
        poly(d,c.trim,(upper-3,top-2),(upper+5,top-3),(upper+4,top+2),(upper,top+3),(upper-3,top+2))
        d.line((upper,top,upper+4,top-2),c.highlight)
    poly(d,INK,(hx-4,jaw_y-9),(hx-2,jaw_y-11),(hx+2,jaw_y-11),(hx+4,jaw_y-9),
         (hx+4,jaw_y-6),(hx+5,jaw_y-5),(hx+4,jaw_y-4),(hx+4,jaw_y-2),
         (hx+2,jaw_y),(hx-1,jaw_y),(hx-3,jaw_y-2),(hx-4,jaw_y-5))
    poly(d,shade,(hx-2,jaw_y-8),(hx+2,jaw_y-9),(hx+3,jaw_y-7),(hx+3,jaw_y-5),
         (hx+4,jaw_y-5),(hx+3,jaw_y-4),(hx+3,jaw_y-2),(hx+2,jaw_y-1),(hx-1,jaw_y-1),(hx-2,jaw_y-3))
    poly(d,skin,(hx+1,jaw_y-8),(hx+2,jaw_y-8),(hx+3,jaw_y-6),(hx+3,jaw_y-3),
         (hx+2,jaw_y-2),(hx,jaw_y-2),(hx-1,jaw_y-4))
    poly(d,c.hair,(hx-3,jaw_y-8),(hx-2,jaw_y-10),(hx+2,jaw_y-10),(hx+3,jaw_y-9),
         (hx+3,jaw_y-8),(hx+1,jaw_y-9),(hx-1,jaw_y-5),(hx-3,jaw_y-4))
    d.line((hx-2,jaw_y-9,hx+1,jaw_y-10),c.hair_light)
    d.point((hx+3,jaw_y-7),"#624251" if cid in ("ren","angie") else "#43393c")
    d.point((hx+3,jaw_y-3),shade)
    if cid=="ren":
        poly(d,INK,(hx-5,jaw_y-8),(hx-3,jaw_y-9),(hx-3,jaw_y-6),(hx-5,jaw_y-5))
        d.line((hx-3,jaw_y-8,hx-2,jaw_y-9),c.hair_light)
        d.point((hx+3,jaw_y-8),"#513c48")
    elif cid=="angie":
        d.line((hx-3,jaw_y-9,hx-3,jaw_y-5),c.hair_light)
        d.point((hx+2,jaw_y-7),"#8c5b88")
    if cid=="sona":
        d.line((hx-2,jaw_y-8,hx+3,jaw_y-8),"#8d765b")
        d.point((hx+2,jaw_y-9),"#85bbbf")
    elif cid=="jin":
        d.ellipse((hx-5,jaw_y-13,hx-1,jaw_y-9),INK)
        d.point((hx-3,jaw_y-12),c.hair_light)
        d.point((hx-2,jaw_y-10),"#8a4856")
    elif cid=="john":
        d.line((hx+2,jaw_y-5,hx+1,jaw_y-3),"#9a675d")
        d.point((hx-2,jaw_y-9),"#e4be7e")

    # 腕と装備。待機では身体を丸めず、攻撃の瞬間のみ肩と腰を移す。
    grip=(min(36,x+hand[0]),hand[1]+(y-31))
    form=(upper+1,top+4)
    elbow=(round((form[0]+grip[0])/2),max(form[1]+4,round((form[1]+grip[1])/2)+3))
    limb(d,(form,elbow,grip),c.base,c.light,5 if cid=="john" else 3)
    if cid=="john":
        d.line((elbow,grip),"#cab69c",3)
    weapon(d,c.weapon,grip,angle)
    px,py=grip
    d.rectangle((px-1,py-1,px+1,py+1),c.boots if cid=="ren" else shade)
    d.point((px,py-1),"#ac8871" if cid=="ren" else skin)
    if 4<=row<=7 and frame==(3 if row==7 else 2):
        if c.weapon=="gun":
            poly(d,"#f4d396",(43,grip[1]),(45,grip[1]-2),(47,grip[1]),(45,grip[1]+1))
        else:
            d.line([(41,15),(44,19),(46,24),(45,30),(42,35)],"#b6c3cb")
            d.line([(43,19),(45,23),(45,27)],"#e9e8d8")
    return img


def pots_frame(i):
    img=Image.new("RGBA",(24,24))
    d=ImageDraw.Draw(img)
    y=11+(0,1,0,-1)[i]
    d.ellipse((3,y-2,21,y+3),INK)
    for cx in (4,19):
        d.line((cx-3,y-4,cx+3,y-4),"#a19f87")
        d.rectangle((cx-1,y-3,cx+1,y+1),"#526b74")
    d.ellipse((6,y-7,17,y+6),INK)
    d.ellipse((7,y-6,16,y+5),"#769ca9")
    d.line([(8,y-3),(9,y-5),(13,y-5),(15,y-4)],"#c5d6cd")
    d.rectangle((8,y-2,15,y+2),"#273c49")
    d.line((9,y-1,9,y+1),"#a2efde")
    d.line((13,y-1,13,y+1),"#a2efde")
    d.line((11,y-7,11,y-9),"#a18058")
    d.point((11,y-9),"#c9efda")
    d.rectangle((10,y+6,13,y+7),"#7ecbc7")
    d.line((10+i%2,y+8,13-i%2,y+8),"#a5dbd2")
    return img


def main():
    out=Path(sys.argv[1])/"battle"
    out.mkdir(parents=True,exist_ok=True)
    for name in (*COSTUMES, "ren_cape"):
        cape = name == "ren_cape"
        cid = "ren" if cape else name
        img=Image.new("RGBA",(384,576))
        for r,n in enumerate(HERO_COUNTS):
            for f in range(n):
                img.paste(hero_frame(cid,r,f,cape),(f*48,r*48))
        with (out/(name+".png")).open("xb") as fh:
            img.save(fh,"PNG",optimize=True)
    img=Image.new("RGBA",(96,24))
    for i in range(4):
        img.paste(pots_frame(i),(i*24,0))
    with (out/"pots.png").open("xb") as fh:
        img.save(fh,"PNG",optimize=True)


if __name__=="__main__":
    main()
