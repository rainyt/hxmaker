package game;

import hx.assets.GlbAsset;
import hx.display.MeshObject;
import hx.display.Model3D;
import hx.display.Node3D;
import hx.geom.Vector3D;
import hx.geometry.Geometry3D;
import hx.material.Material3D;

/** 示例角色业务：目标移动、Idle/Walk 选择及道具挂载，不承担引擎帧调度。 */
class CharacterActor {
	public var model(default, null):Model3D;
	public var goal(default, null):Vector3D;
	public var disposed(default, null):Bool = false;
	private var attachment:MeshObject;
	private var socket:Node3D;
	private var fadeSeconds:Float;
	public function new(source:GlbAsset, geometry:Geometry3D, material:Material3D, fadeSeconds:Float, index:Int) {
		this.fadeSeconds = fadeSeconds; model = source.createInstance(-1,{lightingEnabled:true}); model.name = "角色 "+(index+1);
		try {
			for (mesh in model.meshes) mesh.castShadow = true;
			attachment = new MeshObject(geometry,material); attachment.name = "角色 "+(index+1)+" 的道具"; attachment.castShadow = true;
			setHand("R"); model.animation.play("Idle"); model.animation.seek(index*0.25%model.animation.duration);
		} catch (error:Dynamic) { dispose(); throw error; }
	}
	public function moveTo(x:Float,z:Float):Void { goal = new Vector3D(x,0,z); }
	public function stop():Void { goal = null; }
	/** 返回是否调用了动画更新；位移坐标使用示例根节点下的 X/Z。 */
	public function step(dt:Float,movementSpeed:Float,playbackSpeed:Float,paused:Bool):Bool {
		if (disposed || paused) return false;
		if (goal != null) {
			var dx = goal.x-model.x, dz = goal.z-model.z, distance = Math.sqrt(dx*dx+dz*dz), step = Math.min(distance,dt*movementSpeed);
			if (distance > 1e-5) { model.x += dx/distance*step; model.z += dz/distance*step; model.rotationY = Math.atan2(dx,dz)*180/Math.PI; }
			if (distance <= step+1e-5) goal = null;
		}
		var clip = goal == null ? "Idle" : "Walk";
		var nextSpeed = goal == null ? 1 : playbackSpeed;
		if (model.animation.speed != nextSpeed) model.animation.speed = nextSpeed;
		if (model.animation.currentName != clip) model.animation.crossFade(clip,fadeSeconds);
		model.update(dt); return true;
	}
	public function setHand(side:String):Void {
		var nodes = model.findNodes("Wrist."+side);
		if (nodes.length != 1) throw "角色需要唯一的手腕骨骼：Wrist."+side;
		var next = model.createSocket(model.getNodeIndex(nodes[0]),"道具挂点"); next.setPosition(0,-0.12,0.08); next.addChild(attachment);
		if (socket != null) socket.dispose(); socket = next;
	}
	public function setAttachmentVisible(value:Bool):Void { if (attachment != null) attachment.visible = value; }
	public function dispose():Void {
		if (disposed) return;
		disposed = true; goal = null; model.dispose();
		if (attachment != null && !attachment.isDisposed) attachment.dispose(); socket = null;
	}
}
