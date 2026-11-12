package;

import hx.core.Hxmaker;
import hx.core.Render;
import hx.display.BitmapData;
import hx.display.BlendMode;
import hx.display.Box;
import hx.display.DisplayObject;
import hx.display.Graphics;
import hx.display.IBitmapData;
import hx.display.Image;
import hx.display.Label;
import hx.display.TextFormat;
import hx.filters.RenderFilter;
import hx.render.TextFieldRender;
import hx.text.TextFieldContextBitmapData;
import hx.text.TextFieldAtlas;
import hx.text.FntFrame;
import hx.geom.ColorTransform;
import hx.geom.Matrix;
import hx.geom.Rectangle;
import hx.render.BufferBuildStats;
import hx.render.ImageBufferData;
import hx.shader.MultiTextureShader;

/** 运行真实组批和写缓冲代码，以独立全量路径逐批、逐分量对照。 */
@:access(hx.display.DisplayObject)
@:access(hx.core.Hxmaker)
@:access(hx.render.ImageBufferData)
@:access(hx.shader.MultiTextureShader)
class IncrementalBufferCheck {
	private static var checks:Int = 0;
	private static var seed:Int = 71361;
	private static var incremental:CaptureRender;
	private static var full:CaptureRender;

	private static function check(value:Bool, message:String):Void {
		checks++;
		if (!value) throw message;
	}

	private static function random(max:Int):Int {
		seed = (seed * 1664525 + 1013904223) | 0;
		return (seed >>> 1) % max;
	}

	private static function image(data:BitmapData, x:Float = 0):Image {
		var value:Image = new Image(data);
		value.x = x;
		value.__updateTransform(null);
		return value;
	}

	private static function compare(objects:Array<DisplayObject>, name:String):Void {
		incremental.begin();
		full.begin();
		for (object in objects) incremental.renderDisplayObject(object);
		incremental.endFill();
		for (object in objects) full.renderDisplayObject(object);
		full.endFill();
		check(incremental.snapshots.length == full.snapshots.length, name + "：批次数");
		for (i in 0...full.snapshots.length) {
			var a:BufferSnapshot = incremental.snapshots[i];
			var b:BufferSnapshot = full.snapshots[i];
			check(a.blend == b.blend && a.smoothing == b.smoothing && a.colors == b.colors, name + "：批次模式");
			check(a.textures.length == b.textures.length, name + "：纹理数量");
			for (j in 0...b.textures.length) check(a.textures[j] == b.textures[j], name + "：纹理顺序");
			check(a.values.length == b.values.length, name + "：缓冲长度");
			for (j in 0...b.values.length) {
				check(a.values[j] == b.values[j] || (Math.isNaN(a.values[j]) && Math.isNaN(b.values[j])),
					name + "：分量 " + j + "，增量=" + a.values[j] + "，全量=" + b.values[j]);
			}
		}
	}

	private static function main():Void {
		Hxmaker.__engine = cast {dt: 0.016, get_stageWidth: () -> 800., get_stageHeight: () -> 600.};
		MultiTextureShader.__supportedMultiTextureUnits = 3;
		incremental = CaptureRender.create(true);
		full = CaptureRender.create(false);
		#if buffer_mixed_benchmark
		mixedBenchmark();
		#elseif buffer_benchmark
		benchmark();
		#else
		correctness();
		trace("缓冲全量对照通过，检查次数：" + checks);
		#end
	}

