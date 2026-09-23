package hx.display;

import hx.layout.ILayout;
import hx.layout.IVirtualLayout;
import hx.layout.VerticalLayout;
import hx.utils.SoundManager;
import haxe.Timer;
import hx.events.MouseEvent;
import hx.events.Event;

/**
 * 数据列表渲染器
 */
@:keep
class ListView extends Scroll implements IDataProider<ArrayCollection> {
	/**
	 * 数据列表
	 */
	public var data(get, set):ArrayCollection;

	/**
	 * Item渲染器
	 */
	public var itemRendererRecycler(default, set):DisplayObjectRecycler<Dynamic>;

	private function set_itemRendererRecycler(value:DisplayObjectRecycler<Dynamic>):DisplayObjectRecycler<Dynamic> {
		this.itemRendererRecycler = value;
		this.__dataDirty = true;
		return value;
	}

	public function updateAllData():Void {
		__dataDirty = true;
	}

	private var __data:ArrayCollection;

	private var __dataDirty:Bool = false;

	private var __selectedIndexDirty:Bool = false;

	/**
	 * 切换选择时播放的音效ID
	 */
	public var changedSoundId:String = null;

	/**
	 * 列表是否允许右键点击来选择
	 */
	public var rightClickSelectEnabled:Bool = true;

	public function set_data(value:ArrayCollection):ArrayCollection {
		this.__data = value;
		this.__dataDirty = true;
		this.invalidate();
		return value;
	}

	public function get_data():ArrayCollection {
		return __data;
	}

	override function onInit() {
		super.onInit();
		this.itemRendererRecycler = DisplayObjectRecycler.withClass(DefaultItemRenderer);
		var layout = new VerticalLayout();
		layout.horizontalFill = true;
		this.layout = layout;
		this.addEventListener(MouseEvent.CLICK, onSelectedItem);
		this.addEventListener(MouseEvent.RIGHT_CLICK, onSelectedItem);
	}

	private function onSelectedItem(e:MouseEvent) {
		if (e.type == MouseEvent.RIGHT_CLICK && !rightClickSelectEnabled)
			return;
		var child:DisplayObject = cast e.target;
		var itemRenderer = __getItemRendererByChild(child);
		var index = this.__getItemRendererIndex(itemRenderer);
		if (index >= 0) {
			this.selectedIndex = index;
			if (changedSoundId != null) {
				SoundManager.getInstance().playEffect(changedSoundId);
			}
		}
	}

	/**
	 * 获得ItemRenderer对应的数据索引，虚拟列表的子对象索引与数据索引并不一致
	 */
	private function __getItemRendererIndex(itemRenderer:DisplayObject):Int {
		if (this.virtual) {
			for (index => renderer in this.__virtualItems) {
				if (renderer == itemRenderer) {
					return index;
				}
			}
			return -1;
		}
		return this.getChildIndexAt(itemRenderer);
	}

	private function __getItemRendererByChild(child:DisplayObject):DisplayObject {
		if (child.parent != null && child.parent != box) {
			return __getItemRendererByChild(child.parent);
		}
		return child;
	}

	/**
	 * 当前选择的数据索引
	 */
	public var selectedIndex(default, set):Int = -1;

	private function set_selectedIndex(value:Int):Int {
		this.selectedIndex = value;
		if (this.virtual) {
			// 虚拟列表只需要刷新可见Item的选中状态
			this.__virtualSelectedDirty = true;
		} else {
			this.__dataDirty = true;
		}
		this.__selectedIndexDirty = true;
		this.dispatchEvent(new Event(Event.CHANGE));
		return value;
	}

	/**
	 * 当前选择的数据
	 */
	public var selectedItem(get, set):Dynamic;

	private function get_selectedItem():Dynamic {
		if (this.__data != null && this.selectedIndex >= 0 && this.selectedIndex < this.__data.source.length) {
			return this.__data.source[this.selectedIndex];
		}
		return null;
	}

	private function set_selectedItem(value:Dynamic):Dynamic {
		this.selectedIndex = this.__data.source.indexOf(value);
		return value;
	}

	override function onUpdate(dt:Float) {
		super.onUpdate(dt);
		if (this.virtual) {
			// 虚拟列表：由虚拟布局排列Item与占位对象
			this.__updateVirtual();
			return;
		}
		if (this.__virtualReady) {
			// 虚拟布局已经被替换为普通布局，清理虚拟列表创建的子对象
			this.__clearChildren();
		}
		if (this.__dataDirty) {
			// 删除所有容器
			this.__clearChildren();
			// 重新创建所有容器
			if (__data != null) {
				for (i in 0...__data.source.length) {
					var itemRenderer:DisplayObject = itemRendererRecycler.create();
					this.addChild(itemRenderer);
					if (itemRenderer is IDataProider) {
						var proider:IDataProider<Dynamic> = cast itemRenderer;
						proider.data = __data.source[i];
					}
					if (itemRenderer is ISelectProider) {
						var proider:ISelectProider = cast itemRenderer;
						proider.selected = selectedIndex == i;
					}
				}
				if (__selectedIndexDirty && this.selectedIndex >= 0) {
					this.updateLayout();
				}
			}
			this.__dataDirty = false;
			if (autoVisible) {
				Timer.delay(this.invalidate, 16);
			}
		}
	}

