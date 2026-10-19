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
class GameStage extends hx.display.Stage {
	var scene:Scene3D;
	var light:DirectionalLight3D;
	var box:MeshObject;
	var mask:MeshObject;
	var parentNode:Node3D;
	var assets:Assets;
	var large:MeshObject;
	var group:hx.display3d.Model3D;
	var ready:Bool=false;
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
	function state():Dynamic {
		var render=renderer();var gl=render==null?null:render.gl;
		return {ready:ready,stats:scene.stats,error:gl==null||gl.isContextLost()?-1:gl.getError(),disposedBytes:disposedBytes,disposedHandles:disposedHandles,
			reused:reused(),webgl:gl==null?'':gl.getParameter(gl.VERSION)};
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

	function command(name:String):Void {
		switch(name) {
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
			case 'move':box.x+=.2;
			case 'parent':parentNode.rotationY+=12;
			case 'mirror':parentNode.scaleX=-parentNode.scaleX;
			case 'color':box.material.color=0xcc8855;
			case 'geometry':box.geometry.positions[0]+=.1;box.geometry.invalidate();
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
				scene.dispose();disposedBytes=0;disposedHandles=0;
				for(resource in resources){var batch:hx.render3d.openfl.ShadowGeometryBuffer3D=resource.batch;disposedBytes+=batch.bytes;if(gl.isBuffer(resource.vertex))disposedHandles++;if(gl.isBuffer(resource.index))disposedHandles++;}
				for(batches in pass.geometryBatches)for(batch in batches)disposedBytes+=batch.bytes;
			case 'lose':var extension:Dynamic=renderer().gl.getExtension('WEBGL_lose_context');extension.loseContext();haxe.Timer.delay(()->extension.restoreContext(),300);
			default:throw '未知阴影缓存检查：'+name;
		}
	}
	function addGroup():Void {
		var geometry=BoxGeometry.create(1,2,1);
		var asset=hx.assets.ModelAsset.fromSource({sourceFormat:"glb",nodes:[
			{name:"根",children:[1,2],mesh:-1,skin:-1,matrix:null,translation:[0.,0.,0.],rotation:[0.,0.,0.,1.],scale:[1.,1.,1.]},
			{name:"左",children:[],mesh:0,skin:-1,matrix:null,translation:[-1.,1.,0.],rotation:[0.,0.,0.,1.],scale:[1.,1.,1.]},
			{name:"右",children:[],mesh:0,skin:-1,matrix:null,translation:[1.,1.,0.],rotation:[0.,0.,0.,1.],scale:[1.,1.5,1.]}
		],scenes:[[0]],scene:0,meshes:[[{positions:geometry.positions,normals:[],uvs:geometry.uvs,indices:geometry.indices,joints:[],weights:[],material:-1}]],materials:[],images:[],textures:[],skins:[],animations:[],warnings:[]});
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