	private static function correctness():Void {
		var texture:FakeBitmap = new FakeBitmap(128, 256);
		var data:BitmapData = BitmapData.formData(texture);
		data.rect = new Rectangle(4, 8, 24, 32);
		var a:Image = image(data);
		var b:Image = image(data, 30);
		var c:Image = image(data, 60);
		a.colorTransform = new ColorTransform();
		var objects:Array<DisplayObject> = [a, b, c];
		compare(objects, "首次");
		compare(objects, "稳定帧");
		#if hxmaker_buffer_stats
		BufferBuildStats.reset();
		incremental.begin();
		for (object in objects) incremental.renderDisplayObject(object);
		incremental.endFill();
		check(BufferBuildStats.reusedImages == 3 && BufferBuildStats.vertexWrites == 0
			&& BufferBuildStats.uvWrites == 0 && BufferBuildStats.indexWrites == 0
			&& BufferBuildStats.colorWrites == 0, "稳定帧不重写任何几何或颜色片段");
		#end
		// 不经过 setter 或世界版本，模拟字形直接写矩阵与公开数据原地修改。
		b.__worldTransform.tx += 7;
		compare(objects, "直接改世界矩阵");
		a.__colorTransform.redOffset = 31;
		a.__worldAlpha = 0.35;
		data.rect.x = 32;
		texture.width = 512;
		compare(objects, "原地修改颜色、透明度、UV与纹理尺寸");
		compare([b, c], "隐藏首项");
		compare([a, b, c], "首项恢复");
		compare([a, c, b], "中间换序");
		compare([a], "缩短");
		check(incremental.imageBufferData[0].__imageEntries.length == 1, "缩短后不保留旧尾部引用");
		compare(objects, "缩短后增长");
		a.colorTransform = null;
		compare(objects, "关闭颜色布局");
		a.colorTransform = new ColorTransform(0.3, 0.4, 0.8, 0.5, 1, 2, 3, 4);
		compare(objects, "恢复颜色布局");
		b.smoothing = false;
		compare(objects, "平滑切批");
		b.blendMode = ADD;
		compare(objects, "ADD与NORMAL混批");
		b.smoothing = true;
		compare(objects, "恢复合批");
		// 同一对象跨渲染器、同一批多次出现，两个缓冲均必须独立更新。
		compare([a, a, c, a], "同一对象重复出现");
		a.__worldTransform.c = 0.23;
		compare([a, a, c, a], "重复对象变换");
		data.rect = null;
		compare(objects, "移除裁切区域");
		data.rect = new Rectangle(2, 3, 9, 11);
		data.data = new FakeBitmap(256, 256);
		compare(objects, "相同数据对象替换根纹理");
		// 同根纹理不同视图、纹理上限变化与纹理ID重排。
		var images:Array<DisplayObject> = [];
		for (i in 0...12) images.push(image(BitmapData.formData(new FakeBitmap(64 + i, 64))));
		for (units in 1...5) {
			MultiTextureShader.__supportedMultiTextureUnits = units;
			compare(images, "纹理上限" + units);
			images.reverse();
			compare(images, "纹理重排" + units);
		}
		MultiTextureShader.__supportedMultiTextureUnits = 3;
		var graphic:Graphics = new Graphics();
		graphic.beginBitmapData(data);
		graphic.drawTriangles([0, 0, 20, 0, 0, 20], [0, 1, 2], [0, 0, 1, 0, 0, 1]);
		compare([a, graphic, b], "首次插入不规则网格");
		compare([a, graphic, b], "不规则网格持续存在");
		// 网格恰好替换一个四边形时，后方图片的物理片段仍可复用。
		incremental = CaptureRender.create(true); full = CaptureRender.create(false);
		compare([a, b, c], "四边形替换预热"); compare([a, b, c], "四边形替换稳定");
		var quadGraphic:Graphics = new Graphics(); quadGraphic.beginBitmapData(data); quadGraphic.drawRect(0, 0, 12, 16);
		compare([a, quadGraphic, c], "相同拓扑网格替换图片");
		#if hxmaker_buffer_stats
		BufferBuildStats.reset(); incremental.begin();
		for (object in [a, quadGraphic, c]) incremental.renderDisplayObject(object);
		incremental.endFill();
		check(BufferBuildStats.reusedImages == 2 && BufferBuildStats.vertexWrites == 0,
			"网格全量写入不污染前后已缓存的图片片段");
		#end
		// 同命令序号不等于同缓冲偏移：原地修改网格长度，图片必须安全重建。
		incremental = CaptureRender.create(true); full = CaptureRender.create(false);
		var meshVertices:Array<Float> = [0, 0, 20, 0, 0, 20];
		var meshIndices:Array<Int> = [0, 1, 2];
		var meshUVs:Array<Float> = [0, 0, 1, 0, 0, 1];
		var dynamicGraphic:Graphics = new Graphics();
		dynamicGraphic.beginBitmapData(data);
		dynamicGraphic.colorTransform = new ColorTransform();
		dynamicGraphic.drawTriangles(meshVertices, meshIndices, meshUVs);
		compare([dynamicGraphic, a, b, c], "首部网格预热");
		compare([dynamicGraphic, a, b, c], "首部网格稳定");
		#if hxmaker_buffer_stats
		BufferBuildStats.reset(); incremental.begin();
		for (object in [dynamicGraphic, a, b, c]) incremental.renderDisplayObject(object);
		incremental.endFill();
		check(BufferBuildStats.reusedImages == 3 && BufferBuildStats.vertexWrites == 0
			&& BufferBuildStats.uvWrites == 0 && BufferBuildStats.indexWrites == 0,
			"首部Graphics不再使同批图片失去缓存");
		#end
		meshVertices.push(20); meshVertices.push(20); meshUVs.push(1); meshUVs.push(1);
		dynamicGraphic.invalidate();
		compare([dynamicGraphic, a, b, c], "顶点增多而索引数不变");
		compare([dynamicGraphic, a, b, c], "顶点增多后稳定");
		meshIndices.push(1); meshIndices.push(2); meshIndices.push(3);
		dynamicGraphic.invalidate();
		compare([dynamicGraphic, a, b, c], "索引增多而顶点数不变");
		compare([dynamicGraphic, a, b, c], "索引增多后稳定");
		meshVertices.resize(6); meshUVs.resize(6); meshIndices.resize(3);
		dynamicGraphic.invalidate();
		compare([dynamicGraphic, a, b, c], "网格缩短");
		meshVertices[0] = 7; dynamicGraphic.invalidate();
		compare([dynamicGraphic, a, b, c], "网格只改数值");
		compare([a, dynamicGraphic, a, c], "同一图片跨网格重复出现");
		compare([dynamicGraphic, dynamicGraphic], "纯图形替换图片记录");
		check(incremental.imageBufferData[0].__imageEntries.length == 0, "纯图形不持有空图片记录尾部");
		for (frame in 0...180) {
			dynamicGraphic.clear(); dynamicGraphic.beginBitmapData(data);
			for (i in 0...1 + frame % 4) dynamicGraphic.drawRect(i * 8, 0, 12, 16);
			var mixed:Array<DisplayObject> = frame % 2 == 0 ? [a, dynamicGraphic, b, dynamicGraphic, c] : [dynamicGraphic, a, b, c];
			compare(mixed, "混排网格命令数变化" + frame);
		}
		// 同一个 Graphics 跨纹理上限拆成多批，命令恢复游标不能污染图片槽位。
		var materials:Graphics = new Graphics();
		materials.colorTransform = new ColorTransform();
		for (i in 0...4) {
			materials.beginBitmapData(BitmapData.formData(new FakeBitmap(32 + i, 32)));
			materials.drawRect(i * 10, 0, 8, 8);
		}
		MultiTextureShader.__supportedMultiTextureUnits = 1;
		compare([a, materials, b, c], "Graphics命令跨批恢复");
		compare([a, materials, b, c], "Graphics跨批稳定");
		MultiTextureShader.__supportedMultiTextureUnits = 3;
		compare([a, materials, b, c], "Graphics跨批边界变化");
		// 连续移动图片偏移的网格应退让，布局稳定后仍能恢复。
		incremental = CaptureRender.create(true); full = CaptureRender.create(false);
		for (i in 0...6) {
			dynamicGraphic.clear(); dynamicGraphic.beginBitmapData(data);
			for (j in 0...1 + i % 3) dynamicGraphic.drawRect(j * 5, 0, 4, 4);
			compare([dynamicGraphic, a, b, c], "动态网格布局退让" + i);
		}
		check(incremental.imageBufferData[0].__fullBuildsRemaining > 0, "持续布局失配使混排批次退让");
		for (i in 0...66) compare([dynamicGraphic, a, b, c], "混排布局稳定恢复" + i);
		#if hxmaker_buffer_stats
		BufferBuildStats.reset(); incremental.begin();
		for (object in [dynamicGraphic, a, b, c]) incremental.renderDisplayObject(object);
		incremental.endFill();
		check(BufferBuildStats.reusedImages == 3 && BufferBuildStats.vertexWrites == 0,
			"变长网格稳定后恢复图片缓存");
		#end
		compare(objects, "移除不规则网格");
		compare(objects, "恢复稳定纯图片");
		// 非正常结束的构建不能晋升为缓存。
		incremental.begin();
		incremental.renderDisplayObject(c);
		compare(objects, "未结束构建后重置");
		incremental.begin(); incremental.renderDisplayObject(dynamicGraphic); incremental.renderDisplayObject(a);
		compare(objects, "混排中断后切回纯图片");
		compare([dynamicGraphic, a, b, c], "混排中断后再次进入混排");
		incremental.incrementalBufferEnabled = false;
		compare(objects, "关闭增量");
		incremental.incrementalBufferEnabled = true;
		compare(objects, "重新启用增量");
		incremental.enableRenderFilterDisplayObject = a;
		compare(objects, "离屏源保护");
		incremental.enableRenderFilterDisplayObject = null;
		compare(objects, "离屏源保护退出");
		// 遮罩、shader 和滤镜只测试真实控制流与回退，提交由捕获器替换。
		var masked:Box = new Box();
		masked.maskRect = new Rectangle(0, 0, 100, 100);
		masked.addChild(a);
		masked.__updateTransform(null);
		compare([masked, b], "遮罩作用域回退");
		check(incremental.visits == 3, "特殊作用域不能重复调用公开绘制入口的覆写");
		check(!incremental.suppressed(), "遮罩退出恢复增量作用域");
		masked.maskRect = null;
		var shader:MultiTextureShader = Type.createEmptyInstance(MultiTextureShader);
		a.shader = shader;
		compare([a, b], "自定义shader回退");
		a.shader = null;
		var filter:RenderFilter = new RenderFilter(); filter.render = c;
		a.filters = [filter];
		compare([a, b], "滤镜输出回退");
		a.filters = [new FailingFilter()];
		var failed:Bool = false;
		try { incremental.renderDisplayObject(a); } catch (error:Dynamic) { failed = true; }
		check(failed && !incremental.suppressed(), "滤镜异常后恢复作用域");
		a.filters = null;
		compare(objects, "异常后的正常构建");
		incremental.bitmapMode(true);
		compare(objects, "cacheAsBitmap回退");
		incremental.bitmapMode(false);
		// 真实 Label 排字、字形对象池和直接世界矩阵同步。
		var context:TextFieldContextBitmapData = Type.createEmptyInstance(TextFieldContextBitmapData);
		context.fontSize = 24;
		var atlas:TextFieldAtlas = Type.createEmptyInstance(TextFieldAtlas);
		var glyph:FntFrame = new FntFrame(atlas);
		glyph.xadvance = 12;
		glyph.data = data;
		untyped atlas.getCharFntFrame = function(char:String):FntFrame return glyph;
		untyped context.getAtlas = function(char:String):TextFieldAtlas return char == " " || char == "\n" ? null : atlas;
		untyped context.drawText = function(text:String):Void {};
		TextFieldRender.setTextFieldContextBitmapData(0, context);
		var label:Label = new Label("缓存字形abcd", new TextFormat(null, 24, 0xff8800));
		TextFieldRender.prepareLabel(label);
		compare([label], "真实字形首次"); compare([label], "真实字形稳定");
		label.x = 30; label.rotation = 17; label.alpha = 0.4; label.__updateTransform(null);
		compare([label], "真实字形父变换和透明度");
		label.data = "文字\n替换";
		TextFieldRender.prepareLabel(label);
		compare([label], "字形池重新排字"); compare([label], "字形池复用后稳定");
		glyph.data = BitmapData.formData(new FakeBitmap(512, 512));
		glyph.data.rect = new Rectangle(32, 12, 16, 20);
		TextFieldRender.prepareLabel(label);
		compare([label], "替换文字图集");
		// 容器遍历、父级版本变化、显隐及重新挂载。
		var root:Box = new Box(); root.addChild(a); root.addChild(b); root.addChild(label);
		root.__updateTransform(null); compare([root], "容器遍历");
		root.x = 18; root.scaleY = 0.7; root.rotation = 11; root.alpha = 0.6;
		root.__updateTransform(null); compare([root], "父级全部变换");
		b.visible = false; compare([root], "容器子项隐藏");
		b.visible = true; root.addChild(a); root.__updateTransform(null); compare([root], "重挂与排序");
		// 长短交替可使 Vector 尾部真实丢失，必须重写恢复的片段。
		var many:Array<DisplayObject> = [];
		for (i in 0...1000) many.push(image(data, i));
		compare(many, "1000项");
		compare(many.slice(0, 10), "10项");
		compare(many, "恢复1000项");
		// 最坏低命中触发批次退让，之后恢复静态仍可重新进入增量模式。
		var dynamicImages:Array<DisplayObject> = [];
		for (i in 0...16) {
			var value:Image = image(data, i); value.colorTransform = new ColorTransform(); dynamicImages.push(value);
		}
		compare(dynamicImages, "动态批次预热");
		for (i in 0...3) {
			data.rect.x += 1;
			for (object in dynamicImages) {
				object.__worldTransform.tx += 1; object.__colorTransform.redOffset += 1;
			}
			compare(dynamicImages, "动态批次探测" + i);
		}
		check(incremental.imageBufferData[0].__fullBuildsRemaining > 0, "低收益完整颜色批次进入全量退让");
		for (i in 0...66) compare(dynamicImages, "退让及恢复" + i);
		#if hxmaker_buffer_stats
		BufferBuildStats.reset(); incremental.begin();
		for (object in dynamicImages) incremental.renderDisplayObject(object);
		incremental.endFill();
		check(BufferBuildStats.reusedImages == 16 && BufferBuildStats.vertexWrites == 0, "稳定后重新恢复缓存命中");
		#end
		// 确定性随机变更，逐帧与未启用缓存的真实写入路径对照。
		for (frame in 0...1200) {
			var selected:Image = cast images[random(images.length)];
			switch random(8) {
				case 0: images.reverse();
				case 1: selected.__worldTransform.tx = random(500); selected.__worldTransform.d = random(10) / 4;
				case 2: selected.__worldAlpha = random(100) / 100;
				case 3: selected.smoothing = !selected.smoothing;
				case 4: selected.colorTransform = random(2) == 0 ? null : new ColorTransform(random(10) / 10);
				case 5: selected.data.rect = random(2) == 0 ? null : new Rectangle(random(20), 4, 13, 15);
				case 6: selected.blendMode = random(2) == 0 ? ADD : NORMAL;
				case 7: MultiTextureShader.__supportedMultiTextureUnits = 1 + random(4);
			}
			compare(images.slice(0, random(images.length) + 1), "随机帧" + frame);
		}
	}

