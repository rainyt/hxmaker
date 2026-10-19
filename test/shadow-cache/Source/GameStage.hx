package;

import hx.core.Hxmaker;
import hx.display.Scene3D;
import hx.display3d.Camera3D;
import hx.display3d.MeshObject;
import hx.display3d.Node3D;
import hx.geom.Vector3D;
import hx.geom.Bounds3D;
import hx.geometry.BoxGeometry;
import hx.geometry.PlaneGeometry;
import hx.geometry.Geometry3D;
import hx.light.DirectionalLight3D;
import hx.light.ShadowQuality3D;
import hx.material.LambertTextureMaterial;
import hx.material.AlphaMode3D;
import hx.material.CullMode3D;
import hx.assets.Assets;
import lime.utils.UInt8Array;

/** 独立 GPU 验证入口，覆盖静态复用、动态失效、合批上限及资源生命周期。 */
@:access(hx.core.Render)
@:access(hx.render3d.openfl.Scene3DDisplay)
@:access(hx.render3d.openfl.Renderer3D)
@:access(hx.render3d.openfl.ShadowPass3D)
@:access(hx.render3d.openfl.ShadowGeometryBuffer3D)
@:access(hx.render3d.openfl.MainGeometryCache3D)
class GameStage extends hx.display.Stage {
	var scene:Scene3D;
	var light:DirectionalLight3D;
	var box:MeshObject;
	var mask:MeshObject;
	var parentNode:Node3D;
	var assets:Assets;
	var large:MeshObject;
	var group:hx.display3d.Model3D;
	var animateGroup:Bool=false;
	var heldMain:Array<Dynamic>=[];
	var disposedMainBytes:Int=-1;
	var disposedMainHandles:Int=-1;
	var ready:Bool=false;
	var skinChecks:Bool=false;
	var disposedBytes:Int=-1;
	var disposedHandles:Int=-1;
	var oldBoxGeometry:Geometry3D;
	var held:Array<Dynamic>=[];
	override public function onStageInit():Void {
		super.onStageInit();
		try { setup(); } catch(error:Dynamic) { Reflect.setField(js.Browser.window,'__shadowCacheError',Std.string(error));trace(Std.string(error)); }
	}
	function setup():Void {
		scene=new Scene3D(192,192);scene.autoRender=false;scene.profilingEnabled=true;scene.backgroundColor=0x263242;addChild(scene);
		var camera=new Camera3D();camera.lookFrom(new Vector3D(9,8,11),new Vector3D());camera.far=80;scene.root.addChild(camera);scene.camera=camera;
		light=new DirectionalLight3D(0xffffff,1);light.direction=new Vector3D(-.5,-1,-.4);light.shadowEnabled=true;light.shadowQuality=ShadowQuality3D.PERFORMANCE;
		var bounds=new Bounds3D();bounds.include(-10,-2,-10);bounds.include(10,8,10);light.shadowBounds=bounds;scene.root.addChild(light);scene.light=light;
		parentNode=new Node3D();scene.root.addChild(parentNode);
		box=new MeshObject(BoxGeometry.create(2,2,2),new LambertTextureMaterial(null,0xd9b765));box.y=1;box.castShadow=true;box.shadowMobility=hx.render3d.ShadowMobility3D.STATIC;parentNode.addChild(box);
		var floor=new MeshObject(PlaneGeometry.create(18,18),new LambertTextureMaterial(null,0xa4b0b9));floor.castShadow=false;scene.root.addChild(floor);
		var material=new LambertTextureMaterial(null,0xa0dba2);material.alphaMode=AlphaMode3D.MASK;material.cullMode=CullMode3D.NONE;
		mask=new MeshObject(PlaneGeometry.create(3,3),material);mask.castShadow=true;mask.shadowMobility=hx.render3d.ShadowMobility3D.STATIC;mask.y=2;mask.x=-4;scene.root.addChild(mask);
		assets=new Assets();assets.loadBitmapData('assets/shadow-mask.png');assets.onComplete(_->{mask.material.texture=assets.getBitmapData('shadow-mask');ready=true;});assets.start();
		Reflect.setField(js.Browser.window,'__shadowCache',{state:state,command:command,pixels:pixels});
	}
	function renderer():hx.render3d.openfl.Renderer3D {
		var render:hx.core.Render=cast Hxmaker.engine.renderer;var display=render.__scene3DDisplays.get(scene);return display==null?null:display.renderer3D;
	}
	function pbrGroupBatches():Int {
		var render=renderer(),count=0;
		if(render!=null&&render.mainGeometry!=null&&group!=null)for(entry in render.mainGeometry.entries)
			for(range in entry.ranges)if(group.meshes.indexOf(range.mesh)>=0){count++;break;}
		return count;
	}
	function state():Dynamic {
		var render=renderer();var gl=render==null?null:render.gl;
		return {ready:ready,skinChecks:skinChecks,pbrGroupBatches:pbrGroupBatches(),stats:scene.stats,error:gl==null||gl.isContextLost()?-1:gl.getError(),disposedBytes:disposedBytes,disposedHandles:disposedHandles,
			reused:reused(),mainReused:mainReused(),autoStatic:box.effectiveGeometryMobility==hx.render3d.GeometryMobility3D.STATIC,autoShadowStatic:box.effectiveShadowMobility==hx.render3d.ShadowMobility3D.STATIC,groupAutoStatic:group==null||group.isDisposed||group.meshes.length==0?false:group.meshes[0].effectiveGeometryMobility==hx.render3d.GeometryMobility3D.STATIC,disposedMainBytes:disposedMainBytes,disposedMainHandles:disposedMainHandles,webgl:gl==null?'':gl.getParameter(gl.VERSION)};
	}
	function pixels():Array<Int> {
		var render=renderer();if(render==null||render.target==null||render.gl==null||render.gl.isContextLost())return [];
		var gl=render.gl,previous:Dynamic=gl.getParameter(gl.FRAMEBUFFER_BINDING),data=new UInt8Array(192*192*4);
		gl.bindFramebuffer(gl.FRAMEBUFFER,render.target.framebuffer);gl.readPixels(0,0,192,192,gl.RGBA,gl.UNSIGNED_BYTE,data);gl.bindFramebuffer(gl.FRAMEBUFFER,previous);
		return [for(i in 0...data.length)data[i]];
	}
	function batches():Array<hx.render3d.openfl.ShadowGeometryBuffer3D> {
		var render=renderer();if(render==null||render.shadowPass==null)return [];
		var result=[];
		for(list in render.shadowPass.geometryBatches)for(batch in list)result.push(batch);
		for(cache in render.shadowPass.dynamicGeometry)for(batch in cache.batches)result.push(batch);
		return result;
	}
	function reused():Int {
		var count=0;for(batch in batches())
			for(old in held)if(old.batch==batch&&old.vertex==batch.vertices&&old.index==batch.indices&&old.array==batch.vertexData)count++;
		return count;
	}

