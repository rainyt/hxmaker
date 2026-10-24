package;

import hx.display.FPS;
import hx.core.OpenFlBitmapData;
import hx.display.BitmapData;
import hx.display.BlendMode;
import hx.display.Box;
import hx.display.DisplayObject;
import hx.display.DisplayObjectContainer;
import hx.display.Image;
import hx.display.Label;
import hx.display.Quad;
import hx.display.Sprite;
import hx.display.Stage;
import hx.display.TextFormat;
import hx.events.MouseEvent;

private typedef BlendCard = {
	var mode:BlendMode;
	var quad:Quad;
	var image:Image;
	var reference:Array<Quad>;
}

/** 混合模式人工验收页；启动后保持静态，由按钮修改现有对象。 */
class GameStage extends Stage {
	private static inline var SURFACE_WIDTH:Int = 80;
	private static inline var SURFACE_HEIGHT:Int = 72;

	private var modes:Array<BlendMode> = [
		       NORMAL,    ADD, MULTIPLY,  SCREEN, DIFFERENCE, SUBTRACT,
		SUBTRACT_FAST, INVERT,   DARKEN, LIGHTEN,  HARDLIGHT,  OVERLAY
	];
	private var descriptions:Array<String> = [
		     "源色覆盖背景",   "颜色相加，结果变亮",    "颜色相乘，结果变暗",       "滤色，结果变亮",
		"背景与源色之差的绝对值", "背景减去源色，下限为零",   "后端特有近似，仅观察", "反转背景，源色只贡献透明度",
		    "逐通道取较小值",     "逐通道取较大值", "按源色亮度决定乘法或滤色",  "按背景亮度决定乘法或滤色"
	];
	private var backgrounds:Array<Int> = [0x244870, 0x808080, 0xe0c080];
	private var sourceColors:Array<Int> = [0xd060a0, 0x40b870];
	private var alphaValues:Array<Float> = [1, 0.5, 0.25, 0];
	private var cards:Array<BlendCard> = [];
	private var textures:Array<BitmapData> = [];
	private var sourceTextures:Array<BitmapData> = [];
	private var alphaIndex:Int = 0;
	private var colorIndex:Int = 0;
	private var forceNormal:Bool = false;
	private var status:Label;

	override public function onStageInit():Void {
		super.onStageInit();

		var fps = new FPS();
		this.topView.addChild(fps);

		addQuad(this, 0, 0, 1200, 960, 0x171e2b);
		text(this, "BlendMode 混合模式对照", 24, 14, 1152, 36, 26);
		text(this, "每格：左 Quad ／ 中 Image ／ 右 CPU 公式参考。背景不透明；比较色块内部，忽略边缘取样差异。", 24, 54, 1152, 24);
		action("切换透明度", 24, () -> {
			alphaIndex = (alphaIndex + 1) % alphaValues.length;
			refreshCards();
		});
		action("切换源颜色", 190, () -> {
			colorIndex = (colorIndex + 1) % sourceColors.length;
			refreshCards();
		});
		action("全部 NORMAL / 恢复", 356, () -> {
			forceNormal = !forceNormal;
			refreshCards();
		});
		action("重置", 570, () -> {
			alphaIndex = colorIndex = 0;
			forceNormal = false;
			refreshCards();
		});
		status = text(this, "", 24, 126, 1152, 24, 15, 0x79dfbe);

		for (color in sourceColors) {
			var sourceColor = color;
			sourceTextures.push(bitmap(56, 48, (x, y) -> 0xff000000 | sourceColor));
		}
		for (index in 0...modes.length)
			buildCard(index);
		refreshCards();
		buildLayerCases();
		buildStateSequence();
		text(this, "下方分组与状态序列使用固定参数，不受顶部按钮影响。参考画面只使用 NORMAL 绘制，不自动判定通过。", 24, 930, 1152, 24, 14, 0xa9b9cf);
	}

