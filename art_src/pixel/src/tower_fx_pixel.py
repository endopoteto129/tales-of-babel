"""攻撃・回復・飛び道具のグレースケールスプライト。色は戦闘側で重ねる。"""
from math import cos, pi, sin, sqrt, tau
from pathlib import Path
from random import Random
import sys

from PIL import Image, ImageDraw


SIZES = {
    "crit": (32, 5), "heal": (32, 6), "buff": (24, 6), "break": (48, 6),
    "ring": (32, 5), "guard": (24, 3), "dust": (16, 4),
    "proj_wave": (16,4), "proj_orb": (12,4), "proj_bullet": (8,2),
    "proj_lance": (24,4), "proj_rock": (16,4), "proj_gear": (16,4),
    "aoe_pillar": (32,6), "aoe_burst": (32,6), "aoe_spikes": (32,6),
    "aoe_storm": (32,6), "aoe_quake": (32,6), "aoe_wave": (32,6),
    "aoe_meteor": (32,6),
}

WHITE="#fff"
LIGHT="#ccc"
MID="#999"
DARK="#666"


def star(d,x,y,r,f=WHITE):
    if r<=1:
        d.point((x,y),f)
        return
    d.polygon([(x,y-r),(x+1,y-1),(x+r,y),(x+1,y+1),
               (x,y+r),(x-1,y+1),(x-r,y),(x-1,y-1)],f)


def ring(d, x, y, rx, ry, color=LIGHT, width=1):
    d.ellipse((round(x-rx),round(y-ry),round(x+rx),round(y+ry)),outline=color,width=width)


def polar(x,y,r,a):
    return round(x+r*cos(a)),round(y+r*sin(a))


def gear(d,x,y,r,count,phase):
    teeth=[]
    for i in range(count):
        theta=i*tau/count+phase
        teeth += [polar(x,y,r-2,theta-.27),polar(x,y,r,theta-.21),
                  polar(x,y,r,theta+.21),polar(x,y,r-2,theta+.27)]
    d.polygon(teeth,fill=MID,outline=DARK)
    ring(d,x,y,r-2,r-2,LIGHT)
    d.ellipse((x-2,y-2,x+2,y+2),fill=DARK)
    d.point((x-1,y-1),WHITE)


