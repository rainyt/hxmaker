package hx.display;

import haxe.DynamicAccess;
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

	private var __logDt:Float = 0;

	override function onUpdate(dt:Float) {
		super.onUpdate(dt);

		if (__mouseMoveTargetX != null) {
			this.scrollX += (__mouseMoveTargetX - this.scrollX) * (dt / 0.016) * this.mouseMoveDeceleration;
		}
		if (__mouseMoveTargetY != null) {
			this.scrollY += (__mouseMoveTargetY - this.scrollY) * (dt / 0.016) * this.mouseMoveDeceleration;
		}

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

	/**
	 * 是否开启overscroll效果
	 */
	public var isOverScrollEnbaled:Bool = true;

	/**
	 * 回弹持续时间
	 */
	public var bounceBackTime:Float = 0.35;

	/**
	 * 减速因子
	 */
	public var deceleration:Float = 0.5;

	/**
	 * 自由滑动，并且超出版边后的减速因子
	 */
	private var freeSlideDecelerationAfterEnterOverScroll:Float = 0.89;

	/**
	 * 惯性
	 */
	private var velocity:Point;

	private var shouldFreeSlideX:Bool = false;
	private var shouldFreeSlideY:Bool = false;

	/**
	 * 自由滑动，并且超出版边的最大距离x
	 */
	private var freeOverScrollMaxDistanceX:Float = -1;

	/**
	 * 自由滑动，并且超出版边的最大距离y
	 */
	private var freeOverScrollMaxDistanceY:Float = -1;

	private static inline var freeOverScrollMaxDistanceMultiplier = 2;

	/**
	 * 最大滚动距离x
	 */
	public var maxScrollX(get, never):Float;

	public function get_maxScrollX():Float {
		return this.getMaxSize().x;
	}

	/**
	 * 最大滚动距离y
	 */
	public var maxScrollY(get, never):Float;

	public function get_maxScrollY():Float {
		return this.getMaxSize().y;
	}

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

	private var __scrollOldX:Float = 0;
	private var __scrollOldY:Float = 0;

	private function onMouseDown(e:MouseEvent) {
		this.startX = e.stageX;
		this.startY = e.stageY;
		this.__lastStepX = 0;
		this.__lastStepY = 0;
		__scrollOldX = scrollX;
		__scrollOldY = scrollY;
		__down = true;

		if (!isOverScrollEnbaled) {
			this.stopScroll();
		} else {
			this.stopFreeSliding();
		}
	}

	/**
	 * 鼠标松开时，滚动的时间
	 */
	public var moveUpTime:Float = 3;

	private function onMouseUp(e:MouseEvent) {
		if (__down) {
			__mouseMoveTargetX = null;
			__mouseMoveTargetY = null;
			__down = false;
			if (!isOverScrollEnbaled) {
				var moveData = getMoveingToData({
					scrollX: scrollX - __lastStepX / 0.016 * moveUpTime,
					scrollY: scrollY - __lastStepY / 0.016 * moveUpTime
				});
				Actuate.tween(this, moveUpTime, moveData);
			} else {
				velocity = new Point(__lastStepX, __lastStepY);

				velocity.x = Math.abs(velocity.x) <= 1.3 ? 0 : velocity.x;
				velocity.y = Math.abs(velocity.y) <= 1.3 ? 0 : velocity.y;

				var maxSize = this.getMaxSize();

				var overScrollSideHorizontal = tryGetOverScrollSide(maxSize.x, HORIZONTAL);
				var overScrollSideVertical = tryGetOverScrollSide(maxSize.y, VERTICAL);

				var scrollMoveToX:Null<Float> = null;
				var scrollMoveToY:Null<Float> = null;

				if (overScrollSideHorizontal == NONE) { // 惯性
					shouldFreeSlideX = velocity.x != 0;
					freeOverScrollMaxDistanceX = -1;
				} else {
					// 弹回
					scrollMoveToX = overScrollSideHorizontal == LEFT ? 0 : -maxSize.x;
				}

				if (overScrollSideVertical == NONE) { // 惯性

					shouldFreeSlideY = velocity.y != 0;
					freeOverScrollMaxDistanceY = -1;
				} else {
					// 弹回
					scrollMoveToY = overScrollSideVertical == TOP ? 0 : -maxSize.y;
				}

				Actuate.stop(this);

				var moveingToData = getMoveingToData({
					scrollX: scrollX - __lastStepX / 0.16 * moveUpTime,
					scrollY: scrollY - __lastStepY / 0.16 * moveUpTime
				});

				if (moveingToData.scrollX <= 0 || moveingToData.scrollX >= maxSize.x)
					scrollMoveToX = moveingToData.scrollX;
				else
					scrollMoveToX = null;

				if (moveingToData.scrollY <= 0 || moveingToData.scrollY >= maxSize.y)
					scrollMoveToY = moveingToData.scrollY;
				else
					scrollMoveToY = null;

				var moveData:DynamicAccess<Float> = {};
				if (scrollMoveToX != null)
					moveData["scrollX"] = scrollMoveToX;
				if (scrollMoveToY != null)
					moveData["scrollY"] = scrollMoveToY;

				if (scrollMoveToX != null || scrollMoveToY != null) {
					// 计算滚动距离
					var distanceX = scrollMoveToX != null ? Math.abs(scrollMoveToX - scrollX) : 0;
					var distanceY = scrollMoveToY != null ? Math.abs(scrollMoveToY - scrollY) : 0;
					var maxDistance = Math.max(distanceX, distanceY);

					// 计算滚动速度
					var speed = Math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y);

					// 综合计算动画时间
					var baseTime = bounceBackTime;
					var distanceFactor = Math.min(2, maxDistance / 500);
					var speedFactor = Math.min(1.5, speed / 50);

					var animationTime = baseTime * distanceFactor * speedFactor;
					animationTime = Math.max(0.2, Math.min(1.5, animationTime));

					Actuate.tween(this, animationTime, moveData);
				}
			}
		}
	}

	public var contentWidth(get, never):Float;

	private function get_contentWidth():Float {
		var ret = box.__superGetBounds();
		return ret.width;
	}

	public var contentHeight(get, never):Float;

	private function get_contentHeight():Float {
		var ret = box.__superGetBounds();
		return ret.height;
	}

	private function getMoveingToData(data:{scrollX:Float, scrollY:Float}):{scrollX:Float, scrollY:Float} {
		var ret = box.__superGetBounds();
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

	/**
	 * 当鼠标按下移动时产生的移动X轴
	 */
	private var __mouseMoveTargetX:Null<Float> = null;

	/**
	 * 当鼠标按下移动时产生的移动Y轴
	 */
	private var __mouseMoveTargetY:Null<Float> = null;

	/**
	 * 鼠标移动时的目标移动缓动值
	 */
	public var mouseMoveDeceleration:Float = 0.2;

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
			this.__scrollOldX -= __lastStepX;
			this.__scrollOldX -= __lastStepY;

			if (this.__scrollOldX > 0 || maxWidth < 0) {
				this.__scrollOldX = 0;
				this.__lastStepX = 0;
			} else if (this.__scrollOldX < -maxWidth) {
				this.__scrollOldX = -maxWidth;
				this.__lastStepX = 0;
			}

			if (this.__scrollOldY > 0 || maxHeight < 0) {
				this.__scrollOldY = 0;
				this.__lastStepY = 0;
			} else if (this.__scrollOldY < -maxHeight) {
				this.__scrollOldY = -maxHeight;
				this.__lastStepY = 0;
			}
		} else {
			// 如果scrollXY超出版边，使用橡皮筋效果限制转移距离
			if (maxWidth > 0 && scrollXEnable)
				this.__scrollOldX -= (tryGetOverScrollSide(maxWidth,
					HORIZONTAL) != NONE) ? __lastStepX != 0 ? rubberBandDistance(__lastStepX, this.width) : 0 : __lastStepX;
			if (maxHeight > 0 && scrollYEnable)
				this.__scrollOldY -= (tryGetOverScrollSide(maxHeight,
					VERTICAL) != NONE) ? __lastStepY != 0 ? rubberBandDistance(__lastStepY, this.height) : 0 : __lastStepY;
		}

		this.__mouseMoveTargetX = __scrollOldX;
		this.__mouseMoveTargetY = __scrollOldY;
	}

	/**
	 * 获取可活动空间大小
	 */
	private function getMaxSize():Point {
		var ret = box.__superGetBounds();
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

	/**
	 * 滚动到指定位置
	 */
	public function scrollTo(x:Float, y:Float, duration:Float = 0.2):Void {
		Actuate.tween(this, duration, {
			scrollX: x,
			scrollY: y
		});
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