	private static function mixedBenchmark():Void {
		var data:BitmapData = BitmapData.formData(new FakeBitmap(256, 256));
		data.rect = new Rectangle(8, 16, 24, 32);
		var images:Array<Image> = [];
		for (i in 0...4000) images.push(image(data, i));
		var graphic:Graphics = new Graphics();
		graphic.beginBitmapData(data); graphic.drawRect(0, 0, 16, 16);
		var modes:Array<String> = ["首部网格", "中间网格", "每100图片一个网格", "持续变长网格", "纯Graphics"];
		for (mode in 0...modes.length) {
			var baseline:Array<Float> = [];
			var cached:Array<Float> = [];
			var bufferA:ImageBufferData = new ImageBufferData();
			var bufferB:ImageBufferData = new ImageBufferData();
			for (frame in 0...450) {
				if (mode == 3) {
					graphic.clear(); graphic.beginBitmapData(data);
					for (i in 0...1 + frame % 3) graphic.drawRect(i * 16, 0, 16, 16);
				}
				for (pass in 0...2) {
					var useCache:Bool = (frame + pass) % 2 == 0;
					var buffer:ImageBufferData = useCache ? bufferA : bufferB;
					var renderer:CaptureRender = useCache ? incremental : full;
					var begin:Float = js.Syntax.code("performance.now()");
					buffer.reset();
					if (mode == 0 || mode == 3) buffer.drawGraphic(graphic, renderer);
					for (i in 0...images.length) {
						if (mode == 4) {
							buffer.drawGraphic(graphic, renderer);
						} else {
							if ((mode == 1 && i == 2000) || (mode == 2 && i % 100 == 0)) buffer.drawGraphic(graphic, renderer);
							buffer.draw(images[i], renderer);
						}
					}
					buffer.endFill();
					var elapsed:Float = js.Syntax.code("performance.now()") - begin;
					if (frame >= 100) (useCache ? cached : baseline).push(elapsed);
				}
			}
			baseline.sort(Reflect.compare); cached.sort(Reflect.compare);
			trace(modes[mode] + "：全量中位数=" + baseline[175] + "ms，增量=" + cached[175]
				+ "ms；P95=" + baseline[332] + "/" + cached[332] + "ms");
		}
	}

