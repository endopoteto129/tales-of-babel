"""塔の敵の探索用アイコンと戦闘スプライトを原寸で描く。"""
from math import cos, sin, tau
from pathlib import Path
import sys

from PIL import Image, ImageDraw

from shasta_pixel import frame as shasta_frame

INK="#262530"
ENEMY_COUNTS=(4,4,2,4,2,3)

# 戦闘のコマ寸法、体の高さ、横幅比、固有の色
DATA={
    "wisp": (32,13,.84,("#428cac","#82c5d3","#d9f4e2")),
    "ikei": (32,21,.89,("#594469","#90749d","#cdb0c5")),
    "oni": (32,20,.91,("#8c4b4d","#bf7764","#e7aa75")),
    "lion": (32,16,1.0,("#9e6139","#cf9254","#ecc379")),
    "book": (32,11,.9,("#6b493b","#ad7b55","#e7d3a5")),
    "gear": (32,17,1.,("#695843","#a78d59","#ddbc7f")),
    "soldier": (48,24,1.05,("#48566c","#788ba0","#c1c9c3")),
    "gunner": (48,24,1.0,("#414c59","#667f88","#b5c3b7")),
    "drone": (32,10,.95,("#4d6570","#8ba8ad","#c3e3d7")),
    "mage_soldier": (48,23,1.0,("#524366","#806996","#c4bad3")),
    "boss_siren": (48,37,1.2,("#346b88","#76bed2","#c5e8e4")),
    "boss_oni": (64,47,1.25,("#713c52","#ab6370","#e4b488")),
    "boss_nene": (48,27,1.06,("#723c5a","#af6585","#e6c1cc")),
    "boss_val": (48,27,1.0,("#413952","#746589","#c3bed6")),
    "boss_zone": (48,28,1.1,("#475044","#769075","#c8c6a2")),
    "boss_shasta": (48,29,1.08,("#82724d","#bd9b62","#ead79c")),
}


class Brush:
    def __init__(self, image, origin, sx, sy, lean=0):
        self.d=ImageDraw.Draw(image)
        self.x,self.y=origin
        self.sx,self.sy,self.lean=sx,sy,lean

    def at(self,x,y):
        return (round(self.x+(x-y*self.lean)*self.sx),round(self.y+y*self.sy))

    def p(self,color,*coords):
        self.d.polygon([self.at(*p) for p in coords],fill=color)

    def line(self,color,*coords,width=1):
        self.d.line([self.at(*p) for p in coords],fill=color,width=width)

    def dot(self,color,x,y):
        self.d.point(self.at(x,y),fill=color)

    def oval(self,color,x0,y0,x1,y1):
        a,b=self.at(x0,y0),self.at(x1,y1)
        self.d.ellipse((min(a[0],b[0]),min(a[1],b[1]),max(a[0],b[0]),max(a[1],b[1])),fill=color)


def jewel(a,base,hi,x,y,r):
    a.p(INK,(x,y-r-1),(x+r+1,y),(x,y+r+1),(x-r-1,y))
    a.p(base,(x,y-r),(x+r,y),(x,y+r),(x-r,y))
    a.p(hi,(x,y-r),(x+1,y),(x-r,y))


