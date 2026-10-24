package;

import hx.render2d.openfl.DirectBatchRenderer;
import hx.render3d.openfl.RenderStateGuard3D;
import hx.render3d.openfl.TextureBridge3D;
import openfl.display.BitmapData;
import openfl.display.OpenGLRenderer;
import openfl.display.Shader;
import openfl.display.ShaderInput;
import openfl.display._internal.ShaderBuffer;
import openfl.display3D.Context3D;
import openfl.display3D.textures.TextureBase;

/** 对照 OpenFL 实际的 sampler 编号方法，使用记录型 GL 检查纹理绑定，不创建 GPU。 */
@:access(hx.render2d.openfl.DirectBatchRenderer)
@:access(hx.render3d.openfl.RenderStateGuard3D)
@:access(openfl.display.Shader)
@:access(openfl.display.ShaderInput)
class DirectBatchSamplerChecks {
	static function check(value:Bool, message:String):Void {
		if (!value) throw message;
	}

	static function input(name:String, location:Dynamic):ShaderInput<BitmapData> {
		var result = new ShaderInput<BitmapData>();
		result.name = name;
		result.index = location;
		return result;
	}

	static function main():Void {
		var activeSlot = 0;
		var uniformUnits:Map<Int, Int> = [];
		var bindings:Map<Int, Dynamic> = [];
		bindings.set(0, "原绑定");
		bindings.set(1, "上一批次的离屏目标");
		bindings.set(2, "上一批次的图片");
		var gl:Dynamic = {
			TEXTURE0: 33984,
			TEXTURE_2D: 3553,
			TEXTURE_BINDING_2D: 32873,
			activeTexture: function(value:Int):Void { activeSlot = value - 33984; },
			bindTexture: function(target:Int, texture:Dynamic):Void { bindings.set(activeSlot, texture); },
			getParameter: function(key:Int):Dynamic { return bindings.get(activeSlot); },
			uniform1i: function(location:Int, unit:Int):Void { uniformUnits.set(location, unit); }
		};
		var context:Context3D = cast {gl: gl, __context: {type: "webgl"}};
		var renderer:OpenGLRenderer = cast {__context3D: context};
		var buffer = new ShaderBuffer();
		buffer.inputRefs = [input("unusedBefore", null), input("background", 0), input("unusedBetween", -1),
			input("emptyActive", 5), input("source", 9)];
		buffer.inputCount = buffer.inputRefs.length;
		var background = Type.createEmptyInstance(BitmapData);
		var source = Type.createEmptyInstance(BitmapData);
		var unused = Type.createEmptyInstance(BitmapData);
		buffer.inputs = [unused, background, unused, null, source];
		for (ref in buffer.inputRefs) {
			buffer.inputFilter.push(ref.filter);
			buffer.inputMipFilter.push(ref.mipFilter);
			buffer.inputWrap.push(ref.wrap);
		}

		// 使用 OpenFL 的真实编号方法作为参照，不在检查中重复实现编号规则。
		var shader = Type.createEmptyInstance(Shader);
		shader.__context = context;
		shader.__inputBitmapData = buffer.inputRefs;
		shader.__enableGL();
		check(uniformUnits.get(0) == 0 && uniformUnits.get(5) == 1 && uniformUnits.get(9) == 2,
			"OpenFL 的 sampler 编号规则发生变化，需要重新核对直接渲染协议");

		var guard = Type.createEmptyInstance(RenderStateGuard3D);
		guard.gl = cast gl;
		guard.textures = [];
		guard.parameters = [];
		guard.queryCount = guard.textureSlotCount = 0;
		var direct = new DirectBatchRenderer();
		direct.gl = cast gl;
		var resolved = 0;
		var originalResolve = TextureBridge3D.resolve;
		untyped TextureBridge3D.resolve = function(bitmap:BitmapData, unusedContext:Dynamic):TextureBase {
			check(bitmap != unused, "未使用的 sampler 不能上传纹理或占用纹理单元");
			resolved++;
			return cast {
				__textureID: bitmap == background ? "背景纹理" : "当前图片",
				__samplerState: null,
				__setSamplerState: function(state:Dynamic):Void {}
			};
		};
		try {
			direct.bindNativeTextures(buffer, renderer, guard);
			check(bindings.get(uniformUnits.get(0)) == "背景纹理", "背景 sampler 与实际绑定的纹理单元不一致");
			check(bindings.get(uniformUnits.get(9)) == "当前图片", "源图片 sampler 与实际绑定的纹理单元不一致");
			check(bindings.get(uniformUnits.get(5)) == null, "空活动输入仍在采样上一批次的纹理");
			check(resolved == 2 && guard.textureSlotCount == 3, "空活动输入必须占位，未使用输入必须跳过");
			check(guard.textures.get(1) == "上一批次的离屏目标", "解绑前必须保存旧绑定以供状态恢复");
		} catch (error:Dynamic) {
			untyped TextureBridge3D.resolve = originalResolve;
			throw error;
		}
		untyped TextureBridge3D.resolve = originalResolve;
		trace("直接渲染 sampler 映射检查完成");
	}
}