	private static function benchmark():Void {
		var data:BitmapData = BitmapData.formData(new FakeBitmap(256, 256));
		data.rect = new Rectangle(16, 32, 24, 36);
		var images:Array<Image> = [];
		for (i in 0...4000) images.push(image(data, i));
		var modes:Array<String> = ["静止多数", "全部移动", "持续换序", "全部属性变化", "完整颜色静止", "完整颜色全动态"];
		for (mode in 0...modes.length) {
			if (mode == 4) for (value in images) value.colorTransform = new ColorTransform(0.8, 0.7, 0.9, 1, 2, 3, 4, 0);
			var baseline:Array<Float> = [];
			var cached:Array<Float> = [];
			var bufferA:ImageBufferData = new ImageBufferData();
			var bufferB:ImageBufferData = new ImageBufferData();
			// 只测缓冲构建，排除快照分配、场景更新与实际提交。
			for (frame in 0...450) {
				if (mode == 0) images[0].__worldTransform.tx += 1;
				if (mode == 1 || mode == 3 || mode == 5) for (value in images) value.__worldTransform.tx += 1;
				if (mode == 2) images.reverse();
				if (mode == 3 || mode == 5) {
					data.rect.x = frame % 32;
					for (value in images) {
						value.__worldAlpha = (frame % 100) / 100;
						if (mode == 5) value.__colorTransform.redMultiplier = (frame % 100) / 100;
					}
				}
				// 交替测量顺序，避免总让一种模式享受更热的输入缓存。
				for (pass in 0...2) {
					var useCache:Bool = (frame + pass) % 2 == 0;
					var buffer:ImageBufferData = useCache ? bufferA : bufferB;
					var renderer:CaptureRender = useCache ? incremental : full;
					var begin:Float = js.Syntax.code("performance.now()");
					buffer.reset();
					for (value in images) buffer.draw(value, renderer);
					buffer.endFill();
					var elapsed:Float = js.Syntax.code("performance.now()") - begin;
					if (frame >= 100) (useCache ? cached : baseline).push(elapsed);
				}
			}
			baseline.sort(Reflect.compare); cached.sort(Reflect.compare);
			trace(modes[mode] + "：全量中位数=" + baseline[175] + "ms，增量=" + cached[175]
				+ "ms；P95=" + baseline[332] + "/" + cached[332] + "ms");
		}
	}
}

