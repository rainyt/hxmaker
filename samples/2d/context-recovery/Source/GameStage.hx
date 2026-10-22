package;

import hx.assets.Assets;
import hx.core.Engine;
import hx.core.Hxmaker;
import hx.display.BitmapData;
import hx.display.DisplayObjectContainer;
import hx.display.Image;
import hx.display.Label;
import hx.display.MakerDisplay;
import hx.display.Quad;
import hx.display.Scroll;
import hx.filters.BlurFilter;
import hx.shader.MultiTextureShader;
import hx.render.TextFieldRender;

/** 纯二维静态恢复页，没有三维回调、动画或用于强制重绘的心跳。 */
class GameStage extends hx.display.Stage {
	private var engine:Engine;
	private var assets:Assets;
	private var ready:Bool = false;
	private var sequence:Int = 0;
	private var restored:Int = 0;
	private var manual:Array<Dynamic> = [];
	private var errors:Array<String> = [];
	private var textSnapshots:Array<Dynamic> = [];
	#if (js && html5)
	private var status:js.html.PreElement;
	#end
	override public function onStageInit():Void {
		super.onStageInit(); engine = cast Hxmaker.engine;
		this.addChild(new Quad(1000,700,0x162134));
		text(this,"纯二维上下文恢复：页面静止后再触发",20,18,23);
		installControls();
		assets = new Assets(); assets.tryLoadTimes = 0; assets.loadBitmapData("assets/checker.png");
		assets.onError(error -> { errors.push(error.error); message(error.error); });
		assets.onComplete(_ -> { build(assets.getBitmapData("checker")); ready=true; message("资源就绪。请检查画面，静置后再点击丢失并恢复。"); });
		assets.start();
	}
	private function text(parent:DisplayObjectContainer,value:String,x:Float,y:Float,size:Int = 16):Label {
		var label = new Label(value); label.x=x; label.y=y; label.fontSize=size; label.color=0xe3edf9;
		parent.addChild(label); return label;
	}
	private function image(parent:DisplayObjectContainer,bitmap:BitmapData,x:Float,y:Float,smooth:Bool):Image {
		var item = new Image(bitmap); item.x=x; item.y=y; item.width=item.height=104; item.smoothing=smooth;
		parent.addChild(item); return item;
	}
	private function build(bitmap:BitmapData):Void {
		text(this,"静态文字、中文、123456；普通色块和贴图必须全部恢复。",20,64);
		var separator = new Quad(950,3,0xe39f37); separator.x=20; separator.y=98; this.addChild(separator);
		image(this,bitmap,20,125,false); text(this,"最近点",20,238);
		image(this,bitmap,155,125,true); text(this,"线性",155,238);
		var shader = new MultiTextureShader(null,"color.rgb *= vec3(0.65, 0.6 + time * 0.4, 1.0);");
		shader.time.value=[0.35]; image(this,bitmap,290,125,true).shader=shader;
		text(this,"自定义 Shader：恢复前后色调相同",290,238);
		var outer = new Scroll(false); outer.x=570; outer.y=125; outer.width=330; outer.height=140;
		outer.scrollXEnable=outer.scrollYEnable=false; this.addChild(outer);
		outer.addChild(new Quad(400,160,0x314a65));
		var inner = new Scroll(false); inner.x=18; inner.y=14; inner.width=210; inner.height=94;
		inner.scrollXEnable=inner.scrollYEnable=false; outer.addChild(inner);
		image(inner,bitmap,170,5,true); text(inner,"嵌套裁剪",8,20);
		text(this,"贴图右侧应被内层边界裁掉",570,280);
		var blurred = image(this,bitmap,20,320,true); blurred.filters=[new BlurFilter(2,2)];
		text(this,"滤镜缓存：模糊图案应恢复",145,357);
		var maker = new MakerDisplay(430,150); maker.x=490; maker.y=350; maker.renderer.cacheAsBitmap=true;
		maker.container.addChild(new Quad(430,150,0x314a65)); image(maker.container,bitmap,12,12,false);
		text(maker.container,"MakerDisplay 位图缓存",135,28); text(maker.container,"中文及图案恢复，位置保持",135,66);
		addChild(maker);
		text(this,"此页面加载后不更新二维内容；诊断控件在 Canvas 外。",20,535);
	}
	private function message(value:String):Void {
		#if (js && html5)
		if (status != null) status.textContent=value;
		#else
		trace(value);
		#end
	}
	private function installControls():Void {
		#if (js && html5)
		var panel=js.Browser.document.createDivElement();
		panel.style.cssText="position:fixed;left:12px;bottom:8px;z-index:2147483647;background:#162134;color:white;padding:10px;font:14px sans-serif";
		function button(value:String,callback:Void->Void):Void {
			var item=js.Browser.document.createButtonElement(); item.textContent=value;
			item.addEventListener("click",_ -> callback()); panel.appendChild(item);
		}
		button("丢失并恢复",loseContext);
		button("重建文字图集",rebuildText);
		button("记录画面通过",() -> record(true)); button("记录画面异常",() -> record(false));
		button("导出记录",exportReport);
		status=js.Browser.document.createPreElement(); status.style.margin="8px 0 0"; panel.appendChild(status);
		js.Browser.document.body.appendChild(panel);
		var gl:Dynamic=openfl.Lib.current.stage.window.context.webgl;
		if (gl != null) {
			var canvas:js.html.CanvasElement=cast gl.canvas;
			canvas.addEventListener("webglcontextlost",function(event:js.html.Event) {
				event.preventDefault(); message("上下文已丢失，等待恢复。");
			});
			canvas.addEventListener("webglcontextrestored",_ -> {
				restored++; message("已收到恢复事件。请检查贴图、文字、色调、遮罩、滤镜和右侧位图缓存。");
				haxe.Timer.delay(() -> captureText("恢复事件后的文字状态"),250);
			});
		}
		js.Browser.window.addEventListener("error",function(event:js.html.ErrorEvent) { errors.push(event.message); message(event.message); });
		js.Browser.window.addEventListener("unhandledrejection",function(event:Dynamic) { var value=Std.string(Reflect.field(event,"reason")); errors.push(value); message(value); });
		#end
	}
	private function loseContext():Void {
		#if (js && html5)
		if (!ready || engine.contextLost || engine.contextRecoveryPending || sequence > restored) return;
		var gl:Dynamic=openfl.Lib.current.stage.window.context.webgl;
		var extension:Dynamic=gl == null ? null : gl.getExtension("WEBGL_lose_context");
		if (extension == null) { message("当前设备不支持主动上下文诊断。"); return; }
		var request=++sequence; captureText("丢失前"); extension.loseContext();
		haxe.Timer.delay(() -> extension.restoreContext(),1000);
		haxe.Timer.delay(function() {
			if (request != sequence) return;
			if (engine.contextLost || engine.contextRecoveryPending) { errors.push("恢复超时"); message("恢复超时，请导出记录。"); }
		},10000);
		#end
	}
	private function captureText(reason:String):Void {
		textSnapshots.push({reason:reason,at:Date.now().toString(),sequence:sequence,
			generation:engine.contextGeneration,pending:engine.contextRecoveryPending,text:TextFieldRender.contextStats()});
	}
	private function rebuildText():Void {
		if (!ready || engine.contextLost || engine.contextRecoveryPending) return;
		TextFieldRender.onContextRestored(true);
		for (stage in engine.stages) stage.invalidate();
		captureText("手动请求重建文字图集");
		message("已请求完整重建文字；请检查画面，再导出记录。");
	}
	private function record(passed:Bool):Void {
		if (passed && (!ready || restored == 0 || engine.contextLost || engine.contextRecoveryPending || engine.contextRecoveryCount == 0)) {
			message("后端尚未完成一次恢复，不能记录通过。"); return;
		}
		manual.push({passed:passed,sequence:sequence,restoredEvents:restored,generation:engine.contextGeneration,
			recovered:engine.contextRecoveryCount,text:TextFieldRender.contextStats(),at:Date.now().toString()});
		message(passed ? "已记录人工画面通过；可继续下一轮恢复。" : "已记录画面异常，请导出记录。");
	}
	private function exportReport():Void {
		#if (js && html5)
		var report={version:2,pure2D:true,sequence:sequence,restoredEvents:restored,generation:engine.contextGeneration,
			recovered:engine.contextRecoveryCount,lost:engine.contextLost,pending:engine.contextRecoveryPending,
			text:TextFieldRender.contextStats(),textSnapshots:textSnapshots,
			manual:manual,errors:errors,createdAt:Date.now().toString(),userAgent:js.Browser.navigator.userAgent};
		var url=js.html.URL.createObjectURL(new js.html.Blob([haxe.Json.stringify(report,null,"  ")],{type:"application/json"}));
		var anchor=js.Browser.document.createAnchorElement(); anchor.href=url; anchor.download="hxmaker-2d-recovery-"+Date.now().getTime()+".json";
		js.Browser.document.body.appendChild(anchor); anchor.click(); anchor.remove();
		haxe.Timer.delay(() -> js.html.URL.revokeObjectURL(url),1000);
		#end
	}
}
