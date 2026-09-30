package hx.display;

import hx.events.Event;
import hx.events.MouseEvent;
import hx.layout.AnchorLayout;
import hx.layout.AnchorLayoutData;
import hx.layout.SplitterLayout;

/**
 * 分割条
 * 可拖动的分隔条，用于在面板之间拖拽调整空间分配：
 * - 父容器使用`hx.layout.SplitterLayout`时（推荐，可直接使用`SplitterBox`），拖动会改写相邻面板的布局尺寸，
 *   弹性面板自动吸收剩余空间，可实现类似VSCode的拖拽分栏效果
 * - 父容器为普通容器时，设置`autoResizeNeighbors`为`true`，拖动会直接改变相邻面板的尺寸与位置
 * 拖动过程中会连续派发`Event.CHANGE`，拖动结束时派发`Event.COMPLETE`
 */
@:keep
class Splitter extends Box {
	/**
	 * 拖动轴方向（父容器为`hx.layout.SplitterLayout`时以布局的`direction`为准）：
	 * `HORIZONTAL`为左右拖拽（竖直分割条），`VERTICAL`为上下拖拽（水平分割条）
	 */
	public var direction(get, set):Direction;

	/**
	 * 分割条的视觉对象
	 * 默认为颜色`0x888888`的色块，沿分割条的拉伸方向自动铺满
	 * 同时也是分割条的命中区域，自定义时如需扩大点击范围，请让视觉对象铺满整个分割条区域
	 */
	public var thumb(default, null):DisplayObject;

	/**
	 * 拖动位置，相对本次拖动起点的累计偏移量，受`min`/`max`钳制
	 */
	public var position(get, set):Float;

	/**
	 * 拖动位置下限，`null`表示不限制，默认为`null`
	 */
	public var min:Null<Float> = null;

	/**
	 * 拖动位置上限，`null`表示不限制，默认为`null`
	 */
	public var max:Null<Float> = null;

	/**
	 * 拖动时是否自动调整相邻面板的尺寸与位置，仅在父容器没有`hx.layout.SplitterLayout`时生效，默认为`false`
	 */
	public var autoResizeNeighbors:Bool = false;

	@:noCompletion private var __direction:Direction = Direction.HORIZONTAL;

	@:noCompletion private var __position:Float = 0;

	@:noCompletion private var __dragging:Bool = false;

	@:noCompletion private var __lastStageX:Float = 0;

	@:noCompletion private var __lastStageY:Float = 0;

	/**
	 * 构造一个分割条
	 * @param direction 拖动轴方向，默认为`HORIZONTAL`（左右拖拽）
	 * @param thumb 视觉对象，传入`Int`作为色块颜色，传入`DisplayObject`作为自定义皮肤，默认颜色`0x888888`
	 */
	public function new(?direction:Direction, ?thumb:Dynamic) {
		super();
		if (direction != null) {
			this.__direction = direction;
		}
		this.width = 6;
		this.height = 6;
		if (thumb == null) {
			thumb = 0x888888;
		}
		if (thumb is Int) {
			this.thumb = new Quad(6, 6, thumb);
		} else {
			this.thumb = thumb;
		}
		this.addChild(this.thumb);
		this.refreshThumbLayout();
	}

	override function onInit() {
		super.onInit();
		this.layout = new AnchorLayout();
	}

	/**
	 * 根据当前拖动轴重置视觉对象的拉伸方式
	 */
	private function refreshThumbLayout():Void {
		if (this.thumb == null) {
			return;
		}
		// 竖直分割条上下拉伸铺满，水平分割条左右拉伸铺满
		this.thumb.layoutData = this.__isDragHorizontal() ? AnchorLayoutData.fillVertical() : AnchorLayoutData.fillHorizontal();
	}

	/**
	 * 当前生效的拖动轴是否为左右拖拽
	 * @return 父容器存在`SplitterLayout`时返回其排列方向是否为水平，否则读取自身的`direction`
	 */
	private function __isDragHorizontal():Bool {
		if (this.parent != null && this.parent.layout != null && this.parent.layout is SplitterLayout) {
			return cast(this.parent.layout, SplitterLayout).direction == Direction.HORIZONTAL;
		}
		return this.__direction == Direction.HORIZONTAL;
	}