/** 仅替换 GPU 提交，保留真实遍历、切批、纹理登记和属性写入。 */
@:access(hx.core.Render)
class CaptureRender extends Render {
	public var snapshots:Array<BufferSnapshot>;
	public var visits:Int;
	override public function renderDisplayObject(object:DisplayObject):Void {
		visits++;
		super.renderDisplayObject(object);
	}

	public static function create(enabled:Bool):CaptureRender {
		var renderer:CaptureRender = Type.createEmptyInstance(CaptureRender);
		renderer.incrementalBufferEnabled = enabled;
		renderer.__incrementalSuppressed = false;
		renderer.__cacheAsBitmap = false;
		renderer.imageBufferData = [];
		renderer.snapshots = [];
		return renderer;
	}

	public function suppressed():Bool return __incrementalSuppressed;
	public function bitmapMode(value:Bool):Void { __cacheAsBitmap = value; }
	override public function setMask(value:Bool):Void {}

	public function begin():Void {
		visits = 0;
		snapshots.resize(0);
		drawImageBuffDataIndex = 0;
		createImageBufferData(0);
	}

	override public function renderImageBuffData(data:ImageBufferData):openfl.display.Sprite {
		if (data.index == 0) return null;
		data.endFill();
		snapshots.push(new BufferSnapshot(data));
		drawImageBuffDataIndex++;
		createImageBufferData(drawImageBuffDataIndex);
		return null;
	}
}

