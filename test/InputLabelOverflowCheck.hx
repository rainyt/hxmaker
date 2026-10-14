package;

import hx.core.Hxmaker;
import hx.core.Render;
import hx.display.*;
import hx.geom.Point;
import hx.geom.Rectangle;
import hx.layout.AnchorLayout;
import hx.layout.AnchorLayoutData;
import hx.render.TextFieldRender;
import hx.render.TextFieldRender.Text;
import hx.text.TextFieldContextBitmapData;
import hx.text.TextFieldAtlas;
import hx.text.FntFrame;
import hx.utils.inputs.HTML5TextInputUtils;

/** 固定字形尺寸，运行真实文字布局、输入框逻辑及遮罩状态，不依赖 GPU。 */
@:access(hx.display.InputLabel)
@:access(hx.display.DisplayObject)
@:access(hx.display.DisplayObjectContainer)
@:access(hx.display.Stage)
@:access(hx.core.Render)
@:access(hx.core.Hxmaker)
class InputLabelOverflowCheck {
	static var checks = 0;
	static var preparations = 0;
	static var host:Stage;
	static function assert(value:Bool, message:String):Void {
		checks++;
		if (!value) throw message;
	}
	static function near(a:Float, b:Float):Bool return Math.abs(a - b) < 0.001;
	static function tick(input:InputLabel):Void {
		input.onUpdate(0.016);
		host.__updateTransform(null);
	}
	static function create(text:String, width:Float = 100, height:Float = 32, wrap:Bool = false):InputLabel {
		var input = new InputLabel();
		input.textFormat = new TextFormat(null, 24, 0xffffff);
		input.width = width; input.height = height; input.wordWrap = wrap; input.data = text;
		host.addChild(input); tick(input);
		return input;
	}
	static function activate(input:InputLabel, index:Int):Void {
		host.focus = input; input.__isClicked = true;
		input.syncSelectionFromNative(index, index); tick(input);
	}
	static function caretVisible(input:InputLabel):Bool {
		return input.line.x - input.__scrollX >= -0.001
			&& input.line.x + input.line.width - input.__scrollX <= input.__viewport.width + 0.001
			&& input.line.y - input.__scrollY >= -0.001
			&& input.line.y + input.line.height - input.__scrollY <= input.__viewport.height + 0.001;
	}
	static function configureText():Void {
		var context = Type.createEmptyInstance(TextFieldContextBitmapData);
		context.fontSize = 24;
		var atlas = Type.createEmptyInstance(TextFieldAtlas);
		var frame = new FntFrame(atlas);
		frame.xadvance = 12;
		frame.data = new BitmapData(); frame.data.rect = new Rectangle(0, 0, 10, 20);
		untyped atlas.getCharFntFrame = function(char:String) return frame;
		untyped context.getAtlas = function(char:String) return char == " " || char == "\n" || char == "\r" ? null : atlas;
		untyped TextFieldRender.prepareLabel = function(label:Label):Void {
			preparations++;
			var text:Text = label.root == null ? new Text(label) : cast label.root;
			label.root = text; text.text = label.data; text.prepared = true;
			text.drawText(context, null, true);
			@:privateAccess label.__textFormatDirty = false;
			label.setDirty(false);
		};
	}
	static function main():Void {
		configureText();
		Hxmaker.__engine = cast { renderer: null, get_stageWidth: () -> 200., get_stageHeight: () -> 150. };
		host = new Stage(); host.__stageWidth = 800; host.__stageHeight = 600;
		var input = create("abc");
		assert(input.__viewport.maskRect == null, "短文本不用遮罩");
		assert(input.__scrollX == 0 && input.__scrollY == 0, "短文本无滚动");
		var before = preparations;
		for (i in 0...120) {
			input.label.setTransformDirty();
			tick(input);
		}
		assert(preparations == before, "后端重复标记变换脏的 120 帧仍不重建文本");
		input.data = "abcdefghijklmnopqrst"; tick(input);
		assert(input.__viewport.maskRect != null, "失焦长文本也被裁剪");
		assert(input.__scrollX == 0, "失焦新文本保留开头");
		var clip = input.__viewport.maskRect;
		activate(input, input.data.length);
		assert(input.__scrollX > 0 && caretVisible(input), "末尾光标滚动到可见范围");
		assert(input.__viewport.maskRect == clip, "复用同一个遮罩矩形");
		input.syncSelectionFromNative(0, 0); tick(input);
		assert(input.__scrollX == 0 && caretVisible(input), "移回开头恢复滚动位置");
		input.syncSelectionFromNative(0, input.data.length); tick(input);
		assert(input.selectionQuad.visible && input.__viewport.maskRect != null, "全选高亮也裁剪");
		input.data = "a"; tick(input);
		assert(input.__viewport.maskRect == null && input.__scrollX == 0, "删除到短文本解除遮罩并复位");
		input.data = "abcdefghijklmnopqrst"; tick(input);
		input.width = 400; tick(input);
		assert(input.__viewport.maskRect == null && input.__scrollX == 0, "扩大尺寸解除遮罩");
		input.width = 70; tick(input);
		assert(input.__viewport.maskRect != null && input.__clipRect.width == 70, "缩小尺寸刷新遮罩");
		input.data = "abcdef"; input.width = 72; activate(input, 6);
		assert(near(input.__scrollX, 1) && caretVisible(input), "文字刚好填满时给末尾光标留出宽度");
		assert(input.__viewport.maskRect != null, "光标导致文字偏移越界时才开启遮罩");
		host.focus = null; tick(input);
		assert(input.__viewport.maskRect == null && !input.line.visible, "失焦去掉仅光标造成的遮罩");

		input = create("", 60);
		input.placeholder = "abcdefghijkl"; tick(input);
		assert(input.placeholderLabel.visible && input.__viewport.maskRect != null, "长提示文案被裁剪");
		input.placeholder = "abc"; tick(input);
		assert(input.__viewport.maskRect == null, "提示文案变短解除遮罩");
		input.data = "    "; tick(input);
		assert(!input.placeholderLabel.visible && input.getTextWidth() > 60, "空格属于已输入内容并计入宽度");
		activate(input, 4);
		assert(caretVisible(input), "尾部空格光标定位正确");

		input = create("abcdefghijkl", 50, 32, true); activate(input, 12);
		assert(input.__scrollY > 0 && caretVisible(input), "多行光标纵向滚动");
		input.syncSelectionFromNative(0, 12); tick(input);
		assert(input.__selectionQuadCount == 3, "跨行选区按三行绘制");
		var text:Text = cast input.label.root;
		var charQueries = 0;
		untyped text.getChatBounds = function(index:Int):Rectangle {
			charQueries++; return text.charBounds[index];
		};
		before = preparations;
		for (i in 0...120) { input.label.setTransformDirty(); tick(input); }
		assert(preparations == before && charQueries == 0, "静止选区不重新测量或扫描字符");
		var first = input.selectionQuad;
		input.syncSelectionFromNative(0, 0); tick(input);
		assert(input.__selectionQuadCount == 0 && !first.visible, "收起选区隐藏所有高亮");
		input.syncSelectionFromNative(0, 12, 0); tick(input);
		assert(input.__scrollY == 0, "反向选区跟随起始活动端");
		input.selectionColor = 0xff0000;
		for (quad in input.__selectionQuads) assert(quad.data == 0xff0000, "所有缓存高亮同步颜色");
		input.width = 200; input.height = 100; tick(input);
		assert(input.__selectionQuadCount == 1 && input.__viewport.maskRect == null, "尺寸变化重新布局选区");
		input.data = "ab\n"; activate(input, 3);
		assert(input.__caretRect.x == 0 && input.__caretRect.y == 60, "末尾换行的光标在空行开头");
		input.data = "ab\r\ncd"; activate(input, 6);
		assert(input.__caretRect.y == 60, "CRLF 只换行一次");

		input = create("abcd", 50);
		input.displayAsPassword = true; input.passwordChar = "##"; activate(input, 4);
		assert(input.label.data == "########" && caretVisible(input), "多字符密码掩码按原文索引定位光标");
		input.passwordChar = ""; tick(input);
		assert(input.passwordChar == "*", "空密码掩码恢复默认字符");
		input.displayAsPassword = false; tick(input);
		assert(input.label.data == "abcd" && input.__viewport.maskRect == null, "取消密码模式重新计算边界");

		input = create("abcdefghijkl", 70); input.x = 100; input.y = 100; input.scale = 1.5;
		input.label.horizontalAlign = CENTER; input.label.verticalAlign = MIDDLE; activate(input, 12);
		var p = input.label.localToGlobal(new Point(120, input.__caretRect.height / 2));
		assert(input.getCharIndexAtPoint(p.x, p.y) == 10, "滚动与缩放后的点击定位到实际字符");
		input.data = "abc"; input.width = 100; tick(input);
		p = input.label.localToGlobal(new Point(13, input.__caretRect.height / 2));
		assert(input.getCharIndexAtPoint(p.x, p.y) == 1, "居中对齐的点击坐标正确");
		input.syncSelectionFromNative(0, 2); tick(input);
		input.label.horizontalAlign = LEFT; input.label.verticalAlign = TOP; tick(input);
		assert(input.label.originX == 0 && input.label.originY == 0 && input.selectionQuad.x == 0, "切回左上对齐刷新光标和选区");
		input.data = "abcdefghij"; activate(input, 0);
		input.selectionAnchor = 0; input.__dragging = true;
		p = input.__viewport.localToGlobal(new Point(130, 16)); input.__dragStageX = p.x; input.__dragStageY = p.y;
		for (i in 0...20) tick(input);
		assert(input.__scrollX > 0 && input.selectionEnd > 0, "鼠标停在右侧边缘外持续滚动并扩大选区");
		input.endDragSelection();

		var parent = new Box(); parent.width = 60; parent.height = 32; parent.layout = new AnchorLayout(); host.addChild(parent);
		input = new InputLabel(); input.wordWrap = false; input.data = "abcdefghij"; input.layoutData = AnchorLayoutData.fill(); parent.addChild(input); tick(input);
		assert(input.__viewport.width == 60 && input.__viewport.maskRect != null, "父布局完成后才判断溢出");
		parent.width = 200; tick(input);
		assert(input.__viewport.width == 200 && input.__viewport.maskRect == null, "父布局尺寸变化更新裁剪");
		input = new InputLabel(); input.wordWrap = false; input.data = "ab"; host.addChild(input); tick(input);
		var oldWidth = input.width;
		input.data = "abcdefgh"; tick(input);
		assert(input.width > oldWidth && near(input.__viewport.width, input.width), "自动尺寸不被内部视口锁定");

		// 原生输入方向同步仍使用原文选区，避免反向选择把滚动带到末尾。
		input = create("abcdefghij", 50); host.focus = input;
		var native:Dynamic = { selectionStart: 0, selectionEnd: 10, selectionDirection: "backward", value: input.data,
			setSelectionRange: function(start:Int, end:Int, direction:String):Void {} };
		HTML5TextInputUtils.input = input; HTML5TextInputUtils.textureArea = cast native;
		HTML5TextInputUtils.onNativeSelect(); tick(input);
		assert(input.__caretIndex == 0 && input.__scrollX == 0, "原生反向选区跟随活动端");
		HTML5TextInputUtils.input = null; HTML5TextInputUtils.textureArea = null;

		checkMasks();
		#if overflow_browser_checks
		checkMaskPixels(false);
		checkMaskPixels(true);
		#end
		trace("输入框溢出行为验证通过：" + checks + " 项断言");
		#if overflow_browser_checks
		if (js.Browser.document.getElementById("result") != null)
			js.Browser.document.getElementById("result").textContent = "输入框溢出行为验证通过：" + checks + " 项断言";
		#end
	}
	static function checkMasks():Void {
		// 遮罩状态测试不提交 GPU 绘制，因此不初始化依赖 GL 的多纹理着色器。
		var shader = new openfl.display.Shader();
		Render.defaultShader = shader; Render.defaultFastShader = shader;
		Render.defaultUnSmoothingShader = shader; Render.defaultUnSmootingFastShader = shader;
		var render = new Render();
		render.setMask(true); var outer = render.__maskSprite;
		render.setMask(true); var inner = render.__maskSprite;
		assert(inner.parent == outer && render.__maskStack.length == 2, "内层遮罩属于外层");
		render.setMask(false);
		assert(render.__maskSprite == outer && render.stage == outer, "内层结束恢复外层绘制目标");
		render.setMask(false);
		assert(render.__maskSprite == null && render.__maskStack.length == 0, "外层结束恢复舞台");
		render.clear();
		assert(outer.numChildren == 0 && inner.numChildren == 0, "清屏递归归还所有层级");
		var object = new Box(); host.addChild(object); host.__dirty = false;
		object.maskRect = new Rectangle(0, 0, 10, 10);
		assert(host.__dirty, "开启遮罩标记舞台重绘");
		host.__dirty = false; object.maskRect = null;
		assert(host.__dirty, "关闭遮罩标记舞台重绘");
	}