	override public function onUpdate(dt:Float):Void {
		super.onUpdate(dt);
		if(animateGroup && group!=null && !group.isDisposed)group.update(dt);
	}
	function mainBuffers():Array<hx.render3d.openfl.MainGeometryBuffer3D> {
		var render=renderer(),result=[];
		if(render!=null&&render.mainGeometry!=null)for(entry in render.mainGeometry.entries)result.push(entry.buffer);
		return result;
	}
	function mainReused():Int {
		var count=0;for(buffer in mainBuffers())for(old in heldMain)
			if(buffer==old.buffer&&buffer.vertexBuffer==old.vertex&&buffer.indexBuffer==old.index&&buffer.vertices==old.array)count++;
		return count;
	}

	function command(name:String):Void {
		switch(name) {
			case 'skinCheck':checkSkin();skinChecks=true;scene.requestRender();
			case 'captureMain':heldMain=[for(buffer in mainBuffers()){buffer:buffer,vertex:buffer.vertexBuffer,index:buffer.indexBuffer,array:buffer.vertices}];scene.requestRender();
			case 'referenceMain':for(entry in renderer().mainGeometry.entries)entry.snapshot=null;scene.requestRender();
			case 'geometryCacheOff':scene.geometryCacheEnabled=false;scene.requestRender();
			case 'geometryCacheOn':scene.geometryCacheEnabled=true;scene.requestRender();
			case 'geometryStatic':box.geometryMobility=hx.render3d.GeometryMobility3D.STATIC;mask.geometryMobility=hx.render3d.GeometryMobility3D.STATIC;
			case 'geometryDynamic':box.geometryMobility=hx.render3d.GeometryMobility3D.DYNAMIC;mask.geometryMobility=hx.render3d.GeometryMobility3D.DYNAMIC;
			case 'autoPolicy':scene.autoStaticDelay=.2;box.geometryMobility=hx.render3d.GeometryMobility3D.AUTO;box.shadowMobility=hx.render3d.ShadowMobility3D.AUTO;
			case 'autoGroup':for(mesh in group.meshes){mesh.geometryMobility=hx.render3d.GeometryMobility3D.AUTO;mesh.shadowMobility=hx.render3d.ShadowMobility3D.AUTO;}
			case 'groupPlay':animateGroup=true;group.animation.speed=1;group.animation.play("移动");
			case 'groupFreeze':animateGroup=false;scene.requestRender();
			case 'groupSpeedZero':group.animation.speed=0;scene.requestRender();
			case 'transparent':mask.material.alphaMode=AlphaMode3D.BLEND;mask.material.opacity=.5;
			case 'pbrGroup':
				for(i in 0...group.meshes.length){var pbr=new hx.material.PbrMaterial3D(null,0xd9b765,0,i == 0 ? 0.25 : 0.85);pbr.baseColorFactor=i==0?[.1,.8,.2]:[.8,.1,.4];group.meshes[i].material=pbr;}
			case 'pbrFactor':(cast group.meshes[1].material:hx.material.PbrMaterial3D).baseColorFactor=[.15,.3,.95];
			case 'pbrRoughness':(cast group.meshes[1].material:hx.material.PbrMaterial3D).roughness=.12;
			case 'pbrMetallic':(cast group.meshes[1].material:hx.material.PbrMaterial3D).metallic=.8;
			case 'pbrEmission':(cast group.meshes[1].material:hx.material.PbrMaterial3D).emissive=[.2,.05,.1];
			case 'pbrMapped':for(mesh in group.meshes){var pbr=new hx.material.PbrMaterial3D(null,0xd9b765,0,.7);pbr.normalTexture=assets.getBitmapData('shadow-mask');mesh.material=pbr;}
			case 'groupFarPart':group.rotationY=0;group.setScale(1,1,1);group.meshes[1].x=50;group.meshes[1].material=new hx.material.PbrMaterial3D(null,0x4488cc,0,.8);
			case 'groupShift':group.x-=50;
			case 'groupScale':group.scaleY=1.7;group.scaleX=-.8;
			case 'capture':held=[];for(batch in batches())held.push({batch:batch,vertex:batch.vertices,index:batch.indices,array:batch.vertexData});light.requestShadowUpdate();
			case 'group':addGroup();
			case 'groupMove':group.x+=.5;group.rotationY+=17;
			case 'groupMirror':group.scaleX=-group.scaleX;
			case 'groupChild':group.meshes[0].rotationZ+=23;
			case 'groupVertex':group.meshes[0].geometry.positions[0]+=.1;group.meshes[0].geometry.invalidate();
			case 'groupStatic':for(mesh in group.meshes)mesh.shadowMobility=hx.render3d.ShadowMobility3D.STATIC;
			case 'groupDynamic':for(mesh in group.meshes)mesh.shadowMobility=hx.render3d.ShadowMobility3D.DYNAMIC;
			case 'dynamic':box.shadowMobility=hx.render3d.ShadowMobility3D.DYNAMIC;
			case 'static':box.shadowMobility=hx.render3d.ShadowMobility3D.STATIC;
			case 'dynamicMask':mask.shadowMobility=hx.render3d.ShadowMobility3D.DYNAMIC;
			case 'refresh':light.requestShadowUpdate();
			case 'reference':renderer().shadowPass.geometrySnapshots=[];for(cache in renderer().shadowPass.dynamicGeometry)cache.snapshot=null;light.requestShadowUpdate();
			case 'camera':scene.camera.x+=.2;light.requestShadowUpdate();
			case 'light':light.direction=new Vector3D(-.4,-1,-.3);
			case 'moveAndSync':box.x+=.2;scene.updateMobility();
			case 'move':box.x+=.2;
			case 'parent':parentNode.rotationY+=12;
			case 'mirror':parentNode.scaleX=-parentNode.scaleX;
			case 'colorToggle':box.material.color=box.material.color==0xcc8855?0x229955:0xcc8855;
			case 'autoZero':scene.autoStaticDelay=0;scene.requestRender();
			case 'color':box.material.color=0xcc8855;
			case 'geometry':box.geometry.positions[0]+=.1;box.geometry.invalidate();
			case 'indicesSwap':var first=box.geometry.indices[0];box.geometry.indices[0]=box.geometry.indices[1];box.geometry.indices[1]=first;box.geometry.invalidate();
			case 'replace':oldBoxGeometry=box.geometry;box.geometry=BoxGeometry.create(3,2,2);
			case 'opacity':mask.material.opacity=mask.material.opacity==1 ? 0.5 : 1;
			case 'cutoff':mask.material.alphaCutoff=mask.material.alphaCutoff == 0.7 ? 0.4 : 0.7;
			case 'atlas':mask.material.texture=assets.getBitmapData('shadow-mask').sub(0,0,32,64);
			case 'atlasMutate':mask.material.texture.rect.x+=4;scene.requestRender();
			case 'uv':mask.geometry.uvs[0]+=.1;mask.geometry.invalidate();
			case 'alpha':for(i in 0...Std.int(mask.geometry.positions.length/3)){mask.geometry.colors.push(1);mask.geometry.colors.push(1);mask.geometry.colors.push(1);mask.geometry.colors.push(.8);}mask.geometry.invalidate();
			case 'maskOff':mask.material.alphaMode=AlphaMode3D.OPAQUE;
			case 'maskOn':mask.material.alphaMode=AlphaMode3D.MASK;
			case 'hide':mask.visible=false;
			case 'show':mask.visible=true;
			case 'disable':light.shadowEnabled=false;
			case 'enable':light.shadowEnabled=true;
			case 'auto':light.shadowBounds=null;light.shadowQuality=ShadowQuality3D.BALANCED;light.shadowDistance=35;
			case 'large':addLarge(false);
			case 'indices':addLarge(true);
			case 'removeLarge':if(large!=null){var geometry=large.geometry,material=large.material;large.dispose();geometry.dispose();material.dispose();large=null;}
			case 'dispose':
				var pass=renderer().shadowPass,gl=renderer().gl,resources:Array<Dynamic>=[];
				var allBatches=pass.geometryBatches.copy();for(cache in pass.dynamicGeometry)allBatches.push(cache.batches);
				for(batches in allBatches)for(batch in batches)resources.push({batch:batch,vertex:batch.vertices,index:batch.indices});
				var mainResources=[for(buffer in mainBuffers()){buffer:buffer,vertex:buffer.vertexBuffer,index:buffer.indexBuffer}];
				var stream=renderer().streamGeometry;if(stream!=null)mainResources.push({buffer:stream,vertex:stream.vertexBuffer,index:stream.indexBuffer});
				scene.dispose();disposedBytes=0;disposedHandles=0;disposedMainBytes=0;disposedMainHandles=0;
				for(resource in mainResources){disposedMainBytes+=resource.buffer.bytes;if(gl.isBuffer(resource.vertex))disposedMainHandles++;if(gl.isBuffer(resource.index))disposedMainHandles++;}
				for(resource in resources){var batch:hx.render3d.openfl.ShadowGeometryBuffer3D=resource.batch;disposedBytes+=batch.bytes;if(gl.isBuffer(resource.vertex))disposedHandles++;if(gl.isBuffer(resource.index))disposedHandles++;}
				for(batches in pass.geometryBatches)for(batch in batches)disposedBytes+=batch.bytes;
			case 'lose':var extension:Dynamic=renderer().gl.getExtension('WEBGL_lose_context');extension.loseContext();haxe.Timer.delay(()->extension.restoreContext(),300);
			default:throw '未知阴影缓存检查：'+name;
		}
	}
	/** 对真实双关节 CPU 蒙皮核对顶点、法线、融合边界与完整校验结果。 */
	function checkSkin():Void {
		function node(name:String,children:Array<Int>,mesh:Int=-1,skin:Int=-1):hx.model.ModelSourceData.ModelNodeData {
			return {name:name,children:children,mesh:mesh,skin:skin,matrix:null,translation:[0.,0.,0.],rotation:[0.,0.,0.,1.],scale:[1.,1.,1.]};
		}
		var unit=new hx.geom.Matrix3D().rawData;
		var asset=hx.assets.ModelAsset.fromSource({sourceFormat:"glb",nodes:[node("根",[1,2,3]),node("网格",[],0,0),node("关节一",[]),node("关节二",[])],scenes:[[0]],scene:0,
			meshes:[[{positions:[-1.,0.,0.,1.,0.,0.,0.,1.,0.],normals:[0.,0.,1.,0.,0.,1.,0.,0.,1.],uvs:[0.,0.,1.,0.,0.,1.],indices:[0,1,2],joints:[0,1,0,0,0,1,0,0,0,1,0,0],weights:[.5,.5,0.,0.,.5,.5,0.,0.,.5,.5,0.,0.],material:-1}]],materials:[],images:[],textures:[],skins:[{joints:[2,3],inverseBindMatrices:[unit,unit]}],
			animations:[{name:"变形",tracks:[{node:2,path:"translation",times:[0.,1.],values:[0.,0.,0.,2.,1.,-1.],interpolation:"LINEAR"},{node:3,path:"scale",times:[0.,1.],values:[1.,1.,1.,.5,2.,1.],interpolation:"LINEAR"}]}],warnings:[]});
		var model=asset.createInstance(-1,{lightingEnabled:true}),g=model.meshes[0].geometry;
		model.animation.play("变形",false);
		for(time in [.25,.5,.75,1.,0.]){
			var version=g.version,events=0;
			var onChange:Dynamic->Void=_->{events++;};g.addEventListener(hx.events.Event.CHANGE,onChange);
			model.animation.seek(time);g.removeEventListener(hx.events.Event.CHANGE,onChange);
			if(g.version<=version||events==0)throw "蒙皮必须递增几何版本并通知订阅者";
			var expected=[-1.+.25*time+time, .5*time,-.5*time, 1.-.25*time+time,.5*time,-.5*time,time,1.+time,-.5*time];
			for(i in 0...expected.length)if(Math.abs(g.positions[i]-expected[i])>1e-6)throw "双关节蒙皮顶点错误";
			for(i in 0...g.normals.length)if(Math.abs(g.normals[i]-(i%3==2?1:0))>1e-6)throw "双关节蒙皮法线错误";
			var before=[g.bounds.min.x,g.bounds.min.y,g.bounds.min.z,g.bounds.max.x,g.bounds.max.y,g.bounds.max.z];
			g.invalidate();var after=[g.bounds.min.x,g.bounds.min.y,g.bounds.min.z,g.bounds.max.x,g.bounds.max.y,g.bounds.max.z];
			for(i in 0...6)if(before[i]!=after[i])throw "融合边界与完整扫描不一致";
		}
		g.uvs[0]=Math.NaN;var rejected=false;try{g.invalidate();}catch(_:Dynamic){rejected=true;}
		if(!rejected)throw "公开 invalidate 必须保留 UV 校验";
		model.dispose();
	}