def clothes(a,kind,colors,step,action,front):
    base,light,hi=colors
    skin="#d4aa8c"
    boots="#34323b"
    armor=kind in ("soldier","gunner")
    long=kind in ("mage_soldier","boss_val","boss_zone","boss_nene")
    for sign in (-1,1):
        fx=sign*(5+step)
        a.p(INK,(sign*3,-10),(sign*5,-10),(fx+3,-3),(fx+4,0),(fx-3,0),(fx-3,-3))
        a.p(boots,(sign*3,-9),(sign*4,-9),(fx+1,-3),(fx+2,-1),(fx-2,-1))
        a.line(light,(fx-1,-3),(fx-1,-2))
    if long:
        a.p(INK,(-7,-24),(6,-24),(8,-13),(10+step,-3),(0,-5),(-11-step,-3),(-8,-11))
        a.p(base,(-6,-23),(5,-23),(7,-13),(9+step,-4),(0,-6),(-10-step,-4),(-7,-10))
        a.line(light,(-6,-18),(-8-step,-6))
    a.p(INK,(-8,-23),(-4,-25),(4,-25),(8,-23),(8,-16),(5,-10),(-5,-9),(-8,-16))
    a.p(base,(-7,-22),(-4,-24),(4,-24),(7,-22),(7,-17),(4,-11),(-5,-10),(-7,-16))
    a.p(light,(-7,-22),(-4,-23),(2,-22),(1,-18),(-3,-15),(-5,-13),(-7,-17))
    a.p(base,(-4,-20),(5,-20),(6,-15),(3,-13),(-4,-14))
    a.line(hi,(-4,-12),(4,-13),width=2)
    if armor or kind=="boss_shasta":
        a.line(hi,(-5,-22),(0,-23),(5,-22))
        a.p(light,(0,-22),(5,-21),(4,-17),(0,-15),(-4,-17))
        a.p(hi,(0,-22),(1,-19),(0,-17),(-1,-19))
    elif kind=="boss_nene":
        a.line(hi,(-5,-22),(-2,-17),(1,-14))
    else:
        jewel(a,light,hi,1,-19,1)
    # 頭のデザインは部隊ごとの装備とボスの識別点を優先。
    a.oval(INK,-6,-35,6,-24)
    a.oval("#493e49",-5,-34,5,-25)
    if armor:
        a.p(light,(-5,-33),(-3,-35),(3,-35),(5,-33),(6,-29),(-5,-29))
        a.line(hi,(-3,-34),(2,-34),(4,-32))
        a.line(INK,(-3,-30),(5,-30),width=2)
        a.dot("#edcc91",3,-30)
    else:
        a.p(skin,(-2,-31),(4,-32),(5,-29),(4,-26),(1,-25),(-2,-27))
        if kind=="boss_nene":
            a.p(hi,(-4,-31),(4,-31),(5,-27),(1,-25),(-3,-27))
            a.line("#743849",(-2,-29),(4,-29))
            a.p(base,(-5,-34),(1,-36),(5,-34),(1,-32),(-4,-31))
        elif kind=="boss_val":
            a.p(light,(-5,-34),(2,-35),(5,-33),(2,-30),(-2,-30),(-4,-27))
            a.line(hi,(-4,-33),(2,-34))
        elif kind=="boss_zone":
            a.p(base,(-6,-34),(3,-35),(5,-32),(2,-30),(-2,-32),(-5,-30))
            a.line(hi,(-2,-28),(3,-29))
        elif kind=="boss_shasta":
            a.p(hi,(-5,-34),(-4,-39),(-1,-36),(1,-40),(3,-36),(5,-38),(5,-34))
            a.line("#a16c46",(-3,-35),(4,-35))
            a.dot("#a64959",1,-36)
        else:
            a.p(light,(-6,-31),(-6,-35),(0,-37),(5,-34),(5,-31),(2,-32),(0,-29),(-4,-29))
        if kind!="boss_nene":
            a.dot("#724c56",3,-30)
    if front and kind not in ("boss_nene","boss_val","boss_zone"):
        a.dot(hi,-3,-30)
    reach=11+action
    a.p(INK,(5,-23),(9,-22),(11,-18),(reach,-17),(reach,-13),(7,-13),(5,-18))
    a.p(light,(6,-22),(8,-21),(10,-17),(reach,-16),(reach,-14),(8,-14),(6,-18))
    if kind in ("gunner","boss_zone"):
        a.p(INK,(reach-2,-19),(reach+9,-19),(reach+11,-17),(reach+10,-15),(reach+4,-15),(reach+2,-12),(reach,-12))
        a.line(hi,(reach,-18),(reach+9,-18))
        if action>1:
            a.p("#f6cc83",(reach+10,-17),(reach+13,-19),(reach+15,-17),(reach+13,-15))
    elif kind in ("mage_soldier","boss_val"):
        a.line(INK,(reach-2,-3),(reach+3,-32),width=3)
        a.line(light,(reach-2,-3),(reach+3,-32))
        jewel(a,light,hi,reach+3,-33,3)
    elif kind=="boss_nene":
        a.p(INK,(reach-1,-15),(reach+3,-24),(reach+12,-29),(reach+8,-22),(reach+3,-15))
        a.line(hi,(reach+1,-17),(reach+10,-27))
        if front:
            a.line(hi,(-9,-13),(-13,-27),width=2)
    elif kind=="boss_shasta":
        a.p(INK,(reach-2,-15),(reach+5,-26),(reach+9,-30),(reach+8,-25),(reach+1,-14))
        a.line("#f2e9d0",(reach,-15),(reach+8,-28),width=2)
        a.line(hi,(reach-3,-17),(reach+2,-14))
    else:
        a.line(INK,(reach-5,-11),(reach+10,-27),width=3)
        a.line(hi,(reach-5,-11),(reach+10,-27))
        a.p(hi,(reach+7,-26),(reach+12,-30),(reach+11,-25))


