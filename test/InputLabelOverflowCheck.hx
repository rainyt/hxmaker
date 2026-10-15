package;

import hx.core.Hxmaker;
import hx.core.Render;
import hx.display.*;
import hx.geom.Point;
import hx.geom.Rectangle;
import hx.layout.AnchorLayout;
import hx.layout.AnchorLayoutData;
import hx.events.MouseEvent;
import hx.events.Event;
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
	static function mouse(type:String, x:Float, y:Float):Void {
		host.__updateTransform(null);
		var event = new MouseEvent(type); event.stageX = x; event.stageY = y;
		host.handleMouseEvent(event, true);
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
		input.height = 22; tick(input);
		assert(input.getTextHeight() == 20 && input.__viewport.maskRect == null, "字形能放下时不因光标高度开启遮罩");
		input.height = 32; tick(input);
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

		checkEmptyCaretAlignment();
		checkDragDeletion();
		checkMasks();
		#if overflow_browser_checks
		checkMaskPixels(false);
		checkMaskPixels(true);
		#end
		trace("输入框溢出行为验证通过：" + checks + " 项断言");
		#if overflow_browser_checks
		if (js.Browser.document.getElementById("result") != null)
			js.Browser.document.getElementById("result").textContent = "输入框溢出行为验证通过：" + checks + " 项断言";
		prepareNativeBackspace();
		#end
	}

	/** 空文本的光标需要按自身尺寸对齐，而不是沿用高度为零的文字原点。 */
	static function checkEmptyCaretAlignment():Void {
		var verticals:Array<VerticalAlign> = [TOP, MIDDLE, BOTTOM];
		var horizontals:Array<HorizontalAlign> = [LEFT, CENTER, RIGHT];
		for (placeholder in [false, true]) {
			for (vertical in verticals) {
				var input = create("", 100, 40);
				input.verticalAlign = vertical;
				if (placeholder)
					input.placeholder = "提示";
				for (horizontal in horizontals) {
					input.horizontalAlign = horizontal;
					activate(input, 0);
					var expectedY = vertical == MIDDLE ? (40 - input.line.height) / 2 : vertical == BOTTOM ? 40 - input.line.height : 0;
					var expectedX = horizontal == CENTER ? (100 - input.line.width) / 2 : horizontal == RIGHT ? 100 - input.line.width : 0;
					assert(near(input.line.y - input.__scrollY, expectedY) && near(input.line.x - input.__scrollX, expectedX),
						"空文本和提示文案下的光标按自身宽高对齐：" + horizontal + "," + vertical);
					assert(input.__scrollX == 0 && input.__scrollY == 0 && input.__viewport.maskRect == null,
						"能放下的空文本光标不触发滚动或遮罩");
				}
				host.removeChild(input);
			}
		}
		var input = create("a", 100, 40);
		input.verticalAlign = MIDDLE; activate(input, 1);
		input.data = ""; tick(input);
		assert(near(input.line.y, (input.height - input.line.height) / 2) && input.__scrollY == 0,
			"删除最后一个字符后光标保持居中且不产生额外滚动");
		input.height = 64; input.label.fontSize = 30; tick(input);
		assert(near(input.line.y, 16) && input.line.height == 32, "改变高度和字号后刷新空文本光标位置");
		var before = preparations;
		for (i in 0...120) tick(input);
		assert(preparations == before && input.__viewport.maskRect == null, "空文本光标闪烁不重建文本或开启遮罩");
		var provider:hx.providers.ITextFieldLayoutProvider = cast input.label.root;
		assert(provider.getCaretBounds(0).y == 0, "对齐补偿不修改后端持有的光标矩形");
	}

	/** 不触发 CLICK，验证在文本空白和输入框外抬起后仍可删除选区。 */
	static function checkDragDeletion():Void {
		#if !overflow_browser_checks
		var native:Dynamic = { value: "", style: {}, selectionStart: 0, selectionEnd: 0, selectionDirection: "none",
			focus: () -> {}, blur: () -> {} };
		native.setSelectionRange = function(start:Int, end:Int, direction:String):Void {
			native.selectionStart = start; native.selectionEnd = end; native.selectionDirection = direction;
		};
		HTML5TextInputUtils.textureArea = cast native;
		#end
		for (outside in [false, true]) {
			var input = create("abcdef", 200); input.x = 400; input.y = 350;
			host.focus = null;
			mouse(MouseEvent.MOUSE_DOWN, 414, 366);
			assert(HTML5TextInputUtils.input == input && host.focus == input, "按下就打开输入通道");
			var x = outside ? 640. : 520.; var y = outside ? 400. : 366.;
			mouse(MouseEvent.MOUSE_MOVE, x, y);
			mouse(MouseEvent.MOUSE_UP, x, y);
			var area = HTML5TextInputUtils.textureArea;
			assert(!input.__dragging && area.selectionStart == 1 && area.selectionEnd == 6, "文字外抬起保留原生选区");
			#if overflow_browser_checks
			assert(js.Browser.document.activeElement == area, "外部抬起后原生输入框保持键盘焦点");
			#end
			// 模拟原生删除的 input 通知，验证回读不会收起选区或覆盖刚删除的内容。
			area.value = area.value.substring(0, area.selectionStart) + area.value.substring(area.selectionEnd);
			area.setSelectionRange(1, 1, "none"); HTML5TextInputUtils.onInput(); tick(input);
			assert(input.data == "a" && input.selectionStart == 1 && input.selectionEnd == 1, "没有 CLICK 也能删除选区");
			HTML5TextInputUtils.closeInput(input); host.removeChild(input);
		}
		HTML5TextInputUtils.textureArea = null;
	}

	#if overflow_browser_checks
	/** 保留一次外部抬起后的真实原生选区，供浏览器发送 Backspace 验证。 */
	static function prepareNativeBackspace():Void {
		var input = create("abcdef", 200); input.x = 400; input.y = 350;
		mouse(MouseEvent.MOUSE_DOWN, 414, 366);
		mouse(MouseEvent.MOUSE_MOVE, 640, 400);
		mouse(MouseEvent.MOUSE_UP, 640, 400);
		input.addEventListener(Event.CHANGE, _ -> {
			tick(input);
			var success = input.data == "a" && input.selectionStart == 1 && input.selectionEnd == 1;
			js.Browser.document.getElementById("native-result").textContent = success ? "外部松开后原生 Backspace 删除选区通过" : "原生删除验证失败：" + input.data;
		});
		js.Browser.document.getElementById("native-result").textContent = "已在输入框外松开，原生选区为 bcdef，等待 Backspace";
	}
	#end
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