	function addGroup():Void {
		var geometry=BoxGeometry.create(1,2,1);
		var asset=hx.assets.ModelAsset.fromSource({sourceFormat:"glb",nodes:[
			{name:"根",children:[1,2],mesh:-1,skin:-1,matrix:null,translation:[0.,0.,0.],rotation:[0.,0.,0.,1.],scale:[1.,1.,1.]},
			{name:"左",children:[],mesh:0,skin:-1,matrix:null,translation:[-1.,1.,0.],rotation:[0.,0.,0.,1.],scale:[1.,1.,1.]},
			{name:"右",children:[],mesh:0,skin:-1,matrix:null,translation:[1.,1.,0.],rotation:[0.,0.,0.,1.],scale:[1.,1.5,1.]}
		],scenes:[[0]],scene:0,meshes:[[{positions:geometry.positions,normals:[],uvs:geometry.uvs,indices:geometry.indices,joints:[],weights:[],material:-1}]],materials:[],images:[],textures:[],skins:[],animations:[{name:"移动",tracks:[{node:0,path:"translation",times:[0.,1.],values:[0.,0.,0.,.3,0.,0.],interpolation:"LINEAR"}]}],warnings:[]});
		group=asset.createInstance(-1,{lightingEnabled:true});group.x=3;group.z=-3;group.rotationY=31;group.scaleY=.8;
		for(mesh in group.meshes)mesh.castShadow=true;
		scene.root.addChild(group);
	}

	function addLarge(repeated:Bool):Void {
		var positions:Array<Float>=[],uvs:Array<Float>=[],elements:Array<Int>=[];
		var count=repeated?3:66000;
		for(i in 0...count){var corner=i%3;positions.push(corner==0?-.2:corner==1 ? 0.2 : 0);positions.push(3);positions.push(corner==2 ? 0.2 : -0.2);uvs.push(0);uvs.push(0);}
		for(i in 0...(repeated?196608:count))elements.push(repeated?i%3:i);
		large=new MeshObject(new Geometry3D(positions,uvs,elements),new LambertTextureMaterial(null,0xffffff));large.material.cullMode=CullMode3D.NONE;large.castShadow=true;large.shadowMobility=hx.render3d.ShadowMobility3D.STATIC;scene.root.addChild(large);
	}
}
