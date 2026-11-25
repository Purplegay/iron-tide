extends SceneTree

var failed:=0
var checks:=0

func check(ok:bool,what:String) -> void:
	checks+=1
	if not ok:
		failed+=1
		push_error(what)

func _initialize() -> void:
	call_deferred("exercise")

func exercise() -> void:
	if not OS.get_user_data_dir().contains("CodexIronTideValidation"):quit(2);return
	var e=root.get_node("Expedition")
	check(e.start("美国","",8312) and e.choose(0),"new camp")
	var run:Dictionary=e.state.duplicate(true)
	run.stage=2
	e.open_event(run)
	run.event.choices=[{"label":"intel","cost":0,"item":{"kind":"refresh_token","id":"refresh_token"}},{"label":"supplies","cost":0,"item":{"kind":"supplies","id":"bonus","amount":100}}]
	run.supplies=0
	check(e.commit(run) and e.resolve_event(0),"claim intel")
	check(e.load_run() and e.free_shelf_purchase(e.state),"coupon persists on reload")
	check(not e.service("kit") and e.free_shelf_purchase(e.state),"kit service still costs supplies")
	check(e.refresh_shop() and e.state.free_refresh==1,"store free roll first")
	check(e.refresh_shop() and e.state.free_refresh==0 and e.refresh_price()==10,"extra free roll second")
	check(not e.buy(-1) and e.free_shelf_purchase(e.state),"failed purchase preserves coupon")
	var later:Dictionary=e.state.duplicate(true)
	later.stage+=1
	check(not e.free_shelf_purchase(later),"coupon expires next stage")
	var slot:=-1
	for i in e.state.shop.size():
		if e.purchase_problem(e.state,i).is_empty() and e.state.shop[i].price>0:slot=i;break
	check(slot>=0 and e.buy(slot),"buy with zero supplies")
	check(e.state.supplies==0 and not e.free_shelf_purchase(e.state),"first purchase consumed once")
	var blocked:=false
	for i in e.state.shop.size():
		if e.purchase_problem(e.state,i).contains("补给不足"):blocked=not e.buy(i);break
	check(blocked,"second purchase needs funds")
	print("INTEL checks=",checks," failed=",failed)
	quit(0 if failed==0 else 1)
