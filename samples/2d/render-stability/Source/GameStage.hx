package;

import hx.core.Engine;
import hx.core.Hxmaker;
import hx.core.OpenFlBitmapData;
import hx.core.Render;
import hx.display.BitmapData;
import hx.display.Image;
import hx.display.Label;
import hx.display.Quad;
import hx.display.Sprite;
import hx.filters.GeryFilter;
import hx.filters.StageBitmapData;
import hx.render2d.openfl.DirectBatchDisplay;
import hx.render2d.openfl.DirectBatchRenderer;
import hx.render2d.openfl.RenderDiagnostics;
import hx.render2d.openfl.TextureLifetime;
import hx.shader.MultiTextureShader;

/** 可由自动化和人工共用的确定性场景；固定色块用于像素验收。 */
@:access(hx.display.DisplayObject)
@:access(hx.core.Render)
@:access(hx.core.Engine)
class GameStage extends hx.display.Stage {
	private var content:Sprite;
	private var gray:Image;
	private var grayFilter:GeryFilter;
	private var shared:MultiTextureShader;
	private var first:Image;
	private var second:Image;
	private var layerMask:Quad;
	private var eraseMask:Quad;
	private var textureGroup:Sprite;
	private var textureSources:Array<BitmapData> = [];
	private var backing:Array<BitmapData> = [];
	private var cycles:Int = 0;
	private var phase:Int = 0;
	private var updateCount:Int = 0;
	private var checks:Array<String> = [];
	private var probe:Render;
	private var leaseBatch:DirectBatchDisplay;
	private var leaseRaw:openfl.display.BitmapData;
	private var faultData:BitmapData;
	private var manualRemaining:Int = 0;
	private var manualStatus:Label;
	#if hx_astcenc
	private var astcData:BitmapData;
	private var astcReady:Bool = false;
	private var astcError:String;
	#end

	/** 建立对照图和自动化入口，不自动宣告真机通过。 */
	override public function onStageInit():Void {
		super.onStageInit();
		addChild(new Quad(960, 640, 0x162134));
		text("渲染稳定性验证：纹理槽、快照、池、滤镜、恢复", 24, 18);
		shared = new MultiTextureShader();
		build();
		#if wechat_zygame_dom
		installManualControls();
		#end
		protocolChecks();
		#if hx_astcenc
		loadASTC();
		#end
		#if (js && html5)
		untyped js.Browser.window.__stability = {
			snapshot:snapshot,
			nested:nestedState,
			step:step,
			clean:function():Void { StageBitmapData.disposeAll(); hx.net.RequestQueue.collectUnused(); },
			protocol:protocolChecks,
			inject:inject,
			feedback:feedback,
			clearFault:clearFault,
			settle:function():Void { if (probe != null) probe.clear(); },
			lose:lose,
			textures:setTextureCount,
			compiled:compiledLimit,
			resize:function(width:Int, height:Int):Void {
				#if (js && html5)
				js.Browser.window.dispatchEvent(new js.html.Event("resize"));
				#end
			},
			foreground:function(visible:Bool):Void { cast(Hxmaker.engine, Engine).setApplicationVisible(visible); },
			memory:function():Void { cast(Hxmaker.engine, Engine).requestMemorySweep(); },
			masks:function(enabled:Bool):Void { layerMask.visible = enabled; eraseMask.visible = enabled; invalidate(); },
			reset:function():Void { phase = 0; cycles = 0; build(); },
			ready:true
		};
		#end
	}
	/** 真机入口使用引擎按钮，微信没有浏览器 DOM 控件也能执行和导出。 */
	private function installManualControls():Void {
		manualStatus = new Label("等待测试；点击自动循环开始。切回前台后请检查全部色块。");
		manualStatus.x = 24; manualStatus.y = 484; manualStatus.fontSize = 16; manualStatus.color = 0xe3edf9; addChild(manualStatus);
		var names:Array<String> = ["自动循环200轮", "切换一步", "安全清理", "恢复测试", "复制诊断"];
		for (index in 0...names.length) {
			var skin:BitmapData = OpenFlBitmapData.fromBitmapData(new openfl.display.BitmapData(168, 44, false, 0x314a65));
			var button:hx.display.Button = new hx.display.Button(names[index], {up:skin}, new hx.display.TextFormat(null, 16, 0xffffff));
			button.x = 24 + index * 184; button.y = 548; addChild(button);
			var action:Int = index;
			button.clickEvent = function():Void {
				switch action {
					case 0: manualRemaining = 600;
					case 1: step();
					case 2: StageBitmapData.disposeAll(); hx.net.RequestQueue.collectUnused();
					case 3: if (!lose()) manualStatus.data = "该环境不支持主动丢失上下文；请使用前后台及广告返回测试。";
					case 4:
						#if wechat_zygame_dom
						Wx.setClipboardData({data:haxe.Json.stringify(snapshot())});
						#end
				}
				if (action != 3) updateManualStatus();
			};
		}
	}
	/** 自动循环由现有主循环驱动，不额外注册定时器或渲染循环。 */
	override public function onUpdate(dt:Float):Void {
		super.onUpdate(dt);
		updateCount++;
		if (manualRemaining > 0) { step(); manualRemaining--; if (manualRemaining == 0) updateManualStatus(); }
	}
	/** 真机状态只在操作完成后更新，方便静止画面压力验证。 */
	private function updateManualStatus():Void {
		if (manualStatus != null) manualStatus.data = '循环：$cycles，持有：${TextureLifetime.references}，池：${StageBitmapData.counts}，故障：${RenderDiagnostics.faults}';
	}

