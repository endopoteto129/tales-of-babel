# 立ち絵の一覧を撮影する（xvfb で実行）
extends Node


func _ready() -> void:
	var main: Main = get_parent()
	main.busy = true
	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.22, 0.28)
	bg.size = Vector2(1280, 720)
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)
	layer.add_child(bg)
	var ids := ["ren", "angie", "sona", "jin", "john", "nine", "maria", "sister", "shasta", "nene", "val", "zone"]
	for i in range(ids.size()):
		var p := Portrait.new()
		p.size = Vector2(200, 300)
		p.position = Vector2(10 + (i % 6) * 212, 20 + (i / 6) * 350)
		bg.add_child(p)
		p.setup(ids[i])
		var l := Label.new()
		l.text = ids[i]
		l.position = p.position + Vector2(70, 305)
		bg.add_child(l)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://").path_join("../shots/gallery.png"))
	print("[gallery] done")
	get_tree().quit()