def basic(kind,d,n,f,frames):
    x=(n-1)/2
    y=x
    t=(f+1)/frames
    rng=Random(78)
    if kind in ("crit","break"):
        rays=10 if kind=="crit" else 14
        for i in range(rays):
            a=rng.random()*.33+i*tau/rays
            near=2+round(t*n*.21)
            far=near+round((1-t)*n*.30)+2+i%3
            u,v=polar(x,y,near,a),polar(x,y,far,a)
            if kind=="crit":
                d.line((u,v),WHITE if f<2 else LIGHT,2 if f==1 and i%2==0 else 1)
            else:
                d.polygon([v,polar(x,y,far-4,a-.16),u,polar(x,y,far-3,a+.12)],
                          fill=(LIGHT,WHITE,MID)[i%3])
        if f<2:
            star(d,round(x),round(y),n//5-f,LIGHT)
            star(d,round(x),round(y),n//7-f,WHITE)
    elif kind in ("heal","buff"):
        for i in range(11):
            theta=i*2.4+t*4
            px=round(x+(n*.26+i%4)*cos(theta))
            py=round((n-2-(i*5+f*3)% (n-5)))
            if kind=="heal":
                r=1+(i+f)%3
                star(d,px,py,r,WHITE if i%2 else LIGHT)
            else:
                d.line((px,py,px,py-3-i%3),LIGHT)
                star(d,px,py-4,1+i%2,WHITE)
        ring(d,x,n-5-t*4,n*.38,.7+t,MID)
    elif kind=="ring":
        r=3+round(t*n*.37)
        ring(d,x,y,r,r,WHITE if f<2 else LIGHT,2 if f<2 else 1)
        if f<4:
            ring(d,x,y,r-3,r-3,MID)
        for i in range(4):
            d.point(polar(x,y,r+1,i*tau/4+f*.3),WHITE)
    elif kind=="guard":
        r=n//3+f
        q=round(y)
        d.polygon([(5,q-r+2),(q,q-r-1),(n-5,q-r+2),(n-6,q+3),
                   (q,q+r),(6,q+3)],outline=LIGHT if f==2 else WHITE,width=2)
        star(d,q,q-2,4-f,WHITE)
        d.line((q-2,q+5,q,q+r-2),MID)
    elif kind=="dust":
        for i in range(5):
            px=round(x+(i-2)*(1+f*.5))
            py=n-4-(i%2)*2-f
            radius=max(1,3-f//2-i%2)
            d.ellipse((px-radius,py-radius,px+radius,py+1),fill=MID if f>1 else LIGHT)
            d.point((px,py-radius),WHITE if not f else LIGHT)


def projectile(kind,d,n,f):
    x=y=(n-1)//2
    m=f%3
    if kind=="proj_wave":
        d.polygon([(1,n-3),(5,n-6),(8,4+m),(12,1),(14,5),(13,n-5),(9,n-3)],fill=MID)
        d.polygon([(3,n-4),(7,n-7),(10,4+m),(12,2),(13,5),(12,n-6),(9,n-4)],fill=WHITE)
        d.line((3,n-2,9,n-2),LIGHT)
    elif kind=="proj_orb":
        r=3+f%2
        d.ellipse((x-r,y-r,x+r,y+r),fill=MID)
        d.ellipse((x-r+1,y-r+1,x+r-1,y+r-1),fill=LIGHT)
        d.ellipse((x-1,y-2,x+1,y+1),fill=WHITE)
        d.point(polar(x,y,r+1,f*pi/2),LIGHT)
    elif kind=="proj_bullet":
        d.polygon([(1,y-1),(5,y-1),(7,y),(5,y+1),(1,y+1)],fill=LIGHT)
        d.line((2+f,y-1,5,y-1),WHITE)
        d.point((0,y),MID)
    elif kind=="proj_lance":
        d.polygon([(1,y),(8,y-2),(12,y-4),(21,y),(12,y+4),(8,y+2)],fill=MID)
        d.polygon([(5,y),(13,y-3),(22,y),(13,y+2)],fill=LIGHT)
        d.line((7+f,y,20,y),WHITE,2)
    elif kind=="proj_rock":
        a=f*tau/4
        shape=[polar(x,y,r,a+i*tau/6) for i,r in enumerate((6,6,5,7,5,6))]
        d.polygon(shape,fill=MID,outline=DARK)
        d.polygon([shape[3],shape[4],shape[5],(x+1,y)],fill=LIGHT)
        d.line((shape[4],(x-1,y-1)),WHITE)
    else:
        gear(d,x,y,7,8,f*pi/16)


def area(kind,d,n,f,frames):
    t=f/(frames-1)
    x=round(n/2)-1
    shade=WHITE if f in (1,2,3) else LIGHT
    if kind=="aoe_pillar":
        width=[3,7,10,8,5,2][f]
        for j in range(-width,width+1,2):
            bot=n-2-((f+j)%3)
            h=4+round((1-abs(j/(width+1)))*(n-5))
            d.line((x+j,bot-h,x+j,bot),WHITE if abs(j)<width//2 else MID,2)
        ring(d,x,n-4,width+2,2,shade)
    elif kind=="aoe_burst":
        r=3+round(11*t)
        for i in range(9):
            a=i*tau/9+.37
            cx,cy=polar(x,n-12,r,a)
            q=max(1,4-f//2)
            d.ellipse((cx-q,cy-q,cx+q,cy+q),outline=MID if f>3 else LIGHT)
            if f<=2:
                d.ellipse((cx-q+1,cy-q+1,cx+q-1,cy+q-1),fill=shade)
        if f<3:
            star(d,x,n-12,5+f,WHITE)
    elif kind=="aoe_spikes":
        for i in range(5):
            px=4+i*6
            h=min(23,1+f*7-abs(i-2)*2) if f<4 else 24-(f-3)*4-abs(i-2)*3
            h=max(h,2)
            d.polygon([(px-3,n-2),(px-1,n-2-h),(px+1,n-5-h),(px+4,n-2)],fill=MID)
            d.polygon([(px-2,n-2),(px+1,n-5-h),(px+1,n-2)],fill=shade)
    elif kind=="aoe_storm":
        for i in range(4):
            yy=6+i*6
            r=11-i*2+f%2
            d.arc((x-r,yy-2,x+r,yy+2),start=(f*57+i*35)%360,
                  end=(f*57+i*35)%360+220,fill=shade,width=2)
        d.line([(21-f%3,3),(17,9),(22,9),(18,17)],LIGHT)
    elif kind=="aoe_quake":
        for i in range(4):
            yy=n-6-i*2
            l=4+f*2+i*2
            d.line([(x-l,yy),(x-l//2,yy-3),(x,yy+1),(x+l//2,yy-2),(x+l,yy)],
                   shade if i>1 else MID)
        for i in range(6):
            d.rectangle((3+i*5,n-7-(i+f)%5-f,4+i*5,n-6-(i+f)%5-f),fill=LIGHT)
    elif kind=="aoe_wave":
        for i in range(3):
            px=1+i*10
            up=3+f*2+(i+f)%3
            d.polygon([(px,n-3),(px+2,n-5-up),(px+6,n-9-up),
                       (px+9,n-9-up),(px+6,n-5-up),(px+9,n-3)],fill=MID)
            d.line([(px,n-5),(px+2,n-5-up),(px+6,n-9-up),(px+9,n-9-up)],shade)
    else:
        for i in range(4):
            px=7+i*7-f%2
            py=(f*5+i*6)%27
            d.line((px+5,py-9,px,py),MID,3)
            d.ellipse((px-2,py-2,px+2,py+2),fill=shade)
            d.point((px-1,py),WHITE)
        if f>2:
            ring(d,x,n-4,4+f*2,2,LIGHT)


def main():
    out=Path(sys.argv[1])/"fx"
    out.mkdir(parents=True,exist_ok=True)
    for kind,(n,frames) in SIZES.items():
        strip=Image.new("RGBA",(n*frames,n))
        for f in range(frames):
            frame=Image.new("RGBA",(n,n))
            d=ImageDraw.Draw(frame)
            if kind.startswith("proj_"):
                projectile(kind,d,n,f)
            elif kind.startswith("aoe_"):
                area(kind,d,n,f,frames)
            else:
                basic(kind,d,n,f,frames)
            strip.paste(frame,(f*n,0))
        with (out/(kind+".png")).open("xb") as fh:
            strip.save(fh,"PNG",optimize=True)


if __name__=="__main__":
    main()