	/** 添加固定位置的中文说明。 */
	private function text(value:String, x:Float, y:Float):Void {
		var label:Label = new Label(value); label.x = x; label.y = y; label.fontSize = 18; label.color = 0xe3edf9;
		addChild(label);
	}
	/** 创建 CPU 像素仍可重传的色块。 */
	private function bitmap(color:Int):BitmapData {
		return OpenFlBitmapData.fromBitmapData(new openfl.display.BitmapData(32, 32, false, color));
	}
	/** 添加确定尺寸的图像。 */
	private function tile(data:BitmapData, x:Float, y:Float, shader:MultiTextureShader = null):Image {
		var image:Image = new Image(data); image.x = x; image.y = y; image.width = 96; image.height = 96;
		image.smoothing = false; image.shader = shader; content.addChild(image); return image;
	}
	/** 重建画面并请求释放旧业务资源，旧快照必须活到下一次拆离。 */
	private function build():Void {
		if (content != null) { removeChild(content); content.dispose(); }
		for (data in backing) data.dispose();
		backing = []; content = new Sprite(); addChild(content);
		var red:BitmapData = bitmap(0xff0000); var green:BitmapData = bitmap(0x00ff00); var blue:BitmapData = bitmap(0x0000ff);
		var healthy:BitmapData = bitmap(0x00ff00);
		backing = [red, green, blue, healthy];
		// 同一 Shader 的双纹理容器随后缩成单纹理，复现历史槽残留。
		var group:Sprite = new Sprite(); group.shader = shared; content.addChild(group);
		first = new Image(red); first.x = 32; first.y = 96; first.width = first.height = 96; first.smoothing = false; group.addChild(first);
		second = new Image(green); second.x = 160; second.y = 96; second.width = second.height = 96; second.smoothing = false; group.addChild(second);
		tile(blue, 288, 96, shared);
		gray = tile(red, 416, 96); grayFilter = new GeryFilter(); gray.filters = [grayFilter];
		// 主画面健康对象必须在故障批次之后依然出现。
		tile(healthy, 800, 96);
		var nested:Sprite = new Sprite(); nested.x = 544; nested.y = 96;
		var pattern:openfl.display.BitmapData = new openfl.display.BitmapData(32, 32, false, 0xff0000);
		pattern.fillRect(new openfl.geom.Rectangle(16, 0, 16, 32), 0xffffff);
		var patternData:BitmapData = OpenFlBitmapData.fromBitmapData(pattern); backing.push(patternData);
		var nestedImage:Image = new Image(patternData); nestedImage.x = nestedImage.y = 8; nestedImage.width = nestedImage.height = 96;
		nestedImage.filters = [new GeryFilter()]; nested.addChild(nestedImage);
		nested.filters = [new GeryFilter()]; content.addChild(nested);
		var clipped:Sprite = new Sprite(); clipped.x = 32; clipped.y = 256; clipped.maskRect = new hx.geom.Rectangle(0, 0, 96, 64);
		clipped.addChild(new Quad(160, 96, 0xffcc00)); content.addChild(clipped);
		var layer:Sprite = new Sprite(); layer.x = 288; layer.y = 256; layer.blendMode = LAYER;
		layer.addChild(new Quad(96, 96, 0x00ffff));
		var mask:Quad = new Quad(48, 96, 0xffffff); layerMask = mask; mask.blendMode = ALPHA; layer.addChild(mask); content.addChild(layer);
		var erased:Sprite = new Sprite(); erased.x = 416; erased.y = 256; erased.blendMode = LAYER;
		erased.addChild(new Quad(96, 96, 0xff00ff));
		var eraser:Quad = new Quad(48, 96, 0xffffff); eraseMask = eraser; eraser.blendMode = ERASE; erased.addChild(eraser); content.addChild(erased);
		#if hx_astcenc
		if (astcData != null) tile(astcData, 672, 256);
		#end
		invalidate();
	}
	/** 实际编译的同一个 Shader 依次覆盖十六、八和一个纹理，清除历史槽。 */
	private function setTextureCount(count:Int):Void {
		if (textureGroup != null) { content.removeChild(textureGroup); textureGroup.dispose(); textureGroup = null; }
		for (data in textureSources) data.dispose(); textureSources = [];
		if (count <= 0) { invalidate(); return; }
		textureGroup = new Sprite(); textureGroup.shader = shared; content.addChild(textureGroup);
		for (index in 0...count) {
			var data:BitmapData = bitmap(((index * 47 + 64) % 256 << 16) | ((index * 71 + 96) % 256 << 8) | ((index * 19 + 128) % 256));
			textureSources.push(data);
			var image:Image = new Image(data); image.x = 32 + index * 48; image.y = 432; image.width = image.height = 32;
			textureGroup.addChild(image);
		}
		invalidate();
	}

