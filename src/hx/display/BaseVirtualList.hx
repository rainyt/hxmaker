package hx.display;

import hx.layout.ILayout;
import hx.layout.IVirtualLayout;

/**
 * 虚拟列表基类
 *
 * 封装虚拟列表的通用机制：`ItemRenderer`的创建、回收与数据绑定，几何计算（可见区间、Item位置与尺寸、占位对象）交给`IVirtualLayout`虚拟布局。
 * 只有可见区域（以及`virtualBufferCount`条缓冲）会创建ItemRenderer，没有被渲染的数据区域由布局的占位对象支撑滚动范围，
 * 因此可以承载成千上万条数据，滚动过程中会自动复用`itemRendererRecycler`对象池中的ItemRenderer。
 *
 * 注意：
 * - `layout`设置为虚拟布局（实现了`IVirtualLayout`，例如`VirtualVerticalLayout`、`VirtualHorizontalLayout`）时自动开启虚拟列表
 * - Item尺寸由虚拟布局决定（`VirtualVerticalLayout`/`VirtualHorizontalLayout`的`itemSize`、`VirtualFlowLayout`的`itemWidth`/`itemHeight`），必须大于`0`
 * - `virtualBufferCount`是额外渲染的行数
 * - 虚拟模式下`children`中会额外存在一个占位对象，请不要把`children`直接当作数据项来遍历
 *
 * 子类需要实现三个钩子：`__getVirtualTotal()`返回数据总量，`__bindVirtualRendererData()`绑定数据，`__bindVirtualRendererSelected()`绑定选中状态。
 */
@:keep
class BaseVirtualList extends Scroll {
	/**
	 * Item渲染器
	 */
	public var itemRendererRecycler(default, set):DisplayObjectRecycler<Dynamic>;

	private function set_itemRendererRecycler(value:DisplayObjectRecycler<Dynamic>):DisplayObjectRecycler<Dynamic> {
		this.itemRendererRecycler = value;
		this.__dataDirty = true;
		return value;
	}

	/**
	 * 数据变化后调用，标记需要刷新（虚拟模式下只刷新可见Item的绑定）
	 */
	public function updateAllData():Void {
		__dataDirty = true;
	}

	private var __dataDirty:Bool = false;

	/**
	 * 选中状态是否发生变化，虚拟模式下只刷新可见Item的选中状态
	 */
	private var __selectionDirty:Bool = false;

	// ============================== 虚拟列表 ==============================

	/**
	 * 当前是否为虚拟列表
	 *
	 * 当`layout`是虚拟布局（实现了`IVirtualLayout`）时为`true`
	 */
	public var virtual(get, never):Bool;

	private function get_virtual():Bool {
		return this.__virtualLayout != null;
	}

	/**
	 * 虚拟列表在可见区域上下（左右）额外渲染的行数，可以减少快速滑动时的空白，默认`1`
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
	 * 最近一次渲染时布局的内容尺寸，用于检测Item尺寸、间距与列数等布局参数的变化
	 */
	private var __virtualContentSize:Float = -1;

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

	override function set_layout(value:ILayout):ILayout {
		var result = super.set_layout(value);
		this.__virtualLayout = value is IVirtualLayout ? cast value : null;
		this.__dataDirty = true;
		this.invalidate();
		return result;
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
		this.__updateNonVirtual();
	}

	/**
	 * 普通布局模式的更新，由子类实现，虚拟模式下不会被调用
	 */
	private function __updateNonVirtual():Void {}