	private function buildCard(index:Int):Void {
		var card = new Sprite();
		card.x = 24 + index % 4 * 290;
		card.y = 158 + Std.int(index / 4) * 168;
		addChild(card);
		addQuad(card, 0, 0, 282, 158, 0x222e40);
		text(card, Std.string(modes[index]).toUpperCase(), 10, 5, 264, 24, 17);
		var positions = [10, 102, 194];
		var names = ["Quad", "Image", modes[index] == SUBTRACT_FAST ? "无统一参考" : "公式参考"];
		for (column in 0...3) {
			text(card, names[column], positions[column], 31, 80, 20, 12, 0xb8c9df);
			if (column < 2 || modes[index] != SUBTRACT_FAST)
				stripedBackground(card, positions[column], 54);
		}
		var quad = addQuad(card, 22, 66, 56, 48, sourceColors[0]);
		var image = addImage(card, sourceTextures[0], 114, 66);
		var reference:Array<Quad> = [];
		if (modes[index] != SUBTRACT_FAST) {
			for (column in 0...3) {
				var left = Math.max(12, stripeEdge(column));
				var right = Math.min(68, stripeEdge(column + 1));
				reference.push(addQuad(card, 194 + left, 66, right - left, 48, 0));
			}
		} else {
			text(card, "近似算法\n单独观察", 194, 70, 80, 52, 12, 0xe8bf7a);
		}
		text(card, descriptions[index], 10, 132, 264, 22, 12, 0xa9b9cf);
		cards.push({
			mode: modes[index],
			quad: quad,
			image: image,
			reference: reference
		});
	}

	private function refreshCards():Void {
		var alpha = alphaValues[alphaIndex];
		var color = sourceColors[colorIndex];
		for (card in cards) {
			var mode:BlendMode = forceNormal ? NORMAL : card.mode;
			card.quad.data = color;
			card.image.data = sourceTextures[colorIndex];
			card.quad.alpha = card.image.alpha = alpha;
			// 在同一个对象上来回设置，以便观察滤镜清除和合批路径切换。
			card.quad.blendMode = card.image.blendMode = mode;
			for (column in 0...card.reference.length)
				card.reference[column].data = BlendReference.composite(backgrounds[column], color, alpha, mode);
		}
		status.data = "上方色块：alpha="
			+ alpha
			+ "，源色=#"
			+ StringTools.hex(color, 6)
			+ (forceNormal ? "；正在强制全部 NORMAL，格子标题保留原模式。" : "；正在使用各格标题对应的模式。")
			+ " 下方三组应与各自参考图一致。";
	}

	private function buildLayerCases():Void {
		text(this, "透明度分组：棋盘是组外背景，擦除或遮罩不能破坏其他格子", 24, 666, 1152, 24, 18);
		for (index in 0...3) {
			var panel = new Sprite();
			panel.x = 24 + index * 388;
			panel.y = 698;
			addChild(panel);
			addQuad(panel, 0, 0, 376, 132, 0x222e40);
			var title = index == 0 ? "LAYER + 父级 alpha=0.5" : (index == 1 ? "LAYER → ALPHA" : "LAYER → ERASE");
			text(panel, title, 10, 5, 356, 24, 16);
			text(panel, "实际", 16, 30, 112, 20, 12);
			text(panel, "CPU 参考", 146, 30, 112, 20, 12);
			var checker = bitmap(112, 64, (x, y) -> 0xff000000 | BlendReference.checker(x, y));
			addImage(panel, checker, 16, 52);
			var group = new Sprite();
			group.x = 16;
			group.y = 52;
			group.blendMode = LAYER;
			panel.addChild(group);
			if (index == 0) {
				group.alpha = 0.5;
				addQuad(group, 0, 0, 74, 44, 0xe85970);
				addQuad(group, 38, 20, 74, 44, 0x40b8e0);
				addImage(panel, bitmap(112, 64, (x, y) -> {
					var back = BlendReference.checker(x, y);
					var source = x >= 38 && y >= 20 ? 0x40b8e0 : (x < 74 && y < 44 ? 0xe85970 : back);
					return 0xff000000 | BlendReference.composite(back, source, 0.5, NORMAL);
				}), 146, 52);
				text(panel, "重叠处\n只衰减一次", 270, 63, 100, 50, 13, 0xe8bf7a);
			} else {
				var erase = index == 2;
				addQuad(group, 0, 0, 56, 64, 0xe8a040);
				addQuad(group, 56, 0, 56, 64, 0x40b8e0);
				var mask = bitmap(112, 64, (x, y) -> (BlendReference.maskAlpha(x, y) << 24) | 0xffffff);
				addImage(group, mask, 0, 0).blendMode = erase ? ERASE : ALPHA;
				addImage(panel, bitmap(112, 64, (x, y) -> {
					var alpha = BlendReference.maskAlpha(x, y) / 255.0;
					return 0xff000000 | BlendReference.composite(BlendReference.checker(x, y), x < 56 ? 0xe8a040 : 0x40b8e0, erase ? 1
						- alpha : alpha, NORMAL);
				}), 146, 52);
				text(panel, erase ? "从左到右\n逐渐擦除" : "从左到右\n逐渐保留", 270, 63, 100, 50, 13, 0xe8bf7a);
			}
		}
	}