def oni(a,kind,colors,step,action,front):
    base,light,hi=colors
    for s in (-1,1):
        x=s*(5+step)
        a.p(INK,(s*5,-12),(s*8,-12),(x+4,-4),(x+5,0),(x-4,0),(x-4,-5))
        a.p(base,(s*5,-10),(s*7,-11),(x+2,-5),(x+3,-1),(x-3,-1))
    a.p(INK,(-13,-23),(-8,-29),(7,-29),(12,-25),(13,-18),(9,-14),(8,-9),(-9,-9),(-12,-15))
    a.p(base,(-12,-23),(-8,-28),(6,-28),(11,-25),(12,-18),(8,-14),(7,-10),(-8,-10),(-11,-15))
    a.p(light,(-12,-22),(-8,-26),(0,-25),(7,-22),(5,-19),(-1,-18),(-5,-15),(-10,-17))
    a.p("#564252",(-8,-14),(7,-16),(10,-9),(0,-10),(-8,-7))
    a.line(hi,(-8,-14),(7,-16),width=2)
    a.p(INK,(-9,-30),(-6,-35),(4,-35),(9,-32),(10,-27),(6,-23),(-4,-24))
    a.p(light,(-8,-30),(-6,-34),(4,-34),(8,-31),(9,-28),(5,-24),(-4,-25))
    a.p(base,(-3,-30),(6,-31),(8,-29),(7,-27),(2,-26),(-3,-28))
    for s in (-1,1):
        a.p(hi,(s*4,-33),(s*8,-38),(s*8,-30),(s*6,-31))
        a.p("#f3d59e",(s*3,-27),(s*5,-26),(s*4,-24))
    a.line("#e9ba6a",(0,-31),(5,-31),width=2)
    if front:
        a.line("#e9ba6a",(-6,-31),(-3,-31),width=2)
    reach=10+action
    a.p(INK,(8,-25),(12,-23),(reach+6,-20),(reach+7,-13),(reach+2,-12),
              (reach-2,-16),(7,-19))
    a.p(base,(9,-24),(11,-22),(reach+5,-19),(reach+6,-14),(reach+2,-13),(reach,-16),(8,-19))
    a.line(light,(10,-22),(reach+4,-18),width=2)
    if kind=="boss_oni":
        a.p(INK,(reach+3,-11),(reach+4,-27),(reach+8,-35),(reach+13,-35),(reach+16,-31),
                 (reach+16,-25),(reach+9,-22),(reach+6,-10))
        a.p("#6d524a",(reach+4,-12),(reach+5,-27),(reach+9,-34),(reach+13,-34),
                     (reach+15,-31),(reach+15,-26),(reach+8,-23),(reach+5,-12))
        a.line("#b08864",(reach+8,-31),(reach+12,-33),(reach+14,-30))