	/**
	 * 滚动到指定的数据索引
	 * @param index 数据索引
	 * @param duration 滚动时间，`0`表示立即定位
	 */
	public function scrollToIndex(index:Int, duration:Float = 0.2):Void {
		if (index < 0) {
			return;
		}
		var x = this.scrollX;
		var y = this.scrollY;
		if (this.virtual) {
			// 主轴位置由布局给出，网格（流）布局中同一行的Item位置相同
			var offset = this.__virtualLayout.getItemOffset(index);
			if (this.__virtualLayout.horizontal) {
				x = -offset;
			} else {
				y = -offset;
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

	/**
	 * 虚拟列表渲染，只为可见区域创建ItemRenderer
	 *
	 * 数据的可见区间、Item的位置与尺寸、占位对象都由虚拟布局负责，列表只负责ItemRenderer的创建、回收与数据绑定
	 */
	private function __updateVirtual():Void {
		var layout = this.__virtualLayout;
		var total = this.__getVirtualTotal();
		// 先把可见Item与数据总量同步给布局，布局的内容尺寸与可见区间都以它为准
		layout.setItems(this.__virtualItems, total);
		var contentSize = layout.contentSize;

		var dataDirty = this.__dataDirty;
		var selectedDirty = this.__selectionDirty || dataDirty;
		this.__dataDirty = false;
		this.__selectionDirty = false;

		// 计算可见（含缓冲）的数据索引区间
		var offset = layout.horizontal ? -this.scrollX : -this.scrollY;
		var viewport = layout.horizontal ? this.width : this.height;
		layout.getVisibleRange(this.__virtualRange, total, offset, viewport, this.virtualBufferCount);
		var first = this.__virtualRange.first;
		var last = this.__virtualRange.last;

		// 可见区间、数据、内容尺寸与列表尺寸都没有变化时，不需要刷新
		if (!dataDirty && !selectedDirty && !this.__virtualSizeChanged() && contentSize == this.__virtualContentSize
			&& total == this.__virtualTotal && first == this.__virtualFirst && last == this.__virtualLast) {
			return;
		}
		if (!this.__virtualReady) {
			// 由普通模式进入虚拟模式时需要先清理普通模式创建的全部ItemRenderer
			this.__clearChildren();
		}
		this.__virtualFirst = first;
		this.__virtualLast = last;
		this.__virtualContentSize = contentSize;
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
				this.__bindVirtualRendererData(renderer, index);
			}
			if (isNewRenderer || selectedDirty) {
				this.__bindVirtualRendererSelected(renderer, index);
			}
		}

		// Item的位置与尺寸、占位对象的内容尺寸都交给虚拟布局计算
		var spacer = layout.spacer;
		if (spacer.parent == null) {
			this.addChild(spacer);
		}
		this.__virtualSpacer = spacer;
		this.updateLayout();

		// 内容尺寸不再由ItemRenderer决定，失效Scroll的内容尺寸缓存
		this.__cachedMaxSize = null;
		// 数据总量变化后钳制滚动位置，避免列表收起后滚动越界出现空白
		this.__clampScroll();
		this.__virtualReady = true;
	}

	/**
	 * 钳制滚动位置到当前内容范围内
	 */
	private function __clampScroll():Void {
		var maxSize = this.getMaxSize();
		if (maxSize.y < 0) {
			maxSize.y = 0;
		}
		if (maxSize.x < 0) {
			maxSize.x = 0;
		}
		if (this.scrollY < -maxSize.y) {
			this.scrollY = -maxSize.y;
		}
		if (this.scrollX < -maxSize.x) {
			this.scrollX = -maxSize.x;
		}
	}

	/**
	 * 列表尺寸是否发生变化
	 */
	private function __virtualSizeChanged():Bool {
		return this.__virtualWidth != this.width || this.__virtualHeight != this.height;
	}

	/**
	 * 获得虚拟列表的数据总量，由子类实现
	 */
	private function __getVirtualTotal():Int {
		return 0;
	}

	/**
	 * 绑定ItemRenderer的数据，由子类实现
	 */
	private function __bindVirtualRendererData(renderer:DisplayObject, index:Int):Void {}

	/**
	 * 绑定ItemRenderer的选中状态，由子类实现
	 */
	private function __bindVirtualRendererSelected(renderer:DisplayObject, index:Int):Void {}

	/**
	 * 获得ItemRenderer对应的数据索引，虚拟列表的子对象索引与数据索引并不一致
	 */
	private function __getRendererIndex(itemRenderer:DisplayObject):Int {
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

	/**
	 * 从子对象向上查找所属的ItemRenderer
	 */
	private function __getRendererByChild(child:DisplayObject):DisplayObject {
		if (child.parent != null && child.parent != box) {
			return __getRendererByChild(child.parent);
		}
		return child;
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
		// 只清空不替换：虚拟布局持有该Map的引用，替换会导致布局读到失效的Map
		this.__virtualItems.clear();
		this.__virtualFirst = -1;
		this.__virtualLast = -1;
		this.__virtualContentSize = -1;
		this.__virtualTotal = -1;
		this.__virtualWidth = -1;
		this.__virtualHeight = -1;
		this.__virtualReady = false;
	}
}
