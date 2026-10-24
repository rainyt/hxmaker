package;

import hx.core.Engine;
import hx.core.Render;
import hx.display.BlendMode;
import hx.display.DisplayObject;
import hx.display.IBitmapData;
import hx.filters.StageBitmapData;
import hx.geom.Matrix;
import hx.geom.Rectangle;
import hx.render.ImageBufferData;
import hx.render3d.openfl.TextureBridge3D;
import hx.shader.MultiTextureShader;
import hx.utils.ContextStats;
import openfl.display.BitmapData;
import openfl.display.Shader;
import openfl.display.ShaderInput;

/** 只记录释放次数，不创建 GPU 纹理。 */
private class PoolBitmap implements IBitmapData {
	public var disposed:Int = 0;
	public function new() {}
	public function getTexture():Dynamic return null;
	public function getWidth():Int return 16;
	public function getHeight():Int return 16;
	public function clear(?rect:Rectangle):Void {}
	public function draw(source:DisplayObject, matrix:Matrix, ?blendMode:BlendMode, updateTransform:Bool = true):Void {}
	public function dispose():Void { disposed++; }
}

/** 检查静止画面、闲置回收、强制失效与批次缩小时的纹理生命周期，不创建 GPU。 */
@:access(hx.filters.StageBitmapData)
@:access(hx.core.Render)
@:access(hx.core.Engine)
@:access(hx.shader.MultiTextureShader)
class BlendModeTextureLifetimeChecks {
	private static function check(value:Bool, message:String):Void {
		if (!value) throw message;
	}

	private static function checkPoolLifetime():Void {
		var first = new PoolBitmap();
		var second = new PoolBitmap();
		var idle = new PoolBitmap();
		StageBitmapData.__pool = [first, second, idle];
		StageBitmapData.__poolIndex = 2;
		StageBitmapData.__cacheSize = 0;
		StageBitmapData.__lastUpdateTime = 0;
		ContextStats.reset();
		StageBitmapData.update(7);
		check(first.disposed == 0 && second.disposed == 0, "画面静止超过六秒，仍在显示的纹理不能释放");
		check(idle.disposed == 1 && StageBitmapData.counts == 2, "超时应只回收闲置尾部");
		StageBitmapData.update(7);
		check(first.disposed == 0 && second.disposed == 0, "多轮空闲更新也必须保留画面引用");

		// 模拟重建为没有混合模式的画面，旧结果才真正闲置。
		StageBitmapData.resetPool();
		StageBitmapData.update(7);
		check(first.disposed == 1 && second.disposed == 1 && StageBitmapData.counts == 0,
			"下一次遍历不再使用纹理后，应允许回收");

		var cached = new PoolBitmap();
		var extra = new PoolBitmap();
		StageBitmapData.__pool = [cached, extra];
		StageBitmapData.__cacheSize = 1;
		StageBitmapData.disposeAll();
		check(cached.disposed == 0 && extra.disposed == 1 && StageBitmapData.counts == 1,
			"普通回收必须保留预设缓存容量");
		StageBitmapData.__poolIndex = 1;
		StageBitmapData.disposeAll(true);
		check(cached.disposed == 1 && StageBitmapData.counts == 0 && StageBitmapData.__poolIndex == 0,
			"强制失效必须清空全部实例，即使池大小没有超过缓存容量");
		check(StageBitmapData.__cacheSize == 1, "强制失效后应保留缓存容量配置");
		StageBitmapData.__cacheSize = 0;
	}

	private static function checkBatchTextures():Void {
		var current = Type.createEmptyInstance(BitmapData);
		var stale = Type.createEmptyInstance(BitmapData);
		var mask = Type.createEmptyInstance(BitmapData);
		var inputs:Array<ShaderInput<BitmapData>> = [];
		for (index in 0...3) {
			var input = new ShaderInput<BitmapData>();
			input.input = stale;
			inputs.push(input);
		}
		var shader = Type.createEmptyInstance(Shader);
		shader.data = cast {uSampler0:inputs[0], uSampler1:inputs[1], uSampler2:inputs[2]};
		var renderer = Type.createEmptyInstance(Render);
		renderer.currentShader = shader;
		var batch = Type.createEmptyInstance(ImageBufferData);
		batch.bitmapDatas = [current];
		batch.smoothing = false;
		var oldUnits = MultiTextureShader.__supportedMultiTextureUnits;
		var oldEnabled = MultiTextureShader.multiTextureEnabled;
		MultiTextureShader.__supportedMultiTextureUnits = 3;
		MultiTextureShader.multiTextureEnabled = true;
		try {
			renderer.setBatchTextures(batch, true);
			for (input in inputs)
				check(input.input == current, "默认批次缩小时，空余槽不能保留历史纹理引用");
			inputs[1].input = mask;
			renderer.setBatchTextures(batch, false);
			check(inputs[0].input == current && inputs[1].input == mask,
				"自定义滤镜额外设置的背景或遮罩输入不能被默认槽清理覆盖");
		} catch (error:Dynamic) {
			MultiTextureShader.__supportedMultiTextureUnits = oldUnits;
			MultiTextureShader.multiTextureEnabled = oldEnabled;
			throw error;
		}
		MultiTextureShader.__supportedMultiTextureUnits = oldUnits;
		MultiTextureShader.multiTextureEnabled = oldEnabled;
	}

	private static function checkDeferredResize():Void {
		var oldTexture = new PoolBitmap();
		StageBitmapData.__pool = [oldTexture];
		StageBitmapData.__poolIndex = 1;
		StageBitmapData.__cacheSize = 0;
		var events:Array<String> = [];
		var renderer = Type.createEmptyInstance(Render);
		// 尺寸事件尚未进入下一帧时，OpenFL 仍可能绘制旧批次。
		untyped renderer.clear = function():Void {
			check(oldTexture.disposed == 0, "拆除旧批次之前不能释放其纹理");
			events.push("拆除旧批次");
			StageBitmapData.resetPool();
		};
		untyped renderer.onStageSizeChange = function():Void {
			check(oldTexture.disposed == 1 && StageBitmapData.counts == 0, "重建目标前必须完成旧纹理释放");
			events.push("重建目标");
		};
		var engine = Type.createEmptyInstance(Engine);
		engine.renderer = renderer;
		engine.stages = [];
		engine.requestStageBitmapReset();
		engine.requestStageBitmapReset();
		check(oldTexture.disposed == 0 && engine.__stageBitmapResetPending,
			"多个尺寸事件应合并为待重建状态，旧画面纹理在帧间仍然有效");
		engine.beginRenderFrame();
		check(events.join(" → ") == "拆除旧批次 → 重建目标" && !engine.__stageBitmapResetPending,
			"帧入口必须按拆除、释放、重建的顺序消费尺寸变化请求");
	}

	private static function checkInvalidTextureMessage():Void {
		var message = "";
		try {
			TextureBridge3D.resolve(null, null, "二维着色器输入 uSampler1");
		} catch (error:Dynamic) {
			message = Std.string(error);
		}
		check(StringTools.contains(message, "二维着色器输入 uSampler1") && StringTools.contains(message, "缺少纹理位图"),
			"错误必须指出实际使用方及无效原因");
		check(!StringTools.contains(message, "分离 Alpha"), "缺少位图不能误报为压缩纹理");
	}

	private static function main():Void {
		checkPoolLifetime();
		checkDeferredResize();
		checkBatchTextures();
		checkInvalidTextureMessage();
		trace("混合模式纹理生命周期检查完成");
	}
}