	/** 真实编译不同槽位数；灰度效果跨容量拆批后也必须保持。 */
	private function compiledLimit(count:Int):Void {
		setTextureCount(0); textureGroup = new Sprite();
		textureGroup.shader = new MultiTextureShader(null, "color.rgb = vec3((color.r + color.g + color.b) / 3.0);", null, null, null, count);
		content.addChild(textureGroup);
		for (index in 0...3) {
			var image:Image = new Image(backing[index]); image.x = 32 + index * 48; image.y = 432; image.width = image.height = 32;
			textureGroup.addChild(image);
		}
		invalidate();
	}

	/** 双纹理变单纹理，并释放上一轮第二张图片；每三步完全重建资源。 */
	private function step():Void {
		phase++;
		if (phase % 3 == 1) {
			second.visible = false; backing[1].dispose();
		} else if (phase % 3 == 2) {
			first.data = backing[2]; backing[0].dispose(); gray.visible = false;
			for (child in content.children) if (child.x == 544) child.visible = false;
		} else { cycles++; build(); }
		invalidate();
	}
	/** 用真实位图验证捕获后释放、静止持有、退役幂等和切片所有权。 */
	private function protocolChecks():Void {
		var root:BitmapData = bitmap(0x335577);
		var child:BitmapData = root.sub(0, 0, 8, 8);
		root.dispose(); check(child.data != null && child.width == 8 && child.data.getWidth() == 32, "切片不受根视图释放影响");
		child.dispose();
		var resource:BitmapData = bitmap(0x123456);
		leaseRaw = resource.data.getTexture();
		leaseBatch = new DirectBatchDisplay(new DirectBatchRenderer()); leaseBatch.addTexture(leaseRaw);
		resource.dispose();
		check(leaseRaw.width == 32 && TextureLifetime.record(leaseRaw).pending, "快照阻止提前物理释放");
		leaseBatch.retire(); leaseBatch.retire();
		check(leaseRaw.width == 0 && TextureLifetime.record(leaseRaw).references == 0, "退役幂等且最终回收");
		leaseBatch.dispose(); leaseBatch = null; leaseRaw = null;
		var a:StageBitmapData = new StageBitmapData(); var b:StageBitmapData = new StageBitmapData();
		a.clear(); b.clear();
		var firstRaw:openfl.display.BitmapData = a.data.getTexture(); var secondRaw:openfl.display.BitmapData = b.data.getTexture();
		check(firstRaw != secondRaw, "两个借用者拥有不同输出目标");
		a.dispose(); check(secondRaw.width > 0 && firstRaw.width > 0, "借用者销毁不销毁池资源");
		b.dispose(); StageBitmapData.disposeAll();
		var shader:MultiTextureShader = new MultiTextureShader();
		var one:BitmapData = bitmap(0xffaa22); var two:BitmapData = bitmap(0x22aaff);
		var before:DirectBatchDisplay = new DirectBatchDisplay(new DirectBatchRenderer());
		var after:DirectBatchDisplay = new DirectBatchDisplay(new DirectBatchRenderer());
		shader.uSampler0.input = one.data.getTexture(); shader.time.value = [0.25]; before.captureShader(shader);
		shader.uSampler0.input = two.data.getTexture(); shader.time.value = [0.75]; after.captureShader(shader);
		var oldTime:Float = -1; var newTime:Float = -1;
		for (index in 0...before.shaderBuffer.paramFloatCount) {
			if (@:privateAccess before.shaderBuffer.paramRefs_Float[index].name == "time") {
				oldTime = before.shaderBuffer.paramData[before.shaderBuffer.paramPositions[before.shaderBuffer.paramBoolCount + index]];
				newTime = after.shaderBuffer.paramData[after.shaderBuffer.paramPositions[after.shaderBuffer.paramBoolCount + index]];
			}
		}
		check(oldTime == 0.25 && newTime == 0.75, "共享 Shader 数值快照隔离");
		var isolated:Bool = false;
		for (index in 0...before.shaderBuffer.inputCount) if (@:privateAccess before.shaderBuffer.inputRefs[index].name == "uSampler0")
			isolated = before.shaderBuffer.inputs[index] == one.data.getTexture() && after.shaderBuffer.inputs[index] == two.data.getTexture();
		check(isolated, "共享 Shader 输入快照隔离");
		one.dispose(); two.dispose(); before.retire(); after.retire();
		check(before.shaderBuffer.inputs.length == 0 && after.shaderBuffer.inputRefs.length == 0, "退役清除快照尾部引用");
		before.dispose(); after.dispose();
	}
	/** 检查失败直接抛出，让自动化保留真实错误。 */
	private function check(value:Bool, message:String):Void {
		if (!value) throw message;
		if (checks.indexOf(message) < 0) checks.push(message);
	}
	/** 注入绕过公开协议的原生误释放，受损批次必须局部隔离。 */
	private function inject(kind:String = "disposed"):Void {
		clearFault(); probe = new Render(); probe.clear();
		var raw:openfl.display.BitmapData = new openfl.display.BitmapData(32, 32, false, 0xffffff);
		var data:BitmapData = OpenFlBitmapData.fromBitmapData(raw); faultData = data;
		var image:Image = new Image(data); image.x = 672; image.y = 96; image.width = image.height = 96;
		image.__updateTransform(null); probe.renderDisplayObject(image); probe.endFill();
		switch kind {
			case "disposed": raw.dispose();
			case "invalidSize": @:privateAccess raw.width = -1;
			case "uploadFailed": untyped raw.getTexture = function(context:openfl.display3D.Context3D):openfl.display3D.textures.TextureBase { throw "注入上传失败"; };
			case "missingRecovery": raw.disposeImage(); @:privateAccess raw.image = null; TextureLifetime.record(raw).generation = -1;
			default: throw "未知故障注入类型";
		}
		openfl.Lib.current.addChild(probe.stage);
	}
	/** 移除故障注入；原生直接 dispose 属于破坏性误用。 */
	private function clearFault():Void {
		if (probe == null) return;
		if (probe.stage.parent != null) probe.stage.parent.removeChild(probe.stage);
		probe.dispose(); probe = null;
		if (faultData != null) { faultData.dispose(); faultData = null; }
	}
	/** 显式注入输出反馈，后端必须拒绝自采样并恢复原目标。 */
	private function feedback():Void {
		var target:BitmapData = OpenFlBitmapData.fromSize(32, 32, true, 0);
		target.clear(); target.draw(new Image(target)); target.dispose();
	}

