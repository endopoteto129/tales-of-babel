"""シナリオ台本（Excel）とゲームのデータファイル（data/*.gd）を行き来させるための共通部品。

data/story.gd などの const 定数の中から "lines": [...] を探し、
どの場面の台詞かを表す ID と、ファイル内の位置を取り出す。
"""
import os
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
XLSX = os.path.join(ROOT, "シナリオ台本.xlsx")

# (シート名, ファイル, 読む定数, ID の頭)
SOURCES = [
    ("本編", "data/story.gd", ["DATA", "AFTER_CREDITS"], "story"),
    ("スキット", "data/skits.gd", ["DATA"], "skit"),
    ("焚火の会話", "data/skits.gd", ["CAMP"], "camp"),
    ("戦闘チャット", "data/chats.gd", ["DATA"], "chat"),
    ("イベント", "data/events.gd", ["DATA"], "event"),
]

EXPRS = [("", "通常"), ("smile", "笑顔"), ("laugh", "大笑い"), ("angry", "怒り"), ("sad", "悲しみ"),
         ("cry", "泣き"), ("surprise", "驚き"), ("serious", "真剣"), ("cold", "冷たい"), ("think", "考える"),
         ("sweat", "汗"), ("blush", "照れ"), ("blank", "無表情")]
EXPR_TO_JP = dict(EXPRS)
JP_TO_EXPR = {jp: e for e, jp in EXPRS}
NARRATION = "ナレーション"
ARG_SEP = "｜"

DIRECTIVES = {
    "@title_card": "タイトル表示", "@bg": "背景", "@cg": "スチル", "@join": "仲間加入", "@leave": "退場",
    "@title": "称号", "@flag": "フラグ", "@unflag": "フラグ解除", "@buff": "加護", "@item": "アイテム",
    "@recipe": "レシピ", "@shake": "画面揺れ", "@flash": "フラッシュ", "@sfx": "効果音", "@clear": "立ち絵を消す",
    "@caption": "字幕",
}


def characters():
    """キャラID -> 名前（data/characters.gd から）"""
    text = open(os.path.join(ROOT, "data/characters.gd"), encoding="utf-8").read()
    out = {}
    for m in re.finditer(r'^\t"([a-z_0-9]+)": \{\s*"name": "([^"]+)"', text, re.M):
        out[m.group(1)] = m.group(2)
    return out


# ------------------------------------------------------------ GDScript の定数の簡易パーサ
class P:
    def __init__(self, s, i):
        self.s, self.i = s, i

    def ws(self):
        s = self.s
        while self.i < len(s):
            c = s[self.i]
            if c in " \t\r\n,":
                self.i += 1
            elif c == "#":
                while self.i < len(s) and s[self.i] != "\n":
                    self.i += 1
            else:
                break

    def value(self, path, found):
        self.ws()
        c = self.s[self.i]
        if c == "{":
            self.i += 1
            d = {}
            while True:
                self.ws()
                if self.s[self.i] == "}":
                    self.i += 1
                    return d
                key = self.value(path, found)
                self.ws()
                assert self.s[self.i] == ":", self.s[self.i - 30:self.i + 30]
                self.i += 1
                self.ws()
                start = self.i
                v = self.value(path + [key], found)
                d[key] = v
                if key == "lines" and self.s[start] == "[":
                    found.append((list(path), start, self.i, v))
        if c == "[":
            self.i += 1
            items = []
            n = 0
            while True:
                self.ws()
                if self.s[self.i] == "]":
                    self.i += 1
                    return items
                items.append(self.value(path + [n], found))
                n += 1
        if c == '"':
            j = self.i + 1
            buf = []
            while self.s[j] != '"':
                if self.s[j] == "\\":
                    nxt = self.s[j + 1]
                    buf.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(nxt, nxt))
                    j += 2
                else:
                    buf.append(self.s[j])
                    j += 1
            self.i = j + 1
            return "".join(buf)
        # 数値・true/false・Color(...) などは中身を見ずに飛ばす
        m = re.compile(r"[A-Za-z_0-9.\-+]+").match(self.s, self.i)
        self.i = m.end()
        if self.i < len(self.s) and self.s[self.i] == "(":
            depth = 0
            while True:
                ch = self.s[self.i]
                if ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
                    if depth == 0:
                        self.i += 1
                        break
                elif ch == '"':
                    self.value(path, [])
                    continue
                self.i += 1
        return m.group(0)


def scan(file, consts):
    """file の consts から lines ブロックを全部取り出す。[(path, start, end, lines)]"""
    return scan_text(open(os.path.join(ROOT, file), encoding="utf-8").read(), consts)


def scan_text(text, consts):
    found = []
    roots = {}
    for name in consts:
        m = re.search(r"^const %s := " % name, text, re.M)
        p = P(text, m.end())
        roots[name] = p.value([name], found)
    return text, found, roots


def lookup(roots, path):
    v = roots
    for k in path:
        v = v[k]
    return v


def block_id(prefix, path):
    # path 例: ["DATA", "f1_intro"] / ["DATA", "start", 3] / ["DATA", "e_x", "choices", 0, "result"]
    parts = [str(x) for x in path[1:]] if path[0] == "DATA" or path[0] == "CAMP" else [str(x) for x in path]
    return prefix + ":" + "/".join(parts)


def gd_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'
