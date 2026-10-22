import hx.render3d.openfl.GLStateCache3D;
import lime.graphics.WebGLRenderContext;

/** 使用真实 WebGL 对照状态镜像与驱动查询，覆盖跨通道恢复所依赖的状态。 */
class GLStateCacheChecks {
	static var checks:Int = 0;
	static function same(actual:Dynamic, expected:Dynamic):Bool {
		if (actual == expected) return true;
		if (js.Syntax.typeof(actual) == "number" && js.Syntax.typeof(expected) == "number") return Math.abs(actual-expected)<0.000001;
		if (actual != null && expected != null && js.Syntax.typeof(actual.length) == "number" && actual.length == expected.length) {
			for (i in 0...Std.int(actual.length)) if (!same(actual[i],expected[i])) return false;
			return true;
		}
		return false;
	}
	static function check(gl:WebGLRenderContext, cache:GLStateCache3D, keys:Array<Int>):Void {
		for (key in keys) {
			if (!same(cache.query(key),gl.getParameter(key))) throw "状态镜像不一致："+key;
			checks++;
		}
	}
	static function main():Void {
		try { run(); } catch(error:Dynamic) { Reflect.setField(js.Browser.window,"__stateCacheError",Std.string(error)); }
	}
	static function run():Void {
		var canvas=js.Browser.document.createCanvasElement();
		var raw:Dynamic=canvas.getContext(js.Browser.location.search.indexOf("webgl1")>=0?"webgl":"webgl2");
		if(raw==null)throw "无法创建验证上下文";
		var gl:WebGLRenderContext=cast raw, cache=GLStateCache3D.obtain(gl);
		if(cache==null)throw "状态缓存未启用";
		var keys=[gl.CURRENT_PROGRAM,gl.ARRAY_BUFFER_BINDING,gl.ACTIVE_TEXTURE,gl.DEPTH_WRITEMASK,gl.BLEND_SRC_RGB,gl.BLEND_DST_RGB,
			gl.BLEND_SRC_ALPHA,gl.BLEND_DST_ALPHA,gl.BLEND_EQUATION_RGB,gl.BLEND_EQUATION_ALPHA,gl.FRAMEBUFFER_BINDING,gl.RENDERBUFFER_BINDING,
			gl.VIEWPORT,gl.SCISSOR_BOX,gl.DEPTH_FUNC,gl.DEPTH_CLEAR_VALUE,gl.DEPTH_RANGE,gl.COLOR_CLEAR_VALUE,gl.COLOR_WRITEMASK,
			gl.CULL_FACE_MODE,gl.FRONT_FACE,gl.UNPACK_ALIGNMENT,gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL,gl.UNPACK_FLIP_Y_WEBGL,gl.UNPACK_COLORSPACE_CONVERSION_WEBGL];
		check(gl,cache,keys);
		var before=cache.misses;check(gl,cache,keys);if(cache.misses!=before)throw "已知状态仍在重复查询";
		gl.viewport(2,3,128,64);gl.scissor(4,5,100,50);gl.depthMask(false);gl.depthFunc(gl.GREATER);gl.clearDepth(2);
		gl.depthRange(.2,.9);gl.clearColor(-1,.3,.7,2);gl.colorMask(true,false,true,false);gl.cullFace(gl.FRONT);gl.frontFace(gl.CW);
		gl.blendFunc(gl.SRC_ALPHA,gl.ONE_MINUS_SRC_ALPHA);gl.blendEquation(gl.FUNC_SUBTRACT);check(gl,cache,keys);
		gl.blendFuncSeparate(gl.ONE,gl.ZERO,gl.ZERO,gl.ONE);gl.blendEquationSeparate(gl.FUNC_ADD,gl.FUNC_REVERSE_SUBTRACT);
		gl.pixelStorei(gl.UNPACK_ALIGNMENT,1);gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL,1);gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL,1);check(gl,cache,keys);
		for(flag in [gl.BLEND,gl.CULL_FACE,gl.DEPTH_TEST,gl.SCISSOR_TEST,gl.STENCIL_TEST]) {
			gl.enable(flag);if(cache.isEnabled(flag)!=gl.isEnabled(flag))throw "启用状态不一致";
			gl.disable(flag);if(cache.isEnabled(flag)!=gl.isEnabled(flag))throw "禁用状态不一致";checks+=2;
		}
		var texture=gl.createTexture(),buffer=gl.createBuffer(),framebuffer=gl.createFramebuffer(),renderbuffer=gl.createRenderbuffer();
		gl.activeTexture(gl.TEXTURE1);gl.bindTexture(gl.TEXTURE_2D,texture);check(gl,cache,[gl.TEXTURE_BINDING_2D]);
		gl.activeTexture(gl.TEXTURE0);gl.bindTexture(gl.TEXTURE_2D,null);check(gl,cache,[gl.TEXTURE_BINDING_2D]);
		gl.activeTexture(gl.TEXTURE1);check(gl,cache,[gl.TEXTURE_BINDING_2D]);
		gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.bindFramebuffer(gl.FRAMEBUFFER,framebuffer);gl.bindRenderbuffer(gl.RENDERBUFFER,renderbuffer);check(gl,cache,keys);
		var extension:Dynamic=raw.bindVertexArray==null?gl.getExtension("OES_vertex_array_object"):null;
		var create:Void->Dynamic=raw.bindVertexArray==null?()->extension.createVertexArrayOES():()->raw.createVertexArray();
		var bind:Dynamic->Void=raw.bindVertexArray==null?v->extension.bindVertexArrayOES(v):v->raw.bindVertexArray(v);
		var indexBuffer=gl.createBuffer();
		var vao=create();bind(vao);gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER,indexBuffer);check(gl,cache,[0x85B5,gl.ELEMENT_ARRAY_BUFFER_BINDING]);
		bind(null);check(gl,cache,[0x85B5,gl.ELEMENT_ARRAY_BUFFER_BINDING]);bind(vao);check(gl,cache,[0x85B5,gl.ELEMENT_ARRAY_BUFFER_BINDING]);
		if(raw.bindVertexArray!=null) {
			var other=gl.createFramebuffer();raw.bindFramebuffer(0x8CA8,other);check(gl,cache,[gl.FRAMEBUFFER_BINDING,0x8CAA]);gl.deleteFramebuffer(other);
		}
		gl.deleteTexture(texture);gl.deleteBuffer(buffer);gl.deleteBuffer(indexBuffer);gl.deleteFramebuffer(framebuffer);gl.deleteRenderbuffer(renderbuffer);
		check(gl,cache,keys);check(gl,cache,[gl.TEXTURE_BINDING_2D,gl.ELEMENT_ARRAY_BUFFER_BINDING]);
		before=cache.misses;cache.query(gl.MAX_TEXTURE_SIZE);cache.query(gl.MAX_TEXTURE_SIZE);if(cache.misses!=before+2)throw "未知状态必须保留查询回退";
		if(gl.getError()!=gl.NO_ERROR)throw "验证产生 WebGL 错误";
		Reflect.setField(js.Browser.window,"__stateCacheChecks",{passed:checks,webgl:gl.getParameter(gl.VERSION)});
	}
}