	override function onStageInit() {
		super.onStageInit();
		this.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
	}

	override function onAddToStage() {
		super.onAddToStage();
		this.stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
	}

	override function onRemoveToStage() {
		super.onRemoveToStage();
		this.stage.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);
		this.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
		this.__dragging = false;
	}

	private function onMouseDown(e:MouseEvent) {
		// 判断命中的是否为分割条自身区域，避免父级容器命中间接触发时误开始拖动
		var hitObject:DisplayObject = e.target;
		while (hitObject != null && hitObject != this) {
			hitObject = hitObject.parent;
		}
		if (hitObject != this) {
			return;
		}
		this.__dragging = true;
		this.__lastStageX = e.stageX;
		this.__lastStageY = e.stageY;
		this.stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
	}

	private function onMouseMove(e:MouseEvent) {
		var horizontal = this.__isDragHorizontal();
		var rawDelta = horizontal ? e.stageX - this.__lastStageX : e.stageY - this.__lastStageY;
		this.__lastStageX = e.stageX;
		this.__lastStageY = e.stageY;
		// min/max钳制
		var target = this.__position + rawDelta;
		if (this.min != null && target < this.min) {
			target = this.min;
		}
		if (this.max != null && target > this.max) {
			target = this.max;
		}
		var delta = target - this.__position;
		if (delta != 0) {
			this.applyDelta(delta);
		}
	}

	private function onMouseUp(e:MouseEvent) {
		if (!this.__dragging) {
			return;
		}
		this.__dragging = false;
		this.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
		this.dispatchEvent(new Event(Event.COMPLETE));
	}

	/**
	 * 应用位移量：优先转移给父容器的`SplitterLayout`，其次按`autoResizeNeighbors`联动相邻面板，最后更新拖动位置
	 * @param delta 沿拖动轴的位移量
	 */
	private function applyDelta(delta:Float):Void {
		var layout = this.parent != null ? this.parent.layout : null;
		if (layout != null && layout is SplitterLayout) {
			cast(layout, SplitterLayout).adjustSplitter(this, delta);
		} else if (this.autoResizeNeighbors) {
			this.resizeNeighbors(delta);
		}
		this.__position += delta;
		this.dispatchEvent(new Event(Event.CHANGE));
	}

	/**
	 * 普通容器中的联动方式：直接改变前后相邻面板的尺寸，并同步平移后继面板与自身
	 * @param delta 沿拖动轴的位移量
	 */
	private function resizeNeighbors(delta:Float):Void {
		if (this.parent == null) {
			return;
		}
		var index = this.parent.getChildIndexAt(this);
		if (index == -1) {
			return;
		}
		var horizontal = this.__isDragHorizontal();
		var prev = index > 0 ? this.parent.getChildAt(index - 1) : null;
		var next = index < this.parent.numChildren - 1 ? this.parent.getChildAt(index + 1) : null;
		if (prev != null) {
			if (horizontal) {
				prev.width += delta;
			} else {
				prev.height += delta;
			}
		}
		if (next != null) {
			if (horizontal) {
				next.width -= delta;
				next.x += delta;
			} else {
				next.height -= delta;
				next.y += delta;
			}
		}
		if (horizontal) {
			this.x += delta;
		} else {
			this.y += delta;
		}
	}

	private function get_direction():Direction {
		return this.__direction;
	}

	private function set_direction(value:Direction):Direction {
		this.__direction = value;
		this.refreshThumbLayout();
		return value;
	}

	private function get_position():Float {
		return this.__position;
	}

	private function set_position(value:Float):Float {
		if (this.min != null && value < this.min) {
			value = this.min;
		}
		if (this.max != null && value > this.max) {
			value = this.max;
		}
		var delta = value - this.__position;
		if (delta != 0) {
			this.applyDelta(delta);
		}
		return value;
	}
}
