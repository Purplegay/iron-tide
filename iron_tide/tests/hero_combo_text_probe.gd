extends "res://scripts/ui/hero_combo_demo.gd"
var drawn_text:Array=[]
func _draw_demo() -> void:
	drawn_text.clear();super._draw_demo()
func _text(at:Vector2,text:String,color:=Color.WHITE) -> void:
	drawn_text.append({"at":at,"text":text});super._text(at,text,color)
