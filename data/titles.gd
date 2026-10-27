# 称号データ。char が "" の称号は条件を満たした時点のパーティ全員に付与。
# bonus は装備中に加算されるステータス。
extends RefCounted

const DATA := {
	# ---------- 共通 ----------
	"climber": {"name": "塔に挑む者", "char": "", "desc": "バベルの塔に足を踏み入れた証。全てはここから始まる。", "bonus": {"hp": 20}},
	"first_victory": {"name": "初陣", "char": "", "desc": "塔の中で初めての戦闘に勝利した。", "bonus": {"atk": 2}},
	"floor1": {"name": "草原を越えし者", "char": "", "desc": "第一層を踏破した。エレベーターの乗り心地は最悪だった。", "bonus": {"def": 3}},
	"floor2": {"name": "異形の隣人", "char": "", "desc": "第二層を踏破した。見た目で判断してはいけないと学んだ。", "bonus": {"mdef": 4}},
	"floor3": {"name": "月下の旅人", "char": "", "desc": "第三層を踏破した。竹林の月は、少しだけ寂しかった。", "bonus": {"agi": 3}},
	"floor4": {"name": "反逆者", "char": "", "desc": "塔の真実を知り、王国に背いた。もう後戻りはできない。", "bonus": {"atk": 4, "matk": 4}},
	"floor5": {"name": "記憶の守り手", "char": "", "desc": "第五層を踏破した。書庫の本は、誰かの『認識』の欠片だった。", "bonus": {"mdef": 5}},
	"floor6": {"name": "絶対に等しいもの", "char": "", "desc": "裏切りを越えて、なお前へ進んだ。", "bonus": {"hp": 80}},
	"combo20": {"name": "連撃の申し子", "char": "", "desc": "20ヒット以上のコンボを決めた。手が勝手に動く。", "bonus": {"agi": 3}},
	"combo50": {"name": "止まらない男たち", "char": "", "desc": "50ヒット以上のコンボを決めた。ナインが数えきれなくなった。", "bonus": {"atk": 5}},
	"link_first": {"name": "心ひとつに", "char": "", "desc": "初めて共鳴秘技を放った。言葉はいらなかった。", "bonus": {"atk": 3, "matk": 3}},
	"campfire5": {"name": "焚火の語り部", "char": "", "desc": "焚火を囲んで5回語り合った。夜更かしは旅の醍醐味。", "bonus": {"tp": 10}},
	"rich": {"name": "小金持ち", "char": "", "desc": "所持金が2000ガルドを超えた。財布の紐はソナが握っている。", "bonus": {"agi": 2}},
	"no_damage": {"name": "無傷の勝利", "char": "", "desc": "誰もダメージを受けずに戦闘に勝利した。完璧な連携。", "bonus": {"def": 3}},
	# ---------- レン ----------
	"ren_soldier": {"name": "王国軍幹部", "char": "ren", "desc": "若くして国王軍の幹部に名を連ねる兵士。本人は肩書きに興味がない。", "bonus": {"atk": 3}},
	"ren_redman": {"name": "レッドマン（仮）", "char": "ren", "desc": "ナインにヒーローと呼ばれた。赤いマントは持っていない。", "bonus": {"hp": 50}},
	"ren_guardian": {"name": "小さな手を握る者", "char": "ren", "desc": "ナインを守り抜いた。今度こそ、と心に決めて。", "bonus": {"def": 5}},
	"ren_hero": {"name": "絶対のヒーロー", "char": "ren", "desc": "絶対なんてない。それでも、この子の前でだけは。", "bonus": {"atk": 10, "def": 10}},
	# ---------- アンジー ----------
	"angie_otaku": {"name": "魔術オタク", "char": "angie", "desc": "魔術について語らせると三時間は止まらない。", "bonus": {"matk": 4}},
	"angie_turncoat": {"name": "手のひら返しの達人", "char": "angie", "desc": "魔術資料の山に釣られて宿敵の作戦に乗った。後悔はしていない。", "bonus": {"tp": 15}},
	"angie_prince": {"name": "白馬の王子様待ち", "char": "angie", "desc": "本物の王子を目の前にしても信じなかった。", "bonus": {"mdef": 4}},
	"angie_guts": {"name": "大義なき魔術師", "char": "angie", "desc": "大義なんかなくたって、守りたいものがあれば十分。", "bonus": {"matk": 10}},
	# ---------- ソナ ----------
	"sona_researcher": {"name": "自称研究員", "char": "sona", "desc": "塔の調査をしているらしい。らしい。", "bonus": {"atk": 3}},
	"sona_purse": {"name": "財布番", "char": "sona", "desc": "パーティの財布を握る。無駄遣いは許さない。", "bonus": {"agi": 3}},
	"sona_sister": {"name": "弟の誇り", "char": "sona", "desc": "過去と向き合い、自分の意志で引き金を引いた。", "bonus": {"atk": 8, "matk": 8}},
	# ---------- ジン ----------
	"jin_liar": {"name": "胡散臭いお兄さん", "char": "jin", "desc": "全て本心なのに誰も信じてくれない。糸目のせいだろうか。", "bonus": {"agi": 3}},
	"jin_cursed": {"name": "正直者の呪い", "char": "jin", "desc": "嘘をつくと死ぬほど苦しむ。お世辞も言えない。", "bonus": {"hp": 40}},
	"jin_author": {"name": "物語の記し手", "char": "jin", "desc": "この旅を書き留めている。題名はもう決めてある。", "bonus": {"matk": 6, "atk": 6}},
	# ---------- ジョン ----------
	"john_gladiator": {"name": "伝説の剣闘士", "char": "john", "desc": "コロシアムで無敗を誇った奴隷。観客の歓声はもう聞きたくない。", "bonus": {"atk": 4}},
	"john_bigbro": {"name": "でっかい兄ちゃん", "char": "john", "desc": "ナインに肩車をせがまれ続けている。", "bonus": {"def": 4}},
	"john_brother": {"name": "迎えに来た兄", "char": "john", "desc": "遅すぎた約束。それでも、最後に抱きしめた。", "bonus": {"hp": 120, "atk": 6}},
}
