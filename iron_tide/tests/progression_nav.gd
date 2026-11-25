extends Node
func _ready() -> void:
	if not OS.get_user_data_dir().contains("ProgressNavValidation"):
		get_tree().quit(2);return
	MetaProgress.currency.cores=300
	MetaProgress.academy.expedition_research={}
	for pair in [["expedition_research","expedition"],["skill_draw","pool"],["unit_training","units"]]:
		var menu=load("res://scenes/main.tscn").instantiate()
		add_child(menu)
		var caption:String={"expedition":"远征养成","pool":"技能抽卡","units":"单位养成"}[pair[1]]
		var shortcut=menu.find_children("*","Button",true,false).filter(func(button):return button.text==caption)[0]
		var connections:Array=shortcut.pressed.get_connections()
		assert(shortcut.icon!=null and connections[0].callable.get_bound_arguments()==["res://scenes/%s.tscn"%pair[0]])
		menu.free()
		var page=load("res://scenes/%s.tscn"%pair[0]).instantiate()
		add_child(page)
		assert(page._page==pair[1])
		assert(page.expedition_tab.icon!=page.pool_tab.icon and page.pool_tab.icon!=page.tab_units_btn.icon)
		if pair[1]=="expedition":
			var nodes=page.expedition_tree.find_children("*","Button",true,false)
			assert(nodes.size()==40)
			nodes[0].pressed.emit()
			assert(MetaProgress.balance("cores")==200 and MetaProgress.academy.expedition_research.army==1)
			assert(page.expedition_tree.find_children("*","Button",true,false)[0].text.contains("已研究"))
		page._set_page("tasks")
		assert(page.tasks.find_children("ResourceIcon","TextureRect",true,false).size()==1+page.tasks.TASKS.size())
		page._set_page("shop")
		assert(page.shop_body.find_children("ResourceIcon","TextureRect",true,false).size()>=10)
		page.free()
	print("PROGRESSION_NAV_PASS")
	get_tree().quit()
