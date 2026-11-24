"""Check assets/pixel/ against the pixel-art spec (assets/pixel/SPEC.md).

Usage (from the project root):  python art_src/pixel/check_pixel.py
Needs Pillow (pip install pillow). Prints OK / NG per file and a list of files not made yet.
"""
import os, sys
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "pixel")

# path -> (exact size) or ("strip", frame_w, frame_h, min_frames, max_frames)
SPEC = {}
for t in ["grass", "town", "bamboo", "colosseum", "library", "factory", "summit"]:
    SPEC[f"tiles/{t}.png"] = (128, 32)
    SPEC[f"battle_bg/{t}.png"] = (320, 180)
    SPEC[f"battle_bg/{t}_boss.png"] = ((320, 180), "optional")
for c in ["chara_ren", "npc_merchant", "npc_towner", "npc_ghost", "npc_librarian", "npc_robot"]:
    SPEC[f"field/{c}.png"] = (48, 96)
SPEC["field/chara_ren_cape.png"] = ((48, 96), "optional")
for c in ["chara_angie", "chara_nine"]:
    SPEC[f"field/{c}.png"] = ((48, 96), "optional")
SYM = ["slime", "bat", "wolf", "golem", "wisp", "ikei", "oni", "lion", "book", "gear",
       "soldier", "gunner", "drone", "mage_soldier"]
for e in SYM:
    SPEC[f"field/sym_{e}.png"] = (48, 24)
BOSS = ["beast", "siren", "oni", "nene", "val", "zone", "shasta"]
for b in BOSS:
    SPEC[f"field/boss_{b}.png"] = (96, 48)
SPEC["field/obj_chest.png"] = (32, 16)
SPEC["field/obj_campfire.png"] = (64, 16)
SPEC["field/obj_event.png"] = (64, 16)
for h in ["ren", "angie", "sona", "jin", "john"]:
    SPEC[f"battle/{h}.png"] = (384, 576)
SPEC["battle/ren_cape.png"] = ((384, 576), "optional")
SPEC["battle/nine.png"] = (256, 64)
SPEC["battle/pots.png"] = (96, 24)
CELL = {"golem": 48, "soldier": 48, "gunner": 48, "mage_soldier": 48,
        "boss_beast": 64, "boss_oni": 64, "boss_siren": 48, "boss_nene": 48,
        "boss_val": 48, "boss_zone": 48, "boss_shasta": 48}
for e in SYM + ["boss_" + b for b in BOSS]:
    c = CELL.get(e, 32)
    SPEC[f"battle/{e}.png"] = (c * 8, c * 6)
for k, s, n in [("spark", 24, 4), ("crit", 32, 5), ("heal", 32, 6), ("buff", 24, 6),
                ("break", 48, 6), ("ring", 32, 5), ("guard", 24, 3), ("dust", 16, 4)]:
    SPEC[f"fx/{k}.png"] = ("strip", s, s, 2, 12)
for k, s in [("wave", 16), ("orb", 12), ("bullet", 8), ("lance", 24), ("rock", 16), ("gear", 16)]:
    SPEC[f"fx/proj_{k}.png"] = ("strip", s, s, 1, 8)
for k in ["pillar", "burst", "spikes", "storm", "quake", "wave", "meteor"]:
    SPEC[f"fx/aoe_{k}.png"] = ("strip", 32, 32, 2, 12)

for k in ("beast_roar", "siren_song", "oni_moon", "nene_curse", "val_verdict",
          "zone_barrage", "shasta_chain", "shasta_light"):
    SPEC[f"fx/boss_{k}.png"] = (640, 80)


def check(path, rule):
    im = Image.open(path)
    errs = []
    if im.mode != "RGBA":
        im = im.convert("RGBA")
        if not path.replace("\\", "/").split("/")[-2] == "battle_bg":
            errs.append("透明がない（RGBAで保存してください）")
    w, h = im.size
    if isinstance(rule, tuple) and rule and rule[0] == "strip":
        _, fw, fh, lo, hi = rule
        if h != fh or w % fw != 0 or not (lo <= w // fw <= hi):
            errs.append(f"大きさ {w}x{h}：高さ{fh}、幅は{fw}の倍数（{lo}〜{hi}コマ）にしてください")
    else:
        if (w, h) != rule:
            errs.append(f"大きさ {w}x{h}：{rule[0]}x{rule[1]} にしてください")
    alphas = im.getchannel("A").tobytes()
    semi = sum(1 for a in alphas if 0 < a < 255)
    if semi and "battle_bg" not in path:
        errs.append(f"半透明のドットが {semi} 個（アンチエイリアスを消してください）")
    if "battle_bg" not in path and all(a == 255 for a in alphas):
        errs.append("背景が透明になっていない")
    if all(a == 0 for a in alphas):
        errs.append("何も描かれていない")
    colors = len(im.getcolors(1 << 20) or [])
    if colors > 256:
        errs.append(f"色数 {colors}（拡大した絵を縮めた可能性。ドット単位で描き直してください）")
    return errs

def main():
    ok = ng = 0
    missing = []
    for rel, rule in SPEC.items():
        opt = isinstance(rule, tuple) and len(rule) == 2 and rule[1] == "optional"
        if opt:
            rule = rule[0]
        p = os.path.join(ROOT, rel)
        if not os.path.exists(p):
            if not opt:
                missing.append(rel)
            continue
        errs = check(p, rule)
        if errs:
            ng += 1
            print(f"NG  {rel}\n    - " + "\n    - ".join(errs))
        else:
            ok += 1
            print(f"OK  {rel}")
    known = set(SPEC)
    for d, _, fs in os.walk(ROOT):
        for f in fs:
            if f.endswith(".png"):
                rel = os.path.relpath(os.path.join(d, f), ROOT).replace("\\", "/")
                if rel not in known:
                    print(f"??  {rel}（表にないファイル名です。ゲームは読みません）")
    print(f"\nOK {ok} / NG {ng} / 未作成 {len(missing)}")
    if missing:
        print("未作成: " + ", ".join(missing))
    sys.exit(1 if ng else 0)

if __name__ == "__main__":
    main()
