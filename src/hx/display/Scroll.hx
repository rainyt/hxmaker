package hx.display;

import hx.events.MouseEvent;
import hx.geom.Point;
import hx.geom.Rectangle;
import hx.layout.AnchorLayout;
import motion.Actuate;

/**
 * 滚动遮罩支持的容器
 */
class Scroll extends BoxContainer {
	public var quad = new Quad(0, 0, 0xffffff);

	private var __scrollX:Float = 0;

	private var __scrollY:Float = 0;

	public var scrollX(get, set):Float;

	public function new(isOverScrollEnbaled:Bool = true) {
		this.isOverScrollEnbaled = isOverScrollEnbaled;
		super();
	}

	private function get_scrollX():Float {
		return this.__scrollX;
	}

	private function set_scrollX(value:Float):Float {
		this.setDirty();
		this.__scrollX = value;
		this.box.x = value;
		return value;
	}

	public var scrollY(get, set):Float;

	private function get_scrollY():Float {
		return this.__scrollY;
	}

	private function set_scrollY(value:Float):Float {
		this.setDirty();
		this.__scrollY = value;
		this.box.y = value;
		return value;
	}

	/**
	 * 背景颜色
	 */
	public var backgroundColor(get, set):Int;

	private function get_backgroundColor():Int {
		return quad.data;
	}

	private function set_backgroundColor(value:Int):Int {
		quad.data = value;
		return value;
	}

	/**
	 * 背景透明度
	 */
	public var backgroundAlpha(get, set):Float;

	private function get_backgroundAlpha():Float {
		return quad.alpha;
	}

	private function set_backgroundAlpha(value:Float):Float {
		quad.alpha = value;
		return value;
	}

	override function onInit() {
		super.onInit();
		#if !zide
		quad.alpha = 0;
		#end
		this.layout = new AnchorLayout();
		// box.layoutData = AnchorLayoutData.fill();
		this.maskRect = new Rectangle(0, 0, 100, 100);
		this.width = 100;
		this.height = 100;
		this.background = quad;
		this.mouseClickEnabled = true;
	}

	override function set_width(value:Float):Float {
		this.maskRect.width = value;
		this.quad.width = value;
		return super.set_width(value);
	}

	override function set_height(value:Float):Float {
		this.maskRect.height = value;
		this.quad.height = value;
		return super.set_height(value);
	}

	override function addChild(child:DisplayObject) {
		setDirty();
		super.addChild(child);
	}

	override function addChildAt(child:DisplayObject, index:Int) {
		setDirty();
		super.addChildAt(child, index);
	}

	override function onAddToStage() {
		super.onAddToStage();
		if (!this.hasEventListener(MouseEvent.MOUSE_DOWN)) {
			this.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
			this.addEventListener(MouseEvent.MOUSE_WHEEL, onMouseWheel);
			this.stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
			this.stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
		}
	}

