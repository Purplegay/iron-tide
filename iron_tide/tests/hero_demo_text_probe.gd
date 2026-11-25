extends "res://scripts/ui/hero_talent_demo.gd"
var drawn_text:Array=[]

func _draw_demo() -> void:
	drawn_text.clear()
	super._draw_demo()

func _text(pos:Vector2,text:String,ink:=Color.WHITE) -> void:
	drawn_text.append({"position":pos,"text":text,"ink":ink})
	super._text(pos,text,ink)
