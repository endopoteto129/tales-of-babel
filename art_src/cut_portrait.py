# 立ち絵の白背景を透過して幅600にそろえる: python3 cut.py 出力先 入力...
from PIL import Image, ImageFilter
import numpy as np, sys
from scipy import ndimage
out_dir=sys.argv[1]
for f in sys.argv[2:]:
    a=np.asarray(Image.open(f).convert('RGB')).astype(np.int32)
    h,w,_=a.shape
    border=np.concatenate([a[0],a[-1],a[:,0],a[:,-1]])
    bg=np.median(border,axis=0)
    d=np.sqrt(((a-bg)**2).sum(2))
    lab,n=ndimage.label(d<28)
    edge=set(np.unique(np.concatenate([lab[0],lab[-1],lab[:,0],lab[:,-1]])))-{0}
    mask=np.isin(lab,list(edge))
    # 腕と胴のすき間など、閉じた背景（顔より下の大きいものだけ。白目を消さないように）
    pockets=(d<14)&~mask
    lab2,n2=ndimage.label(pockets)
    if n2:
        idx=range(1,n2+1)
        sizes=ndimage.sum(pockets,lab2,idx)
        cents=ndimage.center_of_mass(pockets,lab2,idx)
        big=[i for i,s,c in zip(idx,sizes,cents) if s>1500*(w/926)**2 and c[0]>0.35*h]
        mask|=np.isin(lab2,big)
    fg=ndimage.binary_opening(~mask,iterations=1)
    al=np.asarray(Image.fromarray((fg*255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.0))).astype(np.float32)/255
    rgb=a.astype(np.float32)
    m=(al>0.02)&(al<0.98)
    rgb[m]=np.clip((rgb[m]-bg*(1-al[m,None]))/al[m,None],0,255)
    o=Image.fromarray(np.dstack([rgb,al*255]).astype(np.uint8),'RGBA').resize((600,int(round(600*h/w))),Image.LANCZOS)
    o.save(out_dir+'/'+f.split('/')[-1])