	/** 输出嵌套缓存的尺寸和变换，用于像素故障定位。 */
	private function nestedState():Dynamic {
		for (child in content.children) if (child.x == 544) {
			var inner:Image = cast cast(child, Sprite).children[0];
			var outerResult:Image = cast child.filters[0].render;
			var innerResult:Image = cast inner.filters[0].render;
			return {outerBounds:child.getBounds(), innerBounds:inner.getBounds(),
				outerSize:outerResult == null ? null : [outerResult.data.width, outerResult.data.height],
				innerSize:innerResult == null ? null : [innerResult.data.width, innerResult.data.height],
				outerMatrix:outerResult == null ? null : outerResult.__worldTransform,
				innerMatrix:innerResult == null ? null : innerResult.__worldTransform,
				matrix:child.__worldTransform};
		}
		return null;
	}

	/** 公开结构化记录，含正常流程与故障注入计数。 */
	private function snapshot():Dynamic {
		var astc:Dynamic = {enabled:false};
		#if hx_astcenc
		astc = {enabled:true, ready:astcReady, error:astcError,
			bytes:hx.render2d.openfl.RecoverableASTCBitmapData.sourceBytes,
			fallback:astcData != null && cast(astcData.data.getTexture(), hx.render2d.openfl.RecoverableASTCBitmapData).fallbackActive};
		#end
		var engine:Engine = cast Hxmaker.engine;
		return {applicationVisible:engine.applicationVisible, updateCount:updateCount, resizePending:engine.__stageBitmapResetPending, astc:astc, buildId:hx.utils.RenderBuildInfo.buildId, windowWidth:openfl.Lib.current.stage.window.width, windowHeight:openfl.Lib.current.stage.window.height, stageWidth:engine.stageWidth, stageHeight:engine.stageHeight, phase:phase, cycles:cycles, generation:engine.contextGeneration, recovered:engine.contextRecoveryCount,
			lost:engine.contextLost, pending:engine.contextRecoveryPending, checks:checks.copy(), pool:StageBitmapData.counts,
			diagnostics:RenderDiagnostics.snapshot()};
	}
	#if hx_astcenc
	/** 固定颜色 ASTC 数据来自规范中的常量块格式，无外部游戏资源。 */
	private function loadASTC():Void {
		hx.net.RequestQueue.loadBytes("assets/constant.astc", function(bytes:haxe.io.Bytes, error:hx.events.FutureErrorEvent):Void {
			if (error != null) { astcError = error.error; return; }
			try {
				var raw:hx.render2d.openfl.RecoverableASTCBitmapData = hx.render2d.openfl.RecoverableASTCBitmapData.decode(bytes, "assets/constant.png");
				astcData = OpenFlBitmapData.fromBitmapData(raw); tile(astcData, 672, 256);
				astcReady = true; invalidate();
			} catch (failure:Dynamic) { astcError = Std.string(failure); }
		});
	}
	#end

	/** 能力检测后注入真实 context loss，恢复由原有引擎状态机执行。 */
	private function lose():Bool {
		#if (js && html5)
		var gl:Dynamic = openfl.Lib.current.stage.window.context.webgl;
		var extension:Dynamic = gl == null ? null : gl.getExtension("WEBGL_lose_context");
		if (extension == null) return false;
		extension.loseContext(); haxe.Timer.delay(function():Void { extension.restoreContext(); }, 150); return true;
		#else
		return false;
		#end
	}
}
