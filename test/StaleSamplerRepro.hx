package;

import hx.core.Render;
import hx.render.ImageBufferData;
import hx.shader.MultiTextureShader;
import openfl.display.BitmapData;
import openfl.display.ShaderInput;

/** 对照真实 setBatchTextures 实现；旧基线必须复现残留，修复版本必须移除残留。 */
@:access(hx.core.Render)
class StaleSamplerRepro {
	private static function main():Void {
		var first:BitmapData = new BitmapData(8, 8, true, 0xffffffff);
		var old:BitmapData = new BitmapData(8, 8, true, 0xffffffff);
		var a:ShaderInput<BitmapData> = new ShaderInput(); var b:ShaderInput<BitmapData> = new ShaderInput();
		var shader:MultiTextureShader = Type.createEmptyInstance(MultiTextureShader);
		shader.data = cast {uSampler0:a, uSampler1:b};
		#if !expect_stale_sampler
		shader.batchTextureSlots = ["uSampler0", "uSampler1"];
		#end
		var renderer:Render = Type.createEmptyInstance(Render); renderer.currentShader = shader;
		var data:ImageBufferData = new ImageBufferData(); data.bitmapDatas = [first, old];
		renderer.setBatchTextures(data, false);
		data.bitmapDatas = [first]; old.dispose(); renderer.setBatchTextures(data, false);
		#if expect_stale_sampler
		if (b.input != old || b.input.width != 0) throw "旧基线没有复现历史槽残留";
		trace("旧基线已复现：第二槽仍引用尺寸归零的已释放位图");
		#else
		if (b.input != first || b.input.width != 8) throw "修复版本仍残留已释放输入";
		trace("修复版本通过：第二槽已更新为当前批次合法输入");
		#end
		first.dispose();
	}
}