	override function onRemoveToStage() {
		super.onRemoveToStage();
		if (this.hasEventListener(MouseEvent.MOUSE_DOWN)) {
			this.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
			this.removeEventListener(MouseEvent.MOUSE_WHEEL, onMouseWheel);
			this.stage.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);
			this.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
		}
	}

	private var startX:Float = 0;

	private var startY:Float = 0;

	private var __lastStepX:Float = 0;

	private var __lastStepY:Float = 0;

	private var __down:Bool = false;

	/**
	 * 横向滑动
	 */
	public var scrollXEnable:Bool = true;

	/**
	 * 纵向滑动
	 */
	public var scrollYEnable:Bool = true;

	/**
	 * 是否自动隐藏窗口外的显示对象，该接口会自动影响显示对象的`visible`属性，默认为`false`
	 */
	public var autoVisible(default, set):Bool = false;

	/**
	 * 垂直滚动条
	 */
	public var vScrollBar(default, set):IScrollBar;

	private function set_vScrollBar(value:IScrollBar):IScrollBar {
		this.vScrollBar = value;
		value.scroll = this;
		return value;
	}

	/**
	 * 横向滚动条
	 */
	public var hScrollBar(default, set):IScrollBar;

	private function set_hScrollBar(value:IScrollBar):IScrollBar {
		this.hScrollBar = value;
		value.scroll = this;
		return value;
	}

	private function set_autoVisible(value:Bool):Bool {
		this.autoVisible = value;
		this.setDirty();
		return value;
	}

	override function onUpdate(dt:Float) {
		super.onUpdate(dt);

		updateScrollPosition();

		if (this.autoVisible && __dirty) {
			if (this.vScrollBar != null) {
				this.vScrollBar.measure();
			}
			if (this.hScrollBar != null) {
				this.hScrollBar.measure();
			}
			var maskRect = new Rectangle(0, 0, this.width, this.height);
			var counts = 0;
			for (i in 0...this.numChildren) {
				var child:DisplayObject = this.getChildAt(i);
				if (child == null)
					continue;
				var testX = child.x + this.scrollX;
				var testY = child.y + this.scrollY;
				var testHeight = child.height;
				var testWidth = child.width;
				if (testY + testHeight <= maskRect.y
					|| testX + testWidth <= maskRect.x
					|| testY >= maskRect.y + maskRect.height
					|| testX >= maskRect.x + maskRect.width) {
					child.visible = false;
				} else {
					child.visible = true;
				}
				if (child.visible) {
					counts++;
				}
			}
		}
	}

	public var isOverScrollEnbaled:Bool = true; // 是否开启overscroll效果

	public var bounceBackTime:Float = 0.35; // 回弹持续时间

	public var deceleration:Float = 0.75; // 减速因子

	private var freeSlideDecelerationAfterEnterOverScroll:Float = 0.89; // 自由滑动，并且超出版边后的减速因子

	private var velocity:Point; // 惯性

	private var shouldFreeSlideX:Bool = false;
	private var shouldFreeSlideY:Bool = false;

	private var freeOverScrollMaxDistanceX:Float = -1; // 自由滑动，并且超出版边的最大距离x
	private var freeOverScrollMaxDistanceY:Float = -1; // 自由滑动，并且超出版边的最大距离y

	private static inline var freeOverScrollMaxDistanceMultiplier = 2;

	private function updateScrollPosition() {
		if (!shouldFreeSlideX && !shouldFreeSlideY) {
			return;
		}

		var maxSize = this.getMaxSize();

		if (shouldFreeSlideX) {
			this.scrollX -= velocity.x;
			var overScrollSideHorizontal = tryGetOverScrollSide(maxSize.x, HORIZONTAL);
			if (overScrollSideHorizontal == NONE) {
				velocity.x *= deceleration;
			} else {
				if (freeOverScrollMaxDistanceX == -1) {
					freeOverScrollMaxDistanceX = Math.abs(velocity.x) * freeOverScrollMaxDistanceMultiplier;
				}

				if (this.scrollX >= freeOverScrollMaxDistanceX || Math.abs(velocity.x) < 0.001) {
					this.scrollX = freeOverScrollMaxDistanceX;
					shouldFreeSlideX = false;
				} else if (this.scrollX <= -maxSize.x - freeOverScrollMaxDistanceX || Math.abs(velocity.x) < 0.001) {
					this.scrollX = -maxSize.x - freeOverScrollMaxDistanceX;
					shouldFreeSlideX = false;
				}

				if (!shouldFreeSlideX) {
					Actuate.tween(this, bounceBackTime, {
						scrollX: overScrollSideHorizontal == LEFT ? 0 : -maxSize.x
					});
				}

				velocity.x *= freeSlideDecelerationAfterEnterOverScroll;
			}

			velocity.x = Math.abs(velocity.x) <= 1.3 ? 0 : velocity.x;
			if (velocity.x == 0) {
				shouldFreeSlideX = false;
			}
		}

		if (shouldFreeSlideY) {
			this.scrollY -= velocity.y;
			var overScrollSideVertical = tryGetOverScrollSide(maxSize.y, VERTICAL);
			if (overScrollSideVertical == NONE) {
				velocity.y *= deceleration;
			} else {
				if (freeOverScrollMaxDistanceY == -1) {
					freeOverScrollMaxDistanceY = Math.abs(velocity.y) * 2;
				}

				if (this.scrollY >= freeOverScrollMaxDistanceY || Math.abs(velocity.y) < 0.001) {
					this.scrollY = freeOverScrollMaxDistanceY;
					shouldFreeSlideY = false;
				} else if (this.scrollY <= -maxSize.y - freeOverScrollMaxDistanceY || Math.abs(velocity.y) < 0.001) {
					this.scrollY = -maxSize.y - freeOverScrollMaxDistanceY;
					shouldFreeSlideY = false;
				}

				if (!shouldFreeSlideY) {
					Actuate.tween(this, bounceBackTime, {
						scrollY: overScrollSideVertical == TOP ? 0 : -maxSize.y
					});
				}

				velocity.y *= freeSlideDecelerationAfterEnterOverScroll;
			}

			velocity.y = Math.abs(velocity.y) <= 1.3 ? 0 : velocity.y;
			if (velocity.y == 0) {
				shouldFreeSlideY = false;
			}
		}
	}

	private function stopFreeSliding() {
		shouldFreeSlideX = false;
		shouldFreeSlideY = false;
		freeOverScrollMaxDistanceX = -1;
		freeOverScrollMaxDistanceY = -1;
		Actuate.stop(this);
	}

	private function stopScroll():Void {
		Actuate.stop(this);
	}

	private function onMouseWheel(e:MouseEvent) {
		// 鼠标滚动支持
		var data = getMoveingToData({
			scrollY: this.scrollY + e.delta * 0.1,
			scrollX: this.scrollX
		});
		// this.scrollY = data.scrollY;
		Actuate.tween(this, 0.1, getMoveingToData(data));
	}

	private function onMouseDown(e:MouseEvent) {
		this.startX = e.stageX;
		this.startY = e.stageY;
		this.__lastStepX = 0;
		this.__lastStepY = 0;
		__down = true;

		if (!isOverScrollEnbaled) {
			this.stopScroll();
		} else {
			this.stopFreeSliding();
		}
	}

	private function onMouseUp(e:MouseEvent) {
		if (__down) {
			__down = false;
			if (!isOverScrollEnbaled) {
				var time = 0.5;
				Actuate.tween(this, time, getMoveingToData({
					scrollX: scrollX - __lastStepX / time * 4,
					scrollY: scrollY - __lastStepY / time * 4
				}));
			} else {
				velocity = new Point(__lastStepX, __lastStepY);

				velocity.x = Math.abs(velocity.x) <= 1.3 ? 0 : velocity.x;
				velocity.y = Math.abs(velocity.y) <= 1.3 ? 0 : velocity.y;

				var maxSize = this.getMaxSize();

				var overScrollSideHorizontal = tryGetOverScrollSide(maxSize.x, HORIZONTAL);
				var overScrollSideVertical = tryGetOverScrollSide(maxSize.y, VERTICAL);

				if (overScrollSideHorizontal == NONE) { // 惯性

					shouldFreeSlideX = velocity.x != 0;
					freeOverScrollMaxDistanceX = -1;
				} else { // 弹回

					Actuate.tween(this, bounceBackTime, {
						scrollX: overScrollSideHorizontal == LEFT ? 0 : -maxSize.x
					});
				}

				if (overScrollSideVertical == NONE) { // 惯性

					shouldFreeSlideY = velocity.y != 0;
					freeOverScrollMaxDistanceY = -1;
				} else { // 弹回

					Actuate.tween(this, bounceBackTime, {
						scrollY: overScrollSideVertical == TOP ? 0 : -maxSize.y
					});
				}
			}
		}
	}

	public var contentWidth(get, never):Float;

	private function get_contentWidth():Float {
		var ret = box.__getBounds();
		return ret.width;
	}

	public var contentHeight(get, never):Float;

	private function get_contentHeight():Float {
		var ret = box.__getBounds();
		return ret.height;
	}

	private function getMoveingToData(data:{scrollX:Float, scrollY:Float}):{scrollX:Float, scrollY:Float} {
		var ret = box.__getBounds();
		var maxWidth = ret.width - this.width;
		var maxHeight = ret.height - this.height;
		if (!scrollXEnable || data.scrollX > 0 || maxWidth < 0) {
			data.scrollX = 0;
		} else if (data.scrollX < -maxWidth) {
			data.scrollX = -maxWidth;
		}
		if (!scrollYEnable || data.scrollY > 0 || maxHeight < 0) {
			data.scrollY = 0;
		} else if (data.scrollY < -maxHeight) {
			data.scrollY = -maxHeight;
		}
		return data;
	}

	private function onMouseMove(e:MouseEvent) {
		if (!__down)
			return;

		var maxSize = this.getMaxSize();
		var maxWidth = maxSize.x;
		var maxHeight = maxSize.y;

		this.__lastStepX = this.startX - e.stageX;
		this.__lastStepY = this.startY - e.stageY;
		this.startX = e.stageX;
		this.startY = e.stageY;

		if (!isOverScrollEnbaled) {
			// 原本的逻辑
			this.scrollX -= __lastStepX;
			this.scrollY -= __lastStepY;

			if (this.scrollX > 0 || maxWidth < 0) {
				this.scrollX = 0;
				this.__lastStepX = 0;
			} else if (this.scrollX < -maxWidth) {
				this.scrollX = -maxWidth;
				this.__lastStepX = 0;
			}

			if (this.scrollY > 0 || maxHeight < 0) {
				this.scrollY = 0;
				this.__lastStepY = 0;
			} else if (this.scrollY < -maxHeight) {
				this.scrollY = -maxHeight;
				this.__lastStepY = 0;
			}
		} else {
			// 如果scrollXY超出版边，使用橡皮筋效果限制转移距离
			if (maxWidth > 0 && scrollXEnable)
				this.scrollX -= (tryGetOverScrollSide(maxWidth,
					HORIZONTAL) != NONE) ? __lastStepX != 0 ? rubberBandDistance(__lastStepX, this.width) : 0 : __lastStepX;
			if (maxHeight > 0 && scrollYEnable)
				this.scrollY -= (tryGetOverScrollSide(maxHeight,
					VERTICAL) != NONE) ? __lastStepY != 0 ? rubberBandDistance(__lastStepY, this.height) : 0 : __lastStepY;
		}
	}

	/**
	 * 获取可活动空间大小
	 */
	private function getMaxSize():Point {
		var ret = box.__getBounds();
		if (!scrollYEnable)
			ret.height = 0;
		if (!scrollXEnable)
			ret.width = 0;
		return new Point(ret.width - this.width, ret.height - this.height);
	}

	/**
	 * 模拟橡皮筋拉动距离
	 */
	private function rubberBandDistance(distance:Float, dimension:Float):Float {
		var constant:Float = 0.35;
		return (distance * constant * dimension) / (dimension + constant * Math.abs(distance));
	}

	/**
	 * 判断是否超出版边
	 */
	private function tryGetOverScrollSide(maxSpace:Float, scrollDirection:ScrollDirection):OverScrollSide {
		if (scrollDirection == HORIZONTAL) {
			if (this.scrollX > 0 || maxSpace < 0) {
				return LEFT;
			} else if (this.scrollX < -maxSpace) {
				return RIGHT;
			}
			return NONE;
		} else {
			if (this.scrollY > 0 || maxSpace < 0) {
				return TOP;
			} else if (this.scrollY < -maxSpace) {
				return DOWN;
			}
		}
		return NONE;
	}
}

/**
 * 拖拽方向
 */
enum ScrollDirection {
	VERTICAL;
	HORIZONTAL;
}

/**
 * 超出版边的位置
 */
enum OverScrollSide {
	TOP;
	LEFT;
	RIGHT;
	DOWN;
	NONE;
}
