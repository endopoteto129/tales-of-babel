"""シナリオ台本（プロジェクト直下の シナリオ台本.xlsx）の内容を、ゲームのデータ（data/*.gd）へ反映する。

  python art_src/scenario/import_scenario.py          # 反映する
  python art_src/scenario/import_scenario.py --check  # 間違いがないか調べるだけ

書き間違い（一覧にない話者・表情、知らない ID など）があれば、シートと行番号を表示して、何も書き換えずに止まる。
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scenario_lib as L
from openpyxl import load_workbook


def cell(v):
    if v is None:
        return ""
    if isinstance(v, float) and v.is_integer():
        v = int(v)
    return str(v).replace("\r\n", "\n").replace("\r", "\n").strip("\n")


def main():
    check_only = "--check" in sys.argv
    if not os.path.exists(L.XLSX):
        print("台本が見つかりません:", L.XLSX)
        sys.exit(1)
    chars = L.characters()
    name_to_id = {v: k for k, v in chars.items()}
    wb = load_workbook(L.XLSX)
    errors = []
    changed_files = {}
    total_changed = 0
    summary = []
    for sheet, file, consts, prefix in L.SOURCES:
        if sheet not in wb.sheetnames:
            errors.append("シート「%s」がありません" % sheet)
            continue
        ws = wb[sheet]
        # skits.gd のように 1 ファイルを 2 シートで扱うときは、先に直した内容の上から続ける
        if file in changed_files:
            text, found, roots = L.scan_text(changed_files[file], consts)
        else:
            text, found, roots = L.scan(file, consts)
        known = {L.block_id(prefix, path): (s, e, lines) for path, s, e, lines in found}
        blocks = {}
        order = []
        cur = None
        for r, row in enumerate(ws.iter_rows(min_row=2, values_only=True), 2):
            row = list(row) + [None] * 7
            bid, _scene, sp, ex, body, cmd = [cell(x) for x in row[:6]]
            if not any([bid, sp, ex, body, cmd]):
                continue
            if bid:
                cur = bid
            if cur is None:
                errors.append("%s %d行目: ID がありません（一番上の行には ID が必要です）" % (sheet, r))
                continue
            if cur not in known:
                errors.append("%s %d行目: 知らない ID「%s」です（ID 列は書き換えないでください）" % (sheet, r, cur))
                continue
            if cur not in blocks:
                blocks[cur] = []
                order.append(cur)
            if cmd:
                if cmd not in L.DIRECTIVES:
                    errors.append("%s %d行目: 演出「%s」はありません" % (sheet, r, cmd))
                    continue
                args = [a.strip() for a in body.split(L.ARG_SEP)] if body else []
                blocks[cur].append([cmd] + args)
                continue
            if sp == "" and body == "":
                continue
            if sp in ("", L.NARRATION):
                sid = ""
            elif sp in name_to_id:
                sid = name_to_id[sp]
            elif sp in chars:
                sid = sp
            else:
                errors.append("%s %d行目: 話者「%s」は一覧にありません" % (sheet, r, sp))
                continue
            if ex in L.JP_TO_EXPR:
                e = L.JP_TO_EXPR[ex]
            elif ex in L.EXPR_TO_JP:
                e = ex
            else:
                errors.append("%s %d行目: 表情「%s」は一覧にありません" % (sheet, r, ex))
                continue
            if body == "":
                errors.append("%s %d行目: 本文が空です" % (sheet, r))
                continue
            blocks[cur].append([sid, body, e] if e else [sid, body])
        # 置き換え（後ろから）
        edits = []
        for bid, (s, e, lines) in known.items():
            new = blocks.get(bid, [])
            if _same(new, lines):
                continue
            if not new:
                summary.append("  ・%s「%s」の台詞がすべて消えています" % (sheet, bid))
            edits.append((s, e, _format(text, s, e, new)))
        if edits:
            total_changed += len(edits)
            summary.append("%s：%d 場面を更新" % (sheet, len(edits)))
            for s, e, rep in sorted(edits, reverse=True):
                text = text[:s] + rep + text[e:]
            changed_files[file] = text
    if errors:
        print("台本に直すところがあります（ゲームのデータは変えていません）：")
        for e in errors[:60]:
            print("  " + e)
        if len(errors) > 60:
            print("  ほか %d 件" % (len(errors) - 60))
        sys.exit(1)
    if not changed_files:
        print("変更はありませんでした。")
        return
    print("\n".join(summary))
    if check_only:
        print("（--check なので書き換えていません）")
        return
    for file, text in changed_files.items():
        open(os.path.join(L.ROOT, file), "w", encoding="utf-8", newline="\n").write(text)
    print("反映しました（%d 場面）。Godot で実行すると新しい台詞になります。" % total_changed)


def _same(new, old):
    def norm(l):
        l = [str(x) for x in l]
        if not l[0].startswith("@") and len(l) == 3 and l[2] == "":
            l = l[:2]
        return l
    return [norm(x) for x in new] == [norm(x) for x in old]


def _item(l):
    return "[" + ", ".join(L.gd_str(str(x)) for x in l) + "]"


def _format(text, s, e, lines):
    orig = text[s:e]
    if "\n" not in orig:
        return "[" + ", ".join(_item(l) for l in lines) + "]"
    first_nl = orig.index("\n")
    j = first_nl + 1
    while orig[j] in " \t":
        j += 1
    inner = orig[first_nl + 1:j]
    last_nl = orig.rindex("\n")
    close = orig[last_nl + 1:-1]
    if not lines:
        return "[]"
    return "[" + "".join("\n" + inner + _item(l) + "," for l in lines) + "\n" + close + "]"


if __name__ == "__main__":
    main()