class BufferSnapshot {
	public var values:Array<Float> = [];
	public var textures:Array<openfl.display.BitmapData>;
	public var blend:BlendMode;
	public var smoothing:Bool;
	public var colors:Bool;

	public function new(buffer:ImageBufferData) {
		// 各段长度也写入，防止相邻属性抵消长度错误。
		values.push(buffer.vertices.length); for (v in buffer.vertices) values.push(v);
		values.push(buffer.indices.length); for (v in buffer.indices) values.push(v);
		values.push(buffer.uvtData.length); for (v in buffer.uvtData) values.push(v);
		for (array in [buffer.ids, buffer.alphas, buffer.addBlendModes, buffer.hasColorTransform, buffer.colorMultiplier, buffer.colorOffset]) {
			values.push(array.length); for (v in array) values.push(v);
		}
		textures = buffer.bitmapDatas.copy();
		blend = buffer.blendMode; smoothing = buffer.smoothing; colors = buffer.enabledColorTransform;
	}
}

/** 纹理内容不参与缓冲构建，只模拟原生纹理身份和尺寸。 */
class FakeBitmap implements IBitmapData {
	public var width:Int;
	public var height:Int;
	private var texture:Dynamic = {};
	public function new(width:Int, height:Int) { this.width = width; this.height = height; }
	public function getTexture():Dynamic return texture;
	public function getWidth():Int return width;
	public function getHeight():Int return height;
	public function clear(?rect:Rectangle):Void {}
	public function draw(source:DisplayObject, matrix:Matrix, ?blendMode:BlendMode, updateTransform:Bool = true):Void {}
	public function dispose():Void {}
}

/** 验证异常恢复，不模拟错误的全量输出。 */
class FailingFilter extends RenderFilter {
	override public function update(source:DisplayObject, dt:Float):Void { throw "预期的滤镜异常"; }
}
