package;
#if hxmaker_fog_checks
import hx.core.Hxmaker;
import hx.display.Scene3D;
import hx.display3d.Camera3D;
import hx.display3d.MeshObject;
import hx.geometry.Geometry3D;
import hx.material.Material3D;
import hx.material.AlphaMode3D;
import hx.material.BlendMode3D;
import hx.material.CullMode3D;
import hx.material.LambertTextureMaterial;
import hx.material.PbrMaterial3D;
import hx.render3d.FogMode3D;
import hx.render3d.Skybox3D;
import hx.render3d.SkyboxTexture3D;
import lime.utils.UInt8Array;

/** 验收专用场景与 GPU 读回，普通构建完全移除。 */
@:access(hx.core.Render)
@:access(hx.render3d.openfl.Scene3DDisplay)
@:access(hx.render3d.openfl.Renderer3D)
class FogChecks {
	private var scene:Scene3D;
	private var mesh:MeshObject;
	private var geometry:Geometry3D;
	private var materials:Array<Material3D> = [];
	private var base:Material3D;
	private var sky:Skybox3D;
	private var precision:Bool;
	public function new(stage:hx.display.Stage, texture:SkyboxTexture3D) {
		scene = new Scene3D(128,128); scene.autoRender = false;
		scene.backgroundAlpha = 0; scene.backgroundColor = 0;
		var camera = new Camera3D(); camera.far=100; scene.root.addChild(camera);scene.camera=camera;
		geometry = new Geometry3D([-100.,-100.,-10.,100.,-100.,-10.,0.,100.,-10.],[0.,0.,1.,0.,0.,1.],[0,1,2],[0.,0.,1.,0.,0.,1.,0.,0.,1.]);
		base = new Material3D();base.color=0xff0000;base.cullMode=CullMode3D.NONE;materials.push(base);
		mesh = new MeshObject(geometry,base);scene.root.addChild(mesh);stage.addChild(scene);
		scene.fog.start=5;scene.fog.end=15;scene.fog.color=0x80a0c0;scene.ambientIntensity=1;
		sky = new Skybox3D(texture);sky.toneMapping=true;
		Reflect.setField(js.Browser.window,"__hxmakerFog",{state:state,pixel:pixel,command:command});
	}
	private function renderer():hx.render3d.openfl.Renderer3D {
		var render:hx.core.Render=cast Hxmaker.engine.renderer;
		var display=render.__scene3DDisplays.get(scene);return display==null?null:display.renderer3D;
	}
	private function state():Dynamic {
		var render=renderer();return {stats:scene.stats,version:scene.contentVersion,
			webgl:render==null||render.gl==null?"":Std.string(render.gl.getParameter(render.gl.VERSION)),
			error:render==null||render.gl==null||render.gl.isContextLost()?-1:render.gl.getError()};
	}
	private function pixel(x:Float=0.5,y:Float=0.5):Array<Int> {
		var render=renderer();if(render==null||render.gl==null||render.target==null||render.gl.isContextLost())return [];
		var gl=render.gl,previous:Dynamic=gl.getParameter(gl.FRAMEBUFFER_BINDING),value=new UInt8Array(4);
		gl.bindFramebuffer(gl.FRAMEBUFFER,render.target.framebuffer);
		gl.readPixels(Std.int(x*127),Std.int(y*127),1,1,gl.RGBA,gl.UNSIGNED_BYTE,value);
		gl.bindFramebuffer(gl.FRAMEBUFFER,previous);return [for(i in 0...4)value[i]];
	}
	private function command(name:String):Void {
		switch(name){
			case "linear":scene.fog.enabled=true;scene.fog.mode=FogMode3D.LINEAR;
			case "off":scene.fog.enabled=false;
			case "exp":scene.fog.enabled=true;scene.fog.mode=FogMode3D.EXP;scene.fog.start=0;scene.fog.density=0.1;
			case "exp2":scene.fog.mode=FogMode3D.EXP2;scene.fog.density=0.2;
			case "zero":scene.fog.density=0;
			case "partial":scene.fog.maxOpacity=0.5;
			case "full":scene.fog.maxOpacity=1;scene.fog.mode=FogMode3D.LINEAR;scene.fog.start=0;scene.fog.end=5;scene.fog.enabled=true;
			case "translate":scene.camera.z=5;
			case "reset":scene.camera.z=0;scene.fog.start=5;scene.fog.end=15;scene.fog.maxOpacity=1;scene.fog.enabled=true;scene.fog.mode=FogMode3D.LINEAR;
			case "lambert":var material=new LambertTextureMaterial(null,0xff0000);materials.push(material);mesh.material=material;
			case "pbr":var material=new PbrMaterial3D(null,0xff0000);material.lightingEnabled=true;material.emissive=[1,0,0];material.baseColorFactor=[0,0,0];material.toneMapping=false;materials.push(material);mesh.material=material;
			case "unlit":mesh.material=base;
			case "transparent":base.alphaMode=AlphaMode3D.BLEND;base.opacity=0.5;base.depthWrite=false;
			case "add":base.blendMode=BlendMode3D.ADD;
			case "soft":base.softParticleDistance=1;
			case "mask":base.alphaMode=AlphaMode3D.MASK;base.opacity=0.2;base.alphaCutoff=0.5;
			case "opaque":base.alphaMode=AlphaMode3D.OPAQUE;base.opacity=1;base.depthWrite=true;base.blendMode=BlendMode3D.NORMAL;base.softParticleDistance=0;
			case "sky":mesh.visible=false;scene.skybox=sky;
			case "skyFog":scene.fog.affectSkybox=true;
			case "bloom":scene.bloom.enabled=true;scene.bloom.threshold=0.2;
			case "low":var render=renderer();precision=render.fragmentDepthPrecision;render.fragmentDepthPrecision=false;scene.fog.mode=FogMode3D.EXP;scene.fog.density=1e6;scene.requestRender();
			case "high":renderer().fragmentDepthPrecision=precision;scene.fog.density=0.02;scene.requestRender();
			case "lose":var extension:Dynamic=renderer().gl.getExtension("WEBGL_lose_context");extension.loseContext();haxe.Timer.delay(()->extension.restoreContext(),500);
			default:throw "未知距离雾检查命令："+name;
		}
	}
	public function dispose():Void {Reflect.deleteField(js.Browser.window,"__hxmakerFog");scene.dispose();sky.dispose();geometry.dispose();for(material in materials)material.dispose();}
}
#end
