# 静的データへの窓口
extends Node

const Characters := preload("res://data/characters.gd")
const Artes := preload("res://data/artes.gd")
const Enemies := preload("res://data/enemies.gd")
const Floors := preload("res://data/floors.gd")
const Buffs := preload("res://data/buffs.gd")
const Items := preload("res://data/items.gd")
const Titles := preload("res://data/titles.gd")
const SkillTree := preload("res://data/skilltree.gd")
const Skits := preload("res://data/skits.gd")
const Chats := preload("res://data/chats.gd")
const Events := preload("res://data/events.gd")
const Story := preload("res://data/story.gd")
const Links := preload("res://data/links.gd")
const Mystics := preload("res://data/mystics.gd")
const Finishers := preload("res://data/finishers.gd")
const Callouts := preload("res://data/callouts.gd")
const Tutorials := preload("res://data/tutorials.gd")

const ELEMENT_NAME := {"fire": "火", "ice": "氷", "wind": "風", "thunder": "雷", "light": "光", "earth": "地"}


func chara(id: String) -> Dictionary:
	return Characters.DATA[id]


func cname(id: String) -> String:
	if Characters.DATA.has(id):
		return Characters.DATA[id]["name"]
	return id


func ccolor(id: String) -> Color:
	if Characters.DATA.has(id):
		return Characters.DATA[id]["color"]
	return Color(0.7, 0.7, 0.7)


func arte(id: String) -> Dictionary:
	return Artes.DATA[id]


func enemy(id: String) -> Dictionary:
	return Enemies.DATA[id]


func floor_data(f: int) -> Dictionary:
	return Floors.DATA[clampi(f - 1, 0, Floors.DATA.size() - 1)]


func floor_count() -> int:
	return Floors.DATA.size()


func buff(id: String) -> Dictionary:
	return Buffs.DATA[id]


func item(id: String) -> Dictionary:
	return Items.DATA[id]


func title(id: String) -> Dictionary:
	return Titles.DATA[id]


func tree(cid: String) -> Array:
	return SkillTree.DATA.get(cid, [])


func tree_node(cid: String, nid: String) -> Dictionary:
	for n in tree(cid):
		if n["id"] == nid:
			return n
	return {}


func link_for(a: String, b: String) -> Dictionary:
	var key = pair_key(a, b)
	return Links.DATA.get(key, {})


func pair_key(a: String, b: String) -> String:
	return a + "+" + b if a < b else b + "+" + a
