package test;

#if hxmaker_character_checks
import haxe.Json;
import haxe.io.Bytes;
import hx.animation3d.AnimationClip3D;
import hx.animation3d.AnimationPlayer3D;
import hx.animation3d.AnimationPose3D;
import hx.assets.GlbAsset;
import hx.display.MeshObject;
import hx.display.Model3D;
import hx.display.Node3D;
import hx.events.AnimationEvent3D;
import hx.geom.Vector3D;
import hx.geometry.BoxGeometry;
import hx.material.LambertTextureMaterial;

/** 可选数值回归，由用户显式启用；不替代画面、合批和上下文恢复验收。 */
class AnimationSocketChecks {
	private static var checks:Int;
	public static function run(source:GlbAsset):Void {
		checks = 0; checkPlayer(); checkEvents(); checkModel(source); checkLookupAndZeroScale();
		trace("HXMAKER_ANIMATION_SOCKET_CHECKS PASS 检查数：" + checks);
	}
	private static function checkPlayer():Void {
		var rig = new PoseRig(), player = rig.player;
		try {
			player.play("MoveX"); player.seek(0.2); near(rig.pose.translations[0][0],2,"带非零片段起点的采样");
			player.crossFade("Turn",0.4); near(rig.pose.translations[0][0],2,"切换瞬间连续");
			player.update(0.2);
			near(rig.pose.translations[0][0],3.5,"源片段继续推进，目标缺失平移回退初始姿态");
			near(rig.pose.translations[0][1],2,"缺失轨道平滑回退");
			near(rig.pose.rotations[0][2],Math.sin(Math.PI/20),"跨片段四元数角度插值");
			var before = rig.pose.clone(); player.crossFade("MoveY",0.4);
			poseNear(rig.pose,before,"中断过渡保持当前姿态");
			player.update(0.1);
			near(rig.pose.translations[0][0],2.625,"中断后的源姿态冻结");
			near(rig.pose.translations[0][1],2,"中断后的目标继续推进");
			player.pause(); before.copyFrom(rig.pose); var progress = player.transitionProgress;
			player.update(1); poseNear(rig.pose,before,"暂停冻结混合姿态"); near(player.transitionProgress,progress,"暂停冻结过渡进度");
			player.seek(0.75); expect(!player.transitioning && !player.playing,"seek 取消过渡并保持暂停");
			near(rig.pose.translations[0][1],15,"seek 定位目标片段");
			player.resume(); player.speed = 0; player.update(1); near(player.time,0.75,"零速度冻结播放");
			player.speed = 2; player.seek(0.1); player.update(0.2); near(player.time,0.5,"速度作用于片段时间");
			player.crossFade("Turn",0.8); player.update(0.2); near(player.transitionProgress,0.5,"速度作用于过渡时间");
			var name = player.currentName, time = player.time;
			expectFailure(function() { player.crossFade("不存在",0.2); },"缺失片段拒绝");
			expectFailure(function() { player.crossFade("MoveX",-1); },"负过渡时间拒绝");
			expectFailure(function() { player.speed = Math.NaN; },"无效速度拒绝");
			expectFailure(function() { player.update(-1); },"负 dt 拒绝");
			expect(player.currentName == name,"无效操作不切换片段"); near(player.time,time,"无效操作不修改时间");
			player.crossFade("Turn",0.8); near(player.time,time,"相同目标不重启");
			player.stop(); poseNear(rig.pose,rig.rest,"stop 恢复初始姿态");
			player.speed = 1; player.crossFade("MoveY",0.4); poseNear(rig.pose,rig.rest,"初始姿态可以过渡到动作");
			player.update(0.4); expect(!player.transitioning,"过渡结束清理状态"); near(rig.pose.translations[0][1],8,"过渡终点为目标姿态");
			player.crossFade("MoveX",0); expect(!player.transitioning,"零时长过渡等价于 play"); near(player.time,0,"零时长重播");
			var negative = new AnimationPose3D([[0.,0.,0.]],[[0.,0.,0.,-1.]],[[1.,1.,1.]]);
			var positive = new AnimationPose3D([[0.,0.,0.]],[[0.,0.,0.,1.]],[[1.,1.,1.]]);
			positive.blend(positive,negative,0.5); near(Math.abs(positive.rotations[0][3]),1,"等价反号四元数不绕远路");
			var legacy = new AnimationPlayer3D([new AnimationClip3D("Empty",[])],function(clip,time) {});
			legacy.crossFade("Empty",0); expect(legacy.currentName == "Empty","旧构造接口保留立即播放能力");
			expectFailure(function() { legacy.crossFade("Empty",0.2); },"未提供混合适配时明确拒绝过渡"); legacy.dispose();
		} catch (error:Dynamic) { player.dispose(); throw error; }
		player.dispose();
	}
	private static function checkEvents():Void {
		var rig = new PoseRig(), player = rig.player, loopCount = 0., completes = 0, fades = 0;
		try {
			player.addEventListener(AnimationEvent3D.LOOP,function(event:AnimationEvent3D) { loopCount += event.loopCount; });
			player.addEventListener(AnimationEvent3D.COMPLETE,function(_) { completes++; });
			player.addEventListener(AnimationEvent3D.FADE_COMPLETE,function(_) { fades++; });
			player.play("MoveX"); player.seek(0.25); player.update(3.5);
			near(loopCount,3,"大 dt 合并跨越的循环数"); near(player.time,0.75,"大 dt 余数时间");
			player.play("MoveY",false); player.update(2); player.update(1);
			expect(completes == 1 && !player.playing,"单次片段只完成一次"); near(rig.pose.translations[0][1],20,"完成事件之前应用终点姿态");
			player.seek(0.1); player.resume(); player.update(2); expect(completes == 1,"seek 后重达终点不重复完成事件");
			player.play("Empty"); player.update(0.1); player.resume(); player.update(0.1);
			expect(completes == 2 && !player.playing,"零时长片段只完成一次");
			player.play("MoveX"); player.crossFade("MoveY",0.2); player.update(0.3); player.update(0.3);
			expect(fades == 1,"过渡完成只派发一次");
			player.removeEventListeners();
			var sawOld = false;
			player.addEventListener(AnimationEvent3D.LOOP,function(_) { player.play("MoveY"); });
			player.addEventListener(AnimationEvent3D.LOOP,function(event:AnimationEvent3D) {
				sawOld = player.currentName == "MoveX" && event.clipName == "MoveX";
				near(rig.pose.translations[0][0],1,"同批监听看到相同的最终姿态");
			});
			player.play("MoveX"); player.seek(0.9); player.update(0.2);
			expect(sawOld && player.currentName == "MoveY","播放命令在本批监听完成后执行");
			player.removeEventListeners();
			var starts = 0;
			player.addEventListener(AnimationEvent3D.START,function(_) { starts++; player.play("MoveX"); });
			player.play("MoveX"); expect(starts == 2,"递归开始监听不会无限执行");
			player.removeEventListeners(); player.update(0);
			player.addEventListener(AnimationEvent3D.COMPLETE,function(_) { player.dispose(); });
			player.play("MoveY",false); player.update(2);
			expectFailure(function() { player.play("MoveX"); },"回调中销毁后不能再次播放");
		} catch (error:Dynamic) { player.dispose(); throw error; }
		player.dispose();
	}
	private static function checkModel(source:GlbAsset):Void {
		var a = source.createInstance(), b = source.createInstance(), group = new Node3D();
		var geometry = BoxGeometry.create(0.1,0.5,0.1), material = new LambertTextureMaterial(source.getTexture(2));
		var prop = new MeshObject(geometry,material), preserved = new Node3D();
		try {
			group.setPosition(2,3,-1); group.rotationY = 35; group.addChild(a);
			a.setPosition(1,0.5,2); a.setScale(-1.2,1.2,1.2);
			var bones = a.findNodes("Wrist.R"); expect(bones.length == 1,"通过骨骼名称查询");
			var index = a.getNodeIndex(bones[0]); expect(index >= 0 && a.getNodeByIndex(index) == bones[0],"节点索引稳定映射");
			var socket = a.createSocket(index,"weapon"); socket.setPosition(0,-0.12,0.08); socket.addChild(prop); socket.addChild(preserved);
			expect(a.getNodeIndex(socket) == -1 && a.findNodes("weapon").length == 0,"挂点不冒充导入节点");
			a.animation.play("Walk"); a.animation.seek(0.23);
			var original = a.meshes[0].geometry.positions.copy(), untouched = b.meshes[0].geometry.positions.copy();
			a.animation.crossFade("Idle",0.6); arrayNear(a.meshes[0].geometry.positions,original,"蒙皮切换瞬间连续");
			a.update(0.1); var before = a.meshes[0].geometry.positions.copy();
			a.animation.crossFade("Walk",0.4); arrayNear(a.meshes[0].geometry.positions,before,"蒙皮中断过渡连续");
			a.update(0.4); b.animation.play("Walk"); b.animation.seek(0.4);
			arrayNear(a.meshes[0].geometry.positions,b.meshes[0].geometry.positions,"过渡结束蒙皮等于独立目标实例");
			b.animation.stop(); arrayNear(b.meshes[0].geometry.positions,untouched,"另一实例可独立恢复初始姿态");
			var expected = bones[0].getWorldMatrix().transformVector(new Vector3D(0,-0.12,0.08));
			var actual = socket.getWorldPosition(); near(actual.x,expected.x,"挂点世界 X 含外层变换一次");
			near(actual.y,expected.y,"挂点世界 Y 含外层变换一次"); near(actual.z,expected.z,"挂点世界 Z 含外层变换一次");
			near(socket.y,-0.12,"动画没有覆盖挂点局部偏移");
			socket.removeChild(preserved); a.dispose();
			expect(socket.isDisposed && prop.isDisposed && !preserved.isDisposed,"挂点随模型销毁，移出的附件保留");
			expect(geometry.referenceCount == 0 && material.referenceCount == 0,"附件销毁解除共享资源引用");
			expect(source.getTexture(2).data != null,"模型销毁不释放 Assets 共享贴图");
			expect(a.findNodes("Wrist.R").length == 0 && a.getNodeByIndex(index) == null,"销毁后查询安全返回空");
		} catch (error:Dynamic) {
			a.dispose(); b.dispose(); group.dispose(); prop.dispose(); preserved.dispose(); geometry.dispose(); material.dispose(); throw error;
		}
		a.dispose(); b.dispose(); group.dispose(); prop.dispose(); preserved.dispose(); geometry.dispose(); material.dispose();
	}
	private static function checkLookupAndZeroScale():Void {
		var model = GlbAsset.fromBytes(nodeFixture()).createInstance();
		try {
			expect(model.findNodes("same").length == 2,"同名节点不丢失");
			expect(model.getNodeByIndex(-1) == null && model.getNodeByIndex(3) == null && model.getNodeByIndex(2) == null,"越界和非活动节点不可查询");
			expectFailure(function() { model.createSocket(2); },"非活动节点不能创建挂点");
			model.animation.play("Positive"); model.animation.crossFade("Negative",1); model.update(0.5);
			near(model.getNodeByIndex(0).getLocalMatrix().determinant,0,"正负缩放混合允许经过退化姿态");
			model.update(0.5); near(model.getNodeByIndex(0).scaleX,-1,"退化姿态后可以继续播放");
		} catch (error:Dynamic) { model.dispose(); throw error; }
		model.dispose();
	}
	private static function nodeFixture():Bytes {
		var raw = Bytes.alloc(56); raw.setFloat(0,0); raw.setFloat(4,1);
		for (i in 0...12) raw.setFloat(8+i*4,i >= 6 && i%3 == 0 ? -1 : 1);
		var doc:Dynamic = {asset:{version:"2.0"},scene:0,scenes:[{nodes:[0,1]},{nodes:[2]}],
			nodes:[{name:"same"},{name:"same"},{name:"hidden"}],buffers:[{byteLength:56}],
			bufferViews:[{buffer:0,byteOffset:0,byteLength:8},{buffer:0,byteOffset:8,byteLength:24},{buffer:0,byteOffset:32,byteLength:24}],
			accessors:[{bufferView:0,componentType:5126,count:2,type:"SCALAR"},{bufferView:1,componentType:5126,count:2,type:"VEC3"},{bufferView:2,componentType:5126,count:2,type:"VEC3"}],
			animations:[{name:"Positive",samplers:[{input:0,output:1}],channels:[{sampler:0,target:{node:0,path:"scale"}}]},
				{name:"Negative",samplers:[{input:0,output:2}],channels:[{sampler:0,target:{node:0,path:"scale"}}]}]};
		var json = Bytes.ofString(Json.stringify(doc)), length = (json.length+3)&~3, bytes = Bytes.alloc(28+length+raw.length);
		bytes.setInt32(0,0x46546c67); bytes.setInt32(4,2); bytes.setInt32(8,bytes.length);
		bytes.setInt32(12,length); bytes.setInt32(16,0x4e4f534a); bytes.blit(20,json,0,json.length);
		for (i in json.length...length) bytes.set(20+i,32);
		bytes.setInt32(20+length,raw.length); bytes.setInt32(24+length,0x004e4942); bytes.blit(28+length,raw,0,raw.length); return bytes;
	}
	private static function expect(value:Bool,label:String):Void { if (!value) throw "动画挂点检查失败：" + label; checks++; }
	private static function near(actual:Float,expected:Float,label:String):Void { expect(Math.isFinite(actual) && Math.abs(actual-expected) < 1e-5,label); }
	private static function arrayNear(actual:Array<Float>,expected:Array<Float>,label:String):Void {
		expect(actual.length == expected.length,label + "长度"); for (i in 0...actual.length) near(actual[i],expected[i],label);
	}
	private static function poseNear(actual:AnimationPose3D,expected:AnimationPose3D,label:String):Void {
		arrayNear(actual.translations[0],expected.translations[0],label); arrayNear(actual.rotations[0],expected.rotations[0],label); arrayNear(actual.scales[0],expected.scales[0],label);
	}
	private static function expectFailure(callback:Void->Void,label:String):Void {
		var failed = false; try { callback(); } catch (_:Dynamic) { failed = true; } expect(failed,label);
	}
}

