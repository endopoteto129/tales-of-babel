"""ゲームのデータ（data/*.gd）から、シナリオ台本（プロジェクト直下の シナリオ台本.xlsx）を作る。

  python art_src/scenario/export_scenario.py

※ 台本を書き換えたあとにこれを実行すると、書き換えが消えます。
  先に import_scenario.py でゲームへ反映してから実行してください。
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scenario_lib as L
from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill, Border, Side
from openpyxl.worksheet.datavalidation import DataValidation

CHAT_EVENTS = {
    "start": "戦闘開始", "start_boss": "ボス戦開始", "low_hp": "仲間のHPが減った", "pinch": "ピンチ",
    "ally_ko": "仲間が倒れた", "revive": "仲間が復活", "healed": "回復した", "big_combo": "大コンボ",
    "weak": "弱点を突いた", "kill": "敵を倒した", "break": "ブレイク", "link_ready": "共鳴秘技が使える",
    "link_used": "共鳴秘技を使った", "cheer": "ナインの応援", "boss_phase": "ボスが本気に", "victory": "勝利",
    "victory_boss": "ボスに勝利", "banter": "戦闘中の雑談", "item": "アイテム使用", "ovl_ready": "OVLが使える",
    "ovl": "オーバーリミッツ", "mystic_used": "秘奥義を使った",
}
COND_JP = {"floor": "層", "floor_min": "層以上", "floor_max": "層以下", "req": "必要", "who": "対象", "by": "行為者",
           "boss": "ボス", "flags": "フラグ", "not_flags": "非フラグ", "trigger": "きっかけ", "min_floor": "層以上",
           "max_floor": "層以下"}

HEAD = ["ID（触らない）", "場面", "話者", "表情", "本文", "演出", "メモ（ゲームには入らない）"]
WIDTH = [22, 30, 13, 10, 70, 14, 24]


def info(sheet, path, roots, chars):
    if sheet == "戦闘チャット":
        ev, idx = path[1], path[2]
        c = L.lookup(roots, path)
        conds = []
        for k, v in c.items():
            if k == "lines":
                continue
            if isinstance(v, list):
                v = "・".join(chars.get(x, x) for x in v)
            conds.append("%s:%s" % (COND_JP.get(k, k), chars.get(v, v) if isinstance(v, str) else v))
        return "%s %d%s" % (CHAT_EVENTS.get(ev, ev), idx + 1, ("（" + " ".join(conds) + "）") if conds else "")
    if sheet == "イベント":
        ev = L.lookup(roots, path[:2])
        ch = L.lookup(roots, path[:4])
        tail = {"success": "（成功）", "fail": "（失敗）"}.get(path[-1], "")
        return "%s ／ %s%s" % (ev.get("title", ""), ch.get("text", ""), tail)
    d = L.lookup(roots, path)
    s = d.get("title", "") if isinstance(d, dict) else ""
    if sheet == "スキット":
        conds = []
        for k in ["trigger", "floor", "min_floor", "max_floor", "req"]:
            if k in d:
                v = d[k]
                if isinstance(v, list):
                    v = "・".join(chars.get(x, x) for x in v)
                conds.append("%s:%s" % (COND_JP.get(k, k), v))
        if conds:
            s += "（" + " ".join(conds) + "）"
    return s


def main():
    chars = L.characters()
    wb = Workbook()
    wb.remove(wb.active)
    howto = wb.create_sheet("使い方")
    for r, line in enumerate([
        "テイルズオブバベル シナリオ台本",
        "",
        "■ 書き換え：「本文」「話者」「表情」のセルを書き換える",
        "■ 差し込み：行を挿入して書く。「ID」は空のままでよい（すぐ上の行と同じ場面になる）",
        "■ 削除：行ごと削除する（1つの場面の行を全部消すと、その場面は空になるので注意）",
        "■ 並べ替え：同じ場面の中なら、行を切り取って挿入すれば順番が変わる",
        "",
        "・「ID」列は、どの場面の台詞かを表す名前です。書き換えないでください。",
        "・「話者」と「表情」は、セルを選ぶと出る ▼ の一覧から選べます。地の文は「ナレーション」です。",
        "・「演出」列に何か入っている行は、台詞ではなく演出の命令です（背景の切り替えなど）。",
        "   引数は「本文」に、複数あるときは ｜ で区切って書きます。わからなければ触らないでください。",
        "・「メモ」列は自由に使えます。ゲームには入りません。",
        "・戦闘チャットは表情を使いません（吹き出しだけ）。",
        "",
        "■ ゲームへの反映",
        "  保存して Excel を閉じてから、プロジェクトの「シナリオを反映.bat」をダブルクリック。",
        "  または Claude / Codex に「シナリオ台本を反映して」と頼んでください。",
        "  名前や表情の書き間違いがあると、どのシートの何行目かを表示して止まります（ゲームは変わりません）。",
    ], 1):
        howto.cell(row=r, column=1, value=line)
    howto["A1"].font = Font(size=16, bold=True)
    howto.column_dimensions["A"].width = 110

    speaker_list = [L.NARRATION] + list(chars.values())
    lists = wb.create_sheet("一覧")
    for i, n in enumerate(speaker_list, 1):
        lists.cell(row=i, column=1, value=n)
    for i, (_, jp) in enumerate(L.EXPRS, 1):
        lists.cell(row=i, column=2, value=jp)
    for i, (d, jp) in enumerate(L.DIRECTIVES.items(), 1):
        lists.cell(row=i, column=3, value=d)
        lists.cell(row=i, column=4, value=jp)
    lists.sheet_state = "hidden"

    head_fill = PatternFill("solid", fgColor="3B2F4A")
    scene_fill = PatternFill("solid", fgColor="F3EEDD")
    dir_font = Font(color="7A7A7A", italic=True)
    top = Border(top=Side(style="thin", color="B8A77A"))
    for sheet, file, consts, prefix in L.SOURCES:
        text, found, roots = L.scan(file, consts)
        ws = wb.create_sheet(sheet)
        ws.append(HEAD)
        for c in range(1, len(HEAD) + 1):
            cell = ws.cell(row=1, column=c)
            cell.font = Font(bold=True, color="FFFFFF")
            cell.fill = head_fill
            ws.column_dimensions[cell.column_letter].width = WIDTH[c - 1]
        ws.freeze_panes = "C2"
        dv_sp = DataValidation(type="list", formula1="=一覧!$A$1:$A$%d" % len(speaker_list), allow_blank=True,
                               showErrorMessage=True, errorTitle="話者", error="一覧にない名前です。▼から選んでください。")
        dv_ex = DataValidation(type="list", formula1="=一覧!$B$1:$B$%d" % len(L.EXPRS), allow_blank=True,
                               showErrorMessage=True, errorTitle="表情", error="一覧にない表情です。▼から選んでください。")
        dv_dir = DataValidation(type="list", formula1="=一覧!$C$1:$C$%d" % len(L.DIRECTIVES), allow_blank=True)
        ws.add_data_validation(dv_sp)
        ws.add_data_validation(dv_ex)
        ws.add_data_validation(dv_dir)
        for path, s, e, lines in found:
            bid = L.block_id(prefix, path)
            first = True
            for ln in lines:
                sp = ln[0] if ln else ""
                if sp.startswith("@"):
                    row = [bid, "", "", "", L.ARG_SEP.join(str(a) for a in ln[1:]), sp, ""]
                else:
                    ex = ln[2] if len(ln) > 2 else ""
                    row = [bid, "", L.NARRATION if sp == "" else chars.get(sp, sp),
                           "" if sheet == "戦闘チャット" or (sp == "" and ex == "") else L.EXPR_TO_JP.get(ex, ex), ln[1] if len(ln) > 1 else "", "", ""]
                if first:
                    row[1] = info(sheet, path, roots, chars)
                ws.append(row)
                r = ws.max_row
                if first:
                    for c in range(1, len(HEAD) + 1):
                        ws.cell(row=r, column=c).border = top
                    ws.cell(row=r, column=2).fill = scene_fill
                    ws.cell(row=r, column=2).font = Font(bold=True)
                    first = False
                if sp.startswith("@"):
                    for c in (5, 6):
                        ws.cell(row=r, column=c).font = dir_font
                ws.cell(row=r, column=5).alignment = Alignment(wrap_text=True, vertical="top")
                ws.cell(row=r, column=2).alignment = Alignment(wrap_text=True, vertical="top")
                ws.cell(row=r, column=1).font = Font(color="999999", size=9)
        last = max(ws.max_row + 500, 2000)
        dv_sp.add("C2:C%d" % last)
        if sheet != "戦闘チャット":
            dv_ex.add("D2:D%d" % last)
        dv_dir.add("F2:F%d" % last)
        ws.auto_filter.ref = "A1:G%d" % ws.max_row
    wb.save(L.XLSX)
    print("書き出しました:", L.XLSX)


if __name__ == "__main__":
    main()