def siren(a,c,step,action,front):
    base,light,hi=c
    a.p(INK,(-5,-21),(6,-21),(8,-14),(9,-6),(12,0),(0,-2),(-12,0),(-9,-7))
    a.p(base,(-4,-20),(5,-20),(7,-14),(8,-6),(10,-1),(0,-3),(-10,-1),(-8,-7))
    a.p(light,(-3,-19),(1,-18),(-1,-13),(-1,-5),(-8,-2),(-7,-6))
    a.p(light,(3,-14),(5,-14),(7,-9),(4,-8),(2,-5))
    for x in (-10,-6,6,10):
        y=-6 if abs(x)==10 else -14
        a.p(base,(x-3,y+1),(x-2,y-8-step),(x+1,y-9-step),(x+3,y-3),(x+2,y+4))
        a.line(light,(x-2,y+1),(x+1,y-8-step))
    a.p(INK,(-6,-33),(-2,-37),(4,-36),(7,-32),(6,-26),(3,-24),(-5,-24))
    a.p(light,(-5,-33),(-2,-36),(4,-35),(6,-32),(5,-26),(2,-25),(-4,-25))
    a.p(hi,(-1,-32),(3,-33),(5,-31),(4,-27),(1,-26),(-1,-28))
    a.line("#364f70",(2,-30),(4,-30))
    a.p(hi,(-4,-34),(-4,-40),(0,-36),(3,-40),(5,-35))
    a.line(base,(-2,-35),(4,-35))
    for side in ((-1,1) if front else (1,)):
        x=side*(9+action)
        a.line(INK,(side*4,-23),(x,-21),(x+side*4,-24),width=4)
        a.line(light,(side*4,-23),(x,-21),(x+side*4,-24),width=2)
        jewel(a,light,hi,x+side*5,-25,2+int(action>2))


def lion(a,c,step,action):
    base,light,hi=c
    a.line(INK,(-13,-10),(-20,-17),(-22,-22),width=3)
    a.line(light,(-13,-10),(-20,-17),(-22,-22))
    a.oval(base,-24,-24,-21,-21)
    for x in (-11,-5,5,10):
        st=step if x in (-11,5) else -step
        a.p(INK,(x-2,-12),(x+3,-12),(x+st+3,-4),(x+st+5,0),(x+st-2,0),(x+st-3,-5))
        a.p(base,(x-1,-11),(x+2,-11),(x+st+2,-4),(x+st+3,-1),(x+st-1,-1))
    a.p(INK,(-17,-13),(-13,-22),(0,-24),(9,-19),(10,-11),(1,-8),(-11,-8))
    a.p(light,(-16,-13),(-12,-21),(0,-23),(8,-19),(9,-12),(0,-9),(-11,-9))
    a.p(hi,(-13,-18),(-10,-21),(-2,-22),(0,-19),(-6,-17),(-12,-16))
    a.p(INK,(0,-26),(4,-30),(9,-29),(13,-25),(14,-18),(11,-12),(4,-10),(0,-15),(-3,-19))
    a.p(base,(1,-26),(4,-29),(9,-28),(12,-25),(13,-18),(10,-13),(4,-11),(1,-15),(-2,-19))
    a.line(light,(2,-26),(4,-27),(7,-26))
    a.p(INK,(8,-25),(12,-28),(14,-25),(15,-23),(18+action,-22),(19+action,-19),(15,-16),(10,-17))
    a.p(light,(9,-25),(12,-26),(13,-24),(14,-22),(17+action,-21),(17+action,-19),(14,-17),(11,-18))
    a.p(hi,(14,-21),(17+action,-21),(17+action,-19),(14,-18),(12,-19))
    a.dot(INK,13,-23)
    a.dot("#f4d484",12,-23)