	public function scrollToCurrentSelectedItem():Void {
		this.scrollToIndex(this.selectedIndex, 0);
	}

	/**
	 * 滚动到指定的数据索引
	 * @param index 数据索引
	 * @param duration 滚动时间，`0`表示立即定位
	 */
	public function scrollToIndex(index:Int, duration:Float = 0.2):Void {
		if (index < 0 || this.__data == null || index >= this.__data.source.length) {
			return;
		}
		var x = this.scrollX;
		var y = this.scrollY;
		if (this.virtual) {
			var layout = this.__virtualLayout;
			var slot = layout.slotSize;
			if (slot <= 0) {
				return;
			}
			if (layout.horizontal) {
				x = -index * slot;
			} else {
				y = -index * slot;
			}
		} else {
			var itemRenderer = this.getChildAt(index);
			if (itemRenderer == null) {
				return;
			}
			x = -itemRenderer.x;
			y = -itemRenderer.y;
		}
		if (duration <= 0) {
			var data = getMoveingToData({scrollX: x, scrollY: y});
			this.scrollX = data.scrollX;
			this.scrollY = data.scrollY;
		} else {
			this.scrollTo(x, y, duration);
		}
	}

	// ============================== 虚拟列表 ==============================

	/**
	 * 当前是否为虚拟列表
	 *
	 * 当`layout`是虚拟布局（实现了`IVirtualLayout`，例如`VirtualVerticalLayout`、`VirtualHorizontalLayout`）时自动开启：
	 * 只会为可见区域（以及`virtualBufferCount`条缓冲）创建ItemRenderer，没有被渲染的数据区域由布局的占位对象支撑滚动范围，
	 * 因此可以承载成千上万条数据，滚动过程中会自动复用`itemRendererRecycler`对象池中的ItemRenderer。
	 *
	 * 注意：
	 * - Item尺寸由虚拟布局的`itemSize`指定，必须大于`0`
	 * - 列表方向由虚拟布局决定，纵向使用`VirtualVerticalLayout`，横向使用`VirtualHorizontalLayout`
	 * - 虚拟模式下`children`中会额外存在一个占位对象，请不要把`children`直接当作数据项来遍历
	 */
	public var virtual(get, never):Bool;

	private function get_virtual():Bool {
		return this.__virtualLayout != null;
	}

	/**
	 * 虚拟列表在可见区域上下（左右）额外渲染的Item数量，可以减少快速滑动时的空白，默认`1`
	 */
	public var virtualBufferCount:Int = 1;

	/**
	 * 当前的虚拟布局，`null`表示`layout`不是虚拟布局
	 */
	private var __virtualLayout:IVirtualLayout = null;

	/**
	 * 数据索引与ItemRenderer的映射（虚拟列表）
	 */
	private var __virtualItems:Map<Int, DisplayObject> = new Map();

	/**
	 * 虚拟布局的占位对象，它不属于ItemRenderer，不能回收到Item的对象池中
	 */
	private var __virtualSpacer:DisplayObject = null;

	/**
	 * 可见的数据索引区间，`last`小于`first`时表示没有数据
	 */
	private var __virtualRange:{first:Int, last:Int} = {first: -1, last: -1};

	/**
	 * 最近一次渲染时布局的槽位尺寸，用于检测Item尺寸与间距的变化
	 */
	private var __virtualSlotSize:Float = -1;

	/**
	 * 最近一次渲染时的数据总量
	 */
	private var __virtualTotal:Int = -1;

	/**
	 * 最近一次渲染的可见数据索引区间
	 */
	private var __virtualFirst:Int = -1;

	private var __virtualLast:Int = -1;

	/**
	 * 最近一次渲染时列表的尺寸，用于检测列表尺寸变化
	 */
	private var __virtualWidth:Float = -1;

	private var __virtualHeight:Float = -1;

	/**
	 * 虚拟列表是否已接管子对象
	 */
	private var __virtualReady:Bool = false;

	/**
	 * 虚拟列表的选中状态是否发生变化
	 */
	private var __virtualSelectedDirty:Bool = false;

	override function set_layout(value:ILayout):ILayout {
		var result = super.set_layout(value);
		this.__virtualLayout = value is IVirtualLayout ? cast value : null;
		this.__dataDirty = true;
		this.invalidate();
		return result;
	}