	private function buildStateSequence():Void {
		text(this, "状态恢复：每项左侧实绘、右侧参考；所有 NORMAL 必须颜色相同", 24, 842, 1152, 24, 16);
		var sequence:Array<BlendMode> = [NORMAL, ADD, NORMAL, MULTIPLY, NORMAL, SCREEN, NORMAL];
		for (index in 0...sequence.length) {
			var x = 24 + index * 166;
			var mode = sequence[index];
			text(this, Std.string(mode).toUpperCase(), x, 869, 154, 20, 12, 0xb8c9df);
			addQuad(this, x, 893, 68, 24, 0x5080b0);
			var live = addQuad(this, x + 8, 897, 52, 16, 0xd060a0);
			live.alpha = 0.5;
			live.blendMode = mode;
			addQuad(this, x + 76, 893, 68, 24, 0x5080b0);
			addQuad(this, x + 84, 897, 52, 16, BlendReference.composite(0x5080b0, 0xd060a0, 0.5, mode));
		}
	}

	private static function stripeEdge(index:Int):Int {
		return Std.int(index * SURFACE_WIDTH / 3);
	}

	private function stripedBackground(parent:DisplayObjectContainer, x:Float, y:Float):Void {
		for (index in 0...3)
			addQuad(parent, x + stripeEdge(index), y, stripeEdge(index + 1) - stripeEdge(index), SURFACE_HEIGHT, backgrounds[index]);
	}

	/** 纹理只从 CPU 像素生成，避免通过待验证的混合路径生成参考图。 */
	private function bitmap(width:Int, height:Int, pixel:Int->Int->UInt):BitmapData {
		var nativeBitmap = new openfl.display.BitmapData(width, height, true, 0);
		nativeBitmap.lock();
		for (y in 0...height)
			for (x in 0...width)
				nativeBitmap.setPixel32(x, y, pixel(x, y));
		nativeBitmap.unlock();
		var texture = OpenFlBitmapData.fromBitmapData(nativeBitmap);
		textures.push(texture);
		return texture;
	}

	private function addQuad(parent:DisplayObjectContainer, x:Float, y:Float, width:Float, height:Float, color:Int):Quad {
		var quad = new Quad(width, height, color);
		place(parent, quad, x, y);
		return quad;
	}

	private function addImage(parent:DisplayObjectContainer, texture:BitmapData, x:Float, y:Float):Image {
		var image = new Image(texture);
		image.smoothing = false;
		place(parent, image, x, y);
		return image;
	}

	private function place(parent:DisplayObjectContainer, object:DisplayObject, x:Float, y:Float):Void {
		object.x = x;
		object.y = y;
		object.mouseEnabled = false;
		parent.addChild(object);
	}

	private function text(parent:DisplayObjectContainer, value:String, x:Float, y:Float, width:Float, height:Float, size:Int = 16, color:Int = 0xe4edf9):Label {
		var label = new Label(value, new TextFormat(null, size, color));
		label.width = width;
		label.height = height;
		label.wordWrap = false;
		place(parent, label, x, y);
		return label;
	}

	private function action(value:String, x:Float, callback:Void->Void):Void {
		var button = new Box();
		button.x = x;
		button.y = 86;
		button.width = value == "全部 NORMAL / 恢复" ? 198 : 150;
		button.height = 32;
		button.background = new Quad(button.width, 32, 0x365080);
		button.mouseClickEnabled = true;
		button.mouseChildren = false;
		text(button, value, 10, 5, button.width - 20, 24, 14);
		button.addEventListener(MouseEvent.CLICK, (event:MouseEvent) -> {
			event.bubbling = false;
			callback();
		});
		addChild(button);
	}

	override public function dispose():Void {
		super.dispose();
		for (texture in textures)
			texture.dispose();
		textures = [];
		sourceTextures = [];
		cards = [];
	}
}