def relic(a,kind,palette,step,action,frame):
    base,hi,pale=palette
    if kind=="wisp":
        a.p(INK,(-9,-9),(-7,-22),(-5,-29),(-1,-34),(5,-34),(4,-30),(8,-25),
                   (7,-20),(11,-16),(8,-4),(3,0),(-4,-3))
        a.p(base,(-8,-9),(-6,-22),(-4,-28),(0,-32),(4,-33),(2,-29),(7,-24),(6,-19),
                   (10,-15),(7,-5),(2,-1),(-4,-4))
        a.p(hi,(-6,-12),(-3,-21),(1,-23),(4,-20),(4,-16),(8,-14),(5,-6),(-2,-7))
        a.p(pale,(-2,-15),(0,-19),(4,-16),(4,-10),(0,-8),(-3,-10))
        a.dot(pale,-6+frame,-26)
    elif kind=="book":
        b=4+step
        a.p(INK,(-17,-19-b),(-7,-23-b),(0,-13),(8,-21-b),(17,-18-b),
                   (15,-8),(1,0),(-14,-6))
        a.p(base,(-16,-19-b),(-8,-22-b),(0,-12),(8,-20-b),(16,-17-b),(14,-8),(0,-1),(-14,-7))
        a.p(pale,(-14,-18-b),(-7,-20-b),(0,-11),(-1,-3),(-13,-8))
        a.p(hi,(1,-11),(8,-18-b),(14,-16-b),(13,-9),(1,-3))
        a.line(base,(-11,-16-b),(-8,-16-b),(-4,-13))
        a.line(base,(4,-11),(7,-13),(11,-14))
        a.dot(pale,0,-14-action)
    elif kind=="gear":
        coords=[]
        for i in range(10):
            angle=i*tau/10+frame*.28
            for r,offset in ((13,-.24),(16,-.16),(16,.16),(13,.24)):
                coords.append((r*cos(angle+offset),-17+r*sin(angle+offset)))
        a.p(INK,*[(x*1.04,-17+(y+17)*1.04) for x,y in coords])
        a.p(base,*coords)
        a.oval(hi,-10,-27,10,-7)
        a.oval(base,-8,-25,8,-9)
        a.oval(INK,-5,-22,5,-12)
        jewel(a,hi,pale,0,-17,3)
    else:
        a.p(INK,(-17,-13),(-15,-19),(-10,-21),(10,-21),(15,-18),(18,-14),
                 (16,-9),(11,-9),(7,-5),(5,0),(-5,0),(-8,-6),(-14,-7))
        a.p(base,(-16,-13),(-14,-18),(-9,-20),(9,-20),(14,-17),(17,-14),
                  (15,-10),(10,-10),(6,-6),(4,-1),(-4,-1),(-8,-7),(-13,-8))
        a.p(hi,(-13,-17),(-7,-20),(6,-19),(13,-17),(10,-14),(-6,-14))
        a.p(INK,(-7,-15),(10,-15),(12,-12),(9,-9),(-6,-9))
        a.line(pale,(4,-13),(10,-13),width=2)
        a.line(hi,(-3,-4),(3,-4),width=2)
        if action:
            a.dot(pale,13,-10)


def wanderer(a,c,step,action):
    base,light,hi=c
    for step_x in (-5-step,5+step):
        a.p(INK,(step_x-3,-11),(step_x+3,-11),(step_x+3,-4),(step_x+5,0),(step_x-4,0))
        a.p(base,(step_x-2,-10),(step_x+2,-10),(step_x+3,-2),(step_x-3,-1))
    a.p(INK,(-10,-18),(-8,-27),(-4,-32),(3,-34),(9,-30),(11,-24),
             (9,-17),(13+action,-14),(11+action,-9),(6,-11),(5,-8),(-7,-8))
    a.p(base,(-9,-18),(-7,-27),(-3,-31),(3,-33),(8,-30),(10,-24),
              (8,-16),(12+action,-14),(11+action,-10),(6,-12),(5,-9),(-6,-9))
    a.p(light,(-8,-21),(-6,-27),(-2,-30),(0,-27),(1,-20),(-1,-15),(-5,-14))
    a.p("#47394c",(1,-28),(7,-28),(8,-24),(6,-21),(1,-22))
    a.line(hi,(4,-25),(6,-25),width=2)
    a.line(hi,(-5,-18),(3,-16),(6,-13))
    a.dot(light,3,-10)