	/**
	 * 虚拟列表渲染，只为可见区域创建ItemRenderer
	 *
	 * 数据的可见区间、Item的位置与尺寸、占位对象都由虚拟布局负责，ListView只负责ItemRenderer的创建、回收与数据绑定
	 */
	private function __updateVirtual():Void {
		var layout = this.__virtualLayout;
		var total = this.__data != null ? this.__data.source.length : 0;
		var slotSize = layout.slotSize;

		var dataDirty = this.__dataDirty;
		var selectedDirty = this.__virtualSelectedDirty || dataDirty;
		this.__dataDirty = false;
		this.__selectedIndexDirty = false;
		this.__virtualSelectedDirty = false;

		// 计算可见（含缓冲）的数据索引区间
		var offset = layout.horizontal ? -this.scrollX : -this.scrollY;
		var viewport = layout.horizontal ? this.width : this.height;
		layout.getVisibleRange(this.__virtualRange, total, offset, viewport, this.virtualBufferCount);
		var first = this.__virtualRange.first;
		var last = this.__virtualRange.last;

		// 可见区间、数据、槽位尺寸与列表尺寸都没有变化时，不需要刷新
		if (!dataDirty && !selectedDirty && !this.__virtualSizeChanged() && slotSize == this.__virtualSlotSize
			&& total == this.__virtualTotal && first == this.__virtualFirst && last == this.__virtualLast) {
			return;
		}
		if (!this.__virtualReady) {
			// 由普通模式进入虚拟模式时需要先清理普通模式创建的全部ItemRenderer
			this.__clearChildren();
		}
		this.__virtualFirst = first;
		this.__virtualLast = last;
		this.__virtualSlotSize = slotSize;
		this.__virtualTotal = total;
		this.__virtualWidth = this.width;
		this.__virtualHeight = this.height;

		// 回收可见区间之外的ItemRenderer
		var expired:Array<Int> = [];
		for (index in this.__virtualItems.keys()) {
			if (index < first || index > last) {
				expired.push(index);
			}
		}
		for (index in expired) {
			var renderer = this.__virtualItems.get(index);
			this.__virtualItems.remove(index);
			renderer.parent.removeChild(renderer);
			this.itemRendererRecycler.release(renderer);
		}

		// 创建（或者复用对象池中的）ItemRenderer，并绑定数据
		for (index in first...last + 1) {
			var renderer = this.__virtualItems.get(index);
			var isNewRenderer = renderer == null;
			if (isNewRenderer) {
				renderer = this.itemRendererRecycler.create();
				this.__virtualItems.set(index, renderer);
				this.addChild(renderer);
			}
			if (isNewRenderer || dataDirty) {
				this.__setVirtualRendererData(renderer, index);
			}
			if (isNewRenderer || selectedDirty) {
				this.__setVirtualRendererSelected(renderer, index);
			}
		}

		// Item的位置与尺寸、占位对象的内容尺寸都交给虚拟布局计算
		layout.setItems(this.__virtualItems, total);
		var spacer = layout.spacer;
		if (spacer.parent == null) {
			this.addChild(spacer);
		}
		this.__virtualSpacer = spacer;
		this.updateLayout();

		// 内容尺寸不再由ItemRenderer决定，失效Scroll的内容尺寸缓存
		this.__cachedMaxSize = null;
		this.__virtualReady = true;
	}

	/**
	 * 列表尺寸是否发生变化
	 */
	private function __virtualSizeChanged():Bool {
		return this.__virtualWidth != this.width || this.__virtualHeight != this.height;
	}

	/**
	 * 绑定ItemRenderer的数据
	 */
	private function __setVirtualRendererData(renderer:DisplayObject, index:Int):Void {
		if (renderer is IDataProider) {
			var proider:IDataProider<Dynamic> = cast renderer;
			proider.data = this.__data.source[index];
		}
	}

	/**
	 * 绑定ItemRenderer的选中状态
	 */
	private function __setVirtualRendererSelected(renderer:DisplayObject, index:Int):Void {
		if (renderer is ISelectProider) {
			var proider:ISelectProider = cast renderer;
			proider.selected = this.selectedIndex == index;
		}
	}

	/**
	 * 清理列表创建的所有子对象，全部回收到ItemRenderer的对象池
	 */
	private function __clearChildren():Void {
		var i = this.children.length;
		while (i-- > 0) {
			var child = this.children[i];
			if (child.parent != null) {
				child.parent.removeChild(child);
			}
			if (child == this.__virtualSpacer) {
				// 占位对象不是ItemRenderer，不能放进对象池
				continue;
			}
			this.itemRendererRecycler.release(child);
		}
		this.__virtualSpacer = null;
		this.__virtualItems = new Map();
		this.__virtualFirst = -1;
		this.__virtualLast = -1;
		this.__virtualSlotSize = -1;
		this.__virtualTotal = -1;
		this.__virtualWidth = -1;
		this.__virtualHeight = -1;
		this.__virtualReady = false;
	}
}

/**
 * 默认的ItemRenderer渲染器
 */
class DefaultItemRenderer extends ItemRenderer {
	public var label:Label = new Label();

	override function setData(value:Dynamic) {
		super.setData(value);
		this.label.data = Std.string(value);
	}

	override function onInit() {
		super.onInit();
		this.label.data = "ItemRenderer";
		this.addChild(this.label);
	}
}
