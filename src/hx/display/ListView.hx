package hx.display;

import hx.layout.VerticalLayout;
import hx.utils.SoundManager;
import haxe.Timer;
import hx.events.MouseEvent;
import hx.events.Event;

/**
 * 数据列表渲染器
 *
 * 虚拟机制由基类`BaseVirtualList`提供：`layout`设置为虚拟布局（例如`VirtualVerticalLayout`）时自动开启，
 * 只渲染可见区域，可以承载成千上万条数据；普通布局（例如`VerticalLayout`）下渲染全部数据。
 */
@:keep
class ListView extends BaseVirtualList implements IDataProider<ArrayCollection> {
	/**
	 * 数据列表
	 */
	public var data(get, set):ArrayCollection;

	private var __data:ArrayCollection;

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
		var itemRenderer = __getRendererByChild(child);
		var index = this.__getRendererIndex(itemRenderer);
		if (index >= 0) {
			this.selectedIndex = index;
			if (changedSoundId != null) {
				SoundManager.getInstance().playEffect(changedSoundId);
			}
		}
	}

	/**
	 * 当前选择的数据索引
	 */
	public var selectedIndex(default, set):Int = -1;

	private function set_selectedIndex(value:Int):Int {
		this.selectedIndex = value;
		if (this.virtual) {
			// 虚拟列表只需要刷新可见Item的选中状态
			this.__selectionDirty = true;
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

	override function __updateNonVirtual():Void {
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

	// ============================== 虚拟列表的钩子 ==============================

	override function __getVirtualTotal():Int {
		return this.__data != null ? this.__data.source.length : 0;
	}

	override function __bindVirtualRendererData(renderer:DisplayObject, index:Int):Void {
		if (renderer is IDataProider) {
			var proider:IDataProider<Dynamic> = cast renderer;
			proider.data = this.__data.source[index];
		}
	}

	override function __bindVirtualRendererSelected(renderer:DisplayObject, index:Int):Void {
		if (renderer is ISelectProider) {
			var proider:ISelectProider = cast renderer;
			proider.selected = this.selectedIndex == index;
		}
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