def frame(kind, size, row, col, field=False, front=False):
    if kind == "boss_shasta":
        return shasta_frame(row, col, front)
    image=Image.new("RGBA",(size,size))
    _,height,width,palette=DATA[kind]
    step = (0,-1,1,0)[col] if row==1 else 0
    attack = (0,3,5,2)[col] if row==3 else 0
    gain = ((0,1,1,0),(1,0,1,0),(-2,-3),(-1,2,1,0),(-2,-1),(-4,-7,-8))[row][col]
    shift = ((0,0,0,0),(-1,0,1,0),(-2,-3),(-1,2,3,1),(-2,-1),(-1,0,0))[row][col]
    grounded=kind not in ("wisp","book","drone")
    if field:
        height=min(size-3, round(height*.82) if front else height)
        shift=0
    if row==5 and col>0:
        # ダウン時は足元を維持したまま、横に崩れていく。
        d=ImageDraw.Draw(image)
        x=size//2
        half=min(size//2-2,max(5,round(height*.4)))
        y=size-1
        d.polygon([(x-half,y),(x-half+2,y-5),(x-half+6,y-8),(x,y-7),
                   (x+half-3,y-9+col),(x+half,y-3),(x+half-2,y)],fill=INK)
        d.polygon([(x-half+2,y-1),(x-half+4,y-5),(x-2,y-7),(x+half-3,y-7+col),
                   (x+half-1,y-3),(x+half-3,y-1)],fill=palette[0])
        d.line((x-3,y-5,x+half-3,y-5),palette[1])
        d.point((x+half-4,y-4),palette[2])
        return image
    art_h=max(4,height+gain)
    sx = width * (.80 if size==24 else .98 if size==32 else 1.15)
    if kind=="lion":
        sx *= .61
    elif kind in ("wisp","book","gear","drone"):
        sx *= .64
    if front:
        sx *= 1.16
    y = size-1-(int(not grounded) if field else 0)
    a=Brush(image,(size//2-1+shift,y),sx,art_h/(40 if grounded else 35),
            0 if front else -.04 if row==2 else .085 if row==3 and col in (1,2) else 0)
    if kind in ("oni","boss_oni"):
        oni(a,kind,palette,step,attack,front)
    elif kind=="boss_siren":
        siren(a,palette,step,attack,front)
    elif kind=="lion":
        lion(a,palette,step,attack)
    elif kind=="ikei":
        wanderer(a,palette,step,attack)
    elif kind in ("wisp","book","gear","drone"):
        relic(a,kind,palette,step,attack,col)
    else:
        clothes(a,kind,palette,step,attack,front)
    return image


def save(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    with path.open("xb") as fh:
        data.save(fh,"PNG",optimize=True)


def main():
    root=Path(sys.argv[1])
    for kind,(size,*_) in DATA.items():
        image=Image.new("RGBA",(size*8,size*6))
        for row,count in enumerate(ENEMY_COUNTS):
            for col in range(count):
                image.paste(frame(kind,size,row,col),(col*size,row*size))
        save(root/"battle"/(kind+".png"),image)
        boss=kind.startswith("boss_")
        n=48 if boss else 24
        image=Image.new("RGBA",(n*2,n))
        for col in range(2):
            image.paste(frame(kind,n,0,col,True,boss),(col*n,0))
        save(root/"field"/((kind if boss else "sym_"+kind)+".png"),image)


if __name__ == "__main__":
    main()