	#if overflow_browser_checks
	/** 用真实 Canvas 检查两层遮罩的交集和内层结束后的绘制顺序。 */
	static function checkMaskPixels(cache:Bool):Void {
		var render = new MaskCanvasRender(); render.cacheAsBitmap = cache;
		// 测试使用可读 Canvas 位图，正式后端的 GPU 位图需要完整 OpenFL 舞台。
		if (cache)
			render.__cacheBitmap.bitmapData = new openfl.display.BitmapData(200, 150, true, 0);
		render.clear();
		var root = new Box();
		var outer = new Box(); outer.maskRect = new Rectangle(20, 20, 50, 40); root.addChild(outer);
		var inner = new Box(); inner.maskRect = new Rectangle(40, 10, 50, 50); outer.addChild(inner);
		inner.addChild(new Quad(120, 100, 0xff0000));
		var green = new Quad(10, 10, 0x00ff00); green.x = 20; green.y = 25; outer.addChild(green);
		root.__updateTransform(null); render.renderDisplayObject(root);
		var bitmap = new openfl.display.BitmapData(120, 100, true, 0);
		bitmap.draw(render.stage);
		var mode = cache ? "位图缓存" : "普通绘制";
		assert(bitmap.getPixel32(45, 30) == 0xffff0000, mode + "保留两层交集");
		assert(bitmap.getPixel32(25, 30) == 0xff00ff00, mode + "内层结束后恢复外层");
		assert(bitmap.getPixel32(75, 30) == 0, mode + "裁掉外层之外的内容");
		assert(bitmap.getPixel32(45, 15) == 0, mode + "裁掉交集上方的内容");
		assert(bitmap.getPixel32(30, 50) == 0, mode + "裁掉内层左侧的内容");
		render.clear(); bitmap.dispose();
	}
	#end
}

#if overflow_browser_checks
/** 遮罩检查使用 Canvas 色块，沿用真实遮罩遍历，避免混入多纹理 GPU 环境。 */
@:access(hx.display.DisplayObject)
private class MaskCanvasRender extends Render {
	override public function renderGraphics(graphics:Graphics):Void {
		var quad:Quad = cast graphics;
		var rect = new Rectangle(0, 0, quad.width, quad.height);
		rect.transform(rect, quad.__worldTransform);
		var sprite = new hx.core.EngineSprite(); sprite.isPool = false;
		sprite.graphics.beginFill(quad.data); sprite.graphics.drawRect(rect.x, rect.y, rect.width, rect.height); sprite.graphics.endFill();
		stage.addChild(sprite);
	}
}
#end