/** 一节点数值夹具，完全通过公开动画 API 验证时间与姿态。 */
private class PoseRig {
	public var rest:AnimationPose3D;
	public var pose:AnimationPose3D;
	public var player:AnimationPlayer3D;
	public function new() {
		rest = new AnimationPose3D([[3.,4.,5.]],[[0.,0.,0.,1.]],[[1.,1.,1.]]); pose = rest.clone();
		var a = rest.clone(), b = rest.clone(), snapshot = rest.clone();
		var clips = [
			new AnimationClip3D("MoveX",[{node:0,path:"translation",interpolation:"LINEAR",times:[2.,3.],values:[0.,0.,0.,10.,0.,0.]}]),
			new AnimationClip3D("MoveY",[{node:0,path:"translation",interpolation:"LINEAR",times:[0.,1.],values:[0.,0.,0.,0.,20.,0.]}]),
			new AnimationClip3D("Turn",[{node:0,path:"rotation",interpolation:"LINEAR",times:[0.,1.],values:[0.,0.,0.,1.,0.,0.,1.,0.]}]),
			new AnimationClip3D("Empty",[])
		];
		player = new AnimationPlayer3D(clips,(clip,time) -> { pose.sample(rest,clip,time); },{
			capture:() -> { snapshot.copyFrom(pose); },
			apply:(source,sourceTime,target,targetTime,weight) -> {
				if (source != null) a.sample(rest,source,sourceTime);
				b.sample(rest,target,targetTime); pose.blend(source == null ? snapshot : a,b,weight);
			}
		});
	}
}
#end
