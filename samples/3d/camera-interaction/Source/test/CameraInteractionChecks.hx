package test;

#if hxmaker_camera_checks
import hx.assets.ModelAsset;
import hx.controls3d.FollowCameraController3D;
import hx.controls3d.OrbitCameraController3D;
import hx.controls3d.Scene3DInput;
import hx.display3d.Camera3D;
import hx.display3d.MeshObject;
import hx.display3d.Node3D;
import hx.display.Quad;
import hx.display.Scene3D;
import hx.display.Stage;
import hx.events.Event;
import hx.events.MouseEvent;
import hx.events.Scene3DInputEvent;
import hx.events.TouchEvent;
import hx.geom.Point;
import hx.geom.Ray3D;
import hx.geom.Vector3D;
import hx.geometry.BoxGeometry;
import hx.material.UnlitTextureMaterial;
import hx.render3d.Raycaster3D;

/** 用户显式启用的数值与事件路由回归；不访问后端，不代替实际画面验收。 */
class CameraInteractionChecks {
	private static var checks:Int;
	public static function run(source:ModelAsset):Void {
		checks = 0; checkCamera(); checkQueries(source); checkInput();
		trace("HXMAKER_CAMERA_INTERACTION_CHECKS PASS 检查数："+checks);
	}
	private static function checkCamera():Void {
		var parent = new Node3D(), camera = new Camera3D(); parent.addChild(camera);
		parent.setPosition(7,2,-3); parent.rotationY = 37; parent.setScale(-2,1,0.5);
		var orbit = new OrbitCameraController3D(camera); orbit.yaw = 90; orbit.pitch = 0; orbit.distance = 4; orbit.damping = 0;
		var otherCamera = new Camera3D(), other = new OrbitCameraController3D(otherCamera);
		var target = new Node3D(), follow = new FollowCameraController3D(otherCamera,target);
		try {
			orbit.snap(); vectorNear(camera.getWorldPosition(),new Vector3D(4,0,0),"父节点变换下设置相机世界位置");
			var ray = camera.screenRay(100,50,200,100); near(ray.direction.x,-1,"环绕相机朝向目标"); near(ray.direction.z,0,"环绕相机射线方向");
			orbit.minDistance = 1; orbit.maxDistance = 5; orbit.zoomBy(100); orbit.rotate(0,200);
			near(orbit.distance,5,"距离上限"); near(orbit.pitch,80,"俯仰上限");
			expectFailure(function() { orbit.zoomBy(0); },"拒绝无效缩放");
			var initial = camera.getWorldPosition(); orbit.enabled = false; orbit.update(1); vectorNear(camera.getWorldPosition(),initial,"禁用控制器不移动相机");
			orbit.enabled = true; expectFailure(function() { orbit.update(-1); },"拒绝负 dt");
			camera.lookFrom(new Vector3D(0,0,4),new Vector3D()); otherCamera.lookFrom(new Vector3D(0,0,4),new Vector3D());
			orbit.minDistance = 0.2; orbit.maxDistance = 100; orbit.target.setTo(0,0,0); orbit.syncFromCamera(); other.syncFromCamera();
			for (control in [orbit,other]) { control.target.setTo(1,2,3); control.yaw = 60; control.pitch = 20; control.distance = 8; control.damping = 5; }
			orbit.update(0.2); other.update(0.1); other.update(0.1);
			vectorNear(camera.getWorldPosition(),otherCamera.getWorldPosition(),"固定目标下平滑与 dt 切分一致");
			var worldVersion = camera.worldVersion; orbit.damping = 0; orbit.snap(); camera.getWorldMatrix(); worldVersion = camera.worldVersion;
			orbit.update(0.1); camera.getWorldMatrix(); expect(camera.worldVersion == worldVersion,"已静止相机不重复失效");
			target.setPosition(2,0,1); follow.targetOffset.setTo(0,1,0); follow.yaw = 0; follow.pitch = 0; follow.distance = 4; follow.damping = 0; follow.snap();
			vectorNear(otherCamera.getWorldPosition(),new Vector3D(2,1,5),"跟随目标与世界偏移");
			target.x = 5; follow.update(0.1); vectorNear(otherCamera.getWorldPosition(),new Vector3D(5,1,5),"目标移动后相机跟随");
			expectFailure(function() { follow.targetNode = otherCamera; },"禁止相机跟随自身");
			initial = otherCamera.getWorldPosition(); target.dispose(); follow.update(0.1); vectorNear(otherCamera.getWorldPosition(),initial,"目标销毁后安全停止跟随");
		} catch (error:Dynamic) { orbit.dispose(); other.dispose(); follow.dispose(); parent.dispose(); otherCamera.dispose(); target.dispose(); throw error; }
		orbit.dispose(); other.dispose(); follow.dispose(); parent.dispose(); otherCamera.dispose(); target.dispose();
	}
	private static function checkQueries(source:ModelAsset):Void {
		var stage = new Stage(), view = new Scene3D(200,100), camera = new Camera3D();
		stage.addChild(view); view.root.addChild(camera); view.camera = camera; camera.near = 1; camera.far = 6;
		camera.lookFrom(new Vector3D(0,0,5),new Vector3D());
		var geometry = BoxGeometry.create(2,2,2), material = new UnlitTextureMaterial();
		var front = new MeshObject(geometry,material), back = new MeshObject(geometry,material); back.z = -5;
		view.root.addChild(front); view.root.addChild(back);
		var model = source.createInstance(); model.x = 20; view.root.addChild(model);
		try {
			var ray = new Ray3D(new Vector3D(0,0,5),new Vector3D(0,0,-100));
			var hit = view.raycast(ray); expect(hit != null && hit.object == front,"世界射线选择最近网格"); near(hit.distance,4,"世界距离从射线起点计算");
			expect(view.raycast(ray,3.9) == null,"最大距离过滤");
			hit = view.raycast(ray,null,mesh -> mesh == back); expect(hit != null && hit.object == back,"过滤函数作用于网格"); near(hit.distance,9,"过滤后查询更远网格");
			front.setScale(-2,0.5,2); hit = view.raycast(ray); near(hit.distance,3,"非均匀及负缩放下的世界距离");
			front.scaleX = 0; hit = view.raycast(ray); expect(hit != null && hit.object == back,"跳过退化网格"); front.setScale(1,1,1);
			expect(view.pick(100,50,null,mesh -> mesh == back) == null,"视口拾取保留远裁剪");
			var viewportRay = view.stageRay(100,50); near(viewportRay.origin.z,4,"视口射线起点是近裁剪面");
			hit = view.raycast(viewportRay,null,mesh -> mesh == back); expect(hit != null,"世界查询不继承相机远裁剪");
			view.x = 50; view.y = 40; view.scaleX = 0.8; view.scaleY = 0.9; view.rotation = 17;
			view.stageToViewport(50,40); var center = view.localToGlobal(new Point(100,50));
			var radians = 17*Math.PI/180;
			near(center.x,50+Math.cos(radians)*80-Math.sin(radians)*45,"本地转舞台 X 使用原始坐标");
			near(center.y,40+Math.sin(radians)*80+Math.cos(radians)*45,"本地转舞台 Y 使用原始坐标");
			var local = view.globalToLocal(center); near(local.x,100,"旋转视口逆变换 X"); near(local.y,50,"旋转视口逆变换 Y");
			hit = view.pick(center.x,center.y); expect(hit != null && hit.object == front,"二维视口缩放旋转后的拾取"); near(hit.distance,3,"视口命中距离从近裁剪面计算");
			expect(view.stageRay(-100,-100) == null,"视口外不产生视口射线");
			var ground = new Ray3D(new Vector3D(0,2,0),new Vector3D(0,-1,0)); near(ground.intersectPlane(new Vector3D(0,1,0),0),2,"地面射线求交");
			near(ground.intersectPlane(new Vector3D(0,1e-20,0),0),2,"平面法线缩放不改变距离");
			expect(ground.intersectPlane(new Vector3D(0,1,0),0,1) == null,"地面最大距离");
			expect(ray.intersectPlane(new Vector3D(0,1,0),0) == null,"平行或共面不产生唯一命中");
			expectFailure(function() { view.raycast(ray,-1); },"拒绝负查询距离");
			expectFailure(function() { new Ray3D(new Vector3D(),new Vector3D()); },"拒绝零方向");
			var bone = model.findNodes("Wrist.R")[0], socket = model.createSocket(model.getNodeIndex(bone),"pickSocket");
			var prop = new MeshObject(geometry,material); socket.addChild(prop); model.animation.play("Walk"); model.animation.seek(0.25);
			var position = prop.getWorldPosition();
			ray = new Ray3D(new Vector3D(position.x,position.y,position.z+5),new Vector3D(0,0,-1));
			hit = Raycaster3D.intersect(view.root,ray,null,mesh -> mesh == prop);
			expect(hit != null && hit.model == model,"挂点附件解析所属模型");
			view.root.visible = false; expect(view.raycast(ray) == null,"隐藏三维根节点不参与查询"); view.root.visible = true;
		} catch (error:Dynamic) { stage.dispose(); geometry.dispose(); material.dispose(); throw error; }
		stage.dispose(); geometry.dispose(); material.dispose();
	}
	private static function checkInput():Void {
		var stage = new Stage(), a = new Scene3D(200,100), b = new Scene3D(200,100); b.x = 240;
		stage.addChild(a); stage.addChild(b);
		var ca = new Camera3D(), cb = new Camera3D(); a.root.addChild(ca); b.root.addChild(cb); a.camera = ca; b.camera = cb;
		var orbitA = new OrbitCameraController3D(ca), orbitB = new OrbitCameraController3D(cb); orbitA.snap(); orbitB.snap();
		var ia = new Scene3DInput(a,orbitA), ib = new Scene3DInput(b,orbitB), selections = 0, otherSelections = 0;
		ia.addEventListener(Scene3DInputEvent.SELECT,function(_) { selections++; }); ib.addEventListener(Scene3DInputEvent.SELECT,function(_) { otherSelections++; });
		var overlay = new Quad(70,30,0xffffff); overlay.x = 10; overlay.y = 10; stage.addChild(overlay);
		for (type in [MouseEvent.MOUSE_DOWN,MouseEvent.MOUSE_MOVE,MouseEvent.MOUSE_UP]) overlay.addEventListener(type,function(event:MouseEvent) { event.preventDefault(); });
		a.stageToViewport(0,0);
		try {
			mouse(stage,MouseEvent.MOUSE_DOWN,100,60); mouse(stage,MouseEvent.MOUSE_UP,100,60);
			expect(selections == 1 && !ia.capturing,"正常按下抬起触发一次选择");
			var yaw = orbitA.yaw;
			mouse(stage,MouseEvent.MOUSE_DOWN,20,20); mouse(stage,MouseEvent.MOUSE_UP,20,20);
			expect(selections == 1 && !ia.capturing,"覆盖 UI 按下不启动三维输入"); near(orbitA.yaw,yaw,"覆盖 UI 不旋转相机");
			mouse(stage,MouseEvent.MOUSE_DOWN,100,60); mouse(stage,MouseEvent.MOUSE_MOVE,20,20);
			expect(ia.dragging && orbitA.yaw != yaw,"跨越消费移动事件的 UI 仍保持捕获");
			mouse(stage,MouseEvent.MOUSE_UP,20,20); expect(!ia.capturing && !ia.dragging && selections == 1,"消费抬起的 UI 不留下拖动或选择");
			yaw = orbitB.yaw;
			mouse(stage,MouseEvent.MOUSE_DOWN,100,60); mouse(stage,MouseEvent.MOUSE_MOVE,300,60); mouse(stage,MouseEvent.MOUSE_UP,300,60);
			near(orbitB.yaw,yaw,"跨视口拖动不旋转另一相机"); expect(!ia.capturing && otherSelections == 0,"另一视口抬起不被误判为选择");
			// 保留左键轻点／拖动，轻点的拾取固定在按下时，不随相机平滑更新漂移。
			var selectedRay:hx.geom.Ray3D = null, selectedX:Float = -1, selectedY:Float = -1;
			ia.addEventListener(Scene3DInputEvent.SELECT,function(event:Scene3DInputEvent) { selectedRay = event.ray; selectedX = event.stageX; selectedY = event.stageY; });
			orbitA.rotate(45,0); orbitA.update(0.016);
			var expectedRay = a.stageRay(100,60), selectedBefore = selections;
			mouse(stage,MouseEvent.MOUSE_DOWN,100,60);
			expect(selections == selectedBefore && ia.capturing,"按下先等待轻点／拖动判定，不提前移动角色");
			orbitA.update(0.1); mouse(stage,MouseEvent.MOUSE_UP,102,60);
			expect(selections == selectedBefore+1 && !ia.capturing,"相机仍在平滑转动时轻点正常生效");
			vectorNear(selectedRay.direction,expectedRay.direction,"轻点使用按下时的射线");
			vectorNear(selectedRay.origin,expectedRay.origin,"轻点使用按下时的射线起点");
			near(selectedX,100,"轻点舞台 X 与按下射线一致"); near(selectedY,60,"轻点舞台 Y 与按下射线一致");
			yaw = orbitA.yaw; selectedBefore = selections;
			mouse(stage,MouseEvent.MOUSE_DOWN,100,60); mouse(stage,MouseEvent.MOUSE_MOVE,140,60);
			expect(ia.dragging && orbitA.yaw != yaw,"左键拖动仍可旋转镜头");
			mouse(stage,MouseEvent.MOUSE_UP,140,60);
			expect(!ia.capturing && !ia.dragging && selections == selectedBefore,"左键旋转结束不下达角色移动指令");
			yaw = orbitA.yaw; mouse(stage,MouseEvent.MOUSE_MOVE,180,60); near(orbitA.yaw,yaw,"释放左键后普通移动不旋转镜头");
			mouse(stage,MouseEvent.MOUSE_DOWN,100,60); stage.dispatchEvent(new Event(Event.DEACTIVATE)); expect(!ia.capturing,"失焦取消捕获");
			touch(stage,TouchEvent.TOUCH_BEGIN,100,60,7); yaw = orbitA.yaw;
			touch(stage,TouchEvent.TOUCH_MOVE,150,60,8); touch(stage,TouchEvent.TOUCH_END,150,60,8);
			expect(ia.capturing && ia.pointerId == 7,"忽略其他触摸点的移动和抬起"); near(orbitA.yaw,yaw,"其他触摸点不影响相机");
			touch(stage,TouchEvent.TOUCH_CANCEL,100,60,7); expect(!ia.capturing,"触摸取消解除捕获");
			touch(stage,TouchEvent.TOUCH_BEGIN,100,60,9); stage.removeChild(a); expect(!ia.capturing,"移出舞台解除捕获");
			stage.addChild(a); touch(stage,TouchEvent.TOUCH_BEGIN,100,60,10); a.dispose(); expect(ia.isDisposed && !ia.capturing,"视口销毁自动解绑输入");
		} catch (error:Dynamic) { ia.dispose(); ib.dispose(); orbitA.dispose(); orbitB.dispose(); stage.dispose(); throw error; }
		ia.dispose(); ib.dispose(); orbitA.dispose(); orbitB.dispose(); stage.dispose();
	}
	private static function mouse(stage:Stage,type:String,x:Float,y:Float):Void { var event = new MouseEvent(type); event.stageX = x; event.stageY = y; stage.handleMouseEvent(event,true); }
	private static function touch(stage:Stage,type:String,x:Float,y:Float,id:Int):Void { var event = new TouchEvent(type); event.stageX = event.touchX = x; event.stageY = event.touchY = y; event.touchPointID = id; stage.handleMouseEvent(event,true); }
	private static function vectorNear(actual:Vector3D,expected:Vector3D,label:String):Void { near(actual.x,expected.x,label+" X"); near(actual.y,expected.y,label+" Y"); near(actual.z,expected.z,label+" Z"); }
	private static function near(actual:Float,expected:Float,label:String):Void { expect(Math.isFinite(actual) && Math.abs(actual-expected) < 1e-5,label+"，实际="+actual+"，预期="+expected); }
	private static function expect(value:Bool,label:String):Void { if (!value) throw "相机交互检查失败："+label; checks++; }
	private static function expectFailure(callback:Void->Void,label:String):Void { var failed = false; try { callback(); } catch (_:Dynamic) { failed = true; } expect(failed,label); }
}
#end
